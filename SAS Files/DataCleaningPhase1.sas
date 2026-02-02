/* Import the data */
proc import datafile="/home/u64071450/Data Cleaning with SAS/sales_data_phase1.csv"
    out=work.sales_raw
    dbms=csv
    replace;
    guessingrows=MAX;
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

/* Export to CSV */
proc export data=work.sales_phase1_final
    outfile="/home/u64071450/Data Cleaning with SAS/sales_phase1_clean.csv"
    dbms=csv
    replace;
run;





