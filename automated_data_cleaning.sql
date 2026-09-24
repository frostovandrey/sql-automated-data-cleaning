-- =====================================================================
-- Automated Data Cleaning Project (MySQL 8)
-- Author: Andrii Morozov
--
-- Raw table:     us_household_income          (never modified)
-- Cleaned table: us_household_income_cleaned  (timestamped snapshots)
--
-- What this script does:
--   1. Creates a stored procedure that copies the raw data into a new
--      table, stamps every row with the run time, removes duplicates
--      and fixes typos / inconsistent formatting.
--   2. Runs the procedure once.
--   3. Schedules it to run automatically every 365 days.
--   4. Provides validation queries to prove the cleaning worked.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Quick look at the data
-- ---------------------------------------------------------------------
SELECT * FROM us_household_income;
-- SELECT * FROM us_household_income_cleaned;

-- ---------------------------------------------------------------------
-- 1. Stored procedure: copy and clean
-- ---------------------------------------------------------------------
DELIMITER $$

DROP PROCEDURE IF EXISTS Copy_and_Clean_Data $$

CREATE PROCEDURE Copy_and_Clean_Data()
BEGIN

    -- 1a. Create the cleaned table (only on the first run)
    CREATE TABLE IF NOT EXISTS `us_household_income_cleaned` (
        `row_id`     int DEFAULT NULL,
        `id`         int DEFAULT NULL,
        `State_Code` int DEFAULT NULL,
        `State_Name` text,
        `State_ab`   text,
        `County`     text,
        `City`       text,
        `Place`      text,
        `Type`       text,
        `Primary`    text,
        `Zip_Code`   int DEFAULT NULL,
        `Area_Code`  int DEFAULT NULL,
        `ALand`      int DEFAULT NULL,
        `AWater`     int DEFAULT NULL,
        `Lat`        double DEFAULT NULL,
        `Lon`        double DEFAULT NULL,
        `TimeStamp`  TIMESTAMP DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

    -- 1b. Copy raw data and stamp every row with the time of this run
    INSERT INTO us_household_income_cleaned
    SELECT *, CURRENT_TIMESTAMP
    FROM us_household_income;

    -- 1c. Remove duplicates
    --     Duplicates are identified per id WITHIN the same run (TimeStamp),
    --     so snapshots from earlier runs are never touched.
    DELETE FROM us_household_income_cleaned
    WHERE row_id IN (
        SELECT row_id
        FROM (
            SELECT row_id, id,
                   ROW_NUMBER() OVER (
                       PARTITION BY id, `TimeStamp`
                       ORDER BY id, `TimeStamp`
                   ) AS row_num
            FROM us_household_income_cleaned
        ) duplicates
        WHERE row_num > 1
    );

    -- 1d. Fix typos
    UPDATE us_household_income_cleaned
    SET State_Name = 'Georgia'
    WHERE State_Name = 'georia';

    UPDATE us_household_income_cleaned
    SET `Type` = 'CDP'
    WHERE `Type` = 'CPD';

    UPDATE us_household_income_cleaned
    SET `Type` = 'Borough'
    WHERE `Type` = 'Boroughs';

    -- 1e. Standardise capitalisation
    UPDATE us_household_income_cleaned SET State_Name = UPPER(State_Name);
    UPDATE us_household_income_cleaned SET County     = UPPER(County);
    UPDATE us_household_income_cleaned SET City       = UPPER(City);
    UPDATE us_household_income_cleaned SET Place      = UPPER(Place);

END $$

DELIMITER ;


-- ---------------------------------------------------------------------
-- 2. Run the procedure once
-- ---------------------------------------------------------------------
CALL Copy_and_Clean_Data();


-- ---------------------------------------------------------------------
-- 3. Automate it: run every 365 days
-- ---------------------------------------------------------------------
SET GLOBAL event_scheduler = ON;   -- events only fire if the scheduler is on

DROP EVENT IF EXISTS run_data_cleaning;

CREATE EVENT run_data_cleaning
    ON SCHEDULE EVERY 365 DAY
    STARTS CURRENT_TIMESTAMP + INTERVAL 365 DAY
    DO CALL Copy_and_Clean_Data();
    

SHOW EVENTS;


-- ---------------------------------------------------------------------
-- 4. Validation: prove the cleaning worked
--    Run each check on the raw table and on the cleaned table.
-- ---------------------------------------------------------------------

-- 4a. Row counts (raw vs cleaned)
SELECT COUNT(*) AS raw_rows     FROM us_household_income;
SELECT COUNT(*) AS cleaned_rows FROM us_household_income_cleaned;

-- 4b. Duplicate ids (raw should show some, cleaned should show none)
SELECT id, COUNT(*) AS occurrences
FROM us_household_income
GROUP BY id
HAVING COUNT(*) > 1;

SELECT id, `TimeStamp`, COUNT(*) AS occurrences
FROM us_household_income_cleaned
GROUP BY id, `TimeStamp`
HAVING COUNT(*) > 1;

-- 4c. Rows vs unique ids per run (these two numbers should match)
SELECT `TimeStamp`,
       COUNT(*)           AS total_rows,
       COUNT(DISTINCT id) AS unique_ids
FROM us_household_income_cleaned
GROUP BY `TimeStamp`;

-- 4d. State names (raw contains 'georia' and mixed casing)
SELECT State_Name, COUNT(*) AS n
FROM us_household_income
GROUP BY State_Name
ORDER BY State_Name;

SELECT State_Name, COUNT(*) AS n
FROM us_household_income_cleaned
GROUP BY State_Name
ORDER BY State_Name;

-- 4e. Type categories (raw contains 'CPD' and 'Boroughs')
SELECT `Type`, COUNT(*) AS n
FROM us_household_income
GROUP BY `Type`
ORDER BY `Type`;

SELECT `Type`, COUNT(*) AS n
FROM us_household_income_cleaned
GROUP BY `Type`
ORDER BY `Type`;


-- ---------------------------------------------------------------------
-- 5. Cleanup (optional, only if you want to remove the automation)
-- ---------------------------------------------------------------------
-- DROP EVENT IF EXISTS run_data_cleaning;
-- DROP PROCEDURE IF EXISTS Copy_and_Clean_Data;