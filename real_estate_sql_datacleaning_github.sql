/* ============================================================
   Real Estate USA Data Analysis — Data Cleaning in SQL (MySQL)
   ------------------------------------------------------------
   Source: USA Real Estate Dataset (Kaggle, ~2.2M rows)
   Goal: Clean and prepare raw real estate listing data for
   analysis and Power BI dashboarding.

   Skills used: DISTINCT, CASE, GROUP BY, aggregate functions,
   CREATE TABLE AS SELECT, data type casting, NULL handling,
   outlier detection and removal, string standardization,
   date extraction (YEAR/MONTH), safe UPDATE/DELETE operations.
   ============================================================ */

USE real_estate;
DROP TABLE IF EXISTS re_us1;

-- Create a new table containing only unique rows from the raw import
-- SELECT DISTINCT collapses any row that is 100% identical to another row into just one copy
CREATE TABLE re_us1 AS
SELECT DISTINCT * 
FROM raw_listings;
SELECT COUNT(*) AS total_after_dedup 
FROM re_us1;

-- Create a cleaned table with corrected data types and clearer column names
CREATE TABLE re_us2 AS
SELECT
    status,                              
    price,                                
    bed AS bedrooms,                      
    bath AS bathrooms,
    acre_lot,                             
    street,                               
    city,
    state,
    zip_code,
    house_size,                           
    prev_sold_date AS sold_date           
FROM re_us1;
SELECT COUNT(*) FROM re_us2;

SELECT 
    status, 
    COUNT(*) AS count
FROM re_us2
GROUP BY status;
/* Explanation: our dataset has 3 status types. This actually makes our dataset better for analysis — 
we can compare active listings vs. completed sales. Exclude - those 25,067 rows aren't actual properties,
so they'd skew any house-price/size analysis. */

-- Count how many rows have missing (NULL) bedroom or bathroom values
SELECT 
    SUM(CASE WHEN bedrooms IS NULL THEN 1 ELSE 0 END) AS missing_bed,
    SUM(CASE WHEN bathrooms IS NULL THEN 1 ELSE 0 END) AS missing_bath
FROM re_us2;

/* When we relaxed sql_mode and used LOAD DATA INFILE, MySQL likely converted every blank CSV cell into the number 0 instead of a true NULL. 
So the missing data didn't disappear — it just got disguised as a fake "0 bedrooms" value.*/

-- Check how many rows have bedrooms = 0 (likely disguised missing values)
SELECT 
    SUM(CASE WHEN bedrooms = 0 THEN 1 ELSE 0 END) AS zero_bed,
    SUM(CASE WHEN bathrooms = 0 THEN 1 ELSE 0 END) AS zero_bath
FROM re_us2;

-- Check the highest bedroom/bathroom counts to spot unrealistic data entry errors
SELECT 
    bedrooms, 
    COUNT(*) AS count
FROM re_us2
GROUP BY bedrooms
ORDER BY bedrooms DESC
LIMIT 15;

SELECT 
    bathrooms, 
    COUNT(*) AS count
FROM re_us2
GROUP BY bathrooms
ORDER BY bathrooms DESC
LIMIT 15;

-- Create a cleaned table:
-- 1. Convert 0 in bedrooms/bathrooms to NULL (since 0 was really "missing data")
-- 2. Filter out unrealistic values (keeping only 0-10 bedrooms/bathrooms as a reasonable real-world range)
CREATE TABLE re_us3 AS
SELECT
    status,
    price,
    CASE WHEN bedrooms = 0 THEN NULL ELSE bedrooms END AS bedrooms,
    CASE WHEN bathrooms = 0 THEN NULL ELSE bathrooms END AS bathrooms,
    acre_lot,
    street,
    city,
    state,
    zip_code,
    house_size,
    sold_date
FROM re_us2
WHERE 
    (bedrooms <= 10 OR bedrooms IS NULL)
    AND (bathrooms <= 10 OR bathrooms IS NULL);
/* Why 10 as the cutoff: it's a generous real-world limit (even large mansions rarely exceed 8-10 bedrooms/bathrooms) 
while safely excluding the obvious data errors (473, 830, etc.) without being overly aggressive.*/
SELECT COUNT(*) FROM re_us3;

-- Check for any missing state values
SELECT COUNT(*) AS missing_state
FROM re_us3
WHERE state IS NULL OR state = '';

-- See distinct states and how many listings each has
SELECT 
    state,
    COUNT(*) AS counts
FROM re_us3
GROUP BY state
ORDER BY counts DESC;

-- Look for city name variants for a known problem case: New York
SELECT 
    city,
    state,
    COUNT(*) AS counts
FROM re_us3
WHERE city LIKE 'N%' AND state = 'New York'
GROUP BY city, state
ORDER BY counts DESC;

-- Final cleaning stage:
-- 1. Remove rows with missing state, and the invalid 'New Brunswick' entry
-- 2. Exclude US territories with very small sample sizes (Guam, Virgin Islands)
-- 3. Standardize New York City spelling variants into one consistent name
-- 4. Exclude 'ready_to_build' status rows (empty land, not real houses)
CREATE TABLE re_us4 AS
SELECT
    status,
    price,
    bedrooms,
    bathrooms,
    acre_lot,
    street,
    CASE 
        WHEN city IN ('New York City', 'Nyc', 'Ny') THEN 'New York'
        ELSE city
    END AS city,
    state,
    zip_code,
    house_size,
    sold_date
FROM re_us3
WHERE 
    state IS NOT NULL 
    AND state != ''
    AND state NOT IN ('New Brunswick', 'Guam', 'Virgin Islands')
    AND status != 'ready_to_build';
    
SELECT COUNT(*) FROM re_us4;
    
-- Check for missing values in price and house_size
SELECT 
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS missing_price,
    SUM(CASE WHEN house_size IS NULL OR house_size = 0 THEN 1 ELSE 0 END) AS missing_house_size
FROM re_us4;

-- Check the extreme ends of price to spot garbage/outlier values
SELECT 
    MIN(price) AS min_price,
    MAX(price) AS max_price
FROM re_us4;

-- Look at the cheapest listings — likely placeholder/garbage prices
SELECT *
FROM re_us4
WHERE price < 5000
ORDER BY price ASC
LIMIT 20;

-- Look at the most expensive listings — likely data entry errors
SELECT *
FROM re_us4
ORDER BY price DESC
LIMIT 20;

-- Final cleaning stage for price and house_size:
-- 1. Treat price = 0 as missing (NULL) since it's disguised blank data, not a real free listing
-- 2. Remove the impossible overflow value and other clearly fake round-number prices
-- 3. Treat house_size = 0 as missing (NULL) for the same reason
CREATE TABLE re_us5 AS
SELECT
    status,
    CASE WHEN price = 0 THEN NULL ELSE price END AS price,
    bedrooms,
    bathrooms,
    acre_lot,
    street,
    city,
    state,
    zip_code,
    CASE WHEN house_size = 0 THEN NULL ELSE house_size END AS house_size,
    sold_date
FROM re_us4
WHERE price != 2147483600
  AND price != 1000000000
  AND price != 875000000;
SELECT COUNT(*) FROM re_us5;
SELECT MIN(price), MAX(price) FROM re_us5;

-- Final production table for Power BI:
-- Excludes any remaining unrealistic near-zero prices (under $1000, not a real sale/listing)
CREATE TABLE re_us_final AS
SELECT
    status,
    price,
    bedrooms,
    bathrooms,
    acre_lot,
    street,
    city,
    state,
    zip_code,
    house_size,
    sold_date,
    -- Extract year from sold_date for time-based analysis later (e.g. price trends by year)
    YEAR(sold_date) AS sold_year
FROM re_us5
WHERE price IS NULL OR price >= 1000;
SELECT COUNT(*) FROM re_us_final;

-- Check how many rows have implausible sold_year values
SELECT sold_year, COUNT(*) 
FROM re_us_final 
WHERE sold_year < 1990 OR sold_year > 2025
GROUP BY sold_year
ORDER BY sold_year;

-- Remove the 2 rows with impossible sold_year values (2026 future date, 3019 typo)
SET SQL_SAFE_UPDATES = 0;
DELETE FROM re_us_final
WHERE sold_year IN (2026, 3019);
SET SQL_SAFE_UPDATES = 1;

-- Some sold_date values were empty strings ('') rather than true NULLs, which breaks MONTH().
-- Convert those to NULL as well before extracting the month.
SET SQL_SAFE_UPDATES = 0;
UPDATE re_us_final
SET sold_date = NULL
WHERE sold_date = '';
SET SQL_SAFE_UPDATES = 1;

-- Add a sold_month column for monthly trend analysis
ALTER TABLE re_us_final ADD COLUMN sold_month INT;

-- Populate sold_month, only attempting conversion on values that actually look like valid
-- YYYY-MM-DD dates, skipping anything malformed instead of erroring out.
SET SQL_SAFE_UPDATES = 0;
UPDATE re_us_final
SET sold_month = MONTH(sold_date)
WHERE sold_date IS NOT NULL 
  AND sold_date != ''
  AND sold_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
SET SQL_SAFE_UPDATES = 1;

-- Final check: confirm sold_month populated correctly across all 12 months
SELECT sold_month, COUNT(*) 
FROM re_us_final 
WHERE sold_month IS NOT NULL
GROUP BY sold_month
ORDER BY sold_month;

/* ============================================================
   re_us_final is the finished, analysis-ready table used to
   power the Power BI dashboard (~2.19M clean rows).
   ============================================================ */
