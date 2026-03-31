-- =========================================================
-- STAR SCHEMA - NYC YELLOW TAXI
-- =========================================================

DROP TABLE IF EXISTS fact_trip;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_borough;
DROP TABLE IF EXISTS dim_vendor;
DROP TABLE IF EXISTS dim_payment_type;
DROP TABLE IF EXISTS dim_rate_code;
DROP TABLE IF EXISTS dim_vendor;
DROP TABLE IF EXISTS dim_time;

-- =========================================================
-- DIM_DATE
-- Full calendar for year 2025
-- =========================================================

CREATE TABLE dim_date AS
SELECT
    CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_key,
    d AS full_date,

    EXTRACT(year FROM d) AS year,
    EXTRACT(quarter FROM d) AS quarter,
    EXTRACT(month FROM d) AS month_number,
    EXTRACT(week FROM d) AS week_of_year,
    EXTRACT(day FROM d) AS day_of_month,
    EXTRACT(dow FROM d) AS day_of_week,

    strftime(d, '%Y-%m') AS year_month,
    CONCAT(CAST(EXTRACT(year FROM d) AS VARCHAR), '-Q', CAST(EXTRACT(quarter FROM d) AS VARCHAR)) AS year_quarter,

    strftime(d, '%B') AS month_name,
    strftime(d, '%b') AS month_short_name,
    strftime(d, '%A') AS day_name,
    strftime(d, '%a') AS day_short_name,

    CASE
        WHEN EXTRACT(dow FROM d) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend,

    CASE
        WHEN EXTRACT(dow FROM d) IN (1, 2, 3, 4, 5) THEN TRUE
        ELSE FALSE
    END AS is_weekday,

    CASE
        WHEN EXTRACT(day FROM d) = 1 THEN TRUE
        ELSE FALSE
    END AS is_month_start,

    CASE
        WHEN d = last_day(d) THEN TRUE
        ELSE FALSE
    END AS is_month_end,

    CASE
        WHEN EXTRACT(month FROM d) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(month FROM d) IN (3, 4, 5) THEN 'Spring'
        WHEN EXTRACT(month FROM d) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END AS season

FROM generate_series(
    DATE '2025-01-01',
    DATE '2025-12-31',
    INTERVAL 1 DAY
) t(d)
ORDER BY d;

-- =========================================================
-- DIM_TIME
-- Hour-level time dimension
-- =========================================================

CREATE TABLE dim_time AS
SELECT
    h AS time_key,
    h AS hour_24,
    CASE
        WHEN h = 0 THEN '00:00'
        WHEN h = 1 THEN '01:00'
        WHEN h = 2 THEN '02:00'
        WHEN h = 3 THEN '03:00'
        WHEN h = 4 THEN '04:00'
        WHEN h = 5 THEN '05:00'
        WHEN h = 6 THEN '06:00'
        WHEN h = 7 THEN '07:00'
        WHEN h = 8 THEN '08:00'
        WHEN h = 9 THEN '09:00'
        WHEN h = 10 THEN '10:00'
        WHEN h = 11 THEN '11:00'
        WHEN h = 12 THEN '12:00'
        WHEN h = 13 THEN '13:00'
        WHEN h = 14 THEN '14:00'
        WHEN h = 15 THEN '15:00'
        WHEN h = 16 THEN '16:00'
        WHEN h = 17 THEN '17:00'
        WHEN h = 18 THEN '18:00'
        WHEN h = 19 THEN '19:00'
        WHEN h = 20 THEN '20:00'
        WHEN h = 21 THEN '21:00'
        WHEN h = 22 THEN '22:00'
        ELSE '23:00'
    END AS time_label,

    CASE
        WHEN h BETWEEN 0 AND 5 THEN 'Night'
        WHEN h BETWEEN 6 AND 11 THEN 'Morning'
        WHEN h BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN h BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Late Evening'
    END AS day_period,

    CASE
        WHEN h IN (7, 8, 9, 16, 17, 18) THEN TRUE
        ELSE FALSE
    END AS is_peak_commute_hour
FROM generate_series(0, 23) t(h)
ORDER BY h;

-- =========================================================
-- DIM_BOROUGH
-- =========================================================

CREATE TABLE dim_borough AS
SELECT DISTINCT
    row_number() OVER () AS borough_key,
    borough
FROM (
    SELECT
        CASE
            WHEN Borough IN ('Unknown','N/A') THEN 'Unknown'
            ELSE Borough
        END AS borough
    FROM read_csv_auto('data/lookup/taxi_zone_lookup.csv')
)
ORDER BY borough;

-- =========================================================
-- DIM_LOCATION
-- =========================================================

CREATE TABLE dim_location AS
SELECT
    CAST(z.LocationID AS INTEGER) AS location_key,
    CAST(z.LocationID AS INTEGER) AS location_id,

    b.borough_key,

    z.Zone AS zone_name,

    CASE
        WHEN z.service_zone IN ('Unknown','N/A') THEN 'Unknown'
        ELSE z.service_zone
    END AS service_zone

FROM read_csv_auto('data/lookup/taxi_zone_lookup.csv') z

JOIN dim_borough b
ON (
    CASE
        WHEN z.Borough IN ('Unknown','N/A') THEN 'Unknown'
        ELSE z.Borough
    END
) = b.borough

ORDER BY location_key;

-- =========================================================
-- DIM_PAYMENT_TYPE
-- =========================================================
CREATE TABLE dim_payment_type AS
SELECT DISTINCT
    payment_type AS payment_type_key,
    payment_type AS payment_type_code,
    CASE payment_type
        WHEN 0 THEN 'Flex fare trip'
        WHEN 1 THEN 'Credit card'
        WHEN 2 THEN 'Cash'
        WHEN 3 THEN 'No charge'
        WHEN 4 THEN 'Dispute'
        WHEN 5 THEN 'Unknown'
        WHEN 6 THEN 'Voided trip'
        ELSE 'Other'
    END AS payment_type_desc
FROM stg_yellow_taxi
ORDER BY payment_type_key;

-- =========================================================
-- DIM_RATE_CODE
-- =========================================================
CREATE TABLE dim_rate_code AS
SELECT DISTINCT
    RatecodeID AS rate_code_key,
    RatecodeID AS rate_code_id,
    CASE RatecodeID
        WHEN 1 THEN 'Standard rate'
        WHEN 2 THEN 'JFK'
        WHEN 3 THEN 'Newark'
        WHEN 4 THEN 'Nassau or Westchester'
        WHEN 5 THEN 'Negotiated fare'
        WHEN 6 THEN 'Group ride'
        ELSE 'Other'
    END AS rate_code_desc
FROM stg_yellow_taxi
ORDER BY rate_code_key;

-- =========================================================
-- DIM_VENDOR
-- =========================================================
CREATE TABLE dim_vendor AS
SELECT DISTINCT
    VendorID AS vendor_key,
    VendorID AS vendor_id,
    CASE VendorID
        WHEN 1 THEN 'Creative Mobile Technologies'
        WHEN 2 THEN 'VeriFone'
        ELSE 'Other'
    END AS vendor_desc
FROM stg_yellow_taxi
ORDER BY vendor_key;

-- =========================================================
-- FACT_TRIP
-- =========================================================
CREATE TABLE fact_trip AS
SELECT
    row_number() OVER () AS trip_id,

    CAST(strftime(pickup_date, '%Y%m%d') AS INTEGER) AS pickup_date_key,
    CAST(strftime(dropoff_date, '%Y%m%d') AS INTEGER) AS dropoff_date_key,

    pickup_hour AS pickup_time_key,

    PULocationID AS pickup_location_key,
    DOLocationID AS dropoff_location_key,
    payment_type AS payment_type_key,
    RatecodeID AS rate_code_key,
    VendorID AS vendor_key,

    passenger_count,
    trip_distance,
    trip_duration_minutes,
    avg_speed_mph,

    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    cbd_congestion_fee,
    Airport_fee,
    total_amount

FROM stg_yellow_taxi;