/***************************/
/*** MD SICU  2016-2024 ***/
/*** Data cut and labeling*/
/**************************/

/*** January 2026 ***/

libname SICU 'C:\Users\HP375\Documents\Research\SICU Maryland\SAS_datasets2';
libname AHA 'C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\AHA Hospital Data';

libname md16 "D:\SID\Maryland 2016";
libname md17 "D:\SID\Maryland 2017";
libname md18 "D:\SID\Maryland 2018";
libname md19 "D:\SID\Maryland 2019";
libname md20 "D:\SID\Maryland 2020";
libname md21 "D:\SID\Maryland 2021";
libname md22 "D:\SID\Maryland 2022";
libname md23 "D:\SID\Maryland 2023";
libname md24 "D:\SID\Maryland 2024";

/* This code block is necessary to get correct numbers ***********/
/* It fixes errors in HCUP's Hospital Linkage files **************/
/* Most notably, UM Shock Trauma 218992 is missing hospital link */
/* This resets it to UMMC, which is how AHA Survey Treats it *****/
/* 	210068 is not a permanent hospital. It is Baltimore Convention Center Field Hospital for COVID. It is coded to be excluded.
	210089 is Advantist Rehab */

%macro fix_ahal;

%local yr lib;

%do yr = 2016 %to 2024;

    %let lib = md%substr(&yr,3,2);

    /* Step 1: Create a copy */
    data &lib..md_SIDC_&yr._ahal_;
        set &lib..md_SIDC_&yr._ahal;
    run;

    /* Step 2: Apply updates to the copy */
    proc sql;
        update &lib..md_SIDC_&yr._ahal_
            set AHAID = '6320590',
                COMMUNITY_NONREHAB_NONLTAC = 1
            where missing(AHAID) and DSHOSPID = '210006';

        update &lib..md_SIDC_&yr._ahal_
            set AHAID = '6320395',
                COMMUNITY_NONREHAB_NONLTAC = 1
            where missing(AHAID) and DSHOSPID = '210016';

        update &lib..md_SIDC_&yr._ahal_
            set AHAID = '6320330',
                HOSPID = 24078, 
                HFIPSSTCO = 24510, 
                COMMUNITY_NONREHAB_NONLTAC = 1
            where missing(AHAID) and DSHOSPID = '218992';

        update &lib..md_SIDC_&yr._ahal_
            set COMMUNITY_NONREHAB_NONLTAC = 0
            where DSHOSPID in ('210068', '210089');

        /* 2019-only rule */
        %if &yr = 2019 %then %do;
            update &lib..md_SIDC_&yr._ahal_
                set COMMUNITY_NONREHAB_NONLTAC = 1, HFIPSSTCO=24031
                where DSHOSPID = '210016';
		%end;

		%if &yr = 2023 %then %do;
            update &lib..md_SIDC_&yr._ahal_
                set COMMUNITY_NONREHAB_NONLTAC = 1, HFIPSSTCO=24025, HOSPID=24051
                where DSHOSPID = '210006';
		%end;

		%if &yr = 2024 %then %do;
            update &lib..md_SIDC_&yr._ahal_
                set COMMUNITY_NONREHAB_NONLTAC = 1, HFIPSSTCO=24025, HOSPID=24051
                where DSHOSPID = '210006';
        %end;

    quit;

%end;

%mend;

%fix_ahal;

proc print data=md24.md_sidc_2024_ahal_;run;

/*** Code assumes 2019 and prior are PCLASS labelled ***/

%macro process_year(lib=, yr=);

  %local ds_core ds_chgs ds_ahal
         core_adult core_ahal chgs_icu final_out;

  %let ds_core  = md_sidc_&yr._core;
  %let ds_chgs  = md_sidc_&yr._chgs;
  %let ds_ahal  = md_sidc_&yr._ahal_;

  %let core_adult = work.md&yr._core_adult;
  %let core_ahal  = work.md&yr._core_ahal;
  %let chgs_icu   = work.md&yr._chgs_icu;
  %let final_out  = work.md&yr._final;

  /*****************************************************************
   1) CORE: keep ONLY exclusion criterion = AGE < 18
      Compute icu_stay flag, excluding DaysBurnUnit
  ******************************************************************/
  data &core_adult;
    set &lib..&ds_core;
    where AGE >= 18;

    /* ICU stay days flag (DO NOT include DaysBurnUnit) */
    icu_stay = 0;
    if not missing(DAYSCCU)            then icu_stay = 1;
    else if not missing(DaysICU)       then icu_stay = 1;
    else if not missing(DaysShockUnit) then icu_stay = 1;
    else if not missing(daysPICU)      then icu_stay = 1;
    /* intentionally excluded: DaysBurnUnit */
  run;

  /*****************************************************************
   2) AHA: merge onto adult core by DSHOSPID (keep all adult core rows)
  ******************************************************************/
  proc sort data=&lib..&ds_ahal out=work._ahal_sorted nodupkey;
    by DSHOSPID;
  run;

  proc sort data=&core_adult;
    by DSHOSPID;
  run;

  data &core_ahal;
    merge &core_adult(in=in_core) work._ahal_sorted(in=in_ahal);
    by DSHOSPID;
    if in_core;
	if COMMUNITY_NONREHAB_NONLTAC ne 1 then delete; *<< Added 3/21/26 4:40p - deleting non-acute care admits;
  run;

  /*****************************************************************
   3) CHARGES: flag ICU revenue-coded rows (REVCD1-REVCD52 char '0200')
      ICU rev codes: 0200-0204, 0207-0213, 0219
      EXCLUDE: 0206 and 0214
      Unit flags: 0201 SICU, 0202 MICU, 0207 BurnCare, 0208 TraumaCare, 0213 HeartTransplant
  https://pmc.ncbi.nlm.nih.gov/articles/instance/5511059/bin/NIHMS849966-supplement-Supplemental_Data_File___doc___tif__pdf__etc__.pdf
  ******************************************************************/
  data &chgs_icu;
    set &lib..&ds_chgs;

    length has_icu_revcd 3 is_sicu is_micu is_burncare is_traumacare is_hearttransplant is_200 is_201 is_202 is_203 is_204 is_207 is_208 is_209 is_210 is_211 is_212 is_213 is_219 3;
    has_icu_revcd = 0;
    is_sicu = 0; is_micu = 0; is_burncare = 0; is_traumacare = 0; is_hearttransplant = 0;

    array rev[*] $ REVCD1-REVCD52;

    do i=1 to dim(rev);
      if not missing(rev[i]) then do;
        revnum = input(rev[i], 8.);

        /* specific unit flags */
        if revnum = 201 then is_sicu = 1;            /* 0201 */
        if revnum = 202 then is_micu = 1;            /* 0202 */
        if revnum = 207 then is_burncare = 1;        /* 0207 */
        if revnum = 208 then is_traumacare = 1;      /* 0208 */
        if revnum = 213 then is_hearttransplant = 1; /* 0213 */   

        /* ICU inclusion rules (0206 and 0214 excluded by construction) */
        if (revnum >= 200 and revnum <= 204) or
           (revnum >= 207 and revnum <= 213) or
           (revnum = 219) then has_icu_revcd = 1;
      end;
    end;

    drop i revnum;

	length ICUCHG 8;
  ICUCHG = 0;
  
  array revb[*] $ REVCD1-REVCD53;
  array chg[*] REVCHG1-REVCHG53;
  
  do i = 1 to dim(revb);
    if not missing(revb[i]) then do;
      revnum = input(revb[i], 8.);
      
      /* Sum charges for ICU revenue codes (same inclusion rules as before) */
      if (revnum >= 200 and revnum <= 204) or
         (revnum >= 207 and revnum <= 213) or
         (revnum = 219) then do;

			if not missing(chg[i]) then do;
                /* Initialize on first valid hit */
                if missing(ICUCHG) then ICUCHG = 0;

                ICUCHG = ICUCHG + chg[i];
            end;
      end;
    end;
  end;
  
  drop i revnum;

   /* if has_icu_revcd = 1;*/
  run;

  /*****************************************************************
   4) Restrict CHGS to keys that exist in adult CORE
  ******************************************************************/
  proc sort data=&core_adult(keep=KEY) out=work._core_keys nodupkey;
    by KEY;
  run;

  proc sort data=&chgs_icu;
    by KEY;
  run;

  data &chgs_icu;
    merge &chgs_icu(in=in_chg) work._core_keys(in=in_corekey);
    by KEY;
    if in_chg and in_corekey;
  run;

  /*****************************************************************
   5) FINAL: core_ahal LEFT JOIN chgs_icu by KEY (keep only adult core rows)
  ******************************************************************/
  proc sort data=&core_ahal; by KEY; run;
  proc sort data=&chgs_icu;  by KEY; run;

  data &final_out;
    merge &core_ahal(in=in_core) &chgs_icu(in=in_chg);
    by KEY;
    if in_core; /* prevents charges-only rows */
  run;

  /*****************************************************************
   6) Save canonical outputs (WORK)
  ******************************************************************/
  data work.md&yr._core_ahal; set &core_ahal; run;
  data work.md&yr._chgs_icu;  set &chgs_icu;  run;
  data work.md&yr._final;     set &final_out; run;

  /*****************************************************************
   7) Validation counts
  ******************************************************************/
  proc sql;
    select count(*) as core_adult_rows
    from &core_adult;

    select count(*) as core_adult_icu_days_rows
    from &core_adult
    where icu_stay = 1;

    select count(*) as chg_rows_icu_kept_corekeys
    from &chgs_icu;

    select count(*) as final_rows
    from &final_out;
  quit;

  %put NOTE: Year &yr completed. Outputs: work.md&yr._core_ahal, work.md&yr._chgs_icu, work.md&yr._final ;
%mend process_year;

/* Run for current work years */
%process_year(lib=md16, yr=2016);
%process_year(lib=md17, yr=2017);
%process_year(lib=md18, yr=2018);
%process_year(lib=md19, yr=2019);
%process_year(lib=md20, yr=2020);
%process_year(lib=md21, yr=2021);
%process_year(lib=md22, yr=2022);
%process_year(lib=md23, yr=2023);
%process_year(lib=md24, yr=2024);

/* End of script */

Data Maryland_;
set md2016_final 
	md2017_final
	md2018_final 
	md2019_final
	md2020_final 
	md2021_final
	md2022_final
	md2023_final
	md2024_final;

* Removing variables that are over the 30 dx and pr limit (consistency) or won't be used (unitn);
drop i10_pr31-i10_pr100
i10_dx31-i10_dx101
prday31-prday100
dxpoa31-dxpoa100
unit1-unit53; 
 
run;


/* This is the first sentence of results - total cohort before exclusions */
proc freq data=maryland_ nlevels;
    tables key visitlink/noprint; /* 4262398 visits for 1979217 individual patients */
run;

/* This is a check that the AHA Linkage file worked as intended + exlcusions*/
proc freq data=maryland_;
tables COMMUNITY_NONREHAB_NONLTAC died female los year zipinc_qrtl;
run;
/* For exclusions: Denominator 4262398. Died 1299 (0.0304), Female 972 (0.0228), LOS 72 (0.00169), zipincqrtl 42204 (0.990), hospital info 393 (0.0090)*/


/* Little's MCAR test */
/* This will be <0.001 regardless because of size of the dataset */
%mcartest (indata=  maryland_         /* Input DATASET name */
,testvars=  FEMALE DIED los     /*SPECIFY VARIABLE SET FOR THE MCAR TEST - need at least two */
,misscode='.'      /* SPECIFY THE MISSING VALUE CODE */
); 
 
%include 'C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\SAS Code Library\Littles MCAR Chi square test.sas';


data maryland_combined; set maryland_;

/*** Total ICU days across all ICUs ***/
DaysICU_total=0;

DaysICU_total= sum(daysICU, daysCCU, daysshockunit, daysPICU);

/*** Categorizing age into medicare and not ***/
	age_Cat=0;
	if 18 le age le 64 then age_cat=1;
	else if age ge 65 then age_cat=2;

/*****1 white 2 black 3 hispanic 9 all other***/
	race_cat=9;
	if race=1 then race_Cat=1;
	else if race=2 then race_Cat=2;
	else if race=3 then race_cat=3;

/*****1 govt 3 pvt 9 all others/missing**/
	payer=9;
	if pay1=1 or pay1=2 then payer=1;
	else if pay1=3 then payer=3;


	los_cat=0; /*******Categorizing los into 0-7, 7-14, and >14*****/
	if 		0 le los le 7 then los_cat=1;
	else if 8 le los le 14 then los_cat=2;
	else if los gt 14 then los_cat=3;

	/*******Categorizing year of hospitalization*********/
		YEAR_CAT=0;
				IF 2016 LE YEAR LE 2018 THEN YEAR_CAT=1;
				IF 2019 LE YEAR LE 2021 THEN YEAR_CAT=2;
				IF 2022 LE YEAR LE 2024 THEN YEAR_CAT=3;


		SES_LOW=0;
			if 1 le ZIPINC_QRTL le 2 THEN SES_LOW=1;

			PAYER_GOVT=0;
			IF PAYER=1 THEN PAYER_GOVT=1;

	/****Categorizing ROUTINE discharge******/
	routine_dc=9;
	if Dispuniform = 1 or dispuniform = 6 then routine_dc=1;

	if year lt 0 then delete;	*deleting because all info was missing for these patients;
	if died lt 0 then delete; 
	if female lt 0  then delete;  
	if los lt 0 then delete;

run;
proc freq data=maryland_;
tables year;
run;

/* This is deleting the temp datasets to not clog up scratch disks */
proc datasets library=work nolist;
    delete md2016_final 
	md2017_final
	md2018_final 
	md2019_final
	md2020_final 
	md2021_final
	md2022_final
	md2023_final
	md2024_final
	maryland_;
quit;

/*** This callout labels pclass_orproc for everyone - this fixes the issues that 2020 and beyond lack pclass1-pclass30 ***/
/* It will also create MPROC_day1-MPROC_day10, day of major procedures 1-10 */

%macro Label_PCLASS (indata=, outdata=);

%include 'C:\Users\HP375\Documents\Research\SICU Maryland\PClassR_Mapping_Program_v2026-1_OH.sas';
%mend;
%label_PCLASS (indata=maryland_combined, outdata=maryland_ICU);

/**************************************************************************
 Single-table ICU index + 30-day readmission master
 Output: work.icu_readm_master
 Logic summary:
  - Index candidates: ICU_stay = 1 rows only
  - Index rule: first ICU_stay=1 per VisitLink; subsequent ICU_stay=1 -> index if
    DaysToEvent_current - DaysToEvent_prior - LOS_prior > 30
  - Readmission rule: any subsequent admission with same VisitLink where
    DaysToEvent_read - DaysToEvent_index - LOS_index > 0 and <= 30
  - Attach index-level exposure (index_surgery = PCLASS_ORPROC at index) to all rows
**************************************************************************/

/* 1) Sort the source data by patient/time */
proc sort data=Maryland_ICU out=icu_sorted;
  by VisitLink DaysToEvent;
run;

/* 2) Identify index admissions (ICU_stay=1 eligible only).
     Output one row per index admission into index_admissions. */
data index_admissions;
  set icu_sorted;
  by VisitLink DaysToEvent;

  retain last_index_dte last_index_los;
  if first.VisitLink then do;
    last_index_dte = .;
    last_index_los = .;
  end;

  is_index = 0;

  /* Only ICU rows are eligible to become an index */
  if ICU_stay = 1 then do;
    if missing(last_index_dte) then is_index = 1;
    else if (DaysToEvent - last_index_dte - last_index_los) > 30 then is_index = 1;

    if is_index = 1 then do;
      last_index_dte = DaysToEvent;
      last_index_los = LOS;
      output; /* write index row */
    end;
  end;
run;

/* 3) Mark full chronology rows that are indices (for carry-forward)
     Join on KEY to flag rows that match index rows. */
proc sql;
  create table icu_marked as
  select a.*, (case when b.KEY is not null then 1 else 0 end) as is_index_row
  from icu_sorted as a
  left join index_admissions as b
    on a.KEY = b.KEY
  order by VisitLink, DaysToEvent;
quit;

/* 4) One-pass carry-forward: attach nearest prior (or equal) index info to EVERY row.
     When hitting an index row, update retained index info BEFORE attaching so the
     index row is associated with itself. */
data icu_with_index;
  set icu_marked;
  by VisitLink DaysToEvent;

  retain last_index_dte last_index_los last_index_key last_index_surgery;

  if first.VisitLink then do;
    last_index_dte = .;
    last_index_los = .;
    last_index_key = .;
    last_index_surgery = .;
  end;

  /* If this row corresponds to an index row, update retained index info */
  if is_index_row = 1 then do;
    last_index_dte     = DaysToEvent;
    last_index_los     = LOS;
    last_index_key     = KEY;
    last_index_surgery = PCLASS_ORPROC; /* surgery status at the index */
  end;

  /* Attach nearest prior (or equal) index info to the current row */
  index_dte     = last_index_dte;
  index_los     = last_index_los;
  index_key     = last_index_key;
  index_surgery = last_index_surgery;

  /* Row-level indicator for whether this row itself is an index */
  is_index = is_index_row;

run;

/* 5) Compute days from index discharge and mark readmissions (LOS-adjusted)
     Readmission if days_from_index_discharge > 0 and <= 30 */
data icu_with_index;
  set icu_with_index;

  days_from_index_discharge = .;
  is_readmission30 = 0;

  if not missing(index_dte) then do;
    days_from_index_discharge = DaysToEvent - index_dte - index_los;
    if days_from_index_discharge > 0 and days_from_index_discharge <= 30 then is_readmission30 = 1;
  end;
run;

/* 6) Identify index_keys that had >=1 readmission (used to flag indexes) */
proc sql;
  create table index_readmit_flag as
  select distinct index_key
  from icu_with_index
  where is_readmission30 = 1
    and not missing(index_key)
  ;
quit;

/* 7) Build the single master dataset:
     keep rows that are either an index or a 30-day readmission, and attach
     index_readmit30 (so index rows have the flag readily available) */
proc sql;
  create table icu_readm_master as
  select w.*,
         case when f.index_key is not null then 1 else 0 end as index_readmit30
  from icu_with_index as w
  left join index_readmit_flag as f
    on w.index_key = f.index_key
  where w.is_index = 1 or w.is_readmission30 = 1
  order by VisitLink, index_dte, DaysToEvent;
quit;

proc freq data=icu_readm_master;
where is_index=1;
tables index_readmit30;run;

/* 8) Quick validation summaries */
/* 1) Index-level totals and pct with readmission (derive via left join) */
proc sql;
  select 
    count(*) as n_index_total,
    sum(case when b.index_key is not null then 1 else 0 end) as n_index_with_readm,
    case when count(*)>0 
         then (sum(case when b.index_key is not null then 1 else 0 end)*1.0 / count(*))
         else .
    end format=percent8.2 as pct_readmit
  from index_admissions as a
  left join index_readmit_flag as b
    on a.KEY = b.index_key
  ;
quit;

/* 2) Rows in master file */
proc sql;
  select count(*) as n_rows_master from icu_readm_master;
quit;

/* 3) Distribution of index_surgery among index admissions
     Use index_admissions (one row per index) to avoid duplication */
proc sql;
  select PCLASS_ORPROC as index_surgery, count(*) as n
  from index_admissions
  group by PCLASS_ORPROC
  order by PCLASS_ORPROC;
quit;

/* 4) Concordance with HCUP READMIT for rows in master (readmission-level checks) */
proc sql;
  select
    sum(case when is_readmission30=1 and READMIT=1 then 1 else 0 end) as both_flags,
    sum(case when is_readmission30=1 and (READMIT ne 1 or READMIT is null) then 1 else 0 end) as our_yes_hcup_no,
    sum(case when is_readmission30 ne 1 and READMIT=1 then 1 else 0 end) as our_no_hcup_yes
  from icu_readm_master;
quit;
/* Final output: work.icu_readm_master
   Key derived fields present:
     index_dte, index_los, index_key, index_surgery,
     is_index, is_readmission30, index_readmit30, days_from_index_discharge

| Variable         | Meaning                                      |
| ---------------- | -------------------------------------------- |
| is_index         | 1 if ICU index admission                     |
| is_readmission30 | 1 if 30-day readmission                      |
| index_readmit30  | 1 if that index admission had =1 readmission |
| index_surgery    | surgery status at index                      |
| index_key        | index admission KEY                          |
| index_dte        | index admission DaysToEvent                  |
| index_los        | index LOS                                    |
*/



 
/**********************************/
/***	End of Readmission Code ***/
/**********************************/

 /* Just a rename */
data icu_m; 
 set icu_readm_master;
run;

/**********************************************/
/*** Next step will merge AHA Hospital data ***/
/** into the main merged and readmission files*/
/**********************************************/

%macro AHA_link (dataset=);

proc contents data=&dataset.; run;

proc contents data=AHA.aha_hosps_16_24_all_states; run;


proc sort data=&dataset.;
  by AHAID YEAR;
run;


proc sort data=AHA.aha_hosps_16_24_all_states
          out=work.aha_sorted;
  by AHAID YEAR;
run;

data SICU.&dataset._AHA;
  merge &dataset. (in=in_md)
        work.aha_sorted;
  by AHAID YEAR;
  if in_md;
  if hosp_bedsize lt 1 then delete; /* 	These are 393 hospitalizations at two small community hospitals. A
  										AHA survey didn't have info on one hospital for 2019, presumably opening year. 
  										Another closed in 2024 and didn't have info in survey for 2023 and 2024*/
run;
%mend;
%AHA_link (dataset=icu_m);






/*** Final dataset at this point is SICU.Icu_m_AHA***/
/*** Core + Charges + Hospital 				    ***/ 
/**************************************************/


%macro Label_processing (dataset=);

/*** The code blocks add CMR labels and CMR_Index_Readmission, CMR_Index_Mortality to dataset ***/
/*** outputs dataset &dataset._2		  ***/

%include 'C:\Users\HP375\Documents\Research\SICU Maryland\Elixhauser\2_CMR_Mapping_Program_v2026-1.sas';

%include 'C:\Users\HP375\Documents\Research\SICU Maryland\Elixhauser\3_CMR_Index_Program_v2026-1.sas';

/*** This callout labels NHSN procedure categories & i10_delivery - expects SICU.&dataset._2, outputs &dataset._4 ***/
%include 'C:\Users\HP375\Documents\Research\SICU Maryland\NHSN_Labeling_Code.sas';

/*** This callout labels HFRS based on POA 1/Y/W. It is expecting &dataset._4 and outputs &dataset._5 with 
two addl variables - HFRS and HFRS_cat ***/
%include 'C:\Users\HP375\Documents\Research\SICU Maryland\HFRS_calculator_POA.sas';

/*** This callout labels complications based on POA N. Storesund complication codes. 
It is expecting &dataset._5 and outputs SICU.&dataset._6 */
%include 'C:\Users\HP375\Documents\Research\SICU Maryland\complication_labels.sas';

/*** The CCS code blocks need to be run at the end because the %includes after them don't run ***/
/*** The code block adds PRCCS procedure classes - expects &dataset._2 outputs &dataset._PRCCS_vert and _horz ***/

/*%include 'C:\Users\HP375\Documents\Research\SICU Maryland\PRCCSR_Mapping_Program_v2026-1_HYDER.sas';*/

/*** The code block adds DXCCS procedure classes - expects &dataset._2 outputs &dataset._DXCCS_vert, _horz, and _dflt ***/

/*%include 'C:\Users\HP375\Documents\Research\SICU Maryland\DXCCSR_Mapping_Program_v2026-1.SAS';*/

%mend;
%label_processing (dataset=icu_m_aha);

proc freq data=sicu.icu_m_aha_6; tables is_index icu_Stay hosp_bedsize hosp_locteach urban_flag; run;

/*** Final datasets after mods are 
	SICU.ICU_m_aha_6
***/

/*** End of working code 03/21/26 ***/

/* MS DRG formats */
/* 1) Read CSV (no header). Column A -> msdrg_code (numeric). Column D -> msdrg_label (char length 100). */
data msdrg_raw;
  infile "C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\MS-DRG\ms_drg.csv"
         dsd dlm=',' lrecl=32767 truncover;
  length msdrg_label $100 col2 $200 col3 $200 col5 $200 col6 $200;
  input msdrg_code  /* Column A numeric */
        col2 : $200.
        col3 : $200.
        msdrg_label : $100.  /* Column D */
        col5 : $200.
        col6 : $200.;
run;

/* 2) Build CNTLIN dataset and create the MSDRG numeric format */
data fmt;
  set msdrg_raw (keep=msdrg_code msdrg_label);
  length fmtname $32 type $1;
  fmtname = 'MSDRG';
  type = 'N';
  start = msdrg_code;
  end = msdrg_code;
  label = msdrg_label;
  keep fmtname type start end label;
run;

proc format cntlin=fmt; 
run;
