/**************************************/
/******** MD SICU  2016-2024 **********/
/***Final classification and analysis*/
/*************************************/

libname SICU 'C:\Users\HP375\Documents\Research\SICU Maryland\SAS_datasets2';



%macro RECODING1 (INDATA=, INTMDATA=, OUTDATA=);

/*** Data modification code block ***/

data &INTMDATA;
set sicu.&indata;

AcadMC=0; *<== ACADEMIC MEDICAL CENTER;
if MNAME in ('Johns Hopkins Hospital', 'University of Maryland Medical Center') then AcadMC=1;

/*** Elective Classification ***/
ELECTIVE=0;

if PCLASS_ORPROC = 0 AND ATYPE=3 THEN ELECTIVE=1; * Strict definition of elective;

if PCLASS_ORPROC = 1 and ATYPE=3 AND MPROC_DAY1=0 AND hcup_ed=0 and tran_in=0 THEN ELECTIVE=1; * Strict definition of elective;

/* ICU Stay >= 2 days */
ICULOS2=0;
if daysicu_total ge 2 then ICULOS2=1;

Group=.;
if is_index=1 and elective=1 and PCLASS_ORPROC=1 then group=1; *Elective surgical;
if is_index=1 and elective=0 and PCLASS_ORPROC=1 then group=2; 	*Non-elective surgical;
if is_index=1 and PCLASS_ORPROC=0 then group=3;

HCUP_elective=0; *Classifying into HCUP's definition of elective ATYPE=3;
if atype=3 then HCUP_elective=1;

length mechanical_ventilation 3;
mechanical_ventilation = 0;

array pr[30] $ i10_pr1-i10_pr30;

do i = 1 to dim(pr);
    if pr[i] in ('5A1955Z','5A1945Z','5A1935Z') then do;
        mechanical_ventilation = 1;
        leave; /* stop once found */
    end;
end;

drop i;

run;


/******** ZipInc_Qrtl imputation block******
this is working MI code. The variable is of so little importance
that I don't think it is worth imputing********

proc mi data=&INTMDATA seed=1305417 nimpute=1 out=&OUTDATA;
   class year_cat ZIPINC_QRTL HOSP_BEDSIZE HOSP_LOCTEACH PAYER ;
   fcs regpmm;
   var AGE year_Cat race_cat  HOSP_BEDSIZE HOSP_LOCTEACH payer ZIPINC_QRTL;
run; */

%mend;
%recoding1 (INDATA=ICU_m_aha_6, INTMDATA=INDEX_MAIN1);
%recoding1 (INDATA=ICU_f_aha_6, INTMDATA=INDEX_MAIN1_f);
%recoding1 (INDATA=ICU_fnc_aha_6, INTMDATA=INDEX_MAIN1_fnc);


proc contents data=index_main1; where year=index_main; run;

proc freq data=index_main1;
tables group icu_Stay hcup_elective elective /norow;
run;

proc freq data=index_main1_f;
tables group mechanical_ventilation /norow;
run;

proc freq data=index_main1 nlevels;
    tables visitlink key / noprint; /* noprint suppresses the huge frequency list */
run;

/* Paragraph 1 */
proc freq data=index_main1;
where is_index=1;
tables year_Cat year_cat*group/nofreq nocol nopercent;
run;


/************************************************************/
/* Demographic and hospital characteristics of the cohorts **/
/***********************************************************/

%macro TABLE1 (DATASET=, where=);
/*title1 "total individual patients in &dataset. and &where.";
proc freq data=&dataset. nlevels;
	where &where.;
    tables visitlink / noprint; /* noprint suppresses the huge frequency list */
/*run;

title; */

title2 "Proc Freq for &dataset. and &where.";
PROC FREQ DATA= &dataset.;
where &where.;
tables 
		/*age_cat
		female
		race_cat
		payer*/
		
		HFRS_cat
		/*zipinc_qrtl
		tran_in
		
		
		hosp_bedsize
		Hosp_locteach
		acadmc


		iculos2
		mechanical_ventilation
		routine_dc
		index_readmit30

		died */

;
		run; 
		/*		los_cat
		year_cat*/

title;
/*title3 "Mean, median, p25, p75, number of obs, and missing obs for &dataset. and &where.";
PROC MEANS DATA=&dataset. MEAN MEDIAN P25 P75 N nmiss;
	where &where.;
	VAR 
		age
		CMR_index_mortality		

		hospbd
		MSICBD
		FTEMSI
		daysICU_total
		los
		icuchg
		totchg
		;

	run;*/
title;

%mend;

%table1 (dataset=INDEX_MAIN1, where=is_index=1 and elective=1 and PCLASS_ORPROC=1 and year_cat); *Elective surgical;
%table1 (dataset=INDEX_MAIN1, where=is_index=1 and elective=0 and PCLASS_ORPROC=1 and year_cat); 	*Non-elective surgical;
%table1 (dataset=INDEX_MAIN1, where=is_index=1 and PCLASS_ORPROC=0 and year_cat); 					*non-surgical;

%table1 (dataset=INDEX_MAIN1, where=group=1 and year_cat=1); *Elective surgical;
%table1 (dataset=INDEX_MAIN1, where=group=1 and year_cat=2); *Elective surgical;
%table1 (dataset=INDEX_MAIN1, where=group=1 and year_cat=3); *Elective surgical;

%table1 (dataset=INDEX_MAIN1, where=group=2 and year_cat=1); 	*Non-elective surgical;
%table1 (dataset=INDEX_MAIN1, where=group=2 and year_cat=2); 	*Non-elective surgical;
%table1 (dataset=INDEX_MAIN1, where=group=2 and year_cat=3); 	*Non-elective surgical;

%table1 (dataset=INDEX_MAIN1, where=group=3 and year_cat=1); 					*non-surgical;
%table1 (dataset=INDEX_MAIN1, where=group=3 and year_cat=2); 					*non-surgical;
%table1 (dataset=INDEX_MAIN1, where=group=3 and year_cat=3); 					*non-surgical;


%table1 (dataset=INDEX_MAIN1, where=group=1 and mechanical_ventilation=1); *Elective surgical_MD_vent;
%table1 (dataset=INDEX_MAIN1, where=group=2 and mechanical_ventilation=1); 	*Non-elective surgical_MD_vent;
%table1 (dataset=INDEX_MAIN1, where=group=3 and mechanical_ventilation=1); 					*non-surgical_MD_vent;

%table1 (dataset=INDEX_MAIN1, where=group=1 and daysicu_total gt 1); *Elective surgical_MD_vent;
%table1 (dataset=INDEX_MAIN1, where=group=2 and daysicu_total gt 1); 	*Non-elective surgical_MD_vent;
%table1 (dataset=INDEX_MAIN1, where=group=3 and daysicu_total gt 1); 					*non-surgical_MD_vent;



proc freq;
tables hospst group;
run;


proc print data=index_main1 (obs=10);
where pclass_orproc=0 and drg=981;
var i10_pr1-i10_pr30;
format i10_pr1-i10_pr30 $proccode.;
run;

/* DRG */
%macro DRG(DATASET=, where=);

title2 "DRGs for &dataset. and &where.";
PROC FREQ DATA= &dataset.;
where &where.;
tables DRG year
;

		format drg msdrg.;
	run;
title;

%mend;

%DRG (dataset=INDEX_MAIN1, where=is_index=1 and elective=1 and PCLASS_ORPROC=1 and year_cat); *Elective surgical;
%DRG(dataset=INDEX_MAIN1, where=is_index=1 and elective=0 and PCLASS_ORPROC=1 and year_cat); 	*Non-elective surgical;
%DRG (dataset=INDEX_MAIN1, where=is_index=1 and PCLASS_ORPROC=0 and year_cat); 					*non-surgical;

%quit;

/* Set byvar to year or year_cat to get yearly or three yearly rates */
/* Set sort for hospital type */
%macro Outcomes1 (DATASET=, where=, sort=, byvar=);

title2 "&byvar.ly outcomes for &dataset. and &where.";

proc tabulate data=&dataset.;
    where &where.;
    class &byvar. died HFRS_cat routine_dc index_readmit30;
    
    table 
        &byvar.,
        (died HFRS_cat routine_dc index_readmit30) * rowpctn;
run;

title;

title2 "&byvar.ly outcomes for &dataset. and &where. sorted by &sort.";

proc sort data=&dataset.;
    by &sort.;
run;

proc tabulate data=&dataset.;
    where &where.;
    class &sort. &byvar. died HFRS_cat routine_dc index_readmit30;
    
    table 
        &sort. * &byvar.,
        (died HFRS_cat routine_dc index_readmit30) * rowpctn;
run;

title;

%mend;

%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=1, 
    sort=hosp_bedsize, byvar=year
);
%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=2, 
    sort=hosp_bedsize, byvar=year
);

%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=3, 
    sort=hosp_bedsize, byvar=year
);
/* Three year block outcomes BY YEAR*/
%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=1,   byvar=year_cat
);
%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=2,  byvar=year_cat
);

%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=3, byvar=year_cat
);

/* Three year block outcomes BY HOSPITAL SIZE*/
%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=1,    sort=hosp_bedsize, byvar=year_cat
);
%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=2,   sort=hosp_bedsize, byvar=year_cat
);

%Outcomes1 (
    dataset=INDEX_MAIN1, 
    where=group=3,  sort=hosp_bedsize, byvar=year_cat
);

%macro Outcomes2 (DATASET=, where=, sort=);

proc sort data= &Dataset.; by &sort.;
run;

title2 "Medians for &dataset. and &where.";
PROC means DATA= &dataset. median p25 p75 nmiss;
where &where.;
by &sort.;
var 		age
		CMR_index_mortality		
		daysICU_total
		los
		icuchg
		totchg
;
run;
%mend;
/* Sort by year */
%Outcomes2 (
    dataset=INDEX_MAIN1, 
    where=group=1 and sort=year
);

%Outcomes2 (
    dataset=INDEX_MAIN1, 
    where=group=2 and sort=year
);

%Outcomes2 (
    dataset=INDEX_MAIN1, 
    where=group=3 and sort=year
);

/* Sort by 3 years */
%Outcomes2 (
    dataset=INDEX_MAIN1, 
    where=group=1, sort=year_Cat
);

%Outcomes2 (
    dataset=INDEX_MAIN1, 
    where=group=2, sort=year_Cat
);

%Outcomes2 (
    dataset=INDEX_MAIN1, 
    where=group=3, sort=year_Cat
);



/* Hospital volumes per 3-yr epoch */
proc sort data=index_main1; by group; run;

proc freq data=index_main1;
    by group;
    tables year_cat * hosp_bedsize / nofreq nocol nopercent; /* row pct shows distribution across hospital sizes within each year */
run;



/* Figure 3 - Hospital distribution code */
%macro HospDist (DATASET=, where=, groupname=);
title2 "Hospital size distribution by year for &groupname.";

proc tabulate data=&dataset. out=dist_&groupname.;
    where &where.;
    class year hosp_bedsize;
    
    table 
        year,
        hosp_bedsize * (n rowpctn);
run;

proc print data=dist_&groupname.; run;
title;
%mend;

%HospDist(dataset=INDEX_MAIN1, where=group=1, groupname=elective);
%HospDist(dataset=INDEX_MAIN1, where=group=2, groupname=nonelective);
%HospDist(dataset=INDEX_MAIN1, where=group=3, groupname=nonsurgical);

/* Wide table for four state external comparisons */

%macro TABLEwide (DATASET=, where=);
/*title1 "total individual patients in &dataset. and &where.";
proc freq data=&dataset. nlevels;
	where &where.;
    tables visitlink / noprint; /* noprint suppresses the huge frequency list */
/*run;

title;*/

title2 "Proc Freq for &dataset. and &where.";
PROC FREQ DATA= &dataset.;
where &where.;
tables hfrs_Cat
		/*hosp_bedsize
		Hosp_locteach

		died*/

;
		run; 

/*PROC MEANS DATA=&dataset. MEAN MEDIAN P25 P75 N nmiss;
	where &where.;
	VAR 
		age
		CMR_index_mortality		
		hospbd
		MSICBD
		FTEMSI
		los
		
		totchg
		;

	run;



title;*/

%mend;

%tablewide (dataset=INDEX_MAIN1, where=group=1 and mechanical_Ventilation=1 and year=2022); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1, where=group=2 and mechanical_Ventilation=1 and year=2022); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1, where=group=3 and mechanical_Ventilation=1 and year=2022); *Elective surgical_CA_vent;

%tablewide (dataset=INDEX_MAIN1_fnc, where=group=1 and HOSPST = 'CA'); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1_fnc, where=group=2 and HOSPST = 'CA'); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1_fnc, where=group=3 and HOSPST = 'CA'); *Elective surgical_CA_vent;

%tablewide (dataset=INDEX_MAIN1_fnc, where=group=1 and HOSPST = 'NY'); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1_fnc, where=group=2 and HOSPST = 'NY'); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1_fnc, where=group=3 and HOSPST = 'NY'); *Elective surgical_CA_vent;

%tablewide (dataset=INDEX_MAIN1_fnc, where=group=1 and HOSPST = 'FL'); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1_fnc, where=group=2 and HOSPST = 'FL'); *Elective surgical_CA_vent;
%tablewide (dataset=INDEX_MAIN1_fnc, where=group=3 and HOSPST = 'FL'); *Elective surgical_CA_vent;

/* P-values for median comparisons */
/* everything is <0.01 */

%macro TABLEpnum (DATASET=, where=);

proc npar1way data=&dataset. wilcoxon;
		where &where.;
   class group;
   var 		age
		CMR_index_mortality		
		hospbd
		MSICBD
		FTEMSI
		los
		totchg;
run;
%mend;

%tablepnum(dataset=INDEX_MAIN1, where=group ne .); 
%tablepnum(dataset=INDEX_MAIN1, where=mechanical_Ventilation=1 and year=2022); 
%tablepnum (dataset=INDEX_MAIN1_fnc, where=HOSPST = 'NY'); *Elective surgical_CA_vent;
%tablepnum (dataset=INDEX_MAIN1_fnc, where=HOSPST = 'CA'); *Elective surgical_CA_vent;
%tablepnum (dataset=INDEX_MAIN1_fnc, where=HOSPST = 'FL'); *Elective surgical_CA_vent;

/* Validation table */
%macro TABLE_val (DATASET=, where=);

title2 "Proc Freq for &dataset. and &where.";
PROC FREQ DATA= &dataset.;
where &where.;
tables 

		HFRS_cat
		routine_dc
		died

;
		run; 
		/*		los_cat
		year_cat*/

title;


%mend;

%table_val (dataset=INDEX_MAIN1, where=group=3); *Elective surgical_MD_vent;

%table_val (dataset=INDEX_MAIN1, where=group=1 and mechanical_ventilation=1); *Elective surgical_MD_vent;
%table_val (dataset=INDEX_MAIN1, where=group=2 and mechanical_ventilation=1); 	*Non-elective surgical_MD_vent;
%table_val (dataset=INDEX_MAIN1, where=group=3 and mechanical_ventilation=1); 					*non-surgical_MD_vent;

%table_val (dataset=INDEX_MAIN1, where=group=1 and daysicu_total gt 1); *Elective surgical_MD_vent;
%table_val (dataset=INDEX_MAIN1, where=group=2 and daysicu_total gt 1); 	*Non-elective surgical_MD_vent;
%table_val (dataset=INDEX_MAIN1, where=group=3 and daysicu_total gt 1); 					*non-surgical_MD_vent;

