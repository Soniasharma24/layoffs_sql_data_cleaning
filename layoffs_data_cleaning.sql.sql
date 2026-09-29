-- =====================================================================
-- Project : World Layoffs - Data Cleaning and Exploratory Analysis


-- Database: MySQL 8+ (MySQL Workbench)
-- Raw table: layoffs (imported from layoffs.csv, never modified)
-- Working tables: layoffs_staging, layoffs_staging2
--
-- HOW TO RUN: highlight one statement at a time and press Ctrl+Enter.
-- Do NOT use the lightning bolt (Execute All) on a script that
-- contains DROP/TRUNCATE/INSERT
-- =====================================================================

USE world_layoffs;

SET SQL_SAFE_UPDATES = 0;


-- =====================================================================
-- STEP 1: CREATEING A STAGING COPY
-- =====================================================================
DROP TABLE IF EXISTS layoffs_staging;
CREATE TABLE layoffs_staging LIKE layoffs;

INSERT INTO layoffs_staging
SELECT * FROM layoffs;

-- Expect the same row count as the raw table
SELECT COUNT(*) AS raw_rows     FROM layoffs;
SELECT COUNT(*) AS staging_rows FROM layoffs_staging;


-- =====================================================================
-- STEP 2: REMOVE DUPLICATES

DROP TABLE IF EXISTS layoffs_staging2;
CREATE TABLE layoffs_staging2 (
  company               text,
  location              text,
  industry              text,
  total_laid_off        int DEFAULT NULL,
  percentage_laid_off   text,
  `date`                text,
  stage                 text,
  country               text,
  funds_raised_millions int DEFAULT NULL,
  row_num               int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO layoffs_staging2
SELECT *,
       ROW_NUMBER() OVER (
         PARTITION BY company, location, industry, total_laid_off,
                      percentage_laid_off, `date`, stage, country,
                      funds_raised_millions
       ) AS row_num
FROM layoffs_staging;

-- Inspect duplicates first (row_num > 1)
SELECT * FROM layoffs_staging2 WHERE row_num > 1;

DELETE FROM layoffs_staging2
WHERE row_num > 1;


-- =====================================================================
-- STEP 3: STANDARDIZE THE DATA
-- =====================================================================


UPDATE layoffs_staging2
SET company = TRIM(company);

-- 3b. Mergeing industry variants (Crypto, Crypto Currency, CryptoCurrency)
SELECT DISTINCT industry FROM layoffs_staging2 ORDER BY 1;

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';


SELECT DISTINCT country FROM layoffs_staging2 ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';


UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;


-- =====================================================================
-- STEP 4: NULLS AND BLANKS
-- =====================================================================

-- 4a. Turning blank industries into real NULLs
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

SELECT * FROM layoffs_staging2 WHERE industry IS NULL;

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
 AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;


SELECT * FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- =====================================================================
-- STEP 5: DROP THE HELPER COLUMN
-- =====================================================================
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- =====================================================================
-- STEP 6: VALIDATION CHECKS
-- =====================================================================

SELECT COUNT(*) AS final_rows FROM layoffs_staging2;

SELECT company, location, industry, total_laid_off, percentage_laid_off,
       `date`, stage, country, funds_raised_millions, COUNT(*) AS copies
FROM layoffs_staging2
GROUP BY 1,2,3,4,5,6,7,8,9
HAVING COUNT(*) > 1;

-- Blank industries (expect 0)
SELECT COUNT(*) AS blank_industries
FROM layoffs_staging2 WHERE industry = '';

-- Rows with no layoff data (expect 0)
SELECT COUNT(*) AS empty_rows
FROM layoffs_staging2
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

-- `date` should be type DATE and row_num should be gone
DESCRIBE layoffs_staging2;

-- Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;


-- =====================================================================
-- STEP 7: EXPLORATORY DATA ANALYSIS
-- =====================================================================

-- Layoffs by industry
SELECT industry, SUM(total_laid_off) AS total
FROM layoffs_staging2
GROUP BY industry
ORDER BY total DESC;

-- Layoffs by country
SELECT country, SUM(total_laid_off) AS total
FROM layoffs_staging2
GROUP BY country
ORDER BY total DESC;

-- Layoffs by funding stage
SELECT stage, SUM(total_laid_off) AS total
FROM layoffs_staging2
GROUP BY stage
ORDER BY total DESC;

-- Layoffs by year
SELECT YEAR(`date`) AS yr, SUM(total_laid_off) AS total
FROM layoffs_staging2
GROUP BY yr
ORDER BY yr;

-- Biggest layoff months
SELECT SUBSTRING(`date`, 1, 7) AS month, SUM(total_laid_off) AS total
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY month
ORDER BY total DESC
LIMIT 5;

-- Rolling total by month
WITH monthly AS (
  SELECT SUBSTRING(`date`, 1, 7) AS month, SUM(total_laid_off) AS total
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY month
)
SELECT month, total,
       SUM(total) OVER (ORDER BY month) AS rolling_total
FROM monthly
ORDER BY month;

-- Top 3 companies per year
WITH company_year AS (
  SELECT company, YEAR(`date`) AS yr, SUM(total_laid_off) AS total
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY company, YEAR(`date`)
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY yr ORDER BY total DESC) AS rnk
  FROM company_year
  WHERE total IS NOT NULL
)
SELECT * FROM ranked WHERE rnk <= 3 ORDER BY yr, rnk;

-- Top 3 countries per year
WITH country_year AS (
  SELECT YEAR(`date`) AS yr, country, SUM(total_laid_off) AS total
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY yr, country
  HAVING total IS NOT NULL
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY yr ORDER BY total DESC) AS rnk
  FROM country_year
)
SELECT * FROM ranked WHERE rnk <= 3 ORDER BY yr, rnk;

-- Companies that laid off 100% of staff (biggest funding first)
SELECT company, total_laid_off, funds_raised_millions
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- Complete shutdowns per year
SELECT YEAR(`date`) AS yr, COUNT(*) AS shutdowns
FROM layoffs_staging2
WHERE percentage_laid_off = 1
GROUP BY yr
ORDER BY yr;
