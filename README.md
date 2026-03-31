# nycyellowtaxitrip

![Python](https://img.shields.io/badge/Python-3.x-blue)
![DuckDB](https://img.shields.io/badge/DuckDB-Analytics%20DB-yellow)
![SQL](https://img.shields.io/badge/SQL-Analytics-orange)
![Power BI](https://img.shields.io/badge/PowerBI-Dashboard-F2C811)
![Data Engineering](https://img.shields.io/badge/Data-Engineering-green)
![Data Analytics](https://img.shields.io/badge/Data-Analytics-blueviolet)

# City Mobility Analytics

End-to-end data analytics project analyzing **New York City taxi trips** to explore urban mobility patterns and build demand forecasting models.

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
- dimensional star schema for analytics
- exploratory SQL analysis
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
Data Cleaning & Staging
↓
Dimensional Modeling (Star Schema)
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

duckdb/
nyc_taxi.duckdb # analytical database

sql/
exploration.sql # exploratory analysis queries
quality.sql # compare accepted vs rejected records
quality_start_schema.sql # check star schema composition
staging.sql # data cleaning and staging

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
- initial SQL exploration implemented
- data cleaning and staging layer
- dimensional star schema modeling

---

# Next Steps

- analytical SQL queries
- Power BI dashboard
- demand forecasting model