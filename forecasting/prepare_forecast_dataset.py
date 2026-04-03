from pathlib import Path
import pandas as pd


def main() -> None:
    project_dir = Path(r"C:\dev\nycyellowtaxitrip")

    input_csv = project_dir / "data" / "forecasting" / "daily_demand.csv"
    output_csv = project_dir / "data" / "forecasting" / "daily_demand_prepared.csv"

    if not input_csv.exists():
        raise FileNotFoundError(f"Fichier introuvable : {input_csv}")

    df = pd.read_csv(input_csv)

    expected_columns = {"date", "total_trips"}
    missing_columns = expected_columns - set(df.columns)
    if missing_columns:
        raise ValueError(
            f"Colonnes manquantes dans le dataset : {sorted(missing_columns)}"
        )

    df["date"] = pd.to_datetime(df["date"])

    df = df.sort_values("date")

    df = df.reset_index(drop=True)

    df.to_csv(output_csv, index=False)

    print("Dataset forecasting préparé")
    print(f"Entrée : {input_csv}")
    print(f"Sortie : {output_csv}")
    print(f"Nombre de lignes : {len(df)}")
    print(f"Période : {df['date'].min().date()} → {df['date'].max().date()}")


if __name__ == "__main__":
    main()