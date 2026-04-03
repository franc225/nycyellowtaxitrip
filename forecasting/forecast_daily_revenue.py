from pathlib import Path
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.linear_model import Ridge
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder


def validate_daily_series(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["date"] = pd.to_datetime(df["date"]).dt.normalize()
    df = df.sort_values("date").reset_index(drop=True)

    expected_columns = {"date", "total_revenue"}
    missing_columns = expected_columns - set(df.columns)
    if missing_columns:
        raise ValueError(f"Colonnes manquantes : {sorted(missing_columns)}")

    if df["total_revenue"].isna().any():
        raise ValueError("La colonne total_revenue contient des valeurs NULL.")

    full_range = pd.date_range(df["date"].min(), df["date"].max(), freq="D")
    if len(full_range) != len(df) or not df["date"].equals(pd.Series(full_range, name="date")):
        raise ValueError(
            "La série revenue n'est pas continue au jour le jour. "
            "Vérifie daily_revenue_prepared.csv."
        )

    return df


def build_calendar_features(df: pd.DataFrame) -> pd.DataFrame:
    x = df.copy()
    x["day_of_week"] = x["date"].dt.dayofweek
    x["month"] = x["date"].dt.month
    x["week_of_year"] = x["date"].dt.isocalendar().week.astype(int)
    x["is_weekend"] = (x["day_of_week"] >= 5).astype(int)
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


def main() -> None:
    project_dir = Path(r"C:\dev\nycyellowtaxitrip")

    input_csv = project_dir / "data" / "forecasting" / "daily_revenue_prepared.csv"
    output_csv = project_dir / "data" / "forecasting" / "forecast_daily_revenue.csv"
    metrics_csv = project_dir / "data" / "forecasting" / "forecast_daily_revenue_metrics.csv"

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

    train_feat = build_calendar_features(train_df)
    test_feat = build_calendar_features(test_df)

    features = ["day_of_week", "month", "week_of_year", "is_weekend"]

    X_train = train_feat[features]
    y_train = train_feat["total_revenue"]

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
        ("model", Ridge(alpha=1.0)),
    ])

    model.fit(X_train, y_train)

    backtest_pred = model.predict(X_test)

    backtest_output = pd.DataFrame({
        "date": test_df["date"],
        "actual_revenue": test_df["total_revenue"].round(2),
        "forecast_revenue": np.round(backtest_pred, 2),
        "split": "backtest",
        "model_name": "ridge_calendar_revenue",
    })

    metrics = calculate_metrics(
        actual=backtest_output["actual_revenue"],
        forecast=backtest_output["forecast_revenue"],
    )

    # Refit sur toute la série pour prévoir le futur
    full_feat = build_calendar_features(df)
    X_full = full_feat[features]
    y_full = full_feat["total_revenue"]

    model.fit(X_full, y_full)

    last_date = df["date"].max()
    future_dates = pd.date_range(
        start=last_date + pd.Timedelta(days=1),
        periods=forecast_horizon,
        freq="D",
    )

    future_df = pd.DataFrame({"date": future_dates})
    future_feat = build_calendar_features(future_df)
    X_future = future_feat[features]

    future_pred = model.predict(X_future)

    future_output = pd.DataFrame({
        "date": future_dates,
        "actual_revenue": pd.NA,
        "forecast_revenue": np.round(future_pred, 2),
        "split": "future",
        "model_name": "ridge_calendar_revenue",
    })

    final_output = pd.concat([backtest_output, future_output], ignore_index=True)
    final_output.to_csv(output_csv, index=False)

    metrics_df = pd.DataFrame([
        {
            "model_name": "ridge_calendar_revenue",
            "train_rows": len(train_df),
            "test_rows": len(test_df),
            "forecast_horizon_days": forecast_horizon,
            "mae": round(metrics["MAE"], 2),
            "rmse": round(metrics["RMSE"], 2),
            "mape_pct": round(metrics["MAPE_pct"], 2) if pd.notna(metrics["MAPE_pct"]) else np.nan,
        }
    ])
    metrics_df.to_csv(metrics_csv, index=False)

    print("Revenue forecast generated successfully")
    print(f"Input: {input_csv}")
    print(f"Forecast output: {output_csv}")
    print(f"Metrics output: {metrics_csv}")
    print(f"Historical period: {df['date'].min().date()} -> {df['date'].max().date()}")
    print(f"Backtest period: {test_df['date'].min().date()} -> {test_df['date'].max().date()}")
    print(f"Future forecast: {future_dates.min().date()} -> {future_dates.max().date()}")
    print(f"MAE: {metrics['MAE']:.2f}")
    print(f"RMSE: {metrics['RMSE']:.2f}")
    print(f"MAPE: {metrics['MAPE_pct']:.2f}%" if pd.notna(metrics["MAPE_pct"]) else "MAPE: N/A")


if __name__ == "__main__":
    main()