-- =========================================================
-- STAGING LAYER
-- Clean and prepare taxi trip data
-- =========================================================

CREATE OR REPLACE TABLE stg_yellow_taxi AS
SELECT
    -- Identifiants
    VendorID,
    RatecodeID,
    payment_type,
    store_and_fwd_flag,
    PULocationID,
    DOLocationID,

    -- Dates
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    CAST(tpep_pickup_datetime AS DATE) AS pickup_date,
    CAST(tpep_dropoff_datetime AS DATE) AS dropoff_date,

    -- Dérivés temporels
    EXTRACT(year FROM tpep_pickup_datetime) AS pickup_year,
    EXTRACT(month FROM tpep_pickup_datetime) AS pickup_month,
    EXTRACT(day FROM tpep_pickup_datetime) AS pickup_day,
    EXTRACT(hour FROM tpep_pickup_datetime) AS pickup_hour,
    EXTRACT(dow FROM tpep_pickup_datetime) AS pickup_day_of_week,

    -- Mesures
    passenger_count,
    trip_distance,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    COALESCE(cbd_congestion_fee, 0) AS cbd_congestion_fee,
    Airport_fee,
    total_amount,

    -- Mesures dérivées
    date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) AS trip_duration_minutes,

    CASE
        WHEN date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) > 0
        THEN trip_distance / (date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0)
        ELSE NULL
    END AS avg_speed_mph

FROM yellow_taxi
WHERE
    EXTRACT(year FROM tpep_pickup_datetime) = 2025
    AND tpep_dropoff_datetime >= tpep_pickup_datetime
    AND trip_distance >= 0
    AND fare_amount >= 0
    AND tip_amount >= 0
    AND total_amount >= 0
    AND PULocationID IS NOT NULL
    AND DOLocationID IS NOT NULL
    AND date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) BETWEEN 1 AND 600
    AND trip_distance <= 200
    AND passenger_count BETWEEN 0 AND 8;