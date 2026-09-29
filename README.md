# layoffs_sql_data_cleaning
MYSQL data cleaning and exploratory analysis of global tech layoffs(2020-2023).
# World Layoffs: SQL Data Cleaning & Exploratory Analysis

A MySQL project that takes a raw, messy global layoffs dataset, cleans it step by step, and then analyzes it to find when, where and in which industries layoffs hit hardest.

## Overview

| | |
|---|---|
| **Tool** | MySQL 8 + MySQL Workbench |
| **Raw data** | 2,361 rows (`layoffs.csv`) |
| **Clean data** | 1,999 rows |
| **Period covered** | March 2020 to early 2023 (2023 is a partial year) |
| **SQL skills used** | CTEs, window functions (`ROW_NUMBER`, `DENSE_RANK`, running `SUM`), self-joins, `STR_TO_DATE`, `TRIM`, `GROUP BY` / `HAVING`, `ALTER TABLE` |

**Dataset source:** https://github.com/AlexTheAnalyst/MySQL-YouTube-Series

## Project structure

```
.
├── layoffs_data_cleaning.sql   # full cleaning + analysis script
├── layoffs.csv                 # raw dataset
└── README.md
```

## Data cleaning process

The raw `layoffs` table is never modified. All work happens in staging copies.

1. **Staging table.** Created `layoffs_staging` as a copy of the raw table.
2. **Duplicate check.** Used `ROW_NUMBER() OVER (PARTITION BY ...)` across all columns in a second staging table (`layoffs_staging2`) with a `row_num` helper column. MySQL cannot delete from a CTE, so duplicates are deleted where `row_num > 1`. No true duplicates were found in this dataset.
3. **Standardization.**
   - Trimmed extra spaces in company names.
   - Merged industry variants (`Crypto`, `Crypto Currency`, `CryptoCurrency`) into `Crypto`.
   - Fixed country typos such as `United States.` (trailing period).
   - Converted `date` from text to a real `DATE` column with `STR_TO_DATE`.
4. **NULLs and blanks.**
   - Turned blank industries into NULL.
   - Filled missing industries from other rows of the same company using a self-join.
   - Deleted 362 rows that had neither `total_laid_off` nor `percentage_laid_off`, since they carry no layoff information.
5. **Cleanup.** Dropped the `row_num` helper column.
6. **Validation.** Final checks confirm the row count, no duplicates, no blank industries, no empty rows, and the correct column types.

## Key findings

### Layoffs by industry (top 5)

| Industry | Total laid off |
|---|---|
| Consumer | 46,682 |
| Retail | 43,613 |
| Other | 36,289 |
| Transportation | 31,998 |
| Finance | 28,344 |

### Biggest layoff months

| Month | Total laid off |
|---|---|
| 2023-01 | 84,714 |
| 2022-11 | 53,751 |
| 2023-02 | 38,093 |
| 2020-04 | 26,710 |
| 2020-05 | 25,804 |

- January 2023 is the single worst month in the data, well above the April and May 2020 COVID spike.
- The rolling total reached about 76,951 by July 2020, driven almost entirely by the first three months of the pandemic.

### Layoffs by country (top 5)

| Country | Total laid off |
|---|---|
| United States | 256,474 |
| India | 35,993 |
| Netherlands | 17,220 |
| Sweden | 11,264 |
| Brazil | 10,691 |

### Top 3 countries per year

| Year | 1st | 2nd | 3rd |
|---|---|---|---|
| 2020 | United States (50,385) | India (12,932) | Netherlands (4,600) |
| 2021 | United States (9,470) | India (4,080) | China (1,800) |
| 2022 | United States (106,410) | India (14,224) | Brazil (5,189) |
| 2023 | United States (89,709) | Sweden (9,100) | Netherlands (7,500) |

- The United States ranks first in every year.
- Layoffs fell sharply in 2021, then surged in 2022 and 2023.
- India was second from 2020 to 2022 but dropped out of the top 3 in 2023.

### Companies that shut down completely

116 companies laid off 100% of their staff.

| Year | Complete shutdowns |
|---|---|
| 2020 | 36 |
| 2021 | 8 |
| 2022 | 58 |
| 2023 | 14 |

The five with the most funding raised:

| Company | Funds raised ($M) |
|---|---|
| Britishvolt | 2,400 |
| Quibi | 1,800 |
| Deliveroo Australia | 1,700 |
| Katerra | 1,600 |
| BlockFi | 1,000 |

### Top companies by year (examples)

- 2020: Uber (7,525), Booking.com (4,375), Groupon (2,800)
- 2021: Bytedance (3,600), Katerra (2,434)

## How to run this project

1. Create the schema: `CREATE DATABASE world_layoffs;`
2. In MySQL Workbench, right-click **Tables → Table Data Import Wizard**, import `layoffs.csv`, and name the table `layoffs`.
3. Open `layoffs_data_cleaning.sql` (**File → Open SQL Script**).
4. Run **one statement at a time** with `Ctrl+Enter`. Do not use "Execute All".
5. Check the validation section at the end of the script:
   - `COUNT(*)` on `layoffs_staging2` should return **1999**
   - the duplicate, blank-industry and empty-row checks should return **0**
   - `DESCRIBE layoffs_staging2` should show `date` as `DATE` and no `row_num` column

## Limitations

- 2023 covers only the first few months, so compare it to full years with care.
- `total_laid_off` is missing for some companies, such as Quibi and BlockFi. Sums skip those rows, so totals are a lower bound.
- The data is compiled from public reports and skews toward US tech companies, so country and industry totals reflect what was reported, not every layoff worldwide.
- Bally's Interactive has no industry recorded and no other row to copy it from, so it stays NULL.

## Author

_Your name · [LinkedIn](https://www.linkedin.com/in/sonia-sharma-b21a55325?utm_source=share_via&utm_content=profile&utm_medium=member_android) · [GitHub](https://github.com/Soniasharma24)_
