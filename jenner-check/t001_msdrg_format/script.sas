/* Adapted from: MD SICU Data Cut 0321.sas (MS-DRG format build, end of file). */
/* Reads the repo's ms_drg.csv, builds a CNTLIN dataset, creates a numeric    */
/* MSDRG format, then applies it to a handful of DRG codes to confirm the      */
/* labels resolve. Original code read the CSV from a Dropbox path; here it     */
/* reads the slice shipped in ./input/ms_drg.csv.                              */

/* 1) Read CSV (no header). Column A -> msdrg_code (numeric). Column D -> msdrg_label. */
data msdrg_raw;
  infile "./input/ms_drg.csv"
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

/* 3) Apply the format to a few DRG values to confirm the labels resolve */
data drg_check;
  input drg;
  drg_desc = put(drg, msdrg.);
  datalines;
1
3
5
10
20
;
run;

proc print data=drg_check;
  title "MS-DRG codes mapped through the CNTLIN format";
run;

proc freq data=msdrg_raw;
  tables msdrg_code / noprint out=code_counts;
run;

proc means data=msdrg_raw n;
  var msdrg_code;
  title "Row count of MS-DRG reference table";
run;
