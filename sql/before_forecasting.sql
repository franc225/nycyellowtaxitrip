SELECT *
FROM agg_daily_demand
ORDER BY full_date;

SELECT
    MIN(full_date),
    MAX(full_date),
    COUNT(*) AS days
FROM agg_daily_demand;

SELECT
    AVG(total_trips) avg_trips,
    MIN(total_trips) min_trips,
    MAX(total_trips) max_trips
FROM agg_daily_demand;

SELECT
    d.day_name,
    AVG(a.total_trips) avg_trips
FROM agg_daily_demand a
JOIN dim_date d
    ON a.date_key = d.date_key
GROUP BY d.day_name
ORDER BY avg_trips DESC;

COPY (
    SELECT
        full_date AS date,
        total_trips,
        total_revenue
    FROM agg_daily_demand
    ORDER BY full_date
)
TO 'data/forecasting/daily_demand.csv'
WITH (HEADER, DELIMITER ',');