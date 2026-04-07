libname SICU 'C:\Users\HP375\Documents\Research\SICU Maryland\SAS_datasets2';
libname AHA 'C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\AHA Hospital Data';

libname NY22 'D:\SID\New York 2022';
libname CA22 'D:\SID\California 2022';

%macro process_year(lib=, state=, yr=);

    /* Core: adult rows + mechanical ventilation flag */
    data work._core_&state._&yr;
        set &lib..&state._sidc_&yr._core;
        where age >= 18;

        length mechanical_ventilation 3 ICU_stay 3;
        mechanical_ventilation = 0;
        ICU_stay = 0;

        array pr[30] $ i10_pr1-i10_pr30;

        do i = 1 to dim(pr);
            if strip(pr[i]) in ('5A1955Z','5A1945Z','5A1935Z') then do;
                mechanical_ventilation = 1;
                ICU_stay = 1;
                leave;
            end;
        end;

        drop i;
    run;

    /* AHAL: one row per hospital */
    proc sort data=&lib..&state._sidc_&yr._ahal 
              out=work._ahal_&state._&yr nodupkey;
        by dshospid;
    run;

    /* Merge by DSHOSPID */
    proc sort data=work._core_&state._&yr;
        by dshospid;
    run;

    data work.&state._sidc_&yr._core_ahal;
        merge work._core_&state._&yr(in=in_core)
              work._ahal_&state._&yr(in=in_ahal);
        by dshospid;
        if in_core;
        if COMMUNITY_NONREHAB_NONLTAC ne 1 then delete;
    run;

    /* Clean up */
    proc datasets library=work nolist;
        delete _core_&state._&yr _ahal_&state._&yr;
    quit;

%mend;

%process_year(lib=ny22, state=ny, yr=2022);
%process_year(lib=ca22, state=ca, yr=2022);
%process_year(lib=fl22, state=fl, yr=2022);



proc freq data=FL_SIDC_2022_CORE_AHAL; tables icu_Stay; run;
proc freq data=NY_SIDC_2022_CORE_AHAL; tables icu_Stay; run;
proc freq data=CA_SIDC_2022_CORE_AHAL; tables icu_Stay; run;


Data states_combined;
set FL_SIDC_2022_CORE_AHAL
	NY_SIDC_2022_CORE_AHAL
	CA_SIDC_2022_CORE_AHAL;

	  
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

* Removing variables that are over the 30 dx and pr limit (consistency) or won't be used (unitn);
drop i10_pr31-i10_pr100
i10_dx31-i10_dx101
prday31-prday100
dxpoa31-dxpoa100
unit1-unit53;
run;


/*** This callout labels pclass_orproc for everyone - this fixes the issues that 2020 and beyond lack pclass1-pclass30 ***/
/* It will also create MPROC_day1-MPROC_day10, day of major procedures 1-10 */

%macro Label_PCLASS (indata=, outdata=);

%include 'C:\Users\HP375\Documents\Research\SICU Maryland\PClassR_Mapping_Program_v2026-1_OH.sas';
%mend;
%label_PCLASS (indata=states_combined, outdata=states_ICU);

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
proc sort data=States_ICU out=icu_sorted;
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

data icu_fnc; set icu_readm_master; run; /* Just a rename and ICU charge calculation */
proc freq data=icu_fnc; 
tables index_readmit30 is_index icu_Stay pclass_orproc year; run;

/**********************************/
/***	End of Readmission Code ***/
/**********************************/


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
run;
%mend;
%AHA_link (dataset=icu_fnc);


/*** Final dataset at this point is SICU.Icu_m_AHA***/
/*** Core + Charges + Hospital 				    ***/ 
/**************************************************/


%macro Label_processing (dataset=);

/*** The code blocks add CMR labels and CMR_Index_Readmission, CMR_Index_Mortality to dataset ***/
/*** outputs dataset &dataset._2		  ***/

%include 'C:\Users\HP375\Documents\Research\SICU Maryland\Elixhauser\2_CMR_Mapping_Program_v2026-1.sas';

%include 'C:\Users\HP375\Documents\Research\SICU Maryland\Elixhauser\3_CMR_Index_Program_v2026-1.sas';

/*** This callout labels NHSN procedure categories - expects SICU.&dataset._2, outputs &dataset._4 ***/
%include 'C:\Users\HP375\Documents\Research\SICU Maryland\NHSN_Labeling_Code.sas';

/*** This callout labels HFRS based on POA 1/Y/W. It is expecting &dataset._4 and outputs &dataset._5 with 
two addl variables - HFRS and HFRS_cat ***/
%include 'C:\Users\HP375\Documents\Research\SICU Maryland\HFRS_calculator_POA.sas';

 
/*** This callout labels complications based on POA N. Storesund complication codes. 
It is expecting &dataset._5 and outputs SICU.&dataset._6 */
%include 'C:\Users\HP375\Documents\Research\SICU Maryland\complication_labels.sas';

/*** The CCS code blocks need to be run at the end because the %includes after them don't run ***/
/*** The code block adds PRCCS procedure classes - expects &dataset._2 outputs &dataset._PRCCS_vert and _horz ***/

/*%include 'C:\Users\HP375\Documents\Research\SICU Maryland\PRCCSR_Mapping_Program_v2026-1_HYDER.sas';

/*** The code block adds DXCCS procedure classes - expects &dataset._2 outputs &dataset._DXCCS_vert, _horz, and _dflt ***/

/*%include 'C:\Users\HP375\Documents\Research\SICU Maryland\DXCCSR_Mapping_Program_v2026-1.SAS';*/

%mend;
%label_processing (dataset=icu_fnc_aha);

proc freq data=sicu.icu_fnc_aha_6;
tables icu_stay; run;
