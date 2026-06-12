/* Adapted from: 3_CMR_Index_Program_v2026-1.sas (Elixhauser Comorbidity     */
/* Software Refined index calculation). The original SET an external library   */
/* dataset carrying the 38 CMR_ comorbidity flags; here a small inline DATA    */
/* step supplies a handful of patient records with those same flags. All the   */
/* readmission/mortality weights and the array-based index arithmetic below    */
/* are verbatim from the author's program.                                     */

%Let NUMcomorb_ = 38;

/* Mock input: 6 patients carrying the 38 CMR_ present-on-admission flags */
data cmr_in;
  input KEY CMR_AIDS CMR_ALCOHOL CMR_ANEMDEF CMR_AUTOIMMUNE CMR_BLDLOSS
        CMR_CANCER_LEUK CMR_CANCER_LYMPH CMR_CANCER_METS CMR_CANCER_NSITU
        CMR_CANCER_SOLID CMR_CBVD CMR_HF CMR_COAG CMR_DEMENTIA CMR_DEPRESS
        CMR_DIAB_CX CMR_DIAB_UNCX CMR_DRUG_ABUSE CMR_HTN_CX CMR_HTN_UNCX
        CMR_LIVER_MLD CMR_LIVER_SEV CMR_LUNG_CHRONIC CMR_NEURO_MOVT
        CMR_NEURO_OTH CMR_NEURO_SEIZ CMR_OBESE CMR_PARALYSIS CMR_PERIVASC
        CMR_PSYCHOSES CMR_PULMCIRC CMR_RENLFL_MOD CMR_RENLFL_SEV
        CMR_THYROID_HYPO CMR_THYROID_OTH CMR_ULCER_PEPTIC CMR_VALVE
        CMR_WGHTLOSS;
  datalines;
1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
2 0 0 1 0 0 0 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
3 0 0 0 0 0 0 0 1 0 1 0 1 1 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 1
4 0 1 1 0 1 0 0 0 0 0 1 0 0 1 1 0 0 1 0 0 0 0 1 0 0 1 0 0 1 0 0 0 0 0 0 0 0 0
5 0 0 0 0 0 0 0 0 0 0 0 1 1 0 0 0 0 0 0 1 0 0 1 0 0 0 1 0 1 0 0 1 0 1 0 0 1 0
6 0 0 1 0 0 1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1
;
run;

TITLE1 'Elixhauser Comorbidity Software Refined for ICD-10-CM Diagnoses';
TITLE2 'Assignment of In-Hospital Mortality and 30-Day Readmission Indices';

DATA cmr_out;
   SET  cmr_in ;

   Length
        CMR_Index_Readmission CMR_Index_Mortality 3;

   LABEL
        CMR_Index_Readmission = 'Comorbidity index for risk of 30-day, all-cause readmission'
        CMR_Index_Mortality   = 'Comorbidity index for risk of in-hospital mortality'
        ;

   /*  Weights for calculating readmission index */
   rwAIDS         =  5 ;
   rwALCOHOL      =  3 ;
   rwANEMDEF      =  5 ;
   rwAUTOIMMUNE   =  2 ;
   rwBLDLOSS      =  2 ;
   rwCANCER_LEUK  = 10 ;
   rwCANCER_LYMPH =  7 ;
   rwCANCER_METS  = 11 ;
   rwCANCER_NSITU =  0 ;
   rwCANCER_SOLID =  7 ;
   rwCBVD         =  0 ;
   rwHF           =  7 ;
   rwCOAG         =  3 ;
   rwDEMENTIA     =  1 ;
   rwDEPRESS      =  2 ;
   rwDIAB_CX      =  4 ;
   rwDIAB_UNCX    =  0 ;
   rwDRUG_ABUSE   =  6 ;
   rwHTN_CX       =  0 ;
   rwHTN_UNCX     =  0 ;
   rwLIVER_MLD    =  3 ;
   rwLIVER_SEV    = 10 ;
   rwLUNG_CHRONIC =  4 ;
   rwNEURO_MOVT   =  1 ;
   rwNEURO_OTH    =  2 ;
   rwNEURO_SEIZ   =  5 ;
   rwOBESE        = -2 ;
   rwPARALYSIS    =  3 ;
   rwPERIVASC     =  1 ;
   rwPSYCHOSES    =  6 ;
   rwPULMCIRC     =  3 ;
   rwRENLFL_MOD   =  4 ;
   rwRENLFL_SEV   =  8 ;
   rwTHYROID_HYPO =  0 ;
   rwTHYROID_OTH  =  0 ;
   rwULCER_PEPTIC =  2 ;
   rwVALVE        =  0 ;
   rwWGHTLOSS     =  6 ;

   /*  Weights for calculating mortality index */
   mwAIDS         = -4 ;
   mwALCOHOL      = -1 ;
   mwANEMDEF      = -3 ;
   mwAUTOIMMUNE   =  0 ;
   mwBLDLOSS      = -4 ;
   mwCANCER_LEUK  =  9 ;
   mwCANCER_LYMPH =  5 ;
   mwCANCER_METS  = 22 ;
   mwCANCER_NSITU =  0 ;
   mwCANCER_SOLID = 10 ;
   mwCBVD         =  5 ;
   mwHF           = 14 ;
   mwCOAG         = 14 ;
   mwDEMENTIA     =  5 ;
   mwDEPRESS      = -8 ;
   mwDIAB_CX      = -2 ;
   mwDIAB_UNCX    =  0 ;
   mwDRUG_ABUSE   = -7 ;
   mwHTN_CX       =  1 ;
   mwHTN_UNCX     =  0 ;
   mwLIVER_MLD    =  2 ;
   mwLIVER_SEV    = 16 ;
   mwLUNG_CHRONIC =  2 ;
   mwNEURO_MOVT   = -1 ;
   mwNEURO_OTH    = 22 ;
   mwNEURO_SEIZ   =  2 ;
   mwOBESE        = -7 ;
   mwPARALYSIS    =  4 ;
   mwPERIVASC     =  3 ;
   mwPSYCHOSES    = -9 ;
   mwPULMCIRC     =  4 ;
   mwRENLFL_MOD   =  3 ;
   mwRENLFL_SEV   =  7 ;
   mwTHYROID_HYPO = -3 ;
   mwTHYROID_OTH  = -8 ;
   mwULCER_PEPTIC =  0 ;
   mwVALVE        =  0 ;
   mwWGHTLOSS     = 13 ;

   /*      Arrays Used to Assign Final Indexes                */
   array cmvars(&NUMcomorb_) 	    CMR_AIDS       CMR_ALCOHOL      CMR_ANEMDEF      CMR_AUTOIMMUNE   CMR_BLDLOSS      CMR_CANCER_LEUK  CMR_CANCER_LYMPH CMR_CANCER_METS  CMR_CANCER_NSITU
                   CMR_CANCER_SOLID CMR_CBVD       CMR_HF           CMR_COAG         CMR_DEMENTIA     CMR_DEPRESS      CMR_DIAB_CX      CMR_DIAB_UNCX    CMR_DRUG_ABUSE   CMR_HTN_CX
                   CMR_HTN_UNCX     CMR_LIVER_MLD  CMR_LIVER_SEV    CMR_LUNG_CHRONIC CMR_NEURO_MOVT   CMR_NEURO_OTH    CMR_NEURO_SEIZ   CMR_OBESE        CMR_PARALYSIS    CMR_PERIVASC
                   CMR_PSYCHOSES    CMR_PULMCIRC   CMR_RENLFL_MOD   CMR_RENLFL_SEV   CMR_THYROID_HYPO CMR_THYROID_OTH  CMR_ULCER_PEPTIC CMR_VALVE        CMR_WGHTLOSS
					;

   array rwcms(&NUMcomorb_) 	rwAIDS       rwALCOHOL      rwANEMDEF      rwAUTOIMMUNE  rwBLDLOSS      rwCANCER_LEUK  rwCANCER_LYMPH rwCANCER_METS  rwCANCER_NSITU rwCANCER_SOLID
                    rwCBVD      rwHF         rwCOAG         rwDEMENTIA     rwDEPRESS     rwDIAB_CX      rwDIAB_UNCX    rwDRUG_ABUSE   rwHTN_CX       rwHTN_UNCX
					rwLIVER_MLD rwLIVER_SEV  rwLUNG_CHRONIC rwNEURO_MOVT   rwNEURO_OTH   rwNEURO_SEIZ   rwOBESE        rwPARALYSIS    rwPERIVASC     rwPSYCHOSES
					rwPULMCIRC  rwRENLFL_MOD rwRENLFL_SEV   rwTHYROID_HYPO rwTHYROID_OTH rwULCER_PEPTIC rwVALVE        rwWGHTLOSS
					;

   array mwcms(&NUMcomorb_) 	mwAIDS       mwALCOHOL      mwANEMDEF      mwAUTOIMMUNE  mwBLDLOSS      mwCANCER_LEUK  mwCANCER_LYMPH mwCANCER_METS  mwCANCER_NSITU mwCANCER_SOLID
                    mwCBVD      mwHF         mwCOAG         mwDEMENTIA     mwDEPRESS     mwDIAB_CX      mwDIAB_UNCX    mwDRUG_ABUSE   mwHTN_CX       mwHTN_UNCX
					mwLIVER_MLD mwLIVER_SEV  mwLUNG_CHRONIC mwNEURO_MOVT   mwNEURO_OTH   mwNEURO_SEIZ   mwOBESE        mwPARALYSIS    mwPERIVASC     mwPSYCHOSES
					mwPULMCIRC  mwRENLFL_MOD mwRENLFL_SEV   mwTHYROID_HYPO mwTHYROID_OTH mwULCER_PEPTIC mwVALVE        mwWGHTLOSS
					;

   array ricms(&NUMcomorb_)     riAIDS       riALCOHOL      riANEMDEF      riAUTOIMMUNE   riBLDLOSS      riCANCER_LEUK  riCANCER_LYMPH riCANCER_METS  riCANCER_NSITU riCANCER_SOLID
                    riCBVD      riHF         riCOAG         riDEMENTIA     riDEPRESS      riDIAB_CX      riDIAB_UNCX    riDRUG_ABUSE   riHTN_CX       riHTN_UNCX
					riLIVER_MLD riLIVER_SEV  riLUNG_CHRONIC riNEURO_MOVT   riNEURO_OTH    riNEURO_SEIZ   riOBESE        riPARALYSIS    riPERIVASC     riPSYCHOSES
					riPULMCIRC  riRENLFL_MOD riRENLFL_SEV   riTHYROID_HYPO riTHYROID_OTH  riULCER_PEPTIC riVALVE        riWGHTLOSS
					;

   array micms(&NUMcomorb_)     miAIDS       miALCOHOL      miANEMDEF      miAUTOIMMUNE   miBLDLOSS      miCANCER_LEUK  miCANCER_LYMPH miCANCER_METS  miCANCER_NSITU miCANCER_SOLID
                    miCBVD      miHF         miCOAG         miDEMENTIA     miDEPRESS      miDIAB_CX      miDIAB_UNCX    miDRUG_ABUSE   miHTN_CX       miHTN_UNCX
					miLIVER_MLD miLIVER_SEV  miLUNG_CHRONIC miNEURO_MOVT   miNEURO_OTH    miNEURO_SEIZ   miOBESE        miPARALYSIS    miPERIVASC     miPSYCHOSES
					miPULMCIRC  miRENLFL_MOD miRENLFL_SEV   miTHYROID_HYPO miTHYROID_OTH  miULCER_PEPTIC miVALVE        miWGHTLOSS
					;

   *****Calculate readmission and mortality indices;
   do i = 1 to &NUMcomorb_;
      ricms[i]=cmvars[i]*rwcms[i];
      micms[i]=cmvars[i]*mwcms[i];
   end;

   CMR_Index_Readmission = sum(of ricms[*]);
   CMR_Index_Mortality   = sum(of micms[*]);

   ***drop all intermediate variables;
   drop rw: mw: ri: mi: i;
RUN;

proc print data=cmr_out;
  var KEY CMR_Index_Readmission CMR_Index_Mortality;
  title3 'Per-patient comorbidity indices';
run;

/*  Means of comorbidity variables */
PROC MEANS DATA=cmr_out  N NMISS MEAN STD MIN MAX;
  VAR    CMR_Index_Readmission CMR_Index_Mortality ;
   TITLE3 'Means of Comorbidity Indices';
RUN;
