-- Voir les tables disponibles
SHOW TABLES;

-- Voir la structure de la table
DESCRIBE yellow_taxi;

-- Aperçu des données
SELECT *
FROM yellow_taxi
LIMIT 20;

-- Nombre total de trajets
SELECT COUNT(*) AS total_trips
FROM yellow_taxi;

-- Plage des dates
SELECT
    MIN(tpep_pickup_datetime) AS first_trip,
    MAX(tpep_pickup_datetime) AS last_trip
FROM yellow_taxi;

-- Distance moyenne
SELECT
    AVG(trip_distance) AS avg_distance,
    MIN(trip_distance) AS min_distance,
    MAX(trip_distance) AS max_distance
FROM yellow_taxi;

-- Montants moyens
SELECT
    AVG(total_amount) AS avg_total,
    AVG(fare_amount) AS avg_fare,
    AVG(tip_amount) AS avg_tip
FROM yellow_taxi;

-- Distribution des types de paiement
SELECT
    payment_type,
    COUNT(*) AS trips
FROM yellow_taxi
GROUP BY payment_type
ORDER BY trips DESC;

-- Top zones pickup
SELECT
    PULocationID,
    COUNT(*) AS trips
FROM yellow_taxi
GROUP BY PULocationID
ORDER BY trips DESC
LIMIT 10;

-- Trajets par mois
SELECT
    EXTRACT(month FROM tpep_pickup_datetime) AS month,
    COUNT(*) AS trips
FROM yellow_taxi
GROUP BY month
ORDER BY month;

-- Durée moyenne des trajets
SELECT
    AVG(date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime)) AS avg_duration_minutes
FROM yellow_taxi;