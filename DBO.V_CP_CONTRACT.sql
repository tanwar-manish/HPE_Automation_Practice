-- ---------------------------------------------------------------------------------------------  
--  
-- PURPOSE: RETURN A LISTING OF CUSTOMER INFORMATION.  
--  
--    DATE        VERSION    WHO        CONTROL        COMMENT  
-- ----------    -------    -------    -----------    ----------------------------------------------------  
-- 15/02/2023       V1       RASHAMI                   INITIAL VERSION  
-- 15/02/2023       V1       MANOJ                     ADDED 'CSTMR_CD' LOGIC
-- 15/02/2023       V1       MANOJ                     ADDED 'PROJECT_BUS_UNIT' LOGIC
-- 27/02/2023       V1       MANOJ                     ADDED 'COMBINATIONID' LOGIC  
-- 28/12/2023       V1       MANOJ                     ADDED 'PYRAMIDONLY' COLUMN 
-- -----------------------------------------------------------------------------------------------
CREATE VIEW DBO.V_CP_CONTRACT
AS
SELECT
						CSTMR_CD
						,SRVC_PRVDR_PARTY_ID
						,CH_ID
						,CNTRCT_NO
						,CNTRCT_DESC
						,EOL_NOTICE_DAYS
						,WBS_NO
						,INV_FREQ_CD_FIRM
						,INV_FREQ_CD_EVERGREEN
						,INV_FREQ_CD
						,CNTRCT_DT
						,CNTRCT_MTRTY_DT
						,CNTRCT_BOOKED_DT
						,CNTRCT_STATUS_CD
						,TERM_MONTHS
						,REM_TERM_MONTHS
						,SUM_ORIG_EQUIP_COST
						,SUM_ASSET_CNT
						,SUM_TERMINATED_ASSET_CNT
						,SUM_RETURNED_ASSET_CNT
						,CUR_CD
						,CNTRY_CD
						,CONTRACT_FLAG
						,RETIRED_FLAG
						,AG_LEASE_CLASS
						,AG_LEASE_TYP
						,AVG_RENT_PER_PYMT_AMT
						,ADV_ARRS_CD
						,REM_TERM
						,REM_RENTAL
						,IS_METERING_CNTRCT
						,PURCHASE_OPTION
						,PROGRAM_CODE
						,BILLING_MODEL_CODE
						,SALES_PROGRAM_CODE
						,PROJECT_BUS_UNIT
						,PYRAMIDONLY
		FROM			DBO.REPORT_V_CP_CONTRACT (NOLOCK)