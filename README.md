# Automated Data Cleaning in SQL (MySQL)

A MySQL pipeline that takes a raw dataset of US household income records, copies it into a new table, cleans it, and re-runs itself automatically on a schedule. Every run is timestamped, so each cleaned batch can be traced back to when it was produced, and the original raw data is never modified.

**Tools:** MySQL 8, MySQL Workbench
**Techniques:** stored procedures, window functions (`ROW\_NUMBER`), scheduled events, data validation

\---

## The problem

The raw table `us\_household\_income` contains 32,292 rows describing US locations: state, county, city, place, place type, zip and area codes, land and water area, and coordinates.

It had several data quality issues:

|Issue|Example|
|-|-|
|Duplicate records|the same `id` appearing more than once (6 duplicates)|
|Misspelt state name|`georia` instead of `Georgia`|
|Inconsistent capitalisation|County, City, Place and State\_Name in mixed upper and lower case|
|Inconsistent category labels|`CPD` instead of `CDP`, `Boroughs` alongside `Borough` in the Type column|

Cleaning this by hand every time new data arrives is slow and easy to get wrong. The goal was to write the cleaning logic once and let the database run it automatically.

\---

## How it works

### 1\. Stored procedure: `Copy\_and\_Clean\_Data()`

Each time it runs, the procedure:

1. **Creates** the table `us\_household\_income\_cleaned` (only on the first run).
2. **Copies** every row from the raw table and adds a `TimeStamp` column recording when the run happened.
3. **Removes duplicates** using `ROW\_NUMBER()` partitioned by `id` and `TimeStamp`. This keeps one row per id within each run, so snapshots from previous runs are left untouched.
4. **Fixes typos:** `georia` becomes `Georgia`, `CPD` becomes `CDP`, `Boroughs` becomes `Borough`.
5. **Standardises formatting** by converting State\_Name, County, City and Place to upper case.

### 2\. Scheduled event: `run\_data\_cleaning`

A MySQL event calls the procedure every 365 days, so new raw data is cleaned without anyone having to run the script manually.

### 3\. Why the timestamp matters

Because every run adds a new timestamped snapshot rather than overwriting the old one, it's possible to:

* see exactly which batch a row came from,
* compare results between runs,
* check that the cleaning worked by comparing each batch against the raw data.

\---

## Results

|Check|Raw data|Cleaned data|
|-|-|-|
|Total rows|32292|32286|
|Duplicate ids|6|0|
|Misspelt state names|1 (`georia`)|0|
|Distinct Type values|12|10|

### Before cleaning

!\[Raw data before cleaning](before.png)

### After cleaning

!\[Cleaned data](after.png)

### Row counts

!\[Row counts before and after](row\_counts.png)

\---

## Validation

The script ends with a set of checks that prove the cleaning worked. Each one is run on both the raw and the cleaned table:

* row counts before and after
* a duplicate check (cleaned table returns no rows)
* total rows vs unique ids per run (the two numbers match)
* distinct State\_Name and Type values before and after

\---

## How to run it

1. Import the raw dataset into MySQL as a table named `us\_household\_income` (MySQL Workbench: right-click the schema, then **Table Data Import Wizard**).
2. Open `automated\_data\_cleaning.sql` in MySQL Workbench and run it.
3. The event scheduler must be on for the automation to work. The script turns it on with `SET GLOBAL event\_scheduler = ON;`.

**Dataset:** \[source]

\---

## Why I built this

I work as an auditor, and a large part of the job is testing whether data can be relied on before drawing conclusions from it. This project applies the same mindset in SQL: keep the source data untouched, make every change traceable, and verify the result rather than assume it.

\---

## Possible improvements

* Add a log table recording how many rows were removed or changed on each run.
* Flag suspicious values, such as coordinates outside the US or zero land area.
* Replace one-off typo fixes with a lookup table of valid state names and place types, so new typos are caught automatically.

\---

## Files

|File|Description|
|-|-|
|`automated\_data\_cleaning.sql`|Full script: procedure, event, and validation queries|
|`before.png`, `after.png`, `row\_counts.png`|Screenshots of the data before and after cleaning|



