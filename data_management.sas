/*****************************************************************************/
/* This prog will label and process the download from WRDS AHA Annual Survey */
/* The AHA download contains all US hospitals 2016-2024						*/
/* 1/3/2026 - update 3/22/26 to correctly classify Micropolitian under Rural */
/* https://hcup-us.ahrq.gov/db/vars/hosp_location/kidnote.jsp */
/* https://hcup-us.ahrq.gov/db/vars/hosp_bedsize/nisnote.jsp */

/* 		hospbd Total hospital beds
		mapp3 Residency training approval by ACGME
		mapp8 Member of Council of Teaching Hospital of the AAMC (COTH)
		ftres Full time medical and dental residents and interns
		cbsatype CBSA Type

		msicbd Medical/Surgical intensive care beds
		cicbd Cardiac Intensive Care Beds
		brnbd Burn care beds
		spcicbd Beds other special care
		(othicbd) Other intensive care beds
		(ftemsi) Intensivists FTE Medical-surgical intensive care
		(ftecic) Intensivists FTE Cardiac intensive care
		(fteoic) Intensivists FTE Other intensive care
		(fteint) Intensivists FTE Total
		(intcar) Intensivists provide care

		(teint) Intensivist - total employed - DIDN'T OUTPUT - LIKELY EMPTY
		(ftmsia) Intensivists F-Time Medical-Surgical Intensive Care -EMPTY
		(ftcica) Intensivists F-Time Cardiac Intensive Care -EMPTY
		(ftoica) Intensivists F-Time Other Intensive Care-EMPTY
		(fttinta) Intensivists F-Time Total-EMPTY
		(msichos) Medical/surgical intensive care - hospital
		(mname) Hospital name
		(mtype) Hospital type code - USELESS
		(clsmsi) Closed medical surgical intensive care
*/

libname hcup 'C:\Users\HP375\Partners HealthCare Dropbox\Omar Hyder\Research\HCUP Master Files\AHA Hospital Data';

proc contents data=hcup.qgwfbjebwl6xk66cp; run;

proc freq data=hcup.qgwfbjebwl6xk66cp;
tables MSTATE; run;


data hcup.AHA_hosps_16_24_all_states;
set hcup.qgwfbjebwl6xk66cp;

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

drop MLOCSTCD mtype
FTMSIA
FTCICA
FTOICA
FTTINTA
cbsanorm RES_BED_RATIO HOSP_CLASS3 ;
RUN;


proc freq data=hcup.AHA_hosps_16_24_all_states;
where mstate = ('CA');
tables hosp_locteach urban_flag hosp_bedsize;
run;
