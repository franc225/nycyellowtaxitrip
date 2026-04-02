-- =========================================================
-- VALIDATION TESTS - NYC YELLOW TAXI PIPELINE
-- Validates consistency across raw, staging, and star schema
-- =========================================================

-- =========================================================
-- 1. ROW COUNT VALIDATION
-- =========================================================

-- 1.1 Raw -> Staging row count
SELECT
    'raw_vs_staging_row_count' AS test_name,
    CASE
        WHEN (SELECT COUNT(*) FROM stg_yellow_taxi) <= (SELECT COUNT(*) FROM yellow_taxi)
        THEN 0
        ELSE 1
    END AS failed_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM stg_yellow_taxi) <= (SELECT COUNT(*) FROM yellow_taxi)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    (SELECT COUNT(*) FROM yellow_taxi) AS raw_rows,
    (SELECT COUNT(*) FROM stg_yellow_taxi) AS staging_rows;

-- 1.2 Staging -> Fact row count
SELECT
    'staging_vs_fact_row_count' AS test_name,
    ABS(
        (SELECT COUNT(*) FROM stg_yellow_taxi) -
        (SELECT COUNT(*) FROM fact_trip)
    ) AS failed_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM stg_yellow_taxi) = (SELECT COUNT(*) FROM fact_trip)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    (SELECT COUNT(*) FROM stg_yellow_taxi) AS staging_rows,
    (SELECT COUNT(*) FROM fact_trip) AS fact_rows;

-- =========================================================
-- 2. STAGING BUSINESS RULE VALIDATION
-- =========================================================

-- 2.1 Staging contains only 2025 records
SELECT
    'staging_only_2025' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE pickup_year <> 2025;

-- 2.2 Dropoff is not before pickup
SELECT
    'staging_valid_datetime_order' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE tpep_dropoff_datetime < tpep_pickup_datetime;

-- 2.3 Non-negative trip distance
SELECT
    'staging_non_negative_trip_distance' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE trip_distance < 0;

-- 2.4 Non-negative total amount
SELECT
    'staging_non_negative_total_amount' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE total_amount < 0;

-- 2.5 Pickup and dropoff locations are present
SELECT
    'staging_non_null_locations' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE PULocationID IS NULL
   OR DOLocationID IS NULL;

-- 2.6 Trip duration within expected range
SELECT
    'staging_valid_trip_duration_range' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE trip_duration_minutes NOT BETWEEN 1 AND 600;

-- 2.7 Trip distance within expected range
SELECT
    'staging_valid_trip_distance_range' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE trip_distance > 200;

-- 2.8 Passenger count within expected range
SELECT
    'staging_valid_passenger_count_range' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE passenger_count NOT BETWEEN 0 AND 8;

-- =========================================================
-- 3. DERIVED COLUMN VALIDATION
-- =========================================================

-- 3.1 pickup_date derivation
SELECT
    'pickup_date_derivation' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE pickup_date <> CAST(tpep_pickup_datetime AS DATE);

-- 3.2 dropoff_date derivation
SELECT
    'dropoff_date_derivation' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE dropoff_date <> CAST(tpep_dropoff_datetime AS DATE);

-- 3.3 pickup_hour derivation
SELECT
    'pickup_hour_derivation' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE pickup_hour <> EXTRACT(hour FROM tpep_pickup_datetime);

-- 3.4 trip_duration_minutes derivation
SELECT
    'trip_duration_derivation' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE trip_duration_minutes <> date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime);

-- 3.5 avg_speed_mph derivation
SELECT
    'avg_speed_derivation' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM stg_yellow_taxi
WHERE trip_duration_minutes > 0
  AND ABS(
        avg_speed_mph - (trip_distance / (trip_duration_minutes / 60.0))
      ) > 0.0001;

-- =========================================================
-- 4. STAR SCHEMA REFERENTIAL INTEGRITY
-- =========================================================

-- 4.1 pickup_date_key exists in dim_date
SELECT
    'fact_pickup_date_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_date d
    ON f.pickup_date_key = d.date_key
WHERE d.date_key IS NULL;

-- 4.2 dropoff_date_key exists in dim_date
SELECT
    'fact_dropoff_date_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_date d
    ON f.dropoff_date_key = d.date_key
WHERE d.date_key IS NULL;

-- 4.3 pickup_time_key exists in dim_time
SELECT
    'fact_pickup_time_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_time t
    ON f.pickup_time_key = t.time_key
WHERE t.time_key IS NULL;

-- 4.4 pickup_location_key exists in dim_location
SELECT
    'fact_pickup_location_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_location l
    ON f.pickup_location_key = l.location_key
WHERE l.location_key IS NULL;

-- 4.5 dropoff_location_key exists in dim_location
SELECT
    'fact_dropoff_location_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_location l
    ON f.dropoff_location_key = l.location_key
WHERE l.location_key IS NULL;

-- 4.6 borough_key exists in dim_borough
SELECT
    'dim_location_borough_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM dim_location l
LEFT JOIN dim_borough b
    ON l.borough_key = b.borough_key
WHERE b.borough_key IS NULL;

-- 4.7 payment_type_key exists in dim_payment_type
SELECT
    'fact_payment_type_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_payment_type p
    ON f.payment_type_key = p.payment_type_key
WHERE p.payment_type_key IS NULL;

-- 4.8 rate_code_key exists in dim_rate_code
SELECT
    'fact_rate_code_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_rate_code r
    ON f.rate_code_key = r.rate_code_key
WHERE r.rate_code_key IS NULL;

-- 4.9 vendor_key exists in dim_vendor
SELECT
    'fact_vendor_fk' AS test_name,
    COUNT(*) AS failed_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM fact_trip f
LEFT JOIN dim_vendor v
    ON f.vendor_key = v.vendor_key
WHERE v.vendor_key IS NULL;

-- =========================================================
-- 5. RECONCILIATION TESTS
-- =========================================================

-- 5.1 Revenue reconciliation
SELECT
    'revenue_staging_vs_fact' AS test_name,
    CASE
        WHEN ROUND(s.total_amount,2) = ROUND(f.total_amount,2) THEN 0
        ELSE 1
    END AS failed_rows,
    CASE
        WHEN ROUND(s.total_amount,2) = ROUND(f.total_amount,2) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    ROUND(s.total_amount,2) AS staging_value,
    ROUND(f.total_amount,2) AS fact_value,
    ROUND(s.total_amount,2) - ROUND(f.total_amount,2) AS diff_value
FROM
    (SELECT SUM(total_amount) AS total_amount FROM stg_yellow_taxi) s,
    (SELECT SUM(total_amount) AS total_amount FROM fact_trip) f;

-- 5.2 Tip reconciliation
SELECT
    'tip_amount_staging_vs_fact' AS test_name,
    CASE
        WHEN ROUND(s.tip_amount,2) = ROUND(f.tip_amount,2) THEN 0
        ELSE 1
    END AS failed_rows,
    CASE
        WHEN ROUND(s.tip_amount,2) = ROUND(f.tip_amount,2) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    ROUND(s.tip_amount,2) AS staging_value,
    ROUND(f.tip_amount,2) AS fact_value,
    ROUND(s.tip_amount,2) - ROUND(f.tip_amount,2) AS diff_value
FROM
    (SELECT SUM(tip_amount) AS tip_amount FROM stg_yellow_taxi) s,
    (SELECT SUM(tip_amount) AS tip_amount FROM fact_trip) f;

-- 5.3 Distance reconciliation
SELECT
    'trip_distance_staging_vs_fact' AS test_name,
    CASE
        WHEN ROUND(s.trip_distance,2) = ROUND(f.trip_distance,2) THEN 0
        ELSE 1
    END AS failed_rows,
    CASE
        WHEN ROUND(s.trip_distance,2) = ROUND(f.trip_distance,2) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    ROUND(s.trip_distance,2) AS staging_value,
    ROUND(f.trip_distance,2) AS fact_value,
    ROUND(s.trip_distance,2) - ROUND(f.trip_distance,2) AS diff_value
FROM
    (SELECT SUM(trip_distance) AS trip_distance FROM stg_yellow_taxi) s,
    (SELECT SUM(trip_distance) AS trip_distance FROM fact_trip) f;

-- 5.4 CBD congestion fee reconciliation
SELECT
    'cbd_fee_staging_vs_fact' AS test_name,
    CASE
        WHEN ROUND(s.cbd_fee,2) = ROUND(f.cbd_fee,2) THEN 0
        ELSE 1
    END AS failed_rows,
    CASE
        WHEN ROUND(s.cbd_fee,2) = ROUND(f.cbd_fee,2) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    ROUND(s.cbd_fee,2) AS staging_value,
    ROUND(f.cbd_fee,2) AS fact_value,
    ROUND(s.cbd_fee,2) - ROUND(f.cbd_fee,2) AS diff_value
FROM
    (SELECT SUM(cbd_congestion_fee) AS cbd_fee FROM stg_yellow_taxi) s,
    (SELECT SUM(cbd_congestion_fee) AS cbd_fee FROM fact_trip) f;

-- 5.5 Monthly revenue reconciliation
WITH staging_monthly AS (
    SELECT
        pickup_year,
        pickup_month,
        SUM(total_amount) AS staging_revenue
    FROM stg_yellow_taxi
    GROUP BY pickup_year, pickup_month
),
fact_monthly AS (
    SELECT
        d.year,
        d.month_number,
        SUM(f.total_amount) AS fact_revenue
    FROM fact_trip f
    JOIN dim_date d
        ON f.pickup_date_key = d.date_key
    GROUP BY d.year, d.month_number
)
SELECT
    CONCAT('monthly_revenue_', CAST(s.pickup_year AS VARCHAR), '_', LPAD(CAST(s.pickup_month AS VARCHAR), 2, '0')) AS test_name,
    CASE
        WHEN s.staging_revenue = f.fact_revenue THEN 0
        ELSE 1
    END AS failed_rows,
    CASE
        WHEN ROUND(s.staging_revenue,2) = ROUND(f.fact_revenue,2) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result,
    s.staging_revenue AS staging_value,
    f.fact_revenue AS fact_value,
    s.staging_revenue - f.fact_revenue AS diff_value
FROM staging_monthly s
JOIN fact_monthly f
    ON s.pickup_year = f.year
   AND s.pickup_month = f.month_number
ORDER BY test_name;