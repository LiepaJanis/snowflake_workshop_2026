-- Snowflake Classwork: SalesDW environment, loading, transformation, and analysis

-- =========================================================
-- 1) Environment setup
-- =========================================================
CREATE OR REPLACE DATABASE SalesDW;
USE DATABASE SalesDW;

CREATE OR REPLACE SCHEMA RawData;
CREATE OR REPLACE SCHEMA Analytics;

-- =========================================================
-- 2) Data modeling and table creation (RawData)
-- =========================================================
USE SCHEMA RawData;

-- Music products (songs/albums/etc.)
CREATE OR REPLACE TABLE Products (
    ProductID           STRING,
    ProductName         STRING,
    ArtistName          STRING,
    ProductCategory     STRING,      -- e.g., Pop, Rock, Hip-Hop
    ReleaseDate         DATE,
    UnitPrice           NUMBER(10,2),
    IsActive            BOOLEAN,
    SourceFileName      STRING,
    IngestedAt          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Distribution formats for each product (CD, Vinyl, Streaming, etc.)
CREATE OR REPLACE TABLE ProductFormats (
    ProductID           STRING,
    FormatCode          STRING,      -- e.g., CD, VINYL, DIGITAL, STREAMING
    FormatName          STRING,
    FormatMultiplier    NUMBER(10,4),-- optional coefficient for weighted analytics
    SourceFileName      STRING,
    IngestedAt          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Customers
CREATE OR REPLACE TABLE Customers (
    CustomerID          STRING,
    CustomerName        STRING,
    Region              STRING,
    Country             STRING,
    CustomerTier        STRING,
    SourceFileName      STRING,
    IngestedAt          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Raw sales transactions
CREATE OR REPLACE TABLE SalesTransactions (
    SalesID             STRING,
    SalesDate           DATE,
    CustomerID          STRING,
    ProductID           STRING,
    FormatCode          STRING,
    Quantity            NUMBER(12,2),
    UnitSalePrice       NUMBER(10,2),
    DiscountPct         NUMBER(5,2), -- 0-100
    CurrencyCode        STRING,
    SourceFileName      STRING,
    IngestedAt          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =========================================================
-- 3) Analytics table creation
-- =========================================================
USE SCHEMA Analytics;

CREATE OR REPLACE TABLE SalesSummary (
    SalesDate           DATE,
    SalesMonth          DATE,
    CustomerID          STRING,
    CustomerName        STRING,
    Region              STRING,
    Country             STRING,
    ProductID           STRING,
    ProductName         STRING,
    ArtistName          STRING,
    ProductCategory     STRING,
    FormatCode          STRING,
    FormatName          STRING,
    TotalQuantity       NUMBER(18,2),
    GrossSalesValue     NUMBER(18,2),
    DiscountValue       NUMBER(18,2),
    NetSalesValue       NUMBER(18,2),
    LoadedAt            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =========================================================
-- 4) Data loading options
-- =========================================================
-- Option A: Snowflake UI (Snowsight)
--   Data -> Databases -> SalesDW -> RawData -> target table -> Load Data
--
-- Option B: SQL + Internal Stage + COPY INTO
USE SCHEMA RawData;
CREATE OR REPLACE STAGE raw_csv_stage;

-- PUT requires SnowSQL/CLI and local file access.
-- Example paths (adjust to your files):
-- PUT file://~/kaggle_data/products.csv @raw_csv_stage AUTO_COMPRESS=TRUE;
-- PUT file://~/kaggle_data/product_formats.csv @raw_csv_stage AUTO_COMPRESS=TRUE;
-- PUT file://~/kaggle_data/customers.csv @raw_csv_stage AUTO_COMPRESS=TRUE;
-- PUT file://~/kaggle_data/sales_transactions.csv @raw_csv_stage AUTO_COMPRESS=TRUE;

CREATE OR REPLACE FILE FORMAT csv_ff
  TYPE = CSV
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('NULL','null','');

-- Example COPY commands:
-- COPY INTO Products
-- FROM (
--   SELECT
--     $1,$2,$3,$4,TRY_TO_DATE($5),TRY_TO_DECIMAL($6,10,2),TRY_TO_BOOLEAN($7),METADATA$FILENAME,CURRENT_TIMESTAMP()
--   FROM @raw_csv_stage/products.csv.gz
-- )
-- FILE_FORMAT = (FORMAT_NAME = csv_ff)
-- ON_ERROR = CONTINUE;
--
-- COPY INTO ProductFormats
-- FROM (
--   SELECT $1,$2,$3,TRY_TO_DECIMAL($4,10,4),METADATA$FILENAME,CURRENT_TIMESTAMP()
--   FROM @raw_csv_stage/product_formats.csv.gz
-- )
-- FILE_FORMAT = (FORMAT_NAME = csv_ff)
-- ON_ERROR = CONTINUE;
--
-- COPY INTO Customers
-- FROM (
--   SELECT $1,$2,$3,$4,$5,METADATA$FILENAME,CURRENT_TIMESTAMP()
--   FROM @raw_csv_stage/customers.csv.gz
-- )
-- FILE_FORMAT = (FORMAT_NAME = csv_ff)
-- ON_ERROR = CONTINUE;
--
-- COPY INTO SalesTransactions
-- FROM (
--   SELECT
--     $1,TRY_TO_DATE($2),$3,$4,$5,TRY_TO_DECIMAL($6,12,2),TRY_TO_DECIMAL($7,10,2),TRY_TO_DECIMAL($8,5,2),$9,
--     METADATA$FILENAME,CURRENT_TIMESTAMP()
--   FROM @raw_csv_stage/sales_transactions.csv.gz
-- )
-- FILE_FORMAT = (FORMAT_NAME = csv_ff)
-- ON_ERROR = CONTINUE;

-- Option C: Snowpipe
-- 1) Create pipe on @raw_csv_stage
-- 2) Configure cloud notification integration
-- 3) Auto-ingest as files land in cloud storage

-- =========================================================
-- 5) Transformation and load into Analytics.SalesSummary
-- =========================================================
USE DATABASE SalesDW;

INSERT OVERWRITE INTO Analytics.SalesSummary (
    SalesDate, SalesMonth, CustomerID, CustomerName, Region, Country,
    ProductID, ProductName, ArtistName, ProductCategory, FormatCode, FormatName,
    TotalQuantity, GrossSalesValue, DiscountValue, NetSalesValue
)
SELECT
    s.SalesDate,
    DATE_TRUNC('MONTH', s.SalesDate)::DATE AS SalesMonth,
    s.CustomerID,
    COALESCE(c.CustomerName, 'UNKNOWN') AS CustomerName,
    COALESCE(c.Region, 'UNKNOWN') AS Region,
    COALESCE(c.Country, 'UNKNOWN') AS Country,
    s.ProductID,
    COALESCE(p.ProductName, 'UNKNOWN') AS ProductName,
    COALESCE(p.ArtistName, 'UNKNOWN') AS ArtistName,
    COALESCE(p.ProductCategory, 'UNKNOWN') AS ProductCategory,
    s.FormatCode,
    COALESCE(f.FormatName, 'UNKNOWN') AS FormatName,
    SUM(COALESCE(s.Quantity, 0)) AS TotalQuantity,
    SUM(COALESCE(s.Quantity, 0) * COALESCE(s.UnitSalePrice, p.UnitPrice, 0)) AS GrossSalesValue,
    SUM((COALESCE(s.Quantity, 0) * COALESCE(s.UnitSalePrice, p.UnitPrice, 0)) * (COALESCE(s.DiscountPct, 0) / 100)) AS DiscountValue,
    SUM((COALESCE(s.Quantity, 0) * COALESCE(s.UnitSalePrice, p.UnitPrice, 0)) * (1 - (COALESCE(s.DiscountPct, 0) / 100))) AS NetSalesValue
FROM SalesDW.RawData.SalesTransactions s
LEFT JOIN SalesDW.RawData.Products p
    ON s.ProductID = p.ProductID
LEFT JOIN SalesDW.RawData.ProductFormats f
    ON s.ProductID = f.ProductID
   AND s.FormatCode = f.FormatCode
LEFT JOIN SalesDW.RawData.Customers c
    ON s.CustomerID = c.CustomerID
WHERE s.SalesDate IS NOT NULL
GROUP BY
    s.SalesDate,
    DATE_TRUNC('MONTH', s.SalesDate)::DATE,
    s.CustomerID,
    COALESCE(c.CustomerName, 'UNKNOWN'),
    COALESCE(c.Region, 'UNKNOWN'),
    COALESCE(c.Country, 'UNKNOWN'),
    s.ProductID,
    COALESCE(p.ProductName, 'UNKNOWN'),
    COALESCE(p.ArtistName, 'UNKNOWN'),
    COALESCE(p.ProductCategory, 'UNKNOWN'),
    s.FormatCode,
    COALESCE(f.FormatName, 'UNKNOWN');

-- =========================================================
-- 6) Querying and analysis
-- =========================================================

-- Q1: Total sales revenue per product category
SELECT
    ProductCategory,
    ROUND(SUM(NetSalesValue), 2) AS TotalRevenue
FROM SalesDW.Analytics.SalesSummary
GROUP BY ProductCategory
ORDER BY TotalRevenue DESC;

-- Q2: Top 10 customers by sales volume (value + quantity)
SELECT
    CustomerID,
    CustomerName,
    ROUND(SUM(NetSalesValue), 2) AS TotalSalesValue,
    SUM(TotalQuantity) AS TotalUnits
FROM SalesDW.Analytics.SalesSummary
GROUP BY CustomerID, CustomerName
ORDER BY TotalSalesValue DESC
LIMIT 10;

-- Q3: Sales trends over time (monthly)
SELECT
    SalesMonth,
    ROUND(SUM(NetSalesValue), 2) AS MonthlyRevenue,
    SUM(TotalQuantity) AS MonthlyUnits
FROM SalesDW.Analytics.SalesSummary
GROUP BY SalesMonth
ORDER BY SalesMonth;
