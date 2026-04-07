

/* User must modify */
  %let Indat = &dataset._5;   /* input dataset with KEY, I10_DX2-I10_DX30 and DXPOA2-DXPOA30 */
  %let Outdat = comps;  /* output wide dataset */
  %let fout = SICU.&dataset._6; /* Final merged output dataset */
  %let CompXlsx = "C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\Complications\Storesund_complications_codes_l.xlsx";

  /* Formats for ICD 10 diagnoses from Bobrovskiy on Github */
/* First, import using PROC IMPORT */
proc import datafile="C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\SAS Code Library\diagnosis.csv"
    out=ICDdx_raw
    dbms=csv
    replace;
    getnames=yes;
	guessingrows=5000;*You have to make PROC IMPORT look farther down than usual else it trucates the code;
run;

proc import datafile=&CompXlsx
    out=work.comp_truth_raw
    dbms=xlsx replace;
    getnames=yes;
run;

proc contents data=icddx_raw; run;
proc contents data=comp_truth_raw; run;

/*Create expanded complication file by prefix matching*/
proc sql;
    create table Complications_Expanded as
    select 
        a.CategoryNo,
        a.CAT,
        a.Category,
        a.SUB,
        a.Subcategory,
        a.ICD10 as Parent_Code,
        b.Code as ICD10_Expanded
    from comp_truth_raw as a
    left join icddx_raw as b
    on b.Code like cats(trim(a.ICD10), '%')
    order by a.CategoryNo, a.SUB, a.ICD10, b.Code;
quit;

/* Step 4: Check results */
proc freq data=Complications_Expanded;
    tables Parent_Code / nocum nopercent;
    title "Distribution of Parent Codes and Number of Daughter Codes";
run;

proc print data=Complications_Expanded (obs=50);
    title "First 50 Observations of Expanded Complications";
run;

/*** Classifier ***/
/* Step 1: Create numeric identifiers for categories and subcategories */
proc sort data=Complications_Expanded out=cat_map nodupkey;
    by CategoryNo CAT Category;
run;

/* Convert CategoryNo to numeric for proper sorting */
data sub_map_prep;
    set Complications_Expanded;
    CategoryNo_Num = input(CategoryNo, best.);
run;

proc sort data=sub_map_prep out=sub_map nodupkey;
    by CategoryNo_Num SUB Subcategory;
run;

/* Create subcategory numbering within each category */
data sub_map;
    set sub_map;
    by CategoryNo_Num;
    retain sub_num;
    if first.CategoryNo_Num then sub_num = 0;
    sub_num + 1;
    /* Create SubcategoryNo as Category*10 + sub_num (e.g., 11, 12, 21, 22, etc.) */
    SubcategoryNo = (CategoryNo_Num * 10) + sub_num;
run;

/* Verify the mapping */
proc print data=sub_map;
    var CategoryNo CategoryNo_Num CAT Category SUB Subcategory sub_num SubcategoryNo;
    title "Subcategory Mapping - Verify Order";
run;

/* Step 2: Add SubcategoryNo back to expanded complications */
proc sql;
    create table Complications_Expanded_Num as
    select 
        a.*,
        input(a.CategoryNo, best.) as CategoryNo_Num,
        b.SubcategoryNo
    from Complications_Expanded as a
    left join sub_map as b
    on input(a.CategoryNo, best.) = b.CategoryNo_Num 
       and a.SUB = b.SUB 
       and a.Subcategory = b.Subcategory;
quit;

/* Step 3: Reshape diagnosis data from wide to long and filter for POA='N' */
data dx_long;
    set &Indat;
    array dx{29} I10_DX2-I10_DX30;
    array poa{29} $ DXPOA2-DXPOA30;
    
    do i = 1 to 29;
        if not missing(dx{i}) and poa{i} = 'N' then do;
            ICD10_Code = dx{i};
            output;
        end;
    end;
    
    keep KEY ICD10_Code;
run;

/* Step 4: Match diagnoses to complications */
proc sql;
    create table matched_comps as
    select distinct
        a.KEY,
        b.CategoryNo_Num,
        b.SubcategoryNo
    from dx_long as a
    inner join Complications_Expanded_Num as b
    on a.ICD10_Code = b.ICD10_Expanded;
quit;

/* Step 5: Create wide format with category indicators */
proc sql;
    create table cat_wide as
    select distinct
        KEY,
        CategoryNo_Num,
        1 as flag
    from matched_comps;
quit;

proc transpose data=cat_wide out=cat_transposed(drop=_name_) prefix=CAT;
    by KEY;
    id CategoryNo_Num;
    var flag;
run;

/* Step 6: Create wide format with subcategory indicators */
proc sql;
    create table sub_wide as
    select distinct
        KEY,
        SubcategoryNo,
        1 as flag
    from matched_comps;
quit;

proc transpose data=sub_wide out=sub_transposed(drop=_name_) prefix=SUB;
    by KEY;
    id SubcategoryNo;
    var flag;
run;

/* Step 7: Get all unique KEYs from input dataset */
proc sql;
    create table all_keys as
    select distinct KEY
    from &Indat;
quit;

/* Step 8: Merge everything together and fill missing with 0 */
data &Outdat;
    merge all_keys(in=a)
          cat_transposed(in=b)
          sub_transposed(in=c);
    by KEY;
    
    /* Fill missing category variables with 0 */
    array cats{12} CAT1-CAT12;
    do i = 1 to 12;
        if missing(cats{i}) then cats{i} = 0;
    end;
    
    /* Fill missing subcategory variables with 0 */
    /* Create array for all possible subcategory variables */
    array subs{*} SUB:;
    do i = 1 to dim(subs);
        if missing(subs{i}) then subs{i} = 0;
    end;
    
    drop i;
run;

/* Step 9: Validation - verify subcategory alignment */
proc sql;
    create table validation as
    select 
        s.SubcategoryNo,
        s.CategoryNo_Num,
        s.CAT,
        s.Category,
        s.SUB,
        s.Subcategory,
        coalesce(sum(c.flag), 0) as Patient_Count
    from sub_map as s
    left join (
        select distinct KEY, SubcategoryNo, 1 as flag
        from matched_comps
    ) as c
    on s.SubcategoryNo = c.SubcategoryNo
    group by s.SubcategoryNo, s.CategoryNo_Num, s.CAT, s.Category, s.SUB, s.Subcategory
    order by s.SubcategoryNo;
quit;

proc print data=validation;
    title "Validation: Patient Counts by Subcategory";
run;

/* Step 10: Summary statistics */
proc freq data=&Outdat;
    tables CAT1-CAT12 / nocum nopercent;
    title "Distribution of Category Complications";
run;

/* List all SUB variables that were created */
proc contents data=&Outdat out=subvar_list(keep=name) noprint;
run;

proc sql;
    select name 
    from subvar_list 
    where substr(name,1,3) = 'SUB'
    order by name;
quit;

proc freq data=&Outdat;
    tables SUB: ;
    title "Distribution of Subcategory Complications";
run;
/* Step 10: Summary statistics */
proc freq data=&Outdat;
    tables CAT1-CAT12;
    title "Distribution of Category Complications";
run;

/*************************************/
/*** Merge back into Input dataset ***/

/* Sort datasets for merging */
proc sort data=&Indat;
    by KEY;
run;

proc sort data=&Outdat;
    by KEY;
run;

/* Merge and create Any_Comp variable */
data &fout;
    merge &Indat(in=a)
          &Outdat(in=b);
    by KEY;
    
    if a;  /* Keep all records from input dataset (left join) */
    
    /* Create Any_Comp variable - 1 if any category complication exists */
    Any_Comp = max(of CAT1-CAT12);
    
    /* Ensure Any_Comp is 0 if missing (for patients with no match) */
    if missing(Any_Comp) then Any_Comp = 0;
run;

/* Validation */
proc freq data=&fout;
    tables Any_Comp;
    title "Distribution of Any Complication";
run;

proc means data=&fout n nmiss min max sum;
    var Any_Comp CAT1-CAT12;
    title "Summary Statistics for Complications";
run;
