CREATE VIEW dbo.vwGetEndOfLeaseData_V2
------------------------------------------------------------------------------------  
-- DATE            Release    Who        Control    Comment  
-- ----------    -------    -------    -------    --------------------------------------------  
-- 06/23/2014    V01.00    Karthkum        Initial  
-- 07/01/2014    V01.01    Karthkum        Include the AX Company Code  
-- 10/17/2014    V01.02    Karthkum        Convert to proper date format   
--                                         for TerminationDate and ProcessQueueTimeStamp  
-- 03/25/2015    V01.03    Karthkum        Include fields required for CR 60 (Service Led)  
-- 03/25/2015    V01.03    Karthkum        Include fields required for CR 67 (Soft Cost)  
-- 09/27/2016    V01.04    Marchoug        Fixed ENTRS_LGL_ENT_ASSC Inner Join Logic   
-- 10/06/2016    V01.05    Marchoug        Include fields required for US 9564 (Asset Location)  
-- 10/20/2016    V01.05    Frasanch        Fix EQPMNT_LCTN to not show nulls when one of the columns is null  
-- 01/20/2017    V17.02    Ravsing         Fixed Asset Description issue  
-- 03/01/2017    V17.02OC  SDAN            Added (NOLOCK), (no change to result set).  
-- 04/10/2017    V17.03    SDAN            View changes to support Schema simplification.  
-- 07/17/2017    V17.04  Davilaca          Convert to Proper date Format for Start Date and Maturity Date  
-- 07/20/2017    V17.04  VMadduri          Added the country join between portfolio table and enterprise Legal Entity Tables.  
--                                         Once we start using the AX_Company code from the Lease Portfolio we can remove these joins.  
-- 08/01/2017    V17.04    SDAN            Implemented LS_PTFL changes.  
-- 10/03/2017    V18.01    SDAN            Added TRM_MNTHS.  
-- 08/23/2019			   SUDHEER KUMAR   Performance change  
-- 10/09/2019              FERGUS O'DONNELL NGIT 2.2  
-- 07/16/2024              Veeran          Modified the view with CTE Approach for Performance Improvement

as 
with LS_AGRMNT_ITM_CTE
as
( 
select LT.SYS_ASST_ID ,LT.LS_AGRMNT_ID,LT.SRC_SYS_ADDR_UID ,LT.LS_AGRMNT_SHP_TO_ADDR,
LS_AGRMNT_ITM_USG_PAST_MTRTY_AMT,   LS_AGRMNT_ITM_ANNL_INT_RATE,   LS_AGRMNT_ITM_TYP_CD,        
LS_AGRMNT_ITM_PRCH_INV_LCL_ID,       LS_AGRMNT_ITM_PO_ITM_NR,  RTN_MTRL_ATHZ_ID,    
LS_AGRMNT_ITM_LCK_IND, LS_AGRMNT_ITM_STTS_CD,   LS_AGRMNT_ITM_TRMN_RSN_CD,    
CAST(LS_AGRMNT_ITM_TRMN_TS as datetime)  AS 'LS_AGRMNT_ITM_TRMN_TS',  
CAST(LS_AGRMNT_ITM_TRMN_PRS_TS as datetime) AS 'LS_AGRMNT_ITM_TRMN_PRS_TS', 
LS_AGRMNT_ITM_QT_ITM_NR,     TRMN_SPLST_EML_ADDR ,
        LT.LS_AGRMNT_ITM_RDL_VL_AMT,                        
        LT.LS_AGRMNT_ITM_ORGL_EQPMNT_AMT,                                
        LT.LS_AGRMNT_ITM_Rent_AMT                                         
from LS_AGRMNT_ITM LT
) 
,LS_AGRMNT_ITM_TRMN_RSN_CTE as 
(
select LS_AGRMNT_ITM_TRMN_RSN_DN, LS_AGRMNT_ITM_TRMN_RSN_CD  from LS_AGRMNT_ITM_TRMN_RSN
),LGCY_ADDR_CTE as 
(
select  LD.CTRY_CD,LD.ADDR_1 ,LD.ADDR_2 , LD.CTY , LD.ST_CD ,LD.PSTL_CD ,LD.CNTY_NM, LD.ADDR_CD,LD.SRC_SYS_ASST_UID from dbo.LGCY_ADDR LD
) ,  SYS_ASST_CTE
AS
(
select  SA.SYS_ASST_ID , SA.SYS_ASST_UID,     SA.SYS_PRNT_ASST_ID,    SA.SYS_ASST_PROD_INSN_SRL_NR  ,SA.PROD_ID  from dbo.SYS_ASST SA
) , PROD_DN_CTE AS
(
select PDN.DN , PDN.PROD_ID, PDN.DTA_OWN_GRP_ID from dbo.PROD_DN PDN
)
, PROD_CTE AS
(
SELECT P.PROD_NR,P.DTA_OWN_GRP_ID ,P.PROD_INF_LVL_TYP_CD, P.SLTN_GRP_ID,P.PROD_NR       AS 'SYS_ASST_PROD_NR' ,P.PROD_ID , P.MFR_ID, P.DN FROM dbo.PROD P
)
,FinalCTE as
(
SELECT   
        LA.LS_AGRMNT_ID,   
        SA.SYS_ASST_UID,                                                -- Pyramid Asset ID  
        SA.SYS_PRNT_ASST_ID,                                            -- Pyramid Parent Asset ID  
        SA.SYS_ASST_PROD_INSN_SRL_NR,                                    -- Pyramid Serial Number  
        P.PROD_NR                            AS 'SYS_ASST_PROD_NR',        -- Pyramid Part Number  
        LA.LS_AGRMNT_NR,                                                -- Contract Number  
        XREF.ORG_ID            AS 'ORG_ID',    -- Customer Number  
        LT.LS_AGRMNT_ITM_RDL_VL_AMT,                                    -- Residual Value  
        LT.LS_AGRMNT_ITM_ORGL_EQPMNT_AMT,                                -- Original Equipment Amount  
        LT.LS_AGRMNT_ITM_Rent_AMT,                                        -- Rent Amount  
        --CONVERT(VARCHAR(24), LA.LS_AGRMNT_BK_TS, 21)    AS 'LS_AGRMNT_BK_TS',                -- Start Date  
        --CONVERT(VARCHAR(24), LA.LS_AGRMNT_MTRTY_TS, 21)    AS 'LS_AGRMNT_MTRTY_TS',            -- Maturity Date  
        CAST(LA.LS_AGRMNT_BK_TS as datetime)    AS 'LS_AGRMNT_BK_TS',                -- Start Date  
        CAST(LA.LS_AGRMNT_MTRTY_TS as datetime)    AS 'LS_AGRMNT_MTRTY_TS',            -- Maturity Date  
        P.MFR_ID,                                                        -- Mfr ID  
        PD.PRT_DFN_OWN_ID,                                                -- Part Own ID  
        PD.PRT_DFN_OWN_MFR_CD,                                            -- Mfg Code  
        LT.LS_AGRMNT_ITM_USG_PAST_MTRTY_AMT,                            -- UPM Amount  
        LT.LS_AGRMNT_ITM_ANNL_INT_RATE,                                    -- Annual Interest Rate  
        LA.LS_AGRMNT_INV_FRQ_TYP_CD,                                    -- Billing Cycle  
        LT.LS_AGRMNT_ITM_TYP_CD,                                        -- Lease Type Class  
        LP.LS_PTFL_ID,                                                    -- Portfolio ID  
        LA.PTFL_SPLST_EML_ADDR,                -- Portofolio Specialist  
        LT.LS_AGRMNT_ITM_PRCH_INV_LCL_ID,                                -- Supplier Invoice Number  
        LT.LS_AGRMNT_ITM_PO_ITM_NR,                                        -- Invoice PO Number (new field?)  
        LP.FLEXI_CMPNY_CD                    AS 'IC_ENTRS_LGL_ENT_NR',    -- Company Code (Flexi Company Code, as per the input)  
        LT.RTN_MTRL_ATHZ_ID,                                            -- Deal Number  
        LT.LS_AGRMNT_ITM_LCK_IND,                                        -- Asset Locked on deal number or P+ QUOTE  
        LA.RTN_SPLST_EML_ADDR,                                            -- CRS Email  
        LT.LS_AGRMNT_ITM_STTS_CD,                                        -- Termination Flag  
        LT.LS_AGRMNT_ITM_TRMN_RSN_CD,                                    -- Termination Reason Code  
        trc.LS_AGRMNT_ITM_TRMN_RSN_DN,                                    -- Termination Reason Description  
        --CONVERT(VARCHAR(24), LT.LS_AGRMNT_ITM_TRMN_TS, 21)        AS 'LS_AGRMNT_ITM_TRMN_TS',        -- Effective Termination Date   
        --CONVERT(VARCHAR(24), LT.LS_AGRMNT_ITM_TRMN_PRS_TS, 21)    AS 'LS_AGRMNT_ITM_TRMN_PRS_TS',    -- Process Queue Time stamp  
        CAST( LT.LS_AGRMNT_ITM_TRMN_TS as datetime)        AS 'LS_AGRMNT_ITM_TRMN_TS',        -- Effective Termination Date   
        CAST(LT.LS_AGRMNT_ITM_TRMN_PRS_TS as datetime)    AS 'LS_AGRMNT_ITM_TRMN_PRS_TS',    -- Process Queue Time stamp  
        LT.LS_AGRMNT_ITM_QT_ITM_NR,                                        -- P+ return Quote Number  
        LT.TRMN_SPLST_EML_ADDR,                                            -- Termination queue approved by  
        LA.LS_AGRMNT_ADV_IND,                                            -- Lease Agreement Advance Indictor  
        WR.WRLD_RGN_NM,                                                    -- Geo Code  
        LP.AX_CMPNY_CD                        AS 'PRNT_ENTRS_LGL_ENT_NR',    -- AX Company Code  
        LA.LS_AGRMNT_STTS_CD,                                            -- Contract Booked Status  
        LA.PYRAMID_CO_ID,                                                -- Pyramid Customer ID  
        XREF.END_USR_PHX_CLI_ID,                                        -- End user Phoenix Client ID  
        XREF.SRVC_LED_IN,                                                -- Service Led Indicator  
        PH.PROD_TNGBL_FLTR_DCSN_IND,                                    -- CR Allowed Indicator  
        PH.PROD_INF_LVL_TYP_CD,                                            -- Product Information Level Type Code  
        PH.PROD_ASST_MGMT_HRCHY_ROL_CD,                                    -- Product role type ID      
        XREF.SBL_GLOB_CSTMR_ID,                                            -- End User Org ID  
        concat(LD.ADDR_1    +', ',LD.ADDR_2    +', ' , LD.CTY+', ' , LD.ST_CD +', ',LD.PSTL_CD+', ',LD.CNTY_NM) as 'EQPMNT_LCTN', --Equipment Location  
        LD.CTRY_CD,                                                        -- Equipment Country  
        SG.SLTN_GRP_NM,                                                    -- Product Type      
        COALESCE(PDN.DN, P.DN)            AS 'ASST_DN',                    -- Mfg Model code desc (asset description)  
        LA.TRM_MNTHS  
FROM dbo.LS_AGRMNT LA (NOLOCK)     ---504869
INNER JOIN dbo.LS_PTFL LP (NOLOCK)      ON LP.LS_PTFL_ID      = LA.LS_PTFL_ID    --481054
INNER JOIN dbo.WRLD_RGN WR (NOLOCK)      ON WR.WRLD_RGN_ID      = LP.WRLD_RGN_ID    --481054
outer apply (  
---this is customer entity  
select XREF.END_USR_PHX_CLI_ID, XREF.SRVC_LED_IN, XREF.SBL_GLOB_CSTMR_ID,XREF.LEGACY_SBL_GLOB_CSTMR_ID,   
XREF.LEGACY_ORIG_MDCP_ORG_ID,    
case when ISNUMERIC(XREF.ORIG_MDCP_ORG_ID)    = 1 then CAST(XREF.ORIG_MDCP_ORG_ID AS NUMERIC) end ORG_ID  
FROM    dbo.XREF_BUS_EXTNSN XREF (NOLOCK)  
inner join party.party party(NOLOCK) on (  cast(party.emdmPartyId  as nvarchar(50) )  = XREF.ORIG_MDCP_ORG_ID )   
WHERE     
xref.XREF_BUS_EXTNSN_ID = LA.XREF_BUS_EXTNSN_ID  
)XREF    ----481054
INNER JOIN  LS_AGRMNT_ITM_CTE LT (NOLOCK)  ON (LT.LS_AGRMNT_ID = LA.LS_AGRMNT_ID)     ---157229633
LEFT OUTER JOIN  LS_AGRMNT_ITM_TRMN_RSN_CTE trc (NOLOCK) ON (trc.LS_AGRMNT_ITM_TRMN_RSN_CD = LT.LS_AGRMNT_ITM_TRMN_RSN_CD)  
LEFT OUTER JOIN  LGCY_ADDR_CTE LD (NOLOCK)         ON (LD.SRC_SYS_ASST_UID = LT.SRC_SYS_ADDR_UID AND LD.ADDR_CD = LT.LS_AGRMNT_SHP_TO_ADDR)  
INNER JOIN  SYS_ASST_CTE SA (NOLOCK)   ON (SA.SYS_ASST_ID = LT.SYS_ASST_ID)  
INNER JOIN PROD_CTE P (NOLOCK)    ON (P.PROD_ID = SA.PROD_ID)  
INNER JOIN dbo.SLTN_GRP SG (NOLOCK)   ON (SG.SLTN_GRP_ID = P.SLTN_GRP_ID)  
INNER JOIN dbo.PROD_HRCHY_ROL_TYP_INF_LVL PH (NOLOCK) ON (PH.PROD_INF_LVL_TYP_CD = P.PROD_INF_LVL_TYP_CD AND PH.PROD_ASST_MGMT_HRCHY_ROL_CD = SG.PROD_ASST_MGMT_HRCHY_ROL_CD)  
INNER JOIN dbo.PRT_DFN_OWN PD (NOLOCK)   ON (PD.PRT_DFN_OWN_ID = P.MFR_ID)  
LEFT OUTER JOIN PROD_DN_CTE PDN (NOLOCK)  ON (PDN.PROD_ID = P.PROD_ID AND PDN.DTA_OWN_GRP_ID = P.DTA_OWN_GRP_ID )  
)select LS_AGRMNT_ID,   
SYS_ASST_UID,  
SYS_PRNT_ASST_ID,  
SYS_ASST_PROD_INSN_SRL_NR, 
SYS_ASST_PROD_NR,
LS_AGRMNT_NR,   
ORG_ID,
LS_AGRMNT_ITM_RDL_VL_AMT, 
LS_AGRMNT_ITM_ORGL_EQPMNT_AMT,                             
LS_AGRMNT_ITM_Rent_AMT,                                     
LS_AGRMNT_BK_TS,      
LS_AGRMNT_MTRTY_TS,         
MFR_ID,          
PRT_DFN_OWN_ID,      
PRT_DFN_OWN_MFR_CD,   
LS_AGRMNT_ITM_USG_PAST_MTRTY_AMT,  
LS_AGRMNT_ITM_ANNL_INT_RATE,  
LS_AGRMNT_INV_FRQ_TYP_CD,   
LS_AGRMNT_ITM_TYP_CD,   
LS_PTFL_ID,                 
PTFL_SPLST_EML_ADDR,          
LS_AGRMNT_ITM_PRCH_INV_LCL_ID,                              
LS_AGRMNT_ITM_PO_ITM_NR,  
IC_ENTRS_LGL_ENT_NR,   
RTN_MTRL_ATHZ_ID,    
LS_AGRMNT_ITM_LCK_IND, 
RTN_SPLST_EML_ADDR,  
LS_AGRMNT_ITM_STTS_CD, 
LS_AGRMNT_ITM_TRMN_RSN_CD,       
LS_AGRMNT_ITM_TRMN_RSN_DN,  
LS_AGRMNT_ITM_TRMN_TS,  
LS_AGRMNT_ITM_TRMN_PRS_TS,   
LS_AGRMNT_ITM_QT_ITM_NR,  
TRMN_SPLST_EML_ADDR,    
LS_AGRMNT_ADV_IND,         
WRLD_RGN_NM,      
PRNT_ENTRS_LGL_ENT_NR,   
LS_AGRMNT_STTS_CD,  
PYRAMID_CO_ID,   
END_USR_PHX_CLI_ID,  
SRVC_LED_IN,   
PROD_TNGBL_FLTR_DCSN_IND,   
PROD_INF_LVL_TYP_CD, 
PROD_ASST_MGMT_HRCHY_ROL_CD,       
SBL_GLOB_CSTMR_ID,   
EQPMNT_LCTN,
CTRY_CD,   
SLTN_GRP_NM,   
ASST_DN,   
TRM_MNTHS 
from FinalCTE

