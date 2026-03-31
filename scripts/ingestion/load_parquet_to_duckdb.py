from pathlib import Path
import duckdb

project_dir = Path(r"C:\dev\nycyellowtaxitrip")
db_dir = project_dir / "duckdb"
raw_dir = project_dir / "data" / "raw"

db_dir.mkdir(parents=True, exist_ok=True)

db_path = db_dir / "nyc_taxi.duckdb"
parquet_glob = str(raw_dir / "yellow_tripdata_2025-*.parquet")

con = duckdb.connect(str(db_path))

con.execute(f"""
CREATE OR REPLACE TABLE yellow_taxi AS
SELECT *
FROM read_parquet('{parquet_glob}')
""")

print("Import terminé")