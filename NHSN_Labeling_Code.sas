/******************************************/
/* NHSN Labeling for the Maryland SICU data **/
/*****************************************/
/* Read NHSN data to a SAS dataset */

/* https://www.cdc.gov/nhsn/xls/icd10-pcs-pcm-nhsn-opc.xlsx */

libname SICU 'C:\Users\HP375\Documents\Research\SICU Maryland\SAS_datasets2';


proc import datafile="C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\NHSN_ICD10\NHSN Codes.xlsx"
    out=icd10_lookup
    dbms=xlsx
    replace;
    getnames=yes;
run;


/* This is the proc sql method - takes a while to run */

%macro add_nhsn_labels(input_dataset=, output_dataset=);
    /* Create temporary working dataset */
    data nis_temp; 
        set &input_dataset;
    run;
    
    /* Inner macro to classify each procedure */
    %macro classify_procedure(proc_var, class_var);
        proc sql noprint;
            create table temp_merge as
            select a.*, b.Label as &class_var
            from nis_temp a
            left join icd10_lookup b
            on a.&proc_var = b.ICD10;
        quit;
        
        data nis_temp;
            set temp_merge;
            if missing(&class_var) then &class_var = '';
        run;
        
        proc datasets lib=work nolist;
            delete temp_merge;
        quit;
    %mend classify_procedure;
    
    /* Loop through all 30 procedure variables */
    %do i = 1 %to 30;
        %classify_procedure(i10_pr&i, cat_i10_pr&i);
    %end;
    
    /* Save final dataset */
    data &output_dataset;
        set nis_temp;
    run;
    
    /* Clean up temporary dataset */
    proc datasets lib=work nolist;
        delete nis_temp;
    quit;
%mend add_nhsn_labels;

/* Example usage: */
%add_nhsn_labels(input_dataset=SICU.&dataset._2, output_dataset=&dataset._3_1);


/* THIS CODE BLOCK CREATES PRMAINCAT AND CORRESPONDING DAY OF PROCEDURE - NEEDS TO BE RUN AFTER THE SQL CODE BLOCK */

%macro cut_to_nhsn(input_dataset=, output_dataset=);
    /* Create temporary working dataset */
    data &output_dataset; 
        set &input_dataset;

* Creating prmain: the main procedure ICD10 columnn for NHSN data. If i10_pr1 has a code c/w NHSN then that ports to prmain;
* If i10_pr1 doesn't have a relevant code then it looks down the line to see where it appears. Then ports it to prmain; 

    length prmain $7 prmaind 8 prmaincat $100;

    /* First check if cat_I10_pr1 is not missing */
	/* I10_PR1_CLASS was created by the Procedure classes refined code. This block won't run without that code. Change to cat_10_pr1 if only running NHSN */
    if cat_i10_pr1 ne '' then do; *<<<<<<<<;
        prmain = i10_pr1;
        prmaind = prday1;
        prmaincat = cat_I10_pr1;
    end;

    /* If cat_I10_pr1 is missing, scan from cat_I10_pr2 to cat_I10_pr30 */
    else do;
        array prcodes {*} i10_pr2-i10_pr30;
        array prdays {*} prday2-prday30;
        array prcats {*} cat_I10_pr2-cat_I10_pr30;

        do i = 1 to dim(prcats);
            if prcats[i] ne '' then do;
                prmain    = prcodes[i];
                prmaind   = prdays[i];
                prmaincat = prcats[i];
                leave; /* Exit loop once the first non-missing category is found */
            end;
        end;
    end;

    drop i;



/*prd_marker=.; *Procedure on day prior to admission;

if -10 le prday1 lt 0 then prd_marker=0;
if prday1 = 0 then prd_marker=1;
if prday1 gt 0 then prd_marker=2;*/


/*IF PRMAIND = . THEN DELETE; *On manual review these folks had prday1 listed but NHSN was capturing procedure 2 which didn't have a day listed. Most cases it was part of the same procedure;*/

PRMAINCAT_D=PRMAINCAT;
/* Reduce procedure categories to reflect clinical practice */
IF PRMAINCAT IN ('CARD', 'CBGC' , 'CBGB') THEN PRMAINCAT_D= 'CARD'; *CABG and valves are collapsed into CARD;
IF PRMAINCAT IN ('LAM', 'FUSN') THEN PRMAINCAT_D= 'SPNE'; *This includes lamincectomies and fusion;
IF PRMAINCAT IN ('OVRY' , 'HYST' , 'VHYS') THEN PRMAINCAT_D='HYST'; *This includes hysterectomy and oophorectomy;
IF PRMAINCAT IN ('COLO' , 'REC') THEN PRMAINCAT_D='CREC'; *This includes colorectal surgery;
IF PRMAINCAT IN ('CRAN' , 'VSHN') THEN PRMAINCAT_D='CRNS'; *CRAN already includes the diagnosis that maps to EVD. So, makes sense to include shunts into it;

/*IF PCLASS_ORPROC ne 1 THEN DELETE; /* Note that the cohort is being restricted to the broader definition of Procedure Classes Refined not PRMAINCAT */

    /***************************/
	/* I10 delivery flag code */
	/**************************/
    /* Initialize delivery flag */
    I10_DELIVERY = 0;
    
    /* Only process females */
    if FEMALE = 1 then do;
        
        /* Check for abortion exclusion criteria first */
        _abortion_dx = 0;
        _abortion_pr = 0;
        
        /* Check diagnosis codes for abortion */
        array dx{30} $ i10_dx1-i10_dx30;
        do i = 1 to 30;
            if not missing(dx{i}) then do;
                if substr(dx{i},1,3) in ('O00','O01','O02','O03','O04','O07','O08') then 
                    _abortion_dx = 1;
            end;
        end;
        
        /* Check procedure codes for abortion */
        array pr{30} $ i10_pr1-i10_pr30;
        do i = 1 to 30;
            if not missing(pr{i}) then do;
                if substr(pr{i},1,4) = '10A0' then 
                    _abortion_pr = 1;
            end;
        end;
        
        /* If no abortion indicators, check for delivery criteria */
        if _abortion_dx = 0 and _abortion_pr = 0 then do;
            
            /* Check diagnosis codes */
            do i = 1 to 30;
                if not missing(dx{i}) then do;
                    /* Z37 prefix (outcome of delivery) */
                    if substr(dx{i},1,3) = 'Z37' then I10_DELIVERY = 1;
                    /* O80 (full-term uncomplicated delivery) */
                    if dx{i} = 'O80' then I10_DELIVERY = 1;
                    /* O82 (cesarean delivery without indication) */
                    if dx{i} = 'O82' then I10_DELIVERY = 1;
                    /* O7582 (spontaneous labor 37-39 weeks with planned cesarean) */
                    if dx{i} = 'O7582' then I10_DELIVERY = 1;
                end;
            end;
            
            /* Check procedure codes */
            do i = 1 to 30;
                if not missing(pr{i}) then do;
                    /* 10D00Z0-10D00Z2 */
                    if substr(pr{i},1,6) = '10D00Z' and 
                       substr(pr{i},7,1) in ('0','1','2') then I10_DELIVERY = 1;
                    /* 10D07Z3-10D07Z8 */
                    if substr(pr{i},1,6) = '10D07Z' and 
                       substr(pr{i},7,1) in ('3','4','5','6','7','8') then I10_DELIVERY = 1;
                    /* 10E0XZZ */
                    if pr{i} = '10E0XZZ' then I10_DELIVERY = 1;
                end;
            end;
            
            /* Check MS-DRG codes */
            if DRG in (768, 783, 784, 785, 786, 787, 788, 796, 797, 798, 805, 806, 807) then 
                I10_DELIVERY = 1;
                
        end; /* End no abortion check */
        
    end; /* End female check */
    
    /* Clean up temporary variables */
    drop i _abortion_dx _abortion_pr;
	/** End i10_delivery flag code */
run;
%mend;

%cut_to_nhsn(input_dataset=&dataset._3_1, output_dataset=&dataset._4);

