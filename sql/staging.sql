-- Supprimer et recréer la table de staging
CREATE OR REPLACE TABLE stg_yellow_taxi AS
SELECT
    -- Identifiants / codes
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

    -- Mesures brutes
    passenger_count,
    trip_distance,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
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
    -- dates cohérentes
    tpep_dropoff_datetime >= tpep_pickup_datetime

    -- valeurs numériques minimales cohérentes
    AND trip_distance >= 0
    AND fare_amount >= 0
    AND tip_amount >= 0
    AND total_amount >= 0

    -- clés géographiques présentes
    AND PULocationID IS NOT NULL
    AND DOLocationID IS NOT NULL

    -- filtrage grossier des durées absurdes
    AND date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) BETWEEN 1 AND 600

    -- filtrage grossier des distances absurdes
    AND trip_distance <= 200

    -- filtrage grossier sur le nombre de passagers
    AND passenger_count BETWEEN 0 AND 8;