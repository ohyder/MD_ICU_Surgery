/* Adapted from: 1_CMR_Format_Program_v2026-1.sas (Elixhauser Comorbidity      */
/* Software Refined ICD-10-CM format library). The full program defines the     */
/* $COMFMT character format mapping thousands of ICD-10-CM codes to comorbidity */
/* category names. Reproduced here are several category blocks taken verbatim   */
/* from the author's $COMFMT VALUE (AIDS, OBESE, PARALYSIS, VALVE, WGHTLOSS),    */
/* then applied to a handful of diagnosis codes to confirm the format resolves. */
/* Only difference: built in WORK rather than the external 'library' libname,   */
/* and trimmed to a representative subset of categories for a quick check.       */

Proc format ;
   Value $COMFMT
      "B20",
      "E8814",
      "O98711",
      "O98712",
      "O98713",
      "O98719",
      "O9872",
      "O9873",
      "Z21" = "AIDS"

      "Z6842",
      "Z6843",
      "Z6844",
      "Z6845",
      "Z6854",
      "Z6855",
      "Z6856" = "OBESE"

      "R532" = "PARALYSIS"

      "Z952",
      "Z953",
      "Z954" = "VALVE"

      "R634",
      "R64" = "WGHTLOSS"

      other = " "
      ;
run;

/* Apply the format to a small set of diagnosis codes */
data dx_classified;
  length ICD10 $7;
  input ICD10 $;
  CMR_Category = put(ICD10, $COMFMT.);
  datalines;
B20
Z21
Z6856
R532
Z954
R64
I2510
;
run;

proc print data=dx_classified;
  title "ICD-10-CM diagnoses mapped to Elixhauser comorbidity categories";
run;

proc freq data=dx_classified;
  tables CMR_Category / nocum;
  title "Distribution of resolved comorbidity categories";
run;
