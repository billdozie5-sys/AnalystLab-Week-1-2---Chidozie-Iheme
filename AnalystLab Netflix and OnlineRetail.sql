SELECT *
FROM dbo.OnlineRetail

SELECT *
FROM dbo.netflix_titles



CREATE TABLE dbo.netflix_titles_bk (
    show_id       NVARCHAR(50),
    type          NVARCHAR(50),
    title         NVARCHAR(MAX),
    director      NVARCHAR(MAX),
    cast          NVARCHAR(MAX),
    country       NVARCHAR(MAX),
    date_added    DATE,
    release_year  SMALLINT,
    rating        NVARCHAR(50),
    duration      NVARCHAR(50),
    listed_in     NVARCHAR(100),
    description   NVARCHAR(250)
    );



CREATE TABLE dbo.onlineRetail_bkpp (
    invoice_no   VARCHAR(20),
    stock_code   VARCHAR(20),
    description  TEXT,
    quantity     INT,
    invoice_date TEXT,          
    unit_price   NUMERIC(10,2),
    customer_id  VARCHAR(20),
    country      VARCHAR(50)
);


SELECT
    SUM(CASE WHEN director   IS NULL THEN 1 ELSE 0 END) AS missing_director,
    SUM(CASE WHEN cast       IS NULL THEN 1 ELSE 0 END) AS missing_cast,
    SUM(CASE WHEN country    IS NULL THEN 1 ELSE 0 END) AS missing_country,
    SUM(CASE WHEN date_added IS NULL THEN 1 ELSE 0 END) AS missing_date_added,
    SUM(CASE WHEN rating     IS NULL THEN 1 ELSE 0 END) AS missing_rating,
    SUM(CASE WHEN duration   IS NULL THEN 1 ELSE 0 END) AS missing_duration
FROM netflix_titles;

INSERT dbo.netflix_titles_bk
SELECT *
FROM dbo.netflix_titles;

UPDATE dbo.netflix_titles
SET type = UPPER(type);

UPDATE dbo.netflix_titles
SET date_added = TRY_CONVERT(DATE, date_added, 107)
WHERE date_added IS NOT NULL;

SELECT title, type, release_year, COUNT(*) AS cnt
FROM dbo.netflix_titles
GROUP BY title, type, release_year
HAVING COUNT(*) > 1;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN director = 'Unknown' THEN 1 ELSE 0 END) AS imputed_director,
    SUM(CASE WHEN rating = 'NR' THEN 1 ELSE 0 END) AS imputed_rating,
    SUM(CASE WHEN date_added_clean IS NULL THEN 1 ELSE 0 END) AS bad_dates,
    COUNT(DISTINCT show_id) AS unique_shows
FROM dbo.netflix_titles;


SELECT
    SUM(CASE WHEN customer_id  IS NULL THEN 1 ELSE 0 END) AS missing_customerid,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS missing_description
FROM dbo.OnlineRetail;

INSERT dbo.onlineRetail_bkpp
SELECT *
FROM dbo.OnlineRetail;

SELECT stock_code, description, COUNT(*) AS cnt
FROM dbo.OnlineRetail
WHERE unit_price = 0
GROUP BY stock_code, description
ORDER BY cnt DESC;

UPDATE dbo.OnlineRetail
SET description = CONCAT('[ZERO PRICE] ', description)
WHERE unit_price = 0;

UPDATE dbo.OnlineRetail
SET description = UPPER(LEFT(LOWER(description), 1)) + LOWER(SUBSTRING(description, 2, LEN(description)))
WHERE description IS NOT NULL;

UPDATE dbo.OnlineRetail
SET invoice_timestamp = TRY_CONVERT(DATETIME, invoice_date, 101)
WHERE invoice_date IS NOT NULL;

SELECT DISTINCT TOP 20 stock_code
FROM dbo.OnlineRetail
WHERE stock_code LIKE '%[^A-Za-z0-9]%';

SELECT
    invoice_no, stock_code, description, quantity,
    invoice_date, unit_price, Customer_ID, country,
    COUNT(*) AS occurrence_count
FROM dbo.OnlineRetail
GROUP BY
    invoice_no, stock_code, description, quantity,
    invoice_date, unit_price, customer_id, country
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

WITH duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                InvoiceNo, StockCode, Description, Quantity,
                InvoiceDate, UnitPrice, CustomerID, Country
            ORDER BY
                (SELECT NULL)
        ) AS rn
    FROM dbo.OnlineRetail
)
DELETE FROM duplicates
WHERE rn > 1;

SELECT COUNT(*) AS remaining_duplicates
FROM (
    SELECT invoice_no, stock_code, quantity, invoice_date, unit_price, customer_id
    FROM dbo.OnlineRetail
    GROUP BY invoice_no, stock_code, quantity, invoice_date, unit_price, customer_id
    HAVING COUNT(*) > 1
) sub;

SELECT *
INTO dbo.OnlineRetail_bkpp
FROM dbo.OnlineRetail
WHERE quantity < 0 OR invoice_no LIKE 'C%';

DELETE FROM dbo.OnlineRetail
WHERE quantity < 0 OR invoice_no LIKE 'C%';

SELECT COUNT(*)
FROM dbo.OnlineRetail
WHERE description IS NULL AND customer_id IS NULL;

DELETE FROM dbo.OnlineRetail
WHERE description IS NULL AND customer_id IS NULL;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS guest_purchases,
    SUM(CASE WHEN customer_id IS NOT NULL THEN 1 ELSE 0 END) AS identified_customers,
    SUM(CASE WHEN quantity < 0 THEN 1 ELSE 0 END) AS remaining_negatives,
    SUM(CASE WHEN unit_price <= 0 THEN 1 ELSE 0 END) AS remaining_bad_prices,
    MIN(invoice_timestamp) AS earliest_transaction,
    MAX(invoice_timestamp) AS latest_transaction
FROM dbo.OnlineRetail;