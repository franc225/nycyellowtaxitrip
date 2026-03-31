# nycyellowtaxitrip

![Python](https://img.shields.io/badge/Python-3.x-blue)
![DuckDB](https://img.shields.io/badge/DuckDB-Analytics%20DB-yellow)
![SQL](https://img.shields.io/badge/SQL-Analytics-orange)
![Power BI](https://img.shields.io/badge/PowerBI-Dashboard-F2C811)
![Data Engineering](https://img.shields.io/badge/Data-Engineering-green)
![Data Analytics](https://img.shields.io/badge/Data-Analytics-blueviolet)

# City Mobility Analytics

End-to-end **data analytics project** analyzing **New York City taxi trips** to explore urban mobility patterns and build demand forecasting models.

This project demonstrates a complete analytics pipeline including:

- data ingestion
- analytical data warehousing
- dimensional modeling
- exploratory SQL analysis
- business intelligence dashboards
- predictive analytics

---

# Project Overview

The goal of this project is to analyze taxi trip data to better understand **mobility demand in New York City** and identify temporal and spatial patterns in ride activity.

The project includes:

- ingestion of raw trip data
- analytical data warehouse built with DuckDB
- dimensional **star schema** for analytics
- exploratory and analytical SQL queries
- business intelligence dashboards
- demand forecasting

---

# Dataset

The project uses the **NYC Taxi Trip Record dataset** published by the **New York City Taxi & Limousine Commission (TLC)**.

The dataset contains detailed information about each taxi trip, including:

- pickup and dropoff timestamps
- pickup and dropoff locations
- trip distance
- passenger count
- payment type
- fare and tip amounts

For this project, the **Yellow Taxi dataset for 2025** is used.

Raw data is stored as **Parquet files**.

The project also uses the official **TLC Taxi Zone Lookup dataset** to enrich the geographical dimension with:

- borough
- zone
- service zone

---

# Data Model

The analytical warehouse is modeled using a **star schema** optimized for analytics and BI tools.

Fact table:

- **fact_trip** — one row per taxi trip

Dimension tables:

- **dim_date**
- **dim_location**
- **dim_payment_type**
- **dim_rate_code**
- **dim_vendor**

The `dim_location` table is enriched using the official **TLC Taxi Zone Lookup** dataset to provide geographic attributes such as borough and zone names.

---

# Project Architecture

Raw Parquet Files
↓
Python Ingestion
↓
DuckDB Analytical Warehouse
↓
SQL Exploration
↓
Data Cleaning & Staging (2025 only)
↓
Dimensional Modeling (Star Schema)
↓
Analytical SQL Queries
↓
Power BI Dashboard
↓
Demand Forecasting


This architecture mirrors a **modern analytics stack used in real data platforms**.

---

# Repository Structure

nycyellowtaxitrip

data/
raw/ # original parquet files
lookup/ # TLC taxi zone lookup table

duckdb/
nyc_taxi.duckdb # analytical database

sql/
exploration.sql # exploratory data analysis
staging.sql # data cleaning and staging layer
quality.sql # data quality checks
quality_star_schema.sql # star schema validation

scripts/
ingestion/ # Python ingestion scripts

dashboards/
powerbi/ # Power BI dashboard

README.md


---

# Technologies Used

- Python
- DuckDB
- SQL
- Parquet
- Power BI
- Git / GitHub

---

# Current Progress

Current stage:

- raw dataset collected
- DuckDB warehouse created
- data imported from parquet files
- exploratory SQL analysis implemented
- data cleaning and staging layer created
- dimensional star schema implemented
- analytical SQL queries developed

---

# Next Steps

- build Power BI dashboard
- implement demand forecasting model