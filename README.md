# MD_ICU_Surgery

Hello, friend.

This Repo contains all the SAS programming files you will need to figure out what was done to create the analysis dataset and analyze. 

Code was written by ChatGPT, Claude, and me during February and March 2026. I have reviewed every line of the code and every result. There are some small non-working blocks of code in there but everything needed to replicate the analysis works including code for backfilling of missing MD hospital data in AHA survey using MD Dept of Health sources. 

This repo is missing a few source CSVs, and of course, the SID datasets you will need to replicate the analysis.

If you are interested in fully replicating the analysis with the SID files, send me an email and I will send you the CSVs for PCLASS_ORPROC and HFRS that the code calls to. The complications and CCS code isn't used in the results. You can edit it out if need be. Remember to edit the callout SAS files too because the file names are sequential. 

I can also send you the AHA Hospital Classification file for all U.S. hospitals with the variables needed to replicate this analysis. 

The two main files are MD SICU Data Cut 0321.sas and MD SICU Analysis 0321.sas. The four state data prep is in FL_NY_CA datacut 033126.sas and analysis is incorporated into the MD SICU Analysis file via macro calls.

I welcome collaborations requests in areas of ICU and procedural epidemiology, construct validity of SID and NIS classifiers, and anything else related to large data, critical care, anesthesiology, or surgery. 
