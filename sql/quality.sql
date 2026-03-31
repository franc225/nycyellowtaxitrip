SELECT
    COUNT(*) AS raw_rows
FROM yellow_taxi;

SELECT
    COUNT(*) AS clean_rows
FROM stg_yellow_taxi;

SELECT
    COUNT(*) - (SELECT COUNT(*) FROM stg_yellow_taxi) AS removed_rows
FROM yellow_taxi;