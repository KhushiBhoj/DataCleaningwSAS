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

/* customer_id, Rule: Unique ID, drop duplicates (keep first) */
proc sort data=work.sales_raw out=work.sales_raw nodupkey;
    by customer_id;
run;

/* order_id, Rule: Unique order per customer, drop duplicate rows */
proc sort data=work.sales_raw out=work.sales_raw nodupkey;
    by customer_id order_id;
run;

/* order_date, Rule: Standardize YYYY-MM-DD, remove dates > today */
data work.sales_raw;
    set work.sales_raw;

    if not missing(order_date) then do;
        order_date_clean = input(order_date, yymmdd10.);
        if missing(order_date_clean) then order_date_clean = input(order_date, ddmmyy10.);
    end;

    if order_date_clean <= today();
    format order_date_clean yymmdd10.;

    retain customer_id order_id order_date_clean;
    drop order_date;
    rename order_date_clean = order_date;
run;

data work.sales_raw;
    retain customer_id order_id order_date ship_date product_category sales_amount discount region customer_age email;
    set work.sales_raw;
run;





