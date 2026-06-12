/* Adapted from: FL_NY_CA datacut 033126.sas (states_combined recode step).    */
/* The original concatenated three external state SID extracts and then derived */
/* the analytic categories below; here a small inline DATA step supplies records */
/* with the same columns (age, race, pay1, los, zipinc_qrtl, dispuniform, year,  */
/* died, female). The age/race/payer/LOS/SES/discharge categorizations and the   */
/* negative-value DELETE guards are verbatim from the author's program.          */

data states_in;
  input age race pay1 los zipinc_qrtl dispuniform year died female;
  datalines;
45 1 1 5 3 1 2022 0 0
70 2 1 12 1 6 2022 0 1
33 3 3 20 2 2 2022 1 1
58 9 9 3 4 5 2022 0 0
80 1 2 9 1 1 2022 0 1
27 2 3 14 2 6 2022 0 0
-1 1 1 4 3 1 2022 0 1
66 1 3 30 1 2 2022 1 0
;
run;

Data states_combined;
set states_in;


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
run;

proc print data=states_combined;
  var age age_cat race race_cat pay1 payer payer_govt los los_cat zipinc_qrtl ses_low dispuniform routine_dc;
  title "Patient analytic categories derived from state SID records";
run;

proc freq data=states_combined;
  tables age_cat race_cat payer los_cat ses_low routine_dc;
run;
