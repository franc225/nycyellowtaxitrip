-- =========================================================
-- ANALYTICAL QUERIES - NYC YELLOW TAXI STAR SCHEMA
-- =========================================================

-- 1. Volume total et revenus totaux
SELECT
    COUNT(*) AS total_trips,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_revenue_per_trip
FROM fact_trip;

-- 2. Trajets et revenus par mois
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue,
    AVG(f.total_amount) AS avg_revenue_per_trip
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;

-- 3. Trajets par jour de semaine
SELECT
    d.day_of_week,
    d.day_name,
    COUNT(*) AS total_trips,
    AVG(f.total_amount) AS avg_trip_amount
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.day_of_week,
    d.day_name
ORDER BY
    d.day_of_week;

-- 4. Semaine vs fin de semaine
SELECT
    d.is_weekend,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue,
    AVG(f.total_amount) AS avg_trip_amount
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.is_weekend
ORDER BY
    d.is_weekend;

-- 5. Top 10 pickup locations
SELECT
    pl.location_id AS pickup_location_id,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue
FROM fact_trip f
JOIN dim_pickup_location pl
    ON f.pickup_location_key = pl.location_key
GROUP BY
    pl.location_id
ORDER BY
    total_trips DESC
LIMIT 10;

-- 6. Top 10 dropoff locations
SELECT
    dl.location_id AS dropoff_location_id,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue
FROM fact_trip f
JOIN dim_dropoff_location dl
    ON f.dropoff_location_key = dl.location_key
GROUP BY
    dl.location_id
ORDER BY
    total_trips DESC
LIMIT 10;

-- 7. Analyse par type de paiement
SELECT
    pt.payment_type_desc,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue,
    AVG(f.total_amount) AS avg_trip_amount,
    AVG(f.tip_amount) AS avg_tip_amount
FROM fact_trip f
JOIN dim_payment_type pt
    ON f.payment_type_key = pt.payment_type_key
GROUP BY
    pt.payment_type_desc
ORDER BY
    total_trips DESC;

-- 8. Analyse par rate code
SELECT
    rc.rate_code_desc,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue,
    AVG(f.trip_distance) AS avg_distance,
    AVG(f.total_amount) AS avg_trip_amount
FROM fact_trip f
JOIN dim_rate_code rc
    ON f.rate_code_key = rc.rate_code_key
GROUP BY
    rc.rate_code_desc
ORDER BY
    total_trips DESC;

-- 9. Analyse par vendor
SELECT
    v.vendor_desc,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue,
    AVG(f.trip_distance) AS avg_distance,
    AVG(f.trip_duration_minutes) AS avg_duration_minutes
FROM fact_trip f
JOIN dim_vendor v
    ON f.vendor_key = v.vendor_key
GROUP BY
    v.vendor_desc
ORDER BY
    total_trips DESC;

-- 10. Performance opérationnelle globale
SELECT
    AVG(trip_distance) AS avg_trip_distance,
    AVG(trip_duration_minutes) AS avg_trip_duration_minutes,
    AVG(avg_speed_mph) AS avg_speed_mph,
    AVG(passenger_count) AS avg_passenger_count
FROM fact_trip;

-- 11. Revenu moyen par distance
SELECT
    CASE
        WHEN trip_distance < 1 THEN '< 1 mile'
        WHEN trip_distance < 3 THEN '1-3 miles'
        WHEN trip_distance < 5 THEN '3-5 miles'
        WHEN trip_distance < 10 THEN '5-10 miles'
        ELSE '10+ miles'
    END AS distance_bucket,
    COUNT(*) AS total_trips,
    AVG(total_amount) AS avg_trip_amount,
    AVG(tip_amount) AS avg_tip_amount
FROM fact_trip
GROUP BY
    distance_bucket
ORDER BY
    distance_bucket;

-- 12. Analyse des pourboires par type de paiement
SELECT
    pt.payment_type_desc,
    AVG(f.tip_amount) AS avg_tip_amount,
    AVG(
        CASE
            WHEN f.fare_amount > 0 THEN f.tip_amount / f.fare_amount
            ELSE NULL
        END
    ) AS avg_tip_pct_of_fare
FROM fact_trip f
JOIN dim_payment_type pt
    ON f.payment_type_key = pt.payment_type_key
GROUP BY
    pt.payment_type_desc
ORDER BY
    avg_tip_amount DESC;

-- 13. Jours avec le plus de trajets
SELECT
    d.full_date,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.full_date
ORDER BY
    total_trips DESC
LIMIT 20;

-- 14. Jours avec le plus de revenus
SELECT
    d.full_date,
    COUNT(*) AS total_trips,
    SUM(f.total_amount) AS total_revenue
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.full_date
ORDER BY
    total_revenue DESC
LIMIT 20;

-- 15. Analyse mensuelle de la distance moyenne et durée moyenne
SELECT
    d.year,
    d.month,
    d.month_name,
    AVG(f.trip_distance) AS avg_trip_distance,
    AVG(f.trip_duration_minutes) AS avg_trip_duration_minutes,
    AVG(f.avg_speed_mph) AS avg_speed_mph
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;

-- 16. Demande quotidienne
SELECT
    d.full_date,
    COUNT(*) AS total_trips
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.full_date
ORDER BY
    d.full_date;

-- 17. Revenu quotidien
SELECT
    d.full_date,
    SUM(f.total_amount) AS total_revenue
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.full_date
ORDER BY
    d.full_date;

-- 18. Demande mensuelle
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(*) AS total_trips
FROM fact_trip f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;