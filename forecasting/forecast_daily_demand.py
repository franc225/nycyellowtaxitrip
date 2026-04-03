from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline


def validate_daily_series(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["date"] = pd.to_datetime(df["date"]).dt.normalize()
    df = df.sort_values("date").reset_index(drop=True)

    expected_columns = {"date", "total_trips"}
    missing_columns = expected_columns - set(df.columns)
    if missing_columns:
        raise ValueError(f"Colonnes manquantes : {sorted(missing_columns)}")

    if df["total_trips"].isna().any():
        raise ValueError("La colonne total_trips contient des valeurs NULL.")

    full_range = pd.date_range(df["date"].min(), df["date"].max(), freq="D")
    if len(full_range) != len(df) or not df["date"].equals(pd.Series(full_range, name="date")):
        raise ValueError(
            "La série n'est pas continue au jour le jour. "
            "Vérifie daily_demand_prepared.csv."
        )

    return df


def calculate_metrics(actual: pd.Series, forecast: pd.Series) -> dict:
    actual = actual.astype(float)
    forecast = forecast.astype(float)

    mae = float(np.mean(np.abs(actual - forecast)))
    rmse = float(np.sqrt(np.mean((actual - forecast) ** 2)))

    non_zero_mask = actual != 0
    if non_zero_mask.any():
        mape = float(
            np.mean(
                np.abs((actual[non_zero_mask] - forecast[non_zero_mask]) / actual[non_zero_mask])
            ) * 100
        )
    else:
        mape = np.nan

    return {
        "MAE": mae,
        "RMSE": rmse,
        "MAPE_pct": mape,
    }


def fit_trend_weekday_model(train_df: pd.DataFrame) -> dict:
    model_df = train_df.copy()
    model_df["t"] = np.arange(len(model_df), dtype=float)

    y = model_df["total_trips"].to_numpy(dtype=float)
    t = model_df["t"].to_numpy(dtype=float)

    slope, intercept = np.polyfit(t, y, 1)

    trend = intercept + slope * t
    trend = np.clip(trend, a_min=1.0, a_max=None)

    model_df["trend"] = trend
    model_df["detrended"] = model_df["total_trips"] / model_df["trend"]
    model_df["day_of_week"] = model_df["date"].dt.dayofweek

    weekday_factors = model_df.groupby("day_of_week")["detrended"].mean()
    weekday_factors = weekday_factors / weekday_factors.mean()

    fitted = model_df["trend"] * model_df["day_of_week"].map(weekday_factors)
    residuals = model_df["total_trips"] - fitted
    residual_std = float(residuals.std(ddof=1)) if len(residuals) > 1 else 0.0

    return {
        "slope": float(slope),
        "intercept": float(intercept),
        "weekday_factors": weekday_factors.to_dict(),
        "residual_std": residual_std,
    }


def predict_trend_weekday(model: dict, dates: pd.Series, t_start: int) -> pd.DataFrame:
    pred_df = pd.DataFrame({"date": pd.to_datetime(dates)})
    pred_df["t"] = np.arange(t_start, t_start + len(pred_df), dtype=float)

    pred_df["trend"] = model["intercept"] + model["slope"] * pred_df["t"]
    pred_df["trend"] = pred_df["trend"].clip(lower=1.0)

    pred_df["day_of_week"] = pred_df["date"].dt.dayofweek
    pred_df["weekday_factor"] = pred_df["day_of_week"].map(model["weekday_factors"]).fillna(1.0)

    pred_df["forecast_trips"] = pred_df["trend"] * pred_df["weekday_factor"]

    interval = 1.96 * model["residual_std"]
    pred_df["lower_ci"] = (pred_df["forecast_trips"] - interval).clip(lower=0)
    pred_df["upper_ci"] = pred_df["forecast_trips"] + interval

    pred_df["forecast_trips"] = pred_df["forecast_trips"].round().astype(int)
    pred_df["lower_ci"] = pred_df["lower_ci"].round().astype(int)
    pred_df["upper_ci"] = pred_df["upper_ci"].round().astype(int)

    return pred_df[["date", "forecast_trips", "lower_ci", "upper_ci"]]


def predict_naive_weekly_backtest(train_df: pd.DataFrame, test_df: pd.DataFrame) -> pd.DataFrame:
    combined = pd.concat([train_df, test_df], ignore_index=True).copy()
    combined["date"] = pd.to_datetime(combined["date"]).dt.normalize()
    combined = combined.sort_values("date").reset_index(drop=True)

    combined["forecast_trips"] = combined["total_trips"].shift(7)

    pred_df = combined[combined["date"].isin(test_df["date"])].copy()

    missing = pred_df["forecast_trips"].isna()
    if missing.any():
        missing_dates = pred_df.loc[missing, "date"].dt.date.tolist()
        raise ValueError(
            f"Impossible de prédire certaines dates avec le baseline weekly. "
            f"Dates sans référence J-7 : {missing_dates[:5]}"
        )

    pred_df["forecast_trips"] = pred_df["forecast_trips"].round().astype(int)
    pred_df["lower_ci"] = pd.NA
    pred_df["upper_ci"] = pd.NA

    return pred_df[["date", "forecast_trips", "lower_ci", "upper_ci"]]


def predict_naive_weekly_future(full_df: pd.DataFrame, forecast_horizon: int) -> pd.DataFrame:
    history = full_df.copy()
    history["date"] = pd.to_datetime(history["date"]).dt.normalize()
    history = history.sort_values("date").reset_index(drop=True)

    values_by_date = {
        row.date: int(row.total_trips)
        for row in history.itertuples(index=False)
    }

    future_rows = []
    last_date = history["date"].max()

    for step in range(1, forecast_horizon + 1):
        current_date = (last_date + pd.Timedelta(days=step)).normalize()
        ref_date = (current_date - pd.Timedelta(days=7)).normalize()

        if ref_date not in values_by_date:
            raise ValueError(
                f"Impossible de prédire {current_date.date()} : pas de valeur disponible à J-7."
            )

        forecast = int(round(values_by_date[ref_date]))
        values_by_date[current_date] = forecast

        future_rows.append(
            {
                "date": current_date,
                "forecast_trips": forecast,
                "lower_ci": pd.NA,
                "upper_ci": pd.NA,
            }
        )

    return pd.DataFrame(future_rows)


def build_model_output(
    model_name: str,
    backtest_actual: pd.Series,
    backtest_pred: pd.DataFrame,
    future_pred: pd.DataFrame,
) -> pd.DataFrame:
    backtest_output = backtest_pred.copy()
    backtest_output["actual_trips"] = backtest_actual.astype(int).values
    backtest_output["split"] = "backtest"
    backtest_output["model_name"] = model_name

    future_output = future_pred.copy()
    future_output["actual_trips"] = pd.NA
    future_output["split"] = "future"
    future_output["model_name"] = model_name

    return pd.concat(
        [
            backtest_output[["date", "actual_trips", "forecast_trips", "lower_ci", "upper_ci", "split", "model_name"]],
            future_output[["date", "actual_trips", "forecast_trips", "lower_ci", "upper_ci", "split", "model_name"]],
        ],
        ignore_index=True,
    )

def build_calendar_features(df):
    X = df.copy()

    X["t"] = range(len(X))
    X["day_of_week"] = X["date"].dt.dayofweek
    X["month"] = X["date"].dt.month
    X["week_of_year"] = X["date"].dt.isocalendar().week.astype(int)
    X["is_weekend"] = (X["day_of_week"] >= 5).astype(int)

    return X


def main() -> None:
    project_dir = Path(r"C:\dev\nycyellowtaxitrip")

    input_csv = project_dir / "data" / "forecasting" / "daily_demand_prepared.csv"
    output_csv = project_dir / "data" / "forecasting" / "forecast_daily_demand.csv"
    metrics_csv = project_dir / "data" / "forecasting" / "forecast_daily_demand_metrics.csv"

    if not input_csv.exists():
        raise FileNotFoundError(f"Fichier introuvable : {input_csv}")

    df = pd.read_csv(input_csv)
    df = validate_daily_series(df)

    if len(df) < 90:
        raise ValueError("Pas assez d'observations pour un forecast fiable. Minimum recommandé : 90 jours.")

    holdout_days = 30
    forecast_horizon = 30

    train_df = df.iloc[:-holdout_days].copy()
    test_df = df.iloc[-holdout_days:].copy()

    all_outputs = []
    all_metrics = []

    # Modèle 1 : naive weekly
    naive_backtest = predict_naive_weekly_backtest(train_df, test_df)
    naive_future = predict_naive_weekly_future(df, forecast_horizon)

    naive_metrics = calculate_metrics(
        actual=test_df["total_trips"],
        forecast=naive_backtest["forecast_trips"],
    )

    all_outputs.append(
        build_model_output(
            model_name="naive_weekly",
            backtest_actual=test_df["total_trips"],
            backtest_pred=naive_backtest,
            future_pred=naive_future,
        )
    )

    all_metrics.append({
        "model_name": "naive_weekly",
        "train_rows": len(train_df),
        "test_rows": len(test_df),
        "forecast_horizon_days": forecast_horizon,
        "mae": round(naive_metrics["MAE"], 2),
        "rmse": round(naive_metrics["RMSE"], 2),
        "mape_pct": round(naive_metrics["MAPE_pct"], 2) if pd.notna(naive_metrics["MAPE_pct"]) else np.nan,
    })

    # Modèle 2 : trend + weekday
    tw_model = fit_trend_weekday_model(train_df)

    tw_backtest = predict_trend_weekday(
        model=tw_model,
        dates=test_df["date"],
        t_start=len(train_df),
    )

    tw_metrics = calculate_metrics(
        actual=test_df["total_trips"],
        forecast=tw_backtest["forecast_trips"],
    )

    final_tw_model = fit_trend_weekday_model(df)
    future_dates = pd.date_range(
        start=df["date"].max() + pd.Timedelta(days=1),
        periods=forecast_horizon,
        freq="D",
    )

    tw_future = predict_trend_weekday(
        model=final_tw_model,
        dates=pd.Series(future_dates),
        t_start=len(df),
    )

    all_outputs.append(
        build_model_output(
            model_name="trend_plus_weekday",
            backtest_actual=test_df["total_trips"],
            backtest_pred=tw_backtest,
            future_pred=tw_future,
        )
    )

    all_metrics.append({
        "model_name": "trend_plus_weekday",
        "train_rows": len(train_df),
        "test_rows": len(test_df),
        "forecast_horizon_days": forecast_horizon,
        "mae": round(tw_metrics["MAE"], 2),
        "rmse": round(tw_metrics["RMSE"], 2),
        "mape_pct": round(tw_metrics["MAPE_pct"], 2) if pd.notna(tw_metrics["MAPE_pct"]) else np.nan,
    })

    # -------------------------
    # Model 3 : ridge_calendar
    # -------------------------

    train_feat = build_calendar_features(train_df)
    test_feat = build_calendar_features(test_df)

    features = ["day_of_week", "month", "week_of_year", "is_weekend"]

    X_train = train_feat[features]
    y_train = train_feat["total_trips"]

    X_test = test_feat[features]

    preprocess = ColumnTransformer(
        transformers=[
            (
                "cat",
                OneHotEncoder(drop="first", handle_unknown="ignore"),
                ["day_of_week", "month"],
            ),
            ("num", "passthrough", ["is_weekend", "week_of_year"]),
        ]
    )

    model = Pipeline([
        ("preprocess", preprocess),
        ("model", Ridge(alpha=1.0))
    ])

    model.fit(X_train, y_train)

    ridge_pred = model.predict(X_test)

    ridge_backtest = pd.DataFrame({
        "date": test_df["date"],
        "forecast_trips": np.round(ridge_pred).astype(int),
        "lower_ci": pd.NA,
        "upper_ci": pd.NA
    })

    ridge_metrics = calculate_metrics(
        actual=test_df["total_trips"],
        forecast=ridge_backtest["forecast_trips"]
    )

    all_metrics.append({
        "model_name": "ridge_calendar",
        "train_rows": len(train_df),
        "test_rows": len(test_df),
        "forecast_horizon_days": forecast_horizon,
        "mae": round(ridge_metrics["MAE"], 2),
        "rmse": round(ridge_metrics["RMSE"], 2),
        "mape_pct": round(ridge_metrics["MAPE_pct"], 2)
    })

    final_output = pd.concat(all_outputs, ignore_index=True)
    metrics_df = pd.DataFrame(all_metrics).sort_values("mae")

    final_output.to_csv(output_csv, index=False)
    metrics_df.to_csv(metrics_csv, index=False)

    print("Forecast généré avec succès")
    print(f"Entrée : {input_csv}")
    print(f"Sortie forecast : {output_csv}")
    print(f"Sortie métriques : {metrics_csv}")
    print()
    print("Comparaison des modèles")
    print(metrics_df.to_string(index=False))


if __name__ == "__main__":
    main()