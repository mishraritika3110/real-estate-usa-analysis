# Real Estate USA Data Analysis

## Overview
An end-to-end data analytics project analyzing ~2.2 million US real estate listings.
Raw data was cleaned and modeled using SQL (MySQL), then visualized in an interactive
Power BI dashboard to uncover pricing trends, regional market patterns, and property
characteristics across the United States.

## Tools Used
- **MySQL Workbench** — data cleaning, transformation, and modeling (~2.2M rows)
- **Power BI Desktop** — interactive dashboard visualization

## Dataset
Source: USA Real Estate Dataset (Kaggle), containing listing status, price, bedrooms,
bathrooms, lot size, address, house size, and sold date across all US states.

## Data Cleaning Process (SQL)
The raw dataset required substantial cleaning before it could be trusted for analysis.
Key steps (see `sql/data_cleaning.sql` for the full commented script):

- Removed exact duplicate rows
- Corrected data types and renamed columns for clarity
- Identified and converted disguised missing values — blank cells in the source CSV
  had been silently imported as `0` instead of `NULL` (affecting bedrooms, bathrooms,
  and price)
- Removed unrealistic outliers (e.g. listings with 400+ bedrooms, prices in the billions
  caused by data entry errors and integer overflow)
- Standardized inconsistent city name spellings (e.g. "New York City", "Nyc", "Ny" →
  "New York")
- Excluded unreliable/invalid state entries and `ready_to_build` listings (empty land,
  not built properties)
- Extracted `sold_year` and `sold_month` from sale dates for time-based trend analysis
- Final cleaned dataset: **~2.19 million rows**, ready for analysis

## Dashboard Pages

**1. Real Estate Stats Dashboard**
Market overview with KPIs (min/average/max price and house size, average lot size),
number of properties sold by state, market size by state (treemap), and bedroom/bathroom
distribution.

**2. Price Calculator**
Interactive filtering by state, city, bedroom count, and year, with live-updating
average price and total properties sold, plus price and sales trend charts.

**3. Sales Trends by Year & Month**
Time-based trend analysis showing price and sales volume by state over multiple decades,
plus monthly seasonality patterns, with state and year filters.

## Key Insights
- Hawaii, California, New York, and Washington D.C. show the highest average home
  prices, consistent with their real-world cost of living.
- Average home prices have shown noticeable year-over-year fluctuation, with visible
  softening in more recent years.
- The majority of properties sold fall in the 2–4 bedroom and 1–3 bathroom range,
  reflecting typical single-family homes.
- Property sales volume is heavily concentrated in the last few decades, with far fewer
  (but still valid) records from earlier historical sales.

## Repository Structure
```
Real-Estate-USA-Analysis/
├── README.md
├── sql/
│   └── data_cleaning.sql
├── dashboard/
│   └── Real_Estate_USA_Dashboard.pbix
└── screenshots/
    ├── page1_stats_dashboard.png
    ├── page2_price_calculator.png
    └── page3_yearly_monthly.png
```
