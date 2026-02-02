# Data Cleaning with SAS (Phase 1)

## Project Overview

This project demonstrates **data engineering thinking** using **SAS** to clean and prepare raw sales data for downstream ETL and analytics workflows.  

**Key Objectives:**
- Remove duplicates and enforce unique orders
- Standardize and validate dates
- Clean numeric and categorical columns
- Validate email addresses
- Flag missing or invalid data for analyst review
- Produce a **ready-to-use, clean dataset** for ETL / Data Warehousing

---

## Dataset Source

The raw dataset (`sales_data_phase1.csv`) used in this project is **synthetic** and **generated with the help of ChatGPT** for learning and demonstration purposes.  

> ⚠️ Credit: ChatGPT for generating sample data.  

---

## Cleaning Steps

1. **Duplicate Removal**
   - Duplicates at the **order level** (`customer_id + order_id`) are removed, keeping the first occurrence.

2. **Date Cleaning**
   - **Order Date**: Standardized to `YYYY-MM-DD`, invalid or future dates are removed.
   - **Ship Date**: Standardized similarly; if missing → flagged, if earlier than order date → flagged and set to missing.

3. **Numeric Cleaning**
   - `sales_amount`: Negative or zero values → set to missing
   - `discount`: Negative or missing values → set to 0
   - `customer_age`: Age < 18 or > 100 → set to missing

4. **Categorical Cleaning**
   - `product_category` and `region` standardized to common categories (e.g., “Technology”, “Office Supplies”, “North East”)
   - Unknown or misspelled categories mapped to `Unknown`

5. **Email Validation**
   - Simple check for `@` and `.`  
   - Invalid emails flagged

6. **Flag Column**
   - All issues are combined into a single column `flags` for easy review:
     ```
     OrderDate:OK; ShipDate:SHIP_BEFORE_ORDER; Sales:OK; Discount:OK; Age:OK; Email:Y
     ```

7. **Final Dataset**
   - Columns in exact order:
     ```
     customer_id, order_id, order_date, ship_date, sales_amount, discount, customer_age, product_category, region, email, flags
     ```
   - Ready for ETL / Data Warehouse ingestion

---

## SAS Techniques Used

- `proc import` → Load CSV
- `proc sort` → Remove duplicates
- `data step` → Data transformation, validation, cleaning
- `substr`, `input`, `coalesce` → Handle multiple date formats, missing values
- `retain` → Force column order
- `proc export` → Save cleaned CSV
- Conditional logic → Flag invalid / missing data

---

## Project Highlights

- Demonstrates **data engineer mindset**: from raw data → clean → ETL-ready
- Shows **SAS proficiency**: importing, cleaning, transforming, exporting
- **Flagging system** allows analysts to quickly see problematic records
- Ready for **next phase**: ETL pipeline / Data Warehouse / Analytics
- Uses **synthetic data generated with ChatGPT** to simulate real-world scenarios

---

## Files in this Project

| File | Description |
|------|------------|
| `sales_data_phase1.csv` | Raw synthetic sales dataset (generated using ChatGPT) |
| `phase1_cleaning.sas` | SAS script performing full data cleaning |
| `sales_phase1_clean.csv` | Final cleaned dataset ready for ETL |

---

## Credits

- Project workflow & design: **Khushi Bhoj**  
- Synthetic dataset generation: **ChatGPT**  
- Tools used: **SAS Studio / Base SAS**
