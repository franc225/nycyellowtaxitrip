from pathlib import Path
import pandas as pd

def main():

    project_dir = Path(r"C:\dev\nycyellowtaxitrip")

    input_csv = project_dir / "data" / "forecasting" / "daily_borough_demand.csv"
    output_csv = project_dir / "data" / "forecasting" / "daily_borough_demand_prepared.csv"

    df = pd.read_csv(input_csv)

    df["date"] = pd.to_datetime(df["date"])

    df = df.sort_values(["borough", "date"]).reset_index(drop=True)

    df.to_csv(output_csv, index=False)

    print("Borough demand dataset prepared")
    print(f"Rows: {len(df)}")
    print(f"Output: {output_csv}")


if __name__ == "__main__":
    main()