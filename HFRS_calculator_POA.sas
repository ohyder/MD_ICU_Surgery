/******************************************************/
/***	HFRS Score Calculator based on POA Y, 1, W	***/
/******************************************************/

/*** User must modify ***/
/* 
/*  indat=,     /* input dataset */
/*  outdat=,    /* output dataset */
/*  csvfile=    /* HFRS ICD?points CSV */
%let HFRS_CSV = C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\SAS Code Library\hospital_frailty_icd_points_clean.csv;

%let indat=&dataset._4;
%let outdat=&dataset._5;
%let csvfile ="&HFRS_CSV";

%macro calc_hfrs_poa_merge;

    /************************************************************************
     * 1) Import HFRS mapping (ICD10_Code -> Points)
     *    Create macro variables for each mapping entry: &&diag1 ... &&dstr1 ... &&points1 ...
     ************************************************************************/
    proc import datafile=&csvfile
        out=Frailty_Score1
        dbms=csv
        replace;
        guessingrows=max;
        getnames=yes;
    run;

    data Frailty_Score2;
        set Frailty_Score1;
        rowid = _n_;
        /* variable name token for flags (keeps previous convention) */
        name = cats("dxs_", ICD10_Code);
        /* 3-character prefix for matching */
        d3 = substr(ICD10_Code,1,3);
        points_ = Points;
    run;

    proc sql noprint;
        select count(*) into :total trimmed
        from Frailty_Score2;
    quit;

    %do i=1 %to &total;
        %local diag&i dstr&i points&i;
        data _null_;
            set Frailty_Score2;
            if _n_=&i then do;
                call symputx(cats('diag', &i), cats('dxs_', ICD10_Code));
                call symputx(cats('dstr', &i), strip(d3));
                call symputx(cats('points', &i), points_);
            end;
        run;
    %end;

    /************************************************************************
     * 2) Extract POA-limited diagnoses (POA in: 'Y','W','1') into diag_01-diag_34
     ************************************************************************/
    data _hfrs_dx;
        set &indat;

        array dx[34]  $ I10_DX1-I10_DX34;
        array poa[34] $ DXPOA1-DXPOA34;
        array diag[34] $ diag_01-diag_34;

        do i=1 to 34;
            if poa[i] in ('Y','W','1') then diag[i]=dx[i];
            else diag[i]='';
        end;

        keep KEY diag_01-diag_34;
    run;

    /************************************************************************
     * 3) Prepare 3-character concatenated string and flag presence of HFRS codes
     ************************************************************************/
    data _hfrs_flag;
        set _hfrs_dx;
        length diagstr $2000;

        array d[34] $ diag_01-diag_34;
        array d3[34] $ diag3_01-diag3_34;

        do i=1 to 34;
            d3[i] = substr(d[i],1,3);
        end;

        /* concatenate with a separator so find is safe */
        diagstr = ' ' || catx(' ', of diag3_01-diag3_34) || ' ';

        /* create one flag variable per ICD mapping (dxs_...) */
        %do j=1 %to &total;
            /* search for the 3-char code as a whole token */
            if find(diagstr, cats(' ', "&&dstr&j", ' '), 'i') then &&diag&j = 1;
            else &&diag&j = 0;
        %end;

        keep KEY %do j=1 %to &total; &&diag&j %end; ;
    run;

    /************************************************************************
     * 4) Collapse to patient-level (KEY) taking max flag per code
     ************************************************************************/
    proc sql;
        create table _hfrs_collapse as
        select KEY
        %do j=1 %to &total;
            , max(&&diag&j) as &&diag&j
        %end;
        from _hfrs_flag
        group by KEY;
    quit;

    /************************************************************************
     * 5) Compute HFRS score
     ************************************************************************/
    data _hfrs_score;
        set _hfrs_collapse;
        HFRS = 0;
        %do j=1 %to &total;
            if &&diag&j = 1 then HFRS + &&points&j;
        %end;

        /* HFRS categories: 0, >0 to 5, >5 */
        length HFRS_CAT 3;
        if HFRS = 0 then HFRS_CAT = 0;
        else if 0 < HFRS < 5 then HFRS_CAT = 1;
        else if HFRS >= 5 then HFRS_CAT = 2;
    run;

    /************************************************************************
     * 6) Keep only KEY HFRS HFRS_CAT in the HFRS dataset
     ************************************************************************/
    data _hfrs_keep (keep=KEY HFRS HFRS_CAT);
        set _hfrs_score;
    run;

    /************************************************************************
     * 7) Left-merge back onto the original input dataset by KEY
     *    - do not overwrite the original &indat
     *    - result is &outdat
     ************************************************************************/

    /* sort input and hfrs temp datasets by KEY (using work copies) */
    proc sort data=&indat out=work._indat_sorted;
      by KEY;
    run;

    proc sort data=_hfrs_keep out=work._hfrs_sorted;
      by KEY;
    run;

    data &outdat;
        merge work._indat_sorted (in=_in)
              work._hfrs_sorted;
        by KEY;
        if _in; /* left join: keep all original rows */
    run;

    /************************************************************************
     * 8) Cleanup temporary work datasets
     ************************************************************************/
    proc datasets library=work nolist;
        delete Frailty_Score1 Frailty_Score2
               _hfrs_dx _hfrs_flag _hfrs_collapse _hfrs_score
               _hfrs_keep _hfrs_sorted _indat_sorted;
    quit;

%mend calc_hfrs_poa_merge;

%calc_hfrs_poa_merge;


