from pathlib import Path
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.linear_model import Ridge
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder


def validate_borough_series(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["date"] = pd.to_datetime(df["date"]).dt.normalize()
    df = df.sort_values(["borough", "date"]).reset_index(drop=True)

    expected_columns = {"date", "borough", "total_trips"}
    missing_columns = expected_columns - set(df.columns)
    if missing_columns:
        raise ValueError(f"Colonnes manquantes : {sorted(missing_columns)}")

    if df["borough"].isna().any():
        raise ValueError("La colonne borough contient des valeurs NULL.")

    if df["total_trips"].isna().any():
        raise ValueError("La colonne total_trips contient des valeurs NULL.")

    return df

def complete_borough_daily_series(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["date"] = pd.to_datetime(df["date"]).dt.normalize()

    min_date = df["date"].min()
    max_date = df["date"].max()

    boroughs = sorted(df["borough"].dropna().unique())
    full_dates = pd.date_range(min_date, max_date, freq="D")

    full_index = pd.MultiIndex.from_product(
        [boroughs, full_dates],
        names=["borough", "date"],
    )

    completed = (
        df.set_index(["borough", "date"])
        .reindex(full_index)
        .reset_index()
    )

    completed["total_trips"] = completed["total_trips"].fillna(0).astype(int)

    return completed.sort_values(["borough", "date"]).reset_index(drop=True)


def build_calendar_features(df: pd.DataFrame) -> pd.DataFrame:
    x = df.copy()
    x["day_of_week"] = x["date"].dt.dayofweek
    x["month"] = x["date"].dt.month
    x["week_of_year"] = x["date"].dt.isocalendar().week.astype(int)
    x["is_weekend"] = (x["day_of_week"] >= 5).astype(int)
    return x


def add_time_series_features(df: pd.DataFrame, target_column: str) -> pd.DataFrame:
    x = df.copy()
    x = x.sort_values("date").reset_index(drop=True)

    x["lag_7"] = x[target_column].shift(7)
    x["lag_14"] = x[target_column].shift(14)

    x["rolling_mean_7"] = x[target_column].shift(1).rolling(window=7).mean()
    x["rolling_mean_14"] = x[target_column].shift(1).rolling(window=14).mean()

    return x


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


def build_model_pipeline() -> Pipeline:
    preprocess = ColumnTransformer(
        transformers=[
            (
                "cat",
                OneHotEncoder(drop="first", handle_unknown="ignore"),
                ["day_of_week", "month"],
            ),
            (
                "num",
                "passthrough",
                ["is_weekend", "week_of_year", "lag_7", "lag_14", "rolling_mean_7", "rolling_mean_14"],
            ),
        ]
    )

    model = Pipeline([
        ("preprocess", preprocess),
        ("model", Ridge(alpha=1.0)),
    ])

    return model


def predict_future_recursive(
    model: Pipeline,
    history_df: pd.DataFrame,
    forecast_horizon: int,
    borough: str,
) -> pd.DataFrame:
    history = history_df.copy()
    history["date"] = pd.to_datetime(history["date"]).dt.normalize()
    history = history.sort_values("date").reset_index(drop=True)

    future_rows = []

    features = [
        "day_of_week",
        "month",
        "week_of_year",
        "is_weekend",
        "lag_7",
        "lag_14",
        "rolling_mean_7",
        "rolling_mean_14",
    ]

    for _ in range(forecast_horizon):
        current_date = history["date"].max() + pd.Timedelta(days=1)

        temp = pd.DataFrame({"date": [current_date]})
        temp = build_calendar_features(temp)

        temp["lag_7"] = history["total_trips"].iloc[-7]
        temp["lag_14"] = history["total_trips"].iloc[-14]
        temp["rolling_mean_7"] = history["total_trips"].iloc[-7:].mean()
        temp["rolling_mean_14"] = history["total_trips"].iloc[-14:].mean()

        forecast_value = model.predict(temp[features])[0]
        forecast_value = max(0, round(float(forecast_value)))

        new_row = pd.DataFrame({
            "date": [current_date],
            "total_trips": [forecast_value],
        })

        history = pd.concat([history, new_row], ignore_index=True)

        future_rows.append({
            "date": current_date,
            "borough": borough,
            "actual_trips": pd.NA,
            "forecast_trips": int(forecast_value),
            "lower_ci": pd.NA,
            "upper_ci": pd.NA,
            "split": "future",
            "model_name": "ridge_calendar_lags_borough",
        })

    return pd.DataFrame(future_rows)


def main() -> None:
    project_dir = Path(r"C:\dev\nycyellowtaxitrip")

    input_csv = project_dir / "data" / "forecasting" / "daily_borough_demand_prepared.csv"
    output_csv = project_dir / "data" / "forecasting" / "forecast_borough_demand.csv"
    metrics_csv = project_dir / "data" / "forecasting" / "forecast_borough_demand_metrics.csv"

    if not input_csv.exists():
        raise FileNotFoundError(f"Fichier introuvable : {input_csv}")

    df = pd.read_csv(input_csv)
    df = validate_borough_series(df)
    df = complete_borough_daily_series(df)

    holdout_days = 30
    forecast_horizon = 30

    all_outputs = []
    all_metrics = []

    boroughs = sorted(df["borough"].dropna().unique())

    for borough in boroughs:
        borough_df = df[df["borough"] == borough].copy()
        borough_df = borough_df.sort_values("date").reset_index(drop=True)

        borough_df = build_calendar_features(borough_df)
        borough_df = add_time_series_features(borough_df, "total_trips")
        borough_df = borough_df.dropna().reset_index(drop=True)

        if len(borough_df) < 90:
            print(f"[SKIP] Borough '{borough}' ignoré : pas assez d'observations après création des features.")
            continue

        train_df = borough_df.iloc[:-holdout_days].copy()
        test_df = borough_df.iloc[-holdout_days:].copy()

        features = [
            "day_of_week",
            "month",
            "week_of_year",
            "is_weekend",
            "lag_7",
            "lag_14",
            "rolling_mean_7",
            "rolling_mean_14",
        ]

        X_train = train_df[features]
        y_train = train_df["total_trips"]

        X_test = test_df[features]

        model = build_model_pipeline()
        model.fit(X_train, y_train)

        backtest_pred = model.predict(X_test)

        backtest_output = pd.DataFrame({
            "date": test_df["date"],
            "borough": borough,
            "actual_trips": test_df["total_trips"].astype(int),
            "forecast_trips": np.round(backtest_pred).astype(int),
            "lower_ci": pd.NA,
            "upper_ci": pd.NA,
            "split": "backtest",
            "model_name": "ridge_calendar_lags_borough",
        })

        metrics = calculate_metrics(
            actual=backtest_output["actual_trips"],
            forecast=backtest_output["forecast_trips"],
        )

        X_full = borough_df[features]
        y_full = borough_df["total_trips"]

        final_model = build_model_pipeline()
        final_model.fit(X_full, y_full)

        future_output = predict_future_recursive(
            model=final_model,
            history_df=borough_df[["date", "total_trips"]].copy(),
            forecast_horizon=forecast_horizon,
            borough=borough,
        )

        borough_output = pd.concat([backtest_output, future_output], ignore_index=True)
        all_outputs.append(borough_output)

        all_metrics.append({
            "borough": borough,
            "model_name": "ridge_calendar_lags_borough",
            "train_rows": len(train_df),
            "test_rows": len(test_df),
            "forecast_horizon_days": forecast_horizon,
            "mae": round(metrics["MAE"], 2),
            "rmse": round(metrics["RMSE"], 2),
            "mape_pct": round(metrics["MAPE_pct"], 2) if pd.notna(metrics["MAPE_pct"]) else np.nan,
        })

        print(
            f"[OK] {borough} | "
            f"MAE={metrics['MAE']:.2f} | "
            f"RMSE={metrics['RMSE']:.2f} | "
            f"MAPE={metrics['MAPE_pct']:.2f}%"
            if pd.notna(metrics["MAPE_pct"])
            else f"[OK] {borough} | MAE={metrics['MAE']:.2f} | RMSE={metrics['RMSE']:.2f} | MAPE=N/A"
        )

    if not all_outputs:
        raise ValueError("Aucun borough n'a pu être traité.")

    final_output = pd.concat(all_outputs, ignore_index=True)
    metrics_df = pd.DataFrame(all_metrics).sort_values(["mape_pct", "mae"], na_position="last")

    final_output.to_csv(output_csv, index=False)
    metrics_df.to_csv(metrics_csv, index=False)

    print()
    print("Borough demand forecast generated successfully")
    print(f"Input: {input_csv}")
    print(f"Forecast output: {output_csv}")
    print(f"Metrics output: {metrics_csv}")
    print(f"Boroughs processed: {metrics_df['borough'].nunique()}")
    print(f"Overall historical period: {df['date'].min().date()} -> {df['date'].max().date()}")

    if not final_output[final_output["split"] == "future"].empty:
        future_min = final_output.loc[final_output["split"] == "future", "date"].min()
        future_max = final_output.loc[final_output["split"] == "future", "date"].max()
        print(f"Future forecast period: {future_min.date()} -> {future_max.date()}")

    print()
    print("Metrics by borough")
    print(metrics_df.to_string(index=False))


if __name__ == "__main__":
    main()