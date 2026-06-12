/* Adapted from: data_management.sas (AHA Annual Survey hospital labeling).    */
/* The original SET an external HCUP library carrying the AHA download; here a  */
/* small inline DATA step supplies hospitals with the same columns (CBSATYPE,   */
/* MAPP3/MAPP8, FTRES, HOSPBD, MSTATE). The CBSA normalization, teaching flag,  */
/* 3-level location/teaching class, region SELECT/WHEN, and the region-specific */
/* bed-size cut points are all verbatim from the author's program.             */

/* Mock AHA hospitals: a spread across regions, teaching status, and bed sizes */
data raw_hosps;
  length CBSATYPE $10 MSTATE $2;
  input ID CBSATYPE $ MAPP3 MAPP8 FTRES HOSPBD MSTATE $;
  datalines;
101 METRO 1 1 320 640 MD
102 METRO 0 0 0 150 MD
103 RURAL 0 0 0 40 MD
104 METRO 1 0 60 210 NY
105 MICRO 0 0 0 80 NY
106 METRO 0 0 10 110 CA
107 METRO 1 1 150 500 CA
108 RURAL 0 0 0 22 CA
109 METRO 0 0 5 90 IL
110 METRO 1 0 200 410 IL
;
run;

data hosps_labeled;
set raw_hosps;

length cbsanorm $10 HOSP_LOCTEACH 3 HOSP_BEDSIZE 3;

  /* Normalize CBSA type and compute Urban flag (Metro  = Urban) */
  cbsanorm = upcase(strip(CBSATYPE));
  if cbsanorm = 'METRO' then URBAN_FLAG = 1;
  else if cbsanorm in ('RURAL','MICRO') then URBAN_FLAG = 0;
  else URBAN_FLAG = .;

  /* Residents-to-bed ratio (guard divide-by-zero/missing) */
  if HOSPBD > 0 then RES_BED_RATIO = FTRES / HOSPBD;
  else RES_BED_RATIO = .;

  /* Teaching flag:
     ACGME=Yes OR COTH=Yes OR (residents-to-bed ratio >= 0.25) */
  TEACH_FLAG = (MAPP3=1) or (MAPP8=1) or (RES_BED_RATIO >= 0.25);

  /* 3-level hospital class per spec:
     1 Rural; 2 Urban nonteaching; 3 Urban teaching (Micro combined with Urban) */
  if      URBAN_FLAG=0 then HOSP_LOCTEACH = 1;                           /* Rural */
  else if URBAN_FLAG=1 and TEACH_FLAG=0 then HOSP_LOCTEACH = 2;          /* Urban, nonteaching */
  else if URBAN_FLAG=1 and TEACH_FLAG=1 then HOSP_LOCTEACH = 3;          /* Urban, teaching */
  else HOSP_CLASS3 = .;


  length region $20;

mstate = upcase(strip(MSTATE));

select (mstate);
    when ('CT','ME','MA','NH','RI','VT','NJ','NY','PA') region = 'NORTHEAST REGION';
    when ('IL','IN','MI','OH','WI','IA','KS','MN','MO','NE','ND','SD') region = 'MIDWEST REGION';
    when ('DE','DC','FL','GA','MD','NC','SC','VA','WV','AL','KY','MS','TN','AR','LA','OK','TX') region = 'SOUTHERN REGION';
    when ('AZ','CO','ID','MT','NV','NM','UT','WY','AK','CA','HI','OR','WA') region = 'WESTERN REGION';
    otherwise region = '';
end;

HOSP_BEDSIZE = .;

if HOSPBD > 0 then do;
    select (region);

        when ('NORTHEAST REGION') do;
            if HOSP_LOCTEACH = 1 then do;
                if 1 <= HOSPBD <= 49 then HOSP_BEDSIZE = 1;
                else if 50 <= HOSPBD <= 99 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 100 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 2 then do;
                if 1 <= HOSPBD <= 124 then HOSP_BEDSIZE = 1;
                else if 125 <= HOSPBD <= 199 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 200 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 3 then do;
                if 1 <= HOSPBD <= 249 then HOSP_BEDSIZE = 1;
                else if 250 <= HOSPBD <= 424 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 425 then HOSP_BEDSIZE = 3;
            end;
        end;

        when ('MIDWEST REGION') do;
            if HOSP_LOCTEACH = 1 then do;
                if 1 <= HOSPBD <= 29 then HOSP_BEDSIZE = 1;
                else if 30 <= HOSPBD <= 49 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 50 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 2 then do;
                if 1 <= HOSPBD <= 74 then HOSP_BEDSIZE = 1;
                else if 75 <= HOSPBD <= 174 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 175 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 3 then do;
                if 1 <= HOSPBD <= 249 then HOSP_BEDSIZE = 1;
                else if 250 <= HOSPBD <= 374 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 375 then HOSP_BEDSIZE = 3;
            end;
        end;

        when ('SOUTHERN REGION') do;
            if HOSP_LOCTEACH = 1 then do;
                if 1 <= HOSPBD <= 39 then HOSP_BEDSIZE = 1;
                else if 40 <= HOSPBD <= 74 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 75 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 2 then do;
                if 1 <= HOSPBD <= 99 then HOSP_BEDSIZE = 1;
                else if 100 <= HOSPBD <= 199 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 200 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 3 then do;
                if 1 <= HOSPBD <= 249 then HOSP_BEDSIZE = 1;
                else if 250 <= HOSPBD <= 449 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 450 then HOSP_BEDSIZE = 3;
            end;
        end;

        when ('WESTERN REGION') do;
            if HOSP_LOCTEACH = 1 then do;
                if 1 <= HOSPBD <= 24 then HOSP_BEDSIZE = 1;
                else if 25 <= HOSPBD <= 44 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 45 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 2 then do;
                if 1 <= HOSPBD <= 99 then HOSP_BEDSIZE = 1;
                else if 100 <= HOSPBD <= 174 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 175 then HOSP_BEDSIZE = 3;
            end;
            else if HOSP_LOCTEACH = 3 then do;
                if 1 <= HOSPBD <= 199 then HOSP_BEDSIZE = 1;
                else if 200 <= HOSPBD <= 324 then HOSP_BEDSIZE = 2;
                else if HOSPBD >= 325 then HOSP_BEDSIZE = 3;
            end;
        end;

        otherwise HOSP_BEDSIZE = .;
    end;
end;
  Rename ID=AHAID;

drop cbsanorm RES_BED_RATIO HOSP_CLASS3 ;
RUN;

proc print data=hosps_labeled;
  var AHAID MSTATE region URBAN_FLAG TEACH_FLAG HOSP_LOCTEACH HOSPBD HOSP_BEDSIZE;
  title "AHA hospitals classified by location/teaching status and region-specific bed size";
run;

proc freq data=hosps_labeled;
tables hosp_locteach urban_flag hosp_bedsize region;
run;
