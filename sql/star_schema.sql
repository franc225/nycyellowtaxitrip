-- =========================================================
-- STAR SCHEMA - NYC YELLOW TAXI
-- =========================================================

DROP TABLE IF EXISTS fact_trip;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_payment_type;
DROP TABLE IF EXISTS dim_rate_code;
DROP TABLE IF EXISTS dim_vendor;

-- =========================================================
-- DIM_DATE
-- =========================================================
CREATE TABLE dim_date AS
WITH all_dates AS (
    SELECT DISTINCT pickup_date AS full_date
    FROM stg_yellow_taxi

    UNION

    SELECT DISTINCT dropoff_date AS full_date
    FROM stg_yellow_taxi
)
SELECT
    CAST(strftime(full_date, '%Y%m%d') AS INTEGER) AS date_key,
    full_date,
    EXTRACT(year FROM full_date) AS year,
    EXTRACT(quarter FROM full_date) AS quarter,
    EXTRACT(month FROM full_date) AS month,
    strftime(full_date, '%B') AS month_name,
    EXTRACT(day FROM full_date) AS day,
    EXTRACT(dow FROM full_date) AS day_of_week,
    strftime(full_date, '%A') AS day_name,
    CASE
        WHEN EXTRACT(dow FROM full_date) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM all_dates
ORDER BY full_date;

-- =========================================================
-- DIM_LOCATION
-- Source: official TLC taxi zone lookup CSV
-- =========================================================
CREATE TABLE dim_location AS
SELECT
    CAST(LocationID AS INTEGER) AS location_key,
    CAST(LocationID AS INTEGER) AS location_id,
    Borough AS borough,
    Zone AS zone_name,
    service_zone
FROM read_csv_auto('data/lookup/taxi_zone_lookup.csv')
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

    pickup_hour,

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