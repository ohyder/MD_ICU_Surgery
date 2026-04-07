/* Modeling code for the MD Surgery Elective ICU Cohort */




/***********Year categories************/

/**************************************************************************/
/* 1. Create analysis dataset                                              */
/**************************************************************************/

data ana0;
    set index_main1;

    * Missing category for ZIP income quartile ;
    if missing(zipinc_qrtl) then zipinc_qrtl_m = 5;
    else zipinc_qrtl_m = zipinc_qrtl;

    * Missing category for transfer status ;
    if missing(TRAN_IN) then TRAN_IN_m = 3;
    else TRAN_IN_m = TRAN_IN;

    * Pandemic period variable ;
    length period3 8;
    if 2016 <= YEAR <= 2019 then period3 = 0;   /* pre-COVID */
    else if 2020 <= YEAR <= 2021 then period3 = 1;   /* COVID */
    else if 2022 <= YEAR <= 2024 then period3 = 2;   /* post-COVID */
run;


/**************************************************************************/
/* 2. Get knot locations for age spline                                   */
/**************************************************************************/

proc univariate data=ana0 noprint;
    var age;
    output out=age_knots
        pctlpts = 5 27.5 50 72.5 95
        pctlpre = k_;
run;

data _null_;
    set age_knots;
    call symputx('k1', k_5);
    call symputx('k2', k_27_5);
    call symputx('k3', k_50);
    call symputx('k4', k_72_5);
    call symputx('k5', k_95);
run;


/**************************************************************************/
/* 3. Create restricted cubic spline basis for age                        */
/**************************************************************************/

proc glmselect data=ana0 outdesign(addinputvars)=ana noprint;
    effect spl_age = spline(age /
        naturalcubic
        basis=tpf(noint)
        knotmethod=list(&k1 &k2 &k3 &k4 &k5)
    );
    model DIED = spl_age / selection=none;
run;


/**************************************************************************/
/* 4. Cohort-specific GEE models                                           */
/*    Group: 1 elective, 2 non-elective, 3 non-surgical                  */
/**************************************************************************/

%macro gee_period_by_group(grp=, label=);

    ods output
        Type3      = Type3_G&grp
        GEEEmpPEst = PE_G&grp
        LSMeans    = LSMeans_G&grp;

    proc genmod data=ana descending;
        where Group = &grp;

        class
            DSHOSPID
            period3       (ref='0')
            female        (ref='0')
            race_cat      (ref='1')
            payer         (ref='1')
            zipinc_qrtl_m (ref='4')
            HFRS_cat      (ref='0')
            TRAN_IN_m     (ref='0')
            Hosp_bedsize  (ref='3')
            Hosp_locteach (ref='3');

        model DIED =
            period3
            spl_age:
            female
            race_cat
            payer
            zipinc_qrtl_m
            CMR_Index_mortality
            HFRS_cat
            TRAN_IN_m
            Hosp_bedsize
            Hosp_locteach
            / dist=binomial link=logit type3;

        repeated subject=DSHOSPID / type=exch;

        lsmeans period3 / ilink cl;

        title "Hospital-clustered GEE logistic model for &label ICU hospitalizations";
    run;

    title;

%mend;

%gee_period_by_group(grp=1, label=Elective Surgical);
%gee_period_by_group(grp=2, label=Non-Elective Surgical);
%gee_period_by_group(grp=3, label=Non-Surgical);


/**************************************************************************/
/* 5. Combine cohort-specific outputs                                      */
/**************************************************************************/

data Type3_All;
    length Cohort $30;
    set Type3_G1(in=a) Type3_G2(in=b) Type3_G3(in=c);

    if a then Cohort = "Elective Surgical";
    else if b then Cohort = "Non-Elective Surgical";
    else if c then Cohort = "Non-Surgical";
run;

data PE_All;
    length Cohort $30;
    set PE_G1(in=a) PE_G2(in=b) PE_G3(in=c);

    if a then Cohort = "Elective Surgical";
    else if b then Cohort = "Non-Elective Surgical";
    else if c then Cohort = "Non-Surgical";
run;

data LSMeans_All;
    length Cohort $30;
    set LSMeans_G1(in=a) LSMeans_G2(in=b) LSMeans_G3(in=c);

    if a then Cohort = "Elective Surgical";
    else if b then Cohort = "Non-Elective Surgical";
    else if c then Cohort = "Non-Surgical";
run;


/**************************************************************************/
/* 6. Optional: exponentiate period coefficients to odds ratios            */
/*    This keeps only the period3 rows from the parameter table            */
/**************************************************************************/

data PE_periods;
    set PE_All;
    where upcase(Parameter) = 'PERIOD3';

    OR      = exp(Estimate);
    OR_LCL  = exp(LowerWaldCL);
    OR_UCL  = exp(UpperWaldCL);
run;

proc print data=PE_periods noobs;
    var Cohort Level1 Estimate StdErr WaldChiSq ProbChiSq OR OR_LCL OR_UCL;
run;
