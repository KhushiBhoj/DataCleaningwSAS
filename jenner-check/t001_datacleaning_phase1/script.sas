/* Load a small sample of the raw sales data (the same rows and edge cases as
   Data/sales_data_phase1.csv, inlined so the bundle is self-contained and dated
   to keep every row inside the pipeline's own "not in the future" date check).
   Column order and types match what PROC IMPORT with guessingrows=MAX produces
   for this file: dates/category/region/email are character, the three numerics
   are numeric. */
data work.sales_raw;
    length customer_id $8 order_id $8
           order_date $12 ship_date $12
           product_category $20 region $20 email $40;
    infile datalines dsd truncover;
    input customer_id $ order_id $ order_date $ ship_date $
          product_category $ sales_amount discount region $
          customer_age email $;
datalines;
C001,O1001,2018-01-05,2018-01-04,Tech,1200,100,North East,29,john.doe@email.com
C002,O1002,2018-02-10,2018-02-15,technology,-500,50,NE,45,jane@@email.com
C003,O1003,2018-03-18,,Furniture,800,,South,17,
C004,O1004,18-04-2018,2018-04-25,Office Supplies,300,20,west,200,mike@email
C002,O1002,2018-02-10,2018-02-15,Technology,-500,50,NE,45,jane@@email.com
C005,O1005,2019-12-01,2019-12-05,TECH,1500,200,North-East,34,sara@email.com
C006,O1006,2018-06-11,2018-06-18,Office,0,0,,28,abc@email.com
C007,O1007,2020-01-01,2020-01-05,Furniture,400,30,South,31,tom@email.com
C008,O1008,2018-07-22,2018-07-30,office supplies,250,10,West,,invalid@
C009,O1009,2018-08-15,2018-08-20,Tech,999999,0,North East,40,invalidemail.com
C010,O1010,2018-09-10,2018-09-12,,600,50,South,27,lisa@email.com
C011,O1011,2018-10-05,2018-10-10,Technology,450,30,NE,22,user11@email.com
C012,O1012,2018-10-08,2018-10-09,Furniture,700,70,East,65,user12@email.com
C013,O1013,2018-11-01,2018-10-30,Tech,900,90,North East,38,user13@email.com
C014,O1014,2018-11-05,2018-11-12,Office Supplies,150,5,West,19,user14@email.com
;
run;

/* Understanding the structure */
proc contents data=work.sales_raw;
run;

/* Row Count */
proc sql;
    select count(*) as total_rows
    from work.sales_raw;
quit;

/* Missing Values Count */
proc means data=work.sales_raw n nmiss;
run;

/* Categorical Check */
proc freq data=work.sales_raw;
    tables product_category region;
run;

/* Numerical Sanity Check */
proc means data=work.sales_raw min max mean;
    var sales_amount discount customer_age;
run;

proc freq data=work.sales_raw;
    tables order_date ship_date;
run;

/* STEP 1: Remove duplicates (order-level, not customer-level) */
proc sort data=work.sales_raw
          out=work.sales_dedup
          nodupkey;
    by customer_id order_id;
run;

/* STEP 2: Clean & standardize dates */
data work.sales_dates_clean;
    set work.sales_dedup;

    length order_date_issue $20;
    length order_dt 8;

    /* Detect format by position */
    if substr(order_date,5,1) = '-' then
        order_dt = input(order_date, yymmdd10.);
    else if substr(order_date,3,1) = '-' then
        order_dt = input(order_date, ddmmyy10.);
    else
        order_dt = .;

    /* Validation */
    if missing(order_dt) then
        order_date_issue = "INVALID_FORMAT";
    else if order_dt > today() then
        delete;
    else
        order_date_issue = "OK";

    format order_dt yymmdd10.;
    drop order_date;
    rename order_dt = order_date;
run;
data work.sales_dates_clean;
    set work.sales_dates_clean;

    length ship_date_issue $30;
    length ship_dt 8;

    /* Parse ship_date safely */
    if vtype(ship_date) = 'C' then do;
        if substr(ship_date,5,1) = '-' then
            ship_dt = input(ship_date, yymmdd10.);
        else if substr(ship_date,3,1) = '-' then
            ship_dt = input(ship_date, ddmmyy10.);
        else ship_dt = .;
    end;
    else ship_dt = ship_date; /* already numeric */

    /* Validation & rule */
    if missing(ship_dt) then ship_date_issue = "MISSING_SHIP_DATE";
    else if ship_dt < order_date then do;
        ship_date_issue = "SHIP_BEFORE_ORDER";
        ship_dt = .;  /* set invalid date to missing */
    end;
    else ship_date_issue = "OK";

    format ship_dt yymmdd10.;
    drop ship_date;
    rename ship_dt = ship_date;
run;

/* STEP 3: Standardize product category & region */
data work.sales_cat_clean;
    set work.sales_dates_clean;

    /* Product Category */
    product_category = lowcase(strip(product_category));

    if product_category in ("tech","technology") then product_category="Technology";
    else if product_category in ("office","office supplies","office supplies ") then product_category="Office Supplies";
    else if product_category="furniture" then product_category="Furniture";
    else product_category="Unknown";

    /* Region */
    region = lowcase(strip(region));

    if region in ("ne","north east","north-east") then region="North East";
    else if region="west" then region="West";
    else if region="south" then region="South";
    else if region="east" then region="East";
    else region="Unknown";
run;

/* STEP 4: Numeric cleaning (sales, discount, age) */
data work.sales_numeric_clean;
    set work.sales_cat_clean;

    if sales_amount <= 0 then sales_amount = .;

    if missing(discount) or discount < 0 then discount = 0;

    if customer_age < 18 or customer_age > 100 then customer_age = .;
run;

/* STEP 5: Email validation (simple but acceptable) */
data work.sales_stage1_clean;
    set work.sales_numeric_clean;

    if index(email,"@")=0 or index(email,".")=0 then email_valid="N";
    else email_valid="Y";
run;


/* SAS CODE: Final Clean Table & Export */
data work.sales_phase1_final;
    retain customer_id
           order_id
           order_date
           ship_date
           sales_amount
           discount
           customer_age
           product_category
           region
           email
           flags; /* force exact order */

    set work.sales_stage1_clean;

    /* Combine all flags into single column */
    length flags $200;
    flags = catx("; ",
                 "OrderDate:" || order_date_issue,
                 "ShipDate:"  || ship_date_issue,
                 "Sales:"     || coalesce(sales_issue,"OK"),
                 "Discount:"  || coalesce(discount_issue,"OK"),
                 "Age:"       || coalesce(age_issue,"OK"),
                 "Email:"     || email_valid);

	 drop order_date_issue ship_date_issue sales_issue discount_issue age_issue email_valid;

run;

proc sort data=work.sales_phase1_final;
    by customer_id order_id;
run;

/* Final clean table */
proc print data=work.sales_phase1_final noobs;
    var customer_id order_id order_date ship_date sales_amount
        discount customer_age product_category region email flags;
run;
