from pathlib import Path
import pandas as pd


def main():

    project_dir = Path("C:/dev/nycyellowtaxitrip")

    input_csv = project_dir / "data" / "forecasting" / "daily_demand_prepared.csv"
    output_csv = project_dir / "data" / "forecasting" / "daily_revenue_prepared.csv"

    df = pd.read_csv(input_csv)

    df["date"] = pd.to_datetime(df["date"]).dt.normalize()

    revenue_df = df[["date", "total_revenue"]].copy()

    revenue_df = revenue_df.sort_values("date").reset_index(drop=True)

    revenue_df.to_csv(output_csv, index=False)

    print("Revenue forecasting dataset created")
    print(f"Output : {output_csv}")
    print(f"Rows : {len(revenue_df)}")


if __name__ == "__main__":
    main()