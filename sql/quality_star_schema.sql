SHOW TABLES;

SELECT COUNT(*) FROM fact_trip;
SELECT COUNT(*) FROM dim_date;
SELECT COUNT(*) FROM dim_pickup_location;
SELECT COUNT(*) FROM dim_dropoff_location;
SELECT COUNT(*) FROM dim_payment_type;
SELECT COUNT(*) FROM dim_rate_code;
SELECT COUNT(*) FROM dim_vendor;

SELECT *
FROM fact_trip
LIMIT 10;

SELECT
    borough,
    COUNT(*) AS zones
FROM dim_location
GROUP BY borough
ORDER BY zones DESC