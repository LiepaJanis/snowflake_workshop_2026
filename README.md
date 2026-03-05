# Snowflake Classwork - SalesDW

This repository contains a ready-to-run SQL script for your Snowflake workshop task.

## File

- `snowflake_classwork_setup.sql`
  - Creates `SalesDW` database.
  - Creates `RawData` and `Analytics` schemas.
  - Creates raw ingestion tables and an aggregated `SalesSummary` table.
  - Includes sample loading patterns (`Snowflake UI`, `SnowSQL + COPY INTO`, `Snowpipe`).
  - Transforms raw tables into `Analytics.SalesSummary`.
  - Provides analysis queries for revenue, top customers, and monthly trends.

## How to run

1. Open Snowsight Worksheets (or SnowSQL CLI).
2. Paste and run `snowflake_classwork_setup.sql`.
3. Upload your Kaggle CSV files into the stage/table loading flow shown in section 4.
4. Re-run section 5 (transformation load) after data import.
5. Run section 6 queries for results.

## Kaggle source

Dataset discussion reference provided in class:
- https://www.kaggle.com/discussions/accomplishments/469400

> Note: If your file columns differ from the assumed structure, adjust the `COPY INTO` mappings and data types in the script.
