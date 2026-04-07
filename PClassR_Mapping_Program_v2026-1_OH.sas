/**********************************************************************/
/* Title:       PROCEDURE CLASSES REFINED    Hyder amend for procedure day  */
/*              FOR ICD-10-PCS MAPPING PROGRAM                        */
/*                                                                    */
/* Program:     PClassR_Mapping_Program_v2026-1.sas                   */
/*                                                                    */
/* Procedures:  v2026-1 is compatible with ICD-10-PCS procedure       */
/*              codes from October 2015 through September 2026.       */
/*              ICD-10-PCS codes should not include embedded          */
/*              decimals (example: OBH13YZ).                          */
/*                                                                    */
/* Description: This SAS mapping program adds the procedure classes   */
/*              data elements to the user's ICD-10-PCS-coded data.    */
/*                                                                    */
/*              There are two general sections to this program:       */
/*              1) The first section creates a temporary SAS          */
/*                 informat using the Procedure Classes Refined for   */
/*                 ICD-10-PCS CSV file. This informats is used to     */
/*                 create the procedure classes variables.            */
/*              2) The second section loops through the procedure     */
/*                 array in your SAS dataset and assigns the          */
/*                 procedure classes variables added to the output    */
/*                 file.                                              */
/*                                                                    */
/* Output:	This program appends the procedures classes to the    */
/*	        input SAS file. The data elements are named PCLASSn,  */
/*              where n ranges from 1 to the maximum number of        */
/*              available procedures. Program also adds an indicator  */
/*              that an operating room procedure (major diagnostic or */
/*              therapeutic procedure) was found on the record.       */
/*                                                                    */
/**********************************************************************/

/*******************************************************************/
/*      THE SAS MACRO FLAGS BELOW MUST BE UPDATED BY THE USER      */ 
/*  These macro variables must be set to define the locations,     */
/*  names, and characteristics of your input and output SAS        */
/*  formatted data.                                                */
/*******************************************************************/

/**********************************************/
/*          SPECIFY FILE LOCATIONS            */
/**********************************************/
FILENAME INRAW1  'C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\Procedure Classes Refined 2026-1\PClassR_v2026-1.csv' LRECL=300;    * Location of Procedure Classes CSV file.            <===USER MUST MODIFY;
LIBNAME  IN1     'C:\Users\HP375\Documents\Research\SICU Maryland\SAS_datasets2';                                   * Location of input discharge data.                  <===USER MUST MODIFY;
LIBNAME  OUT1    'C:\Users\HP375\Documents\Research\SICU Maryland\SAS_datasets2';                                  * Location of output data.                           <===USER MUST MODIFY;
                                    
                                       
/*********************************************/
/*   SPECIFY INPUT FILE CHARACTERISTICS      */
/*********************************************/ 
* Specify the prefix used to name the ICD-10-PCS 
  procedure data element array in the input dataset. 
  In this example the procedure data elements would be 
  named I10_PR1, I10_PR2, etc., similar to the naming 
  of ICD-10-PCS data elements in HCUP databases;             %LET PRPREFIX = I10_PR;  *<===USER MUST MODIFY;

* Specify the maximum number of procedure codes on 
  any record in the input file;                              %LET NUMPR = 30;         *<===USER MUST MODIFY;

* Specify the name of the variable that contains a 
  count of the ICD-10-PCS codes reported on a record.  
  If no such variable exists, leave macro blank;             %LET NPRVAR = I10_NPR;   *<=== USER MUST MODIFY;

* Specify the number of observations to use from the 
  input dataset.  Use MAX to use all observations and
  use a smaller value for testing the program;               %LET OBS = MAX;          *<===USER MAY MODIFY;

/**********************************************/
/*   SPECIFY INPUT and OUTPUT FILE NAMES      */
/**********************************************/
* Specify the name of the input dataset;                     %LET CORE =&indata;  *<===USER MUST MODIFY;
* Specify the name of the output dataset;                    %LET OUT1 =&outdata;     *<===USER MUST MODIFY; 


/*********************************************/
/*   SET PCLASS VERSION                      */
/*********************************************/ 
%LET PCLASS_VERSION = "2026.1" ; *<=== DO NOT MODIFY;


TITLE1 'Procedure Classes Refined for ICD-10-PCS Procedures';
TITLE2 'Mapping Program';


/******************* SECTION 1: CREATE INFORMATS ******************/
/*  SAS Load the Procedure Classes Refined for ICD-10-PCS mapping */
/*  file and convert it into a temporary SAS informat that will   */
/*  be used to assign the procedure class fields in the next step.*/
/******************************************************************/
data pclass ;
    infile inraw1 dsd dlm=',' end = eof firstobs=3;
    input
       start            : $char7.
       icd10pcs_label   : $char100.
       label            : 3.
       pclass_label     : $char100.
    ;
   retain hlo " ";
   fmtname = "pclass" ;
   type    = "i" ;
   output;

   if eof then do ;
      start = " " ;
      label = . ;
      hlo   = "o";
      output ;
   end ;
run;

proc format lib=work cntlin = pclass ;
run;

/************** SECTION 2: CREATE REFINED PROCEDURE CLASSES ***********/
/*  Create procedure classes for ICD-10-PCS using the SAS             */
/*  informat created above & the SAS output dataset you specified.    */
/*  Users can change the names of the output procedure class          */
/*  variables if needed here. It is also important to make sure       */
/*  that the correct ICD-10-PCS procedure prefixes are specified      */
/*  correctly in the macro PRPREFIX above.                            */
/**********************************************************************/  
%macro pclass;
%if &numpr > 0 %then %do; 
options obs=&OBS.;

data &OUT1 (DROP = I);
   label pclass_version = "Version of ICD-10-PCS Procedure Classes Refined";
   retain PCLASS_VERSION &PCLASS_VERSION;
   
   set &CORE;

   /****************************************************/
   /* Loop through the PCS procedure array in your SAS */
   /* dataset and create the procedure class           */
   /* variables as well as the pclass_orproc flag.     */
   /****************************************************/
   label pclass_orproc = "Indicates operating room procedure reported on the record";
   pclass_orproc = 0;

   array     pclass (*)  3 pclass1-pclass&NUMPR;           * Suggested name for procedure class variables.  <===USER MAY MODIFY;
   array     prs    (*)  $ &PRPREFIX.1-&PRPREFIX.&NUMPR;           

   %if &NPRVAR ne %then %let MAXNPR = &NPRVAR;
   %else                %let MAXNPR = &NUMPR;
   
   do i = 1 to min(&MAXNPR,dim(prs));
      pclass(i) = input(prs(i), pclass.);  
      if pclass(i) in (3,4) then pclass_orproc=1;
   end;
   %do i = 1 %to &NUMPR.;
       label pclass&i. = "ICD-10-PCS Procedure Classes Refined &i.";             * Labels for procedure class variables      <===USER MAY MODIFY;  
   %end;

   /******************************************/
   /* Labeling day of pclass major procedure */
   /******************************************/

  array prday[30]   prday1-prday30;
  array MProc_day[10] MProc_day1-MProc_day10;
  array tmp[30] _temporary_;
  n=0;
  /* collect unique major-procedure days */
  do i=1 to 30;
    if pclass[i] in (3,4) and prday[i] ne . then do;
      found=0;
      do j=1 to n;
        if tmp[j]=prday[i] then do; found=1; leave; end;
      end;
      if not found then do; n+1; tmp[n]=prday[i]; end;
    end;
  end;
  /* simple selection sort of tmp[1..n] */
  if n>1 then do;
    do i=1 to n-1;
      min=i;
      do j=i+1 to n;
        if tmp[j] < tmp[min] then min=j;
      end;
      if min ne i then do;
        t = tmp[i]; tmp[i] = tmp[min]; tmp[min] = t;
      end;
    end;
  end;
  /* initialize outputs then fill first up to 10 sorted unique days */
  do k=1 to 10; MProc_day[k]=.; end;
  do k=1 to min(n,10); MProc_day[k]=tmp[k]; end;
  /* pack left to ensure no internal missing slots */
  idx=1;
  do k=1 to 10;
    if MProc_day[k] ne . then do;
      if k ne idx then MProc_day[idx]=MProc_day[k];
      idx+1;
    end;
  end;
  do k=idx to 10; MProc_day[k]=.; end;
  label
    MProc_day1='Major Procedure Day 1'
    MProc_day2='Major Procedure Day 2'
    MProc_day3='Major Procedure Day 3'
    MProc_day4='Major Procedure Day 4'
    MProc_day5='Major Procedure Day 5'
    MProc_day6='Major Procedure Day 6'
    MProc_day7='Major Procedure Day 7'
    MProc_day8='Major Procedure Day 8'
    MProc_day9='Major Procedure Day 9'
    MProc_day10='Major Procedure Day 10';
  drop i j k idx n found min t;
  /*********************/
  /* End of hyder code */
  /*********************/
run;

proc means data=&OUT1. n nmiss mean min max;
   var pclass1-pclass&NUMPR. pclass_orproc;
   title2 "MEANS ON THE OUTPUT ICD-10-PCS PROCEDURE CLASSES";
run;
%end;
%else %do;
   %put;
   %put 'ERROR: NO PROCEDURE CODES SPECIFIED FOR MACRO VARIABLE NUMPR, PROGRAM ENDING';
   %put;
%end;

%mend pclass;
%pclass;

