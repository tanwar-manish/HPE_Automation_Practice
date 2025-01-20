CREATE PROCEDURE DBO.LOAD_ACTUAL_CP_REPORTTABLES  
  ---ADD THE PARAMETERS FOR THE STORED PROCEDURE HERE   
@JOBINSTANCEID BIGINT = 1   

---------------- Modification Log ----------------------------------------------------------------------------------------------                                              
-- DATE            Release                   WHO        Comments                                                                                           
-- ---------    -------              ----------        ----------                                                                                   
-- 04/07/2023    V1.0                DH team (RM)    Initial Version of SP             
-- 27/12/2023    V2.0                DH team (MN)    Added New Logic for removing scrap assets from main table  
-- 28/12/2023    V3.0                DH team (MN)    Added PYRAMIDONLY COLUMN IN Contract table DBO.REPORT_V_CP_CONTRACT 
-- 11/01/2024    V4.0                DH team (MN)    Data load changes and product mapping changes. 
-- 29/01/2024    V5.0                DH team (MN)    Change in logic of picking terminated contracts from legacy database.  
-- 31/01/2024    V6.0                DH team (MN)    Change in Billing Frequency logic  
-- 06/03/2024    V7.0                DH team (MN)    Change in logic for excluding fully extended contracts      
-- 15/03/2024    V8.0                DH team (MN)    Implemented additional check of ISOVERTERMLEASE column for OTP billing frequency.
-- 26/05/2024    V9.0                DH team (MN)    Change in implemented after discussion with kalyani.   
-- 21/06/2024    V8.0                DH team (RS)    Issue#306 - Datatype sync for Assec_CD (DBO.REPORT_V_CP_CDF_ASSET) joins to DBO.REPORT_LEGECY_TERMINATED_ASSET table.
---------------- End Modification Log ------------------------------------------------------------------------------------------                                               
--------------------------------------------------------------------------------------------------------------------------------   	

AS  
BEGIN  
BEGIN TRY  
 DECLARE @RowsProcessed BIGINT = 0  
  IF OBJECT_ID(N'TEMPDB..#MERGEACTIONS')  IS NOT NULL  
  BEGIN  
   DROP TABLE #MERGEACTIONS  
  END  
  ---------------------------------------------Total Count------------------------  
DECLARE         @StartTime DATETIME = GETDATE(),   
                                                          @EndTime DATETIME = GETDATE(),   
                                                          @ReportLogId INT = 0  	
  
                                                         
                                                          DECLARE @NumRowsInserted BIGINT = 0  
                                                          DECLARE @NumRowsUpdated BIGINT = 0  
--------------------------------------LOAD REPORT_V_CSTMR--------- CREATING VIEWS AS A TABLE-------------------------

-----------------------------DECLARE LegacyRowsCount-----------------------------------------------------  
DECLARE @LegacyRowsCountCUST BIGINT = 0   
SELECT @LegacyRowsCountCUST=COUNT(1) FROM DBO.REPORT_V_CSTMR WHERE FEDERAL_ID = 'PYRAMID' 

------------------------------------LS_AGRMNT------------------------------------------
IF OBJECT_ID(N'TEMPDB..#LS_AGRMNT')  IS NOT NULL      
            BEGIN      
             DROP TABLE #LS_AGRMNT    
            END 

			SELECT  LA.LS_AGRMNT_ID,LA.LS_AGRMNT_TRMN_DT 
			INTO #LS_AGRMNT
			FROM DBO.LS_AGRMNT LA WITH(NOLOCK)
			WHERE DATEDIFF(MONTH, ISNULL(LA.LS_AGRMNT_TRMN_DT, CAST('2999-12-31' AS DATE)), GETDATE()) < 13 AND LS_AGRMNT_STTS_CD='TERMINATED'
			AND 0=@LegacyRowsCountCUST
--------------------------- Create index ---------------------------------------------------  
CREATE NONCLUSTERED INDEX [LS_AGRMNT_CUST_INDX_LS_AGRMNT_ID]  
ON #LS_AGRMNT (LS_AGRMNT_ID)
  
        PRINT 'LOAD REPORT_V_CSTMR'  
                             SET @StartTime = GETDATE()  
                             INSERT INTO [dbo].[REPORT_LOGS]  
                             (  
                                                          JobInstanaceId,  
                                                          ProcessName,  
                                                          StartTime,  
                                                          StatusTypeId  ,
	                                                      JobEntityId
                             )               
                             VALUES  
                             (  
                                                          @JOBINSTANCEID,  
                                                          'Sync DBO.REPORT_V_CSTMR',  
                                                          GETDATE(),  
                                                          0  ,
														  18
                             )  
  
                             SET  @ReportLogId = SCOPE_IDENTITY()  
                             BEGIN TRY  
  
    PRINT 'LOAD REPORT_V_CSTMR'  
    IF OBJECT_ID(N'TEMPDB..#REPORT_V_CSTMR')  IS NOT NULL  
    BEGIN  
     DROP TABLE #REPORT_V_CSTMR  
    END  
    SELECT CSTMR_ID,CSTMR_CD,CSTMR_NM,GEO_CD,CNTRY_CD,CITY,ADDR_ID,CNTRY_DESC,PARENT_CSTMR_ID,DIVISION_NM,PHX_CLIENT_ID,
    SIC_CODE,NAICS_CODE,DUNS_NUMBER,FEDERAL_ID,AMID2_NO,REGN_NUMBER,COLLECTOR_ID,COLLECTOR_DESC,REGION,REGION_DESC,PROCESS_SEGMENT_CD,
	PROCESS_SEGMENT_DESC,INV_REVIEW_IND,SERVICE_TAX_EXEMPT_IND,ACH_EXCLUDE_TERMINATED_IND,ASSET_EDGE_IND,ID_ADMIN_REASON,
	ADMIN_REASON,NBR_OF_DAYS_BEFORE_REFUNDING,INVOICE_COMMENT,LOCKBOX_ID,LOCKBOX_NBR,ID_FINANCE_COMPANY_NAME,FINANCE_COMPANY_NAME,
	USER_DEFINED_CREDIT_RATING,CREDIT_RATING_DESC,CREDIT_LINE,CREDIT_LINE_CURRENCY,CUR_CD,CREDIT_LINE_EXP_DATE,EXT_CREDIT_QUALITY_STEP,
	EXT_CREDIT_RATING_COMPANY,EXT_CREDIT_RATING,LEASING_BUSINESS_MODEL_NM,STATEMENT_GROUPING_CODE_PPT,STATEMENT_GROUPING_PPT_DESC,
	PPT_BILL_TO_ID,CRDT_RATING_DT,LASTREFRESHTIME,UID,CRC1
INTO   #REPORT_V_CSTMR
FROM  (
       SELECT         
          PARTIES.ID                                                                             AS CSTMR_ID,      
          PARTIES.PARTYNUMBER                                                                    AS CSTMR_CD,      
          PARTIES.PARTYNAME                                                                      AS CSTMR_NM,      
          REGIONS.NAME                                                                           AS GEO_CD,      
          COUNTRIES.SHORTNAME                                                                    AS CNTRY_CD,      
          PARTYADDRESSES.CITY                                                                    AS CITY,      
          PARTYADDRESSES.ID                                                                      AS ADDR_ID,      
          COUNTRIES.LONGNAME                                                                     AS CNTRY_DESC,      
          NULL                                                                                   AS PARENT_CSTMR_ID,      
          PARTYADDRESSES.DIVISION                                                                AS DIVISION_NM,      
          PARTIES.PARTYNUMBER                                                                    AS PHX_CLIENT_ID,      
          BUSINESSTYPESSICSCODES.NAME                                                            AS SIC_CODE,      
          PARTY.INTERNALINDUSTRYSEGMENTCODE                                                      AS NAICS_CODE,      
          PARTY.DUNSID                                                                           AS DUNS_NUMBER,      
          NULL                                                                                   AS FEDERAL_ID,      
          NULL                                                                                   AS AMID2_NO,      
          NULL                                                                                   AS REGN_NUMBER,      
          CASE WHEN COLLECTOR.NAME = 'COLLECTIONS'       
            THEN COLLECTOR.LOGINNAME        
            ELSE ''      
          END                                                                                    AS COLLECTOR_ID,      
          CASE WHEN COLLECTOR.NAME = 'COLLECTIONS'       
            THEN COLLECTOR.FULLNAME        
            ELSE ''      
          END                                                                                    AS COLLECTOR_DESC,      
          COUNTRIES.SHORTNAME                                                                    AS REGION,      
          COUNTRIES.SHORTNAME                                                                    AS REGION_DESC,      
          NULL                                                                                   AS PROCESS_SEGMENT_CD,      
          NULL                                                                                   AS PROCESS_SEGMENT_DESC,      
          CASE WHEN TEMPRECEIVABLES.INVOICEPREFERENCE ='GENERATEANDDELIVER' THEN 'N'       
            ELSE 'Y'       
          END                                                                                    AS INV_REVIEW_IND,      
          NULL                                                                                   AS SERVICE_TAX_EXEMPT_IND,      
          NULL                                                                                   AS ACH_EXCLUDE_TERMINATED_IND,      
          NULL                                                                                   AS ASSET_EDGE_IND,      
          NULL                                                                                   AS ID_ADMIN_REASON,      
          NULL                                                                                   AS ADMIN_REASON,      
          NULL                                                                                   AS NBR_OF_DAYS_BEFORE_REFUNDING,      
          NULL                                                                                   AS INVOICE_COMMENT,      
          NULL                                                                                   AS LOCKBOX_ID,      
          NULL                                                                                   AS LOCKBOX_NBR,      
          PARTYADDRESSES.PARTYID                                                                 AS ID_FINANCE_COMPANY_NAME,      
          NULL                                                                                   AS FINANCE_COMPANY_NAME,      
          CUSTOMERS.CUSTOMERRISKRATING                                                           AS USER_DEFINED_CREDIT_RATING,      
          TEMPCREDITRISKGRADES.CUSTOMERRISKRATINGDESC                                            AS CREDIT_RATING_DESC,      
          TEMPCREDITDECISIONS.APPROVEDAMOUNT_AMOUNT                                              AS CREDIT_LINE,      
          TEMPCREDITDECISIONS.APPROVEDAMOUNT_CURRENCY                                            AS CREDIT_LINE_CURRENCY,      
          TEMPLEASEFINANCES.CURRENCIESNAME                                                       AS CUR_CD,      
          TEMPCREDITDECISIONS.EXPIRYDATE                                                         AS CREDIT_LINE_EXP_DATE,      
          TEMPCREDITRISKGRADES.CREDITRISKGRADEDESC                                               AS EXT_CREDIT_QUALITY_STEP,      
          TEMPCREDITRISKGRADE.RATINGMODEL                                                        AS EXT_CREDIT_RATING_COMPANY,      
          TEMPCREDITRISKGRADE.CODE                                                               AS EXT_CREDIT_RATING,      
          TEMPLEASEFINANCES.CSTNAME                                                              AS LEASING_BUSINESS_MODEL_NM,      
          NULL                                                                                   AS STATEMENT_GROUPING_CODE_PPT,      
          TEMPRECEIVABLES.NAME                                                                   AS STATEMENT_GROUPING_PPT_DESC,      
          NULL                                                                                   AS PPT_BILL_TO_ID,      
          TEMPCREDITRISKGRADE.ENTRYDATE                                                          AS CRDT_RATING_DT ,
          GETDATE()                                                                              AS LASTREFRESHTIME,
          CONCAT(PARTIES.PARTYNUMBER,'_')		                                                 AS UID,
		  HASHBYTES('MD5', CONCAT (PARTIES.ID,PARTIES.PARTYNUMBER,PARTIES.PARTYNAME,REGIONS.NAME,COUNTRIES.SHORTNAME,
		  PARTYADDRESSES.CITY,PARTYADDRESSES.ID,COUNTRIES.LONGNAME,PARTYADDRESSES.DIVISION,PARTIES.PARTYNUMBER,BUSINESSTYPESSICSCODES.NAME,
		  PARTY.INTERNALINDUSTRYSEGMENTCODE,PARTY.DUNSID,COLLECTOR.NAME,COLLECTOR.FULLNAME,COUNTRIES.SHORTNAME,TEMPRECEIVABLES.INVOICEPREFERENCE,
		  PARTYADDRESSES.PARTYID,CUSTOMERS.CUSTOMERRISKRATING,TEMPCREDITRISKGRADES.CUSTOMERRISKRATINGDESC,TEMPCREDITDECISIONS.APPROVEDAMOUNT_AMOUNT,
		  TEMPCREDITDECISIONS.APPROVEDAMOUNT_CURRENCY,TEMPLEASEFINANCES.CURRENCIESNAME,TEMPCREDITDECISIONS.EXPIRYDATE,TEMPCREDITRISKGRADES.CREDITRISKGRADEDESC,TEMPCREDITRISKGRADE.RATINGMODEL,TEMPCREDITRISKGRADE.CODE,TEMPLEASEFINANCES.CSTNAME,TEMPRECEIVABLES.NAME,TEMPCREDITRISKGRADE.ENTRYDATE))                                                       AS CRC1
  
        FROM          DATAHUB_ODESSA.ODH.PARTIES_REALTIME PARTIES WITH (NOLOCK)  
        INNER JOIN    DATAHUB_ODESSA.ODH.CUSTOMERS_REALTIME CUSTOMERS WITH (NOLOCK) ON CUSTOMERS.ID = PARTIES.ID  
        LEFT JOIN    (SELECT CURRENCIESNAME,CSTNAME,CUSTOMERID  
                      FROM (SELECT                      CURRENCIES.NAME       AS CURRENCIESNAME,      
                                                        CST.NAME              AS  CSTNAME,      
                                                        LF.CUSTOMERID         AS CUSTOMERID,  
                                                        ROW_NUMBER() OVER(PARTITION BY LF.CUSTOMERID ORDER BY LF.CUSTOMERID DESC) AS ROWID   
                             FROM               DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME(NOLOCK) LF   
                             INNER JOIN         DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CONTRACTS WITH(NOLOCK) ON CONTRACTS.ID  = LF.CONTRACTID AND LF.ISCURRENT = 1          
                             INNER JOIN         DATAHUB_ODESSA.ODH.CONTRACTORIGINATIONS_REALTIME(NOLOCK) CO ON LF.CONTRACTORIGINATIONID = CO.ID AND LF.ISCURRENT = 1   
                             INNER JOIN         DATAHUB_ODESSA.ODH.CURRENCIES_REALTIME CURRENCIES WITH (NOLOCK) ON CURRENCIES.ID = CONTRACTS.CURRENCYID      
                             /*SERVICE PROVIDER DETAILS*/  
                             INNER JOIN         DATAHUB_ODESSA.ODH.ORIGINATIONSOURCETYPES_REALTIME(NOLOCK) CST ON CO.ORIGINATIONSOURCETYPEID = CST.ID 
                             WHERE LF.BookingStatus in ('Commenced','FullyPaidOff')				
                             GROUP BY           CURRENCIES.NAME,      
                                                CST.NAME,        
                                                LF.CUSTOMERID ) TEMPLEASEFINANCE  
                      WHERE TEMPLEASEFINANCE.ROWID = 1  
                     )TEMPLEASEFINANCES  ON TEMPLEASEFINANCES.CUSTOMERID = CUSTOMERS.ID  
        LEFT JOIN    DATAHUB_ODESSA.ODH.PARTYADDRESSES_REALTIME PARTYADDRESSES WITH (NOLOCK) ON PARTYADDRESSES.PARTYID = PARTIES.ID AND PARTYADDRESSES.ISMAIN = 1  
        LEFT JOIN    DATAHUB_ODESSA.ODH.STATES_REALTIME STATES WITH (NOLOCK) ON PARTYADDRESSES.STATEID = STATES.ID AND STATES.ISACTIVE = 1  
        LEFT JOIN    DATAHUB_ODESSA.ODH.COUNTRIES_REALTIME COUNTRIES WITH (NOLOCK) ON STATES.COUNTRYID = COUNTRIES.ID AND COUNTRIES.ISACTIVE = 1  
        LEFT JOIN    DATAHUB_ODESSA.ODH.REGIONS_REALTIME REGIONS WITH (NOLOCK) ON COUNTRIES.REGIONID = REGIONS.ID AND REGIONS.ISACTIVE = 1    
        
		LEFT JOIN     (SELECT        ROLEFUNCTIONS.NAME,EMPLOYEESASSIGNEDTOPARTIES.PARTYID,USERS.LOGINNAME,USERS.FULLNAME 
		                             ,ROW_NUMBER() OVER(PARTITION BY EMPLOYEESASSIGNEDTOPARTIES.ROLEFUNCTIONID ORDER BY EMPLOYEESASSIGNEDTOPARTIES.CREATEDTIME DESC) ROWNUM
                       FROM          DATAHUB_ODESSA.ODH.ROLEFUNCTIONS_REALTIME ROLEFUNCTIONS WITH(NOLOCK)  
                       INNER JOIN    DATAHUB_ODESSA.ODH.EMPLOYEESASSIGNEDTOPARTIES_REALTIME EMPLOYEESASSIGNEDTOPARTIES WITH (NOLOCK)   
                       ON EMPLOYEESASSIGNEDTOPARTIES.ROLEFUNCTIONID = ROLEFUNCTIONS.ID  
                       LEFT JOIN     DATAHUB_ODESSA.ODH.USERS_REALTIME USERS WITH (NOLOCK) ON USERS.ID = EMPLOYEESASSIGNEDTOPARTIES.EMPLOYEEID
                       WHERE ROLEFUNCTIONS.ID in(3)					   
                       ) COLLECTOR  
                       ON            COLLECTOR.PARTYID = PARTIES.ID AND ROWNUM = 1
                        					   
        
        LEFT JOIN     (SELECT RATINGMODEL,CODE,ENTRYDATE,CUSTOMERID FROM     
                                  (SELECT          CREDITRISKGRADES.CODE,CREDITRISKGRADES.ENTRYDATE,CREDITRISKGRADES.CUSTOMERID,RATINGMODELCONFIGS.RATINGMODEL,      
                                   ROW_NUMBER() OVER(PARTITION BY CREDITRISKGRADES.CUSTOMERID ORDER BY CREDITRISKGRADES.ID DESC) AS ROWID      
                                   FROM            DATAHUB_ODESSA.ODH.CREDITRISKGRADES_REALTIME CREDITRISKGRADES WITH (NOLOCK)       
                                   INNER JOIN      DATAHUB_ODESSA.ODH.RATINGMODELCONFIGS_REALTIME RATINGMODELCONFIGS WITH (NOLOCK) ON RATINGMODELCONFIGS.ID = CREDITRISKGRADES.RATINGMODELID       
                                   AND             RATINGMODELCONFIGS.RATINGMODEL ='HPEFS'  AND CREDITRISKGRADES.ISACTIVE = 1      
                                   )               TPCREDITRISKGRADE   
                        WHERE            TPCREDITRISKGRADE.ROWID = 1  )TEMPCREDITRISKGRADE     
          ON            TEMPCREDITRISKGRADE.CUSTOMERID = CUSTOMERS.ID       
        
		LEFT JOIN      (SELECT APPROVEDAMOUNT_AMOUNT,APPROVEDAMOUNT_CURRENCY,EXPIRYDATE,CUSTOMERID FROM     
                        (SELECT            CREDITDECISIONS.APPROVEDAMOUNT_AMOUNT,CREDITDECISIONS.EXPIRYDATE,APPROVEDAMOUNT_CURRENCY,CREDITPROFILES.CUSTOMERID,      
                        ROW_NUMBER() OVER (PARTITION BY CREDITPROFILES.CUSTOMERID ORDER BY CREDITDECISIONS.ID DESC) AS ROWID      
                         FROM              DATAHUB_ODESSA.ODH.CREDITDECISIONS_REALTIME CREDITDECISIONS WITH (NOLOCK)      
                         INNER JOIN        DATAHUB_ODESSA.ODH.CREDITPROFILES_REALTIME CREDITPROFILES WITH (NOLOCK) ON CREDITPROFILES.ID = CREDITDECISIONS.CREDITPROFILEID       
                         WHERE             CREDITDECISIONS.ISACTIVE = 1 AND CREDITPROFILES.ISPREAPPROVAL = 1) TPCREDITDECISIONS   
                            WHERE             TPCREDITDECISIONS.ROWID = 1 ) TEMPCREDITDECISIONS    
                         ON                TEMPCREDITDECISIONS.CUSTOMERID = CUSTOMERS.ID
						 
        LEFT JOIN      DATAHUB_ODESSA.ODH.BUSINESSTYPESSICSCODES_REALTIME BUSINESSTYPESSICSCODES WITH (NOLOCK) ON BUSINESSTYPESSICSCODES.ID = CUSTOMERS.BUSINESSTYPESSICSCODEID AND BUSINESSTYPESSICSCODES.ISACTIVE = 1       
        LEFT JOIN     (SELECT RECEIVABLEINVOICES.CUSTOMERID,RECEIVABLECODES.NAME,RECEIVABLEINVOICES.INVOICEPREFERENCE      
                FROM      
                 (      
                   SELECT RIV.CUSTOMERID,RIV.INVOICEPREFERENCE FROM       
                   (      
                   SELECT           MAX(RECEIVABLEINVOICES.ID) AS ID,RECEIVABLEINVOICES.CUSTOMERID      
                                                
                   FROM             DATAHUB_ODESSA.ODH.RECEIVABLEINVOICES_REALTIME RECEIVABLEINVOICES WITH(NOLOCK)       
                   GROUP BY         RECEIVABLEINVOICES.CUSTOMERID      
                   )RECEIVABLEINVOICES      
                   INNER JOIN       DATAHUB_ODESSA.ODH.RECEIVABLEINVOICES_REALTIME RIV WITH(NOLOCK) ON RIV.ID=RECEIVABLEINVOICES.ID AND RIV.CUSTOMERID=RECEIVABLEINVOICES.CUSTOMERID      
                 )RECEIVABLEINVOICES      
                 INNER JOIN      
                 (      
                   SELECT RECEIVABLES.CUSTOMERID,RECEIVABLECODES.NAME      
                   FROM      
                   (      
                   SELECT            MAX(RECEIVABLES.ID) AS ID,RECEIVABLES.CUSTOMERID      
                   FROM             DATAHUB_ODESSA.ODH.RECEIVABLES_REALTIME RECEIVABLES WITH(NOLOCK)       
                   GROUP BY         RECEIVABLES.CUSTOMERID      
                   )TEMP_RECEIVABLES      
                   INNER JOIN       DATAHUB_ODESSA.ODH.RECEIVABLES_REALTIME RECEIVABLES WITH(NOLOCK) ON RECEIVABLES.ID=TEMP_RECEIVABLES.ID      
                   INNER JOIN       DATAHUB_ODESSA.ODH.RECEIVABLECODES_REALTIME RECEIVABLECODES WITH(NOLOCK) ON RECEIVABLECODES.ID = RECEIVABLES.RECEIVABLECODEID      
                 )RECEIVABLECODES ON RECEIVABLEINVOICES.CUSTOMERID=RECEIVABLECODES.CUSTOMERID      
               ) TEMPRECEIVABLES ON TEMPRECEIVABLES.CUSTOMERID = CUSTOMERS.ID  
			   
        LEFT JOIN      PARTY.PARTY PARTY WITH (NOLOCK) ON  PARTY.EMDMPARTYID = PARTIES.PARTYNUMBER      
        LEFT JOIN     (SELECT      CUSTOMERRISKRATING.DESCRIPTION AS CUSTOMERRISKRATINGDESC,      
                                   CREDITRISKGRADE.DESCRIPTION AS CREDITRISKGRADEDESC,      
                                   CREDITRISKGRADE.CODE      
                       FROM        DBO.CUSTOMERRISKRATINGS CUSTOMERRISKRATING WITH (NOLOCK)       
                       INNER JOIN  DBO.CREDITRISKGRADES CREDITRISKGRADE WITH (NOLOCK) ON CREDITRISKGRADE.CODE = CUSTOMERRISKRATING.CODE      
                       GROUP BY    CUSTOMERRISKRATING.DESCRIPTION,CREDITRISKGRADE.DESCRIPTION,CREDITRISKGRADE.CODE) TEMPCREDITRISKGRADES      
                       ON          TEMPCREDITRISKGRADES.CODE = TEMPCREDITRISKGRADE.CODE

UNION ALL


SELECT DISTINCT
             PARTY.party_isn                                              AS CSTMR_ID,
             PARTY.emdmPartyID                                            AS CSTMR_CD,
             PARTY.PARTYNAME                                              AS CSTMR_NM,
             WRLD_RGN.WRLD_RGN_NM                                         AS GEO_CD ,
             CTRY.ISOCountryCode                                          AS CNTRY_CD,
             NULL                                                         AS CITY,
             NULL                                                         AS ADDR_ID,
             CTRY.NM                                                      AS CNTRY_DESC,
             NULL                                                         AS PARENT_CSTMR_ID,
             NULL                                                         AS DIVISION_NM,
             XREF_BUS_EXTNSN.PHX_CLI_ID                                   AS PHX_CLIENT_ID,
             NULL                                                         AS SIC_CODE,
             NULL                                                         AS NAICS_CODE, 
             PARTY.DUNSID                                                 AS DUNS_NUMBER,
             'PYRAMID'                                                    AS FEDERAL_ID, 
             NULL                                                         AS AMID2_NO,   
             NULL                                                         AS REGN_NUMBER,
             NULL                                                         AS COLLECTOR_ID,
             NULL                                                         AS COLLECTOR_DESC,      
             NULL                                                         AS REGION,      
             NULL                                                         AS REGION_DESC,      
             NULL                                                         AS PROCESS_SEGMENT_CD,  
             NULL                                                         AS PROCESS_SEGMENT_DESC,
             'N'                                                          AS INV_REVIEW_IND,      
             NULL                                                         AS SERVICE_TAX_EXEMPT_IND,      
             NULL                                                         AS ACH_EXCLUDE_TERMINATED_IND,      
             NULL                                                         AS ASSET_EDGE_IND,      
             NULL                                                         AS ID_ADMIN_REASON,      
             NULL                                                         AS ADMIN_REASON,      
             NULL                                                         AS NBR_OF_DAYS_BEFORE_REFUNDING,      
             NULL                                                         AS INVOICE_COMMENT,      
             NULL                                                         AS LOCKBOX_ID,      
             NULL                                                         AS LOCKBOX_NBR,      
             NULL                                                         AS ID_FINANCE_COMPANY_NAME,      
             NULL                                                         AS FINANCE_COMPANY_NAME,      
             NULL                                                         AS USER_DEFINED_CREDIT_RATING,      
             NULL                                                         AS CREDIT_RATING_DESC,      
             NULL                                                         AS CREDIT_LINE,      
             NULL                                                         AS CREDIT_LINE_CURRENCY,      
             P.CURR_CD                                                    AS CUR_CD,      
             NULL                                                         AS CREDIT_LINE_EXP_DATE,      
             NULL                                                         AS EXT_CREDIT_QUALITY_STEP,      
             NULL                                                         AS EXT_CREDIT_RATING_COMPANY,      
             NULL                                                         AS EXT_CREDIT_RATING,      
             NULL                                                         AS LEASING_BUSINESS_MODEL_NM,      
             NULL                                                         AS STATEMENT_GROUPING_CODE_PPT,      
             NULL                                                         AS STATEMENT_GROUPING_PPT_DESC,      
             NULL                                                         AS PPT_BILL_TO_ID,      
             NULL                                                         AS CRDT_RATING_DT ,
             GETDATE()                                                    AS LASTREFRESHTIME,
             CONCAT(PARTY.emdmPartyID,'_')                                AS UID,	
             HASHBYTES('MD5', CONCAT (PARTY.party_isn,PARTY.emdmPartyID,PARTY.PARTYNAME,WRLD_RGN.WRLD_RGN_NM,CTRY.ISOCountryCode
             ,CTRY.NM,XREF_BUS_EXTNSN.PHX_CLI_ID,PARTY.DUNSID,P.CURR_CD)) AS CRC1
FROM                          DBO.LS_AGRMNT LA  WITH(NOLOCK)
			INNER JOIN        #LS_AGRMNT LS WITH(NOLOCK) ON LA.LS_AGRMNT_ID =LS.LS_AGRMNT_ID
			INNER JOIN        DBO.XREF_BUS_EXTNSN XREF_BUS_EXTNSN WITH(NOLOCK) ON XREF_BUS_EXTNSN.XREF_BUS_EXTNSN_ID=LA.XREF_BUS_EXTNSN_ID
			INNER JOIN        party.party PARTY WITH(NOLOCK) ON PARTY.emdmPartyID = ISNULL(XREF_BUS_EXTNSN.SBL_GLOB_CSTMR_ID,XREF_BUS_EXTNSN.ORIG_MDCP_ORG_ID)
			INNER JOIN        DBO.LS_PTFL P WITH(NOLOCK) ON LA.LS_PTFL_ID = P.LS_PTFL_ID 
			INNER JOIN        DBO.CTRY CTRY WITH(NOLOCK) ON CTRY.CTRY_CD = P.CTRY_CD AND MIGRATEDFLAG='Y' 
			INNER JOIN        DBO.WRLD_RGN_ITM WR_ITM WITH (NOLOCK) ON WR_ITM.ctry_cd = CTRY.ctry_cd 
            INNER JOIN        DBO.WRLD_RGN WRLD_RGN WITH (NOLOCK) ON WR_ITM.WRLD_RGN_ID = WRLD_RGN.WRLD_RGN_ID
			LEFT JOIN         DATAHUB_ODESSA.ODH.PARTIES_REALTIME PARTIES WITH(NOLOCK) ON PARTIES.PARTYNUMBER = PARTY.emdmPartyID
			WHERE      
							  PARTIES.PARTYNUMBER IS NULL AND 0=@LegacyRowsCountCUST) CSTMRS 
  
      --------------DUPLICATE DELETE---------------------------------
	   IF OBJECT_ID(N'TEMPDB..#V_CSTMR')  IS NOT NULL  
        BEGIN  
           DROP TABLE #V_CSTMR 
        END  
 		SELECT * INTO #V_CSTMR FROM 
		(SELECT   
          ROW_NUMBER() OVER (PARTITION BY UID ORDER BY LASTREFRESHTIME DESC) AS RID
          ,CSTMR_ID  
          ,CSTMR_CD  
          ,CSTMR_NM  
          ,GEO_CD  
          ,CNTRY_CD  
          ,CITY  
          ,ADDR_ID  
          ,CNTRY_DESC  
          ,PARENT_CSTMR_ID  
          ,DIVISION_NM  
          ,PHX_CLIENT_ID  
          ,SIC_CODE  
          ,NAICS_CODE  
          ,DUNS_NUMBER  
          ,FEDERAL_ID  
          ,AMID2_NO  
          ,REGN_NUMBER  
          ,COLLECTOR_ID  
          ,COLLECTOR_DESC  
          ,REGION  
          ,REGION_DESC  
          ,PROCESS_SEGMENT_CD  
          ,PROCESS_SEGMENT_DESC  
          ,INV_REVIEW_IND  
          ,SERVICE_TAX_EXEMPT_IND  
          ,ACH_EXCLUDE_TERMINATED_IND  
          ,ASSET_EDGE_IND  
          ,ID_ADMIN_REASON  
          ,ADMIN_REASON  
          ,NBR_OF_DAYS_BEFORE_REFUNDING  
          ,INVOICE_COMMENT  
          ,LOCKBOX_ID  
          ,LOCKBOX_NBR  
          ,ID_FINANCE_COMPANY_NAME  
          ,FINANCE_COMPANY_NAME  
          ,USER_DEFINED_CREDIT_RATING  
          ,CREDIT_RATING_DESC  
          ,CREDIT_LINE  
          ,CREDIT_LINE_CURRENCY  
          ,CUR_CD  
          ,CREDIT_LINE_EXP_DATE  
          ,EXT_CREDIT_QUALITY_STEP  
          ,EXT_CREDIT_RATING_COMPANY  
          ,EXT_CREDIT_RATING  
          ,LEASING_BUSINESS_MODEL_NM  
          ,STATEMENT_GROUPING_CODE_PPT  
          ,STATEMENT_GROUPING_PPT_DESC  
          ,PPT_BILL_TO_ID  
          ,CRDT_RATING_DT 
          ,LASTREFRESHTIME
          ,UID
          ,CRC1
      FROM  #REPORT_V_CSTMR) CSTMR
	  WHERE RID = 1
	  
	  CREATE CLUSTERED INDEX [REPORT_V_CSTMR_ASSET_INDX1_UID]  
					ON #V_CSTMR ([UID])  
	   
	      DELETE FROM     #V_CSTMR  WHERE UID IN (SELECT SUMRY.UID FROM DBO.REPORT_V_CSTMR SUMRY
                                                          INNER JOIN #V_CSTMR IDS WITH(NOLOCK) 
														  ON SUMRY.UID = IDS.UID AND SUMRY.CRC = IDS.CRC1) 
	 ---DELETING THE UID FROM MAIN TABLE-----------------
	 DELETE FROM DBO.REPORT_V_CSTMR  WHERE UID IN (SELECT UID FROM  #V_CSTMR)  
	  
	    IF  EXISTS (SELECT UID FROM  #V_CSTMR) 
 
      INSERT INTO  DBO.REPORT_V_CSTMR  
      (  
           CSTMR_ID  
          ,CSTMR_CD  
          ,CSTMR_NM  
          ,GEO_CD  
          ,CNTRY_CD  
          ,CITY  
          ,ADDR_ID  
          ,CNTRY_DESC  
          ,PARENT_CSTMR_ID  
          ,DIVISION_NM  
          ,PHX_CLIENT_ID  
          ,SIC_CODE  
          ,NAICS_CODE  
          ,DUNS_NUMBER  
          ,FEDERAL_ID  
          ,AMID2_NO  
          ,REGN_NUMBER  
          ,COLLECTOR_ID  
          ,COLLECTOR_DESC  
          ,REGION  
          ,REGION_DESC  
          ,PROCESS_SEGMENT_CD  
          ,PROCESS_SEGMENT_DESC  
          ,INV_REVIEW_IND  
          ,SERVICE_TAX_EXEMPT_IND  
          ,ACH_EXCLUDE_TERMINATED_IND  
          ,ASSET_EDGE_IND  
          ,ID_ADMIN_REASON  
          ,ADMIN_REASON  
          ,NBR_OF_DAYS_BEFORE_REFUNDING  
          ,INVOICE_COMMENT  
          ,LOCKBOX_ID  
          ,LOCKBOX_NBR  
          ,ID_FINANCE_COMPANY_NAME  
          ,FINANCE_COMPANY_NAME  
          ,USER_DEFINED_CREDIT_RATING  
          ,CREDIT_RATING_DESC  
          ,CREDIT_LINE  
          ,CREDIT_LINE_CURRENCY  
          ,CUR_CD  
          ,CREDIT_LINE_EXP_DATE  
          ,EXT_CREDIT_QUALITY_STEP  
          ,EXT_CREDIT_RATING_COMPANY  
          ,EXT_CREDIT_RATING  
          ,LEASING_BUSINESS_MODEL_NM  
          ,STATEMENT_GROUPING_CODE_PPT  
          ,STATEMENT_GROUPING_PPT_DESC  
          ,PPT_BILL_TO_ID  
          ,CRDT_RATING_DT 
          ,LASTREFRESHTIME	
          ,UID
          ,CRC
          ,InsertedByJobEntityInstanceId
		  ,UpdatedByJobEntityInstanceId		  
      )  
      SELECT   
           CSTMR_ID  
          ,CSTMR_CD  
          ,CSTMR_NM  
          ,GEO_CD  
          ,CNTRY_CD  
          ,CITY  
          ,ADDR_ID  
          ,CNTRY_DESC  
          ,PARENT_CSTMR_ID  
          ,DIVISION_NM  
          ,PHX_CLIENT_ID  
          ,SIC_CODE  
          ,NAICS_CODE  
          ,DUNS_NUMBER  
          ,FEDERAL_ID  
          ,AMID2_NO  
          ,REGN_NUMBER  
          ,COLLECTOR_ID  
          ,COLLECTOR_DESC  
          ,REGION  
          ,REGION_DESC  
          ,PROCESS_SEGMENT_CD  
          ,PROCESS_SEGMENT_DESC  
          ,INV_REVIEW_IND  
          ,SERVICE_TAX_EXEMPT_IND  
          ,ACH_EXCLUDE_TERMINATED_IND  
          ,ASSET_EDGE_IND  
          ,ID_ADMIN_REASON  
          ,ADMIN_REASON  
          ,NBR_OF_DAYS_BEFORE_REFUNDING  
          ,INVOICE_COMMENT  
          ,LOCKBOX_ID  
          ,LOCKBOX_NBR  
          ,ID_FINANCE_COMPANY_NAME  
          ,FINANCE_COMPANY_NAME  
          ,USER_DEFINED_CREDIT_RATING  
          ,CREDIT_RATING_DESC  
          ,CREDIT_LINE  
          ,CREDIT_LINE_CURRENCY  
          ,CUR_CD  
          ,CREDIT_LINE_EXP_DATE  
          ,EXT_CREDIT_QUALITY_STEP  
          ,EXT_CREDIT_RATING_COMPANY  
          ,EXT_CREDIT_RATING  
          ,LEASING_BUSINESS_MODEL_NM  
          ,STATEMENT_GROUPING_CODE_PPT  
          ,STATEMENT_GROUPING_PPT_DESC  
          ,PPT_BILL_TO_ID  
          ,CRDT_RATING_DT
          ,LASTREFRESHTIME
          ,UID 
          ,CRC1
          ,1
          ,1		  
       FROM   #V_CSTMR  
  
       SET @RowsProcessed = @RowsProcessed+ ISNULL((SELECT COUNT(*) FROM #V_CSTMR),0)  
  
       SET @NumRowsInserted = ISNULL((SELECT COUNT(*) FROM #V_CSTMR),0)  
  
                                                          UPDATE           [dbo].[REPORT_LOGS]  
                                                          SET                         EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = @NumRowsInserted,  
                                                                                      RowsUpdated = @NumRowsUpdated,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = 1  
                                                          WHERE ReportLogId = @ReportLogId  
                             END TRY  
                             BEGIN CATCH  
                                                          SET @RowsProcessed = 0  
                                                          IF OBJECT_ID(N'TEMPDB..#V_CSTMR')  IS NOT NULL  
                                                          BEGIN  
                                                                                      SET @RowsProcessed = ISNULL((SELECT COUNT(*) FROM #V_CSTMR),0)  
                                                          END  
  
                                                          UPDATE             [dbo].[REPORT_LOGS]  
                                                          SET                         EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = 0,  
                                                                                      RowsUpdated = 0,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = -1,  
                                                                                      IsError = 1,  
                                                                                      ErrorMessage =  ERROR_MESSAGE()   
                                                          WHERE ReportLogId = @ReportLogId  
                             END CATCH  
  
          ---------------------------------------------------------LOAD REPORT_V_CP_CONTRACT----------------------------------------------------  
IF OBJECT_ID(N'TEMPDB..#LOADTIME')  IS NOT NULL  
BEGIN  
  DROP TABLE #LOADTIME
 END 
SELECT DISTINCT LASTREFRESHTIME INTO #LOADTIME FROM DBO.REPORT_V_CP_CONTRACT (NOLOCK) WHERE LASTREFRESHTIME>=GETDATE()-5

DECLARE @PICKUP_DATE DATETIME

SELECT @PICKUP_DATE=ISNULL(MAX(LASTREFRESHTIME),'01/01/1910')-2 FROM #LOADTIME (NOLOCK)
-------------------#ACTUAL_LOAD-----------------------------------------------------------
 IF OBJECT_ID(N'TEMPDB..#ACTUAL_LOAD')  IS NOT NULL  
BEGIN  
  DROP TABLE #ACTUAL_LOAD
 END 
SELECT        DISTINCT   CONTRACTS.ID AS CONTRACTID
INTO          #ACTUAL_LOAD  
FROM          DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CONTRACTS WITH (NOLOCK)
INNER JOIN    DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LEASEFINANCES WITH (NOLOCK) ON LEASEFINANCES.CONTRACTID = CONTRACTS.ID AND ISCURRENT=1
INNER JOIN    DATAHUB_ODESSA.ODH.LEASEFINANCEDETAILS_REALTIME LEASEFINANCEDETAIL_REALTIME WITH (NOLOCK) ON LEASEFINANCEDETAIL_REALTIME.ID = LEASEFINANCES.ID
INNER JOIN    DATAHUB_ODESSA.ODH.PARTYADDRESSES_REALTIME PARTYADDRESSES WITH (NOLOCK) ON PARTYADDRESSES.PARTYID =  LEASEFINANCES.CUSTOMERID AND PARTYADDRESSES.ISMAIN = 1           
INNER JOIN    DATAHUB_ODESSA.ODH.STATES_REALTIME STATES WITH (NOLOCK) ON STATES.ID = PARTYADDRESSES.STATEID
WHERE 
CONVERT(DATETIME,(SELECT MAX(T.UPDATEDTIME)  FROM (    
VALUES ( ISNULL(CONTRACTS.LASTREFRESHTIME,CONTRACTS.UPDATEDTIME)),   
( ISNULL(CONTRACTS.UPDATEDTIME,CONTRACTS.CREATEDTIME)), 
( ISNULL(LEASEFINANCES.LASTREFRESHTIME,LEASEFINANCES.UPDATEDTIME)),
( ISNULL(LEASEFINANCES.UPDATEDTIME,LEASEFINANCES.CREATEDTIME)), 
( ISNULL(LEASEFINANCEDETAIL_REALTIME.LASTREFRESHTIME,LEASEFINANCEDETAIL_REALTIME.UPDATEDTIME)),
( ISNULL(LEASEFINANCEDETAIL_REALTIME.UPDATEDTIME,LEASEFINANCEDETAIL_REALTIME.CREATEDTIME)), 
( ISNULL(PARTYADDRESSES.LASTREFRESHTIME,PARTYADDRESSES.UPDATEDTIME)),  
( ISNULL(PARTYADDRESSES.UPDATEDTIME,PARTYADDRESSES.CREATEDTIME)),    
( ISNULL(STATES.LASTREFRESHTIME,STATES.UPDATEDTIME)),  
( ISNULL(STATES.UPDATEDTIME,STATES.CREATEDTIME))) AS T( UPDATEDTIME ))) > @PICKUP_DATE

------------------------------LEASEFINANCES_REALTIME-------------------------------------  
  
IF OBJECT_ID(N'TEMPDB..#LEASEFINANCES_REALTIME')  IS NOT NULL    
        BEGIN    
           DROP TABLE #LEASEFINANCES_REALTIME   
        END   
SELECT LF.PROJECTNAME,LF.CUSTOMERID,LF.CONTRACTID,LF.LEGALENTITYID,LF.CONTRACTORIGINATIONID,LF.SERVICELEDBUSINESSUNITID,LF.ISCURRENT,LF.BOOKINGSTATUS,  
       LF.ID,LF.WBSNUMBERCONFIGID,LF.PROGRAMORPROMOTIONID  
INTO #LEASEFINANCES_REALTIME    
FROM DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LF (NOLOCK)  
INNER JOIN #ACTUAL_LOAD CT (NOLOCK) ON CT.CONTRACTID = LF.CONTRACTID  
WHERE LF.ISCURRENT = 1  
  
  
--------------------------- Create index ---------------------------------------------------  
CREATE NONCLUSTERED INDEX [LEASEFINANCES_REALTIME_INDX_ID]  
ON #LEASEFINANCES_REALTIME (ID)  
CREATE NONCLUSTERED INDEX [LEASEFINANCES_REALTIME_INDX_CONTRACTID]  
ON #LEASEFINANCES_REALTIME (CONTRACTID)  
CREATE NONCLUSTERED INDEX [LEASEFINANCES_REALTIME_INDX_CUSTOMERID]  
ON #LEASEFINANCES_REALTIME (CUSTOMERID)  
------------------------------LEASEFINANCEDETAILS_REALTIME-------------------------------------  
  
IF OBJECT_ID(N'TEMPDB..#LEASEFINANCEDETAILS_REALTIME')  IS NOT NULL    
        BEGIN    
           DROP TABLE #LEASEFINANCEDETAILS_REALTIME   
        END   
SELECT LFD.COMMENCEMENTDATE,LFD.ID,LFD.MATURITYDATE,LFD.OTPPAYMENTFREQUENCY,LFD.RENT_AMOUNT,LFD.TERMINMONTHS,LFD.OTPRENT_AMOUNT,LFD.PAYMENTFREQUENCY  
       ,LFD.ISADVANCE, LFD.FOLLOWUPLEADDAYS,LFD.LEASECONTRACTTYPE,LFD.ISOVERTERMLEASE  
INTO #LEASEFINANCEDETAILS_REALTIME    
FROM DATAHUB_ODESSA.ODH.LEASEFINANCEDETAILS_REALTIME LFD (NOLOCK)  
INNER JOIN #LEASEFINANCES_REALTIME LF (NOLOCK) ON LF.ID = LFD.ID  
  
--------------------------- Create index ---------------------------------------------------  
CREATE NONCLUSTERED INDEX [LEASEFINANCEDETAILS_REALTIME_INDX_ID]  
ON #LEASEFINANCEDETAILS_REALTIME ([ID])  
  
------------------------------CONTRACTS-------------------------------------  
  
IF OBJECT_ID(N'TEMPDB..#CONTRACTS_REALTIME')  IS NOT NULL    
        BEGIN    
           DROP TABLE #CONTRACTS_REALTIME  
        END   
SELECT DISTINCT C.CURRENCYID,C.ID,C.SEQUENCENUMBER,DL.NAME AS DEALTYPE,C.ALIAS,C.DEALTYPEID ,C.PRODUCTANDSERVICETYPECONFIGID,C.STATUS 
INTO #CONTRACTS_REALTIME    
FROM DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME C (NOLOCK)  
INNER JOIN #LEASEFINANCES_REALTIME LF (NOLOCK) ON LF.CONTRACTID = C.ID AND ISCURRENT=1
INNER JOIN DATAHUB_ODESSA.ODH.DEALTYPES_REALTIME DL(NOLOCK) ON DL.ID=C.DEALTYPEID 

  --------------------------- Create index ---------------------------------------------------  
CREATE NONCLUSTERED INDEX [CONTRACTS_INDX_ID]  
ON #CONTRACTS_REALTIME (ID)  
CREATE NONCLUSTERED INDEX [CONTRACTS_INDX_SEQUENCENUMBER]  
ON #CONTRACTS_REALTIME (SEQUENCENUMBER) 

-----------------------------DECLARE LegacyRowsCount-----------------------------------------------------  

DECLARE @LegacyRowsCountCNT BIGINT = 0   
SELECT @LegacyRowsCountCNT=COUNT(1) FROM DBO.REPORT_V_CP_CONTRACT WHERE AG_LEASE_TYP = 'PYRAMID' 

------------------------------------LS_AGRMNT_ITM------------------------------------------
IF OBJECT_ID(N'TEMPDB..#LS_AGRMNT_ITM_CNT')  IS NOT NULL      
            BEGIN      
             DROP TABLE #LS_AGRMNT_ITM_CNT      
            END 
			SELECT  LA.LS_AGRMNT_ID,MAX(LI.LS_AGRMNT_ITM_MTR_IND) AS LS_AGRMNT_ITM_MTR_IND,MAX(LA.LS_AGRMNT_TRMN_DT) AS LS_AGRMNT_TRMN_DT
			INTO #LS_AGRMNT_ITM_CNT
			FROM DBO.LS_AGRMNT_ITM LI WITH(NOLOCK)
			INNER JOIN  DBO.LS_AGRMNT LA WITH(NOLOCK) ON LI.LS_AGRMNT_ID=LA.LS_AGRMNT_ID
			WHERE DATEDIFF(MONTH, ISNULL(LA.LS_AGRMNT_TRMN_DT, CAST('2999-12-31' AS DATE)), GETDATE()) < 13 AND LA.LS_AGRMNT_STTS_CD='TERMINATED'
			AND 0=@LegacyRowsCountCNT
			GROUP BY LA.LS_AGRMNT_ID,LI.LS_AGRMNT_ITM_MTR_IND,LA.LS_AGRMNT_TRMN_DT

  --------------------------- Create index ---------------------------------------------------  

CREATE NONCLUSTERED INDEX [LS_AGRMNT_ITM_CNT_INDX_LS_AGRMNT_ID]  
ON #LS_AGRMNT_ITM_CNT (LS_AGRMNT_ID) 

-----------------AVG_RENT------------------------------------
IF OBJECT_ID(N'TEMPDB..#RENTAL_AMOUNT')  IS NOT NULL      
             BEGIN      
              DROP TABLE #RENTAL_AMOUNT      
             END 
SELECT          
          CONTRACT.ID   AS CH_ID ,      
ISNULL(SUM(CASE WHEN (CONTRACT.CHARGEOFFSTATUS IN('CHARGEDOFF','RECOVERY') OR LEASEFINANCES.BOOKINGSTATUS='FULLYPAIDOFF') THEN 0      
                ELSE ROUND(TEMP.AMOUNT_AMOUNT,CASE WHEN CURRENCIES.NAME = 'IDR' THEN 0        
                                                   WHEN CURRENCIES.NAME = 'JPY'THEN 0         
                                                   ELSE 2         
                                                   END)      
                      END),0) AS 'RENTAL_AMOUNT'
INTO #RENTAL_AMOUNT					  
FROM          DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CONTRACT WITH(NOLOCK)        
              INNER JOIN  DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LEASEFINANCES WITH(NOLOCK) ON LEASEFINANCES.CONTRACTID = CONTRACT.ID AND LEASEFINANCES.ISCURRENT = 1        
              INNER JOIN  DATAHUB_ODESSA.ODH.LEASEFINANCEDETAILS_REALTIME LEASEFINANCEDETAILS WITH(NOLOCK) ON LEASEFINANCEDETAILS.ID = LEASEFINANCES.ID         
              INNER JOIN  DATAHUB_ODESSA.ODH.CURRENCIES_REALTIME CURRENCIES  WITH (NOLOCK) ON CURRENCIES.ID = CONTRACT.CURRENCYID AND CURRENCIES.ISACTIVE = 1        
              INNER JOIN (SELECT LPS.STARTDATE,LPS.LEASEFINANCEDETAILID,LPS.AMOUNT_AMOUNT,LEASEPAYMENTSCHEDULEID FROM      
                                         
                                 (SELECT   MAX(ID) AS LEASEPAYMENTSCHEDULEID ,LEASEPAYMENTSCHEDULES.LEASEFINANCEDETAILID       
                                 FROM     DATAHUB_ODESSA.ODH.LEASEPAYMENTSCHEDULES_REALTIME LEASEPAYMENTSCHEDULES  WITH (NOLOCK)         
                                 WHERE     LEASEPAYMENTSCHEDULES.ISACTIVE = 1  AND STARTDATE <= CAST (GETDATE() AS DATE) AND ENDDATE >= CAST (GETDATE() AS DATE)       
                                 GROUP BY LEASEPAYMENTSCHEDULES.LEASEFINANCEDETAILID) P        
                                     
                          INNER JOIN DATAHUB_ODESSA.ODH.LEASEPAYMENTSCHEDULES_REALTIME LPS  WITH (NOLOCK)      
                          ON       P.LEASEPAYMENTSCHEDULEID = LPS.ID )  TEMP      
    
              ON TEMP.LEASEFINANCEDETAILID = LEASEFINANCES.ID      
              GROUP BY CONTRACT.ID,LEASEFINANCES.ID	
  --------------------------- Create index ---------------------------------------------------  
CREATE NONCLUSTERED INDEX [RENTAL_AMOUNT_INDX_CH_ID]  
ON #RENTAL_AMOUNT (CH_ID) 		  
 ---------------------------------------------------------LOAD REPORT_V_CP_CONTRACT----------------------------------------------------  

PRINT 'LOAD REPORT_V_CP_CONTRACT'  
                             SET @StartTime = GETDATE()  
                             INSERT INTO [dbo].[REPORT_LOGS]  
                             (  
                                                          JobInstanaceId,  
                                                          ProcessName,  
                                                          StartTime,  
                                                          StatusTypeId,
                                                          JobEntityId														  
                             )               
                             VALUES  
                             (  
                                                          @JOBINSTANCEID,  
                                                          'Sync DBO.REPORT_V_CP_CONTRACT',  
                                                          GETDATE(),  
                                                          0  ,
														  18
                             )  
  
                             SET  @ReportLogId = SCOPE_IDENTITY()  
                             BEGIN TRY  
  
        PRINT 'LOAD #REPORT_V_CP_CONTRACT'  
        IF OBJECT_ID(N'TEMPDB..#REPORT_V_CP_CONTRACT')  IS NOT NULL  
        BEGIN  
         DROP TABLE #REPORT_V_CP_CONTRACT  
        END 
		
SELECT CSTMR_CD,SRVC_PRVDR_PARTY_ID,CH_ID,CNTRCT_NO,CNTRCT_DESC,EOL_NOTICE_DAYS,WBS_NO,INV_FREQ_CD_FIRM,INV_FREQ_CD_EVERGREEN,INV_FREQ_CD,
CNTRCT_DT,CNTRCT_MTRTY_DT,CNTRCT_BOOKED_DT,CNTRCT_STATUS_CD,TERM_MONTHS,REM_TERM_MONTHS,SUM_ORIG_EQUIP_COST,SUM_ASSET_CNT,
SUM_TERMINATED_ASSET_CNT,SUM_RETURNED_ASSET_CNT,CUR_CD,CNTRY_CD,CONTRACT_FLAG,RETIRED_FLAG,AG_LEASE_CLASS,AG_LEASE_TYP,AVG_RENT_PER_PYMT_AMT,
ADV_ARRS_CD,REM_TERM,REM_RENTAL,IS_METERING_CNTRCT,PURCHASE_OPTION,PROGRAM_CODE,BILLING_MODEL_CODE,SALES_PROGRAM_CODE,PROJECT_BUS_UNIT,PYRAMIDONLY,LASTREFRESHTIME,
UID,CRC1
INTO #REPORT_V_CP_CONTRACT
FROM
(SELECT        
           PR.PARTYNUMBER                                                                                         AS CSTMR_CD,    
		   CASE WHEN CST.NAME IN ('DIRECT', 'VENDOR') THEN PR.PARTYNUMBER       
                WHEN CST.NAME = 'SERVICEPROVIDER' THEN SP.PARTYNUMBER       
           ELSE PR.PARTYNUMBER END                                                                                AS SRVC_PRVDR_PARTY_ID, 
           CONTRACTS.ID                                                                                           AS CH_ID,          
           CONTRACTS.SEQUENCENUMBER                                                                               AS CNTRCT_NO,          
           CONTRACTS.ALIAS                                                                                        AS CNTRCT_DESC,          
           LEASEFINANCEDETAILS.FOLLOWUPLEADDAYS                                                                   AS EOL_NOTICE_DAYS,          
           WBS.WBSNUMBER                                                                                          AS WBS_NO,          
           CASE WHEN (CAST(GETDATE() AS DATE) <=LEASEFINANCEDETAILS.MATURITYDATE) OR (CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=0) THEN
                       CASE  
 						  WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL'
                       END						  
		   END                                                                                                    AS INV_FREQ_CD_FIRM,            
           CASE WHEN CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=1 THEN
                       CASE
						  WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL' 
                       END						  
		   END                                                                                                    AS INV_FREQ_CD_EVERGREEN,            
           CASE WHEN  (CAST(GETDATE() AS DATE) <=LEASEFINANCEDETAILS.MATURITYDATE) OR (CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=0) THEN
		              CASE
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                          WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL'   
				      END
                WHEN  CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=1 THEN 
			          CASE
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                          WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL'   
				      END
           END                                                                                                    AS INV_FREQ_CD,            
           CONVERT(DATE,LEASEFINANCEDETAILS.COMMENCEMENTDATE)                                                     AS CNTRCT_DT,          
           CONVERT(DATE,LEASEFINANCEDETAILS.MATURITYDATE)                                                         AS CNTRCT_MTRTY_DT,          
           CONVERT(DATE,LEASEFINANCEDETAILS.COMMENCEMENTDATE)                                                     AS CNTRCT_BOOKED_DT,            
           CASE WHEN LEASEFINANCES.BOOKINGSTATUS = 'Commenced' THEN 'BOOKED'    
        		WHEN LEASEFINANCES.BOOKINGSTATUS = 'FullyPaidOff' THEN 'TERMINATED'
				ELSE LEASEFINANCES.BOOKINGSTATUS END                                                              AS CNTRCT_STATUS_CD,
           CEILING(ROUND(LEASEFINANCEDETAILS.TERMINMONTHS,0))                                                     AS TERM_MONTHS,          
           CASE WHEN DATEDIFF(MONTH, GETDATE(), LEASEFINANCEDETAILS.MATURITYDATE) < 0            
            THEN 0            
            ELSE DATEDIFF(MONTH, GETDATE(), LEASEFINANCEDETAILS.MATURITYDATE)            
            END                                                                                                   AS REM_TERM_MONTHS ,           
           CONTRACT_SUMMARY.SUM_ORIG_EQUIP_COST                                                                   AS SUM_ORIG_EQUIP_COST,          
           CONTRACT_SUMMARY.SUM_ASSET_CNT                                                                         AS SUM_ASSET_CNT,   
           CONTRACT_SUMMARY.SUM_TERMINATED_ASSET_CNT                                                              AS SUM_TERMINATED_ASSET_CNT,            
           CONTRACT_SUMMARY.SUM_RETURNED_ASSET_CNT                                                                AS SUM_RETURNED_ASSET_CNT,            
           CURRENCIES.NAME                                                                                        AS CUR_CD,          
           COUNTRIES.SHORTNAME                                                                                    AS CNTRY_CD,          
           CASE WHEN LEASEFINANCES.BOOKINGSTATUS IN ('FullyPaidOff','TERMINATED')            
            THEN 'Y'            
            ELSE 'N'            
           END                                                                                                    AS CONTRACT_FLAG,            
           CASE WHEN CONTRACT_SUMMARY.SUM_TERMINATED_ASSET_CNT > 0            
            THEN 'Y'            
            ELSE 'N'            
            END                                                                                                   AS RETIRED_FLAG,            
           LEASEFINANCEDETAILS.LEASECONTRACTTYPE                                                                  AS AG_LEASE_CLASS,            
           DEALTYPES.PRODUCTTYPE                                                                                  AS AG_LEASE_TYP,          
           RENT.RENTAL_AMOUNT                                                                                     AS AVG_RENT_PER_PYMT_AMT,            
           CASE WHEN LEASEFINANCEDETAILS.ISADVANCE = 1                                                       
					 THEN 'AD' ELSE 'AR' END                                                                      AS ADV_ARRS_CD,            
           CONTRACT_SUMMARY.REM_TERM,            
           CAST(CONTRACT_SUMMARY.AVG_RENT_PER_PYMT_AMT AS decimal(17,2))                                          AS REM_RENTAL,            
           NULL                                                                                                   AS IS_METERING_CNTRCT,            
           TEMPPAYOFFS.PURCHASEOPTION                                                                             AS PURCHASE_OPTION,          
           HPEFS_PROGRAMCONFIGURATIONS.PROGRAMNAME                                                                AS PROGRAM_CODE,          
           CASE WHEN PASTCS.PRODUCTANDSERVICETYPECODE IS NOT NULL THEN 'PT'   
            ELSE '' END                                                                                           AS BILLING_MODEL_CODE,          
           SPC.SALES_PROGRAM_CODE                                                                                 AS SALES_PROGRAM_CODE,         
           CASE WHEN CST.NAME IN ('DIRECT', 'VENDOR') THEN LEASEFINANCES.PROJECTNAME   
            WHEN CST.NAME = 'SERVICEPROVIDER' THEN SBU.SERVICEPROVIDERBUSINESSUNIT  
            ELSE LEASEFINANCES.PROJECTNAME END                                                                    AS PROJECT_BUS_UNIT,
			0                                                                                                     AS PYRAMIDONLY,
           GETDATE()                                                                                              AS LASTREFRESHTIME,
		   CONCAT(CONTRACTS.ID,'_')                                                                               AS UID,
		   HASHBYTES('MD5', CONCAT (PR.PARTYNUMBER,CONTRACTS.ID,CONTRACTS.SEQUENCENUMBER,CONTRACTS.ALIAS,LEASEFINANCEDETAILS.FOLLOWUPLEADDAYS,
		   WBS.WBSNUMBER,LEASEFINANCEDETAILS.PAYMENTFREQUENCY,LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY,LEASEFINANCEDETAILS.COMMENCEMENTDATE,
		   LEASEFINANCEDETAILS.MATURITYDATE,LEASEFINANCEDETAILS.TERMINMONTHS,LEASEFINANCEDETAILS.MATURITYDATE,CONTRACT_SUMMARY.SUM_ORIG_EQUIP_COST,
		   CONTRACT_SUMMARY.SUM_ASSET_CNT,CONTRACT_SUMMARY.SUM_TERMINATED_ASSET_CNT,CONTRACT_SUMMARY.SUM_RETURNED_ASSET_CNT,CURRENCIES.NAME,
		   CONTRACTS.STATUS,COUNTRIES.SHORTNAME,LEASEFINANCEDETAILS.LEASECONTRACTTYPE,DEALTYPES.PRODUCTTYPE,CONTRACT_SUMMARY.AVG_RENT_PER_PYMT_AMT,
		   LEASEFINANCEDETAILS.ISADVANCE,CONTRACT_SUMMARY.REM_TERM,TEMPPAYOFFS.PURCHASEOPTION,PASTCS.PRODUCTANDSERVICETYPECODE,SPC.SALES_PROGRAM_CODE,
		   LEASEFINANCES.PROJECTNAME,CST.NAME,SBU.SERVICEPROVIDERBUSINESSUNIT))                                   AS CRC1
  
  
       FROM               DATAHUB_ODESSA.ODH.PARTIES_REALTIME PR  WITH(NOLOCK)   
       INNER JOIN         #LEASEFINANCES_REALTIME LEASEFINANCES WITH (NOLOCK) ON  LEASEFINANCES.CUSTOMERID = PR.ID AND LEASEFINANCES.ISCURRENT = 1  AND LEASEFINANCES.BOOKINGSTATUS IN ('COMMENCED','FULLYPAIDOFF')
       INNER JOIN         #LEASEFINANCEDETAILS_REALTIME LEASEFINANCEDETAILS  WITH(NOLOCK) ON LEASEFINANCEDETAILS.ID = LEASEFINANCES.ID     
       INNER JOIN         #CONTRACTS_REALTIME CONTRACTS WITH(NOLOCK) ON CONTRACTS.ID = LEASEFINANCES.CONTRACTID AND LEASEFINANCES.ISCURRENT = 1   
       INNER JOIN         DATAHUB_ODESSA.ODH.CONTRACTORIGINATIONS_REALTIME CO WITH(NOLOCK)  ON LEASEFINANCES.CONTRACTORIGINATIONID = CO.ID  
       INNER JOIN         DATAHUB_ODESSA.ODH.ORIGINATIONSOURCETYPES_REALTIME CST WITH(NOLOCK)  ON CO.ORIGINATIONSOURCETYPEID = CST.ID   
       INNER JOIN         DATAHUB_ODESSA.ODH.CURRENCIES_REALTIME CURRENCIES  WITH (NOLOCK) ON CURRENCIES.ID = CONTRACTS.CURRENCYID AND CURRENCIES.ISACTIVE = 1      
  
       INNER JOIN         (SELECT          BUSINESSUNITS_REALTIME.NAME, LE.ID    
                           FROM            DATAHUB_ODESSA.ODH.LEGALENTITIES_REALTIME(NOLOCK)  LE  
                           INNER JOIN      DATAHUB_ODESSA.ODH.BUSINESSUNITS_REALTIME(NOLOCK) BUSINESSUNITS_REALTIME ON BUSINESSUNITS_REALTIME.ID=LE.BUSINESSUNITID  
                           ) BU  
                           ON              BU.ID=LEASEFINANCES.LEGALENTITYID  
  
       INNER JOIN         DATAHUB_ODESSA.ODH.PARTYADDRESSES_REALTIME PARTYADDRESSES WITH (NOLOCK) ON PARTYADDRESSES.PARTYID =  LEASEFINANCES.CUSTOMERID AND PARTYADDRESSES.ISMAIN = 1           
       INNER JOIN         DATAHUB_ODESSA.ODH.STATES_REALTIME STATES WITH (NOLOCK) ON STATES.ID = PARTYADDRESSES.STATEID           
       INNER JOIN         DATAHUB_ODESSA.ODH.COUNTRIES_REALTIME COUNTRIES WITH (NOLOCK) ON COUNTRIES.ID = STATES.COUNTRYID            
       INNER JOIN         DATAHUB_ODESSA.ODH.DEALTYPES_REALTIME DEALTYPES WITH (NOLOCK) ON DEALTYPES.ID = CONTRACTS.DEALTYPEID 
       INNER JOIN         DBO.REPORT_CONTRACT_SUMMARY CONTRACT_SUMMARY WITH(NOLOCK) ON CONTRACT_SUMMARY.CH_ID = CONTRACTS.ID	   
       LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.HPEFS_PROGRAMCONFIGURATIONS_REALTIME HPEFS_PROGRAMCONFIGURATIONS WITH(NOLOCK) ON HPEFS_PROGRAMCONFIGURATIONS.ID = LEASEFINANCES.PROGRAMORPROMOTIONID          
       LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.WBSNumberConfigs_REALTIME  WBS WITH(NOLOCK) ON WBS.ID = LEASEFINANCES.WBSNumberConfigId 

       LEFT OUTER JOIN    (SELECT   PRODUCTANDSERVICETYPECODE,ID  
                           FROM    DATAHUB_ODESSA.ODH.PRODUCTANDSERVICETYPECONFIGS_REALTIME   
                           WHERE   PRODUCTANDSERVICETYPECODE = 'PPU - FLEXIBLE BILLING PASS THRU') PASTCS  
                           ON      PASTCS.ID = CONTRACTS.PRODUCTANDSERVICETYPECONFIGID  
  
       /*SERVICE PROVIDER DETAILS*/  
       LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.PARTIES_REALTIME SP WITH(NOLOCK) ON SP.ID = CO.ORIGINATIONSOURCEID   
       LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.SERVICELEDBUSINESSUNITS_REALTIME SBU WITH(NOLOCK)  ON SBU.ID = LEASEFINANCES.SERVICELEDBUSINESSUNITID   
       /* END  */                    
       LEFT OUTER JOIN    DBO.REPORT_CONTRACT_PURCHASEOPTION TEMPPAYOFFS WITH(NOLOCK) ON TEMPPAYOFFS.LEASEFINANCEID = LEASEFINANCES.ID
       LEFT OUTER JOIN    DBO.REPORT_SALES_CODE SALES_CODE WITH(NOLOCK) ON SALES_CODE.CONTRACTID=CONTRACTS.ID  
       LEFT OUTER JOIN    DBO.SALES_PROGRAM_CODE SPC WITH(NOLOCK) ON SPC.DESCRIPTION=SALES_CODE.SALES_PROGRAM_CODE AND  SPC.GEO_CODE=BU.NAME  
       LEFT OUTER JOIN    #RENTAL_AMOUNT RENT WITH(NOLOCK) ON RENT.CH_ID = CONTRACTS.ID

UNION ALL

SELECT DISTINCT 
            PARTY.emdmPartyID                                                                          AS CSTMR_CD,
			ISNULL(PARTY_SP.emdmPartyID,PARTY.emdmPartyID)                                             AS SRVC_PRVDR_PARTY_ID,
            LA.LS_AGRMNT_ID                                                                            AS CH_ID,  
            LA.LS_AGRMNT_NR                                                                            AS CNTRCT_NO,
            LA.LS_AGRMNT_DN                                                                            AS CNTRCT_DESC,
            LA.END_OF_LEASE_NTCE                                                                       AS EOL_NOTICE_DAYS,
            LA.WBS_NBR                                                                                 AS WBS_NO,
            LA.LS_AGRMNT_INV_FRQ_TYP_CD                                                                AS INV_FREQ_CD_FIRM,
            LA.INV_FREQ_CODE_EVERGREEN                                                                 AS INV_FREQ_CD_EVERGREEN,
            CASE WHEN CAST(GETDATE() AS DATE) <=LA.LS_AGRMNT_MTRTY_TS   
                 THEN LA.LS_AGRMNT_INV_FRQ_TYP_CD    
                 ELSE LA.INV_FREQ_CODE_EVERGREEN   
            END                                                                                        AS INV_FREQ_CD,
            LA.LS_AGRMNT_STRT_TS                                                                       AS CNTRCT_DT,
            LA.LS_AGRMNT_MTRTY_TS                                                                      AS CNTRCT_MTRTY_DT,
            LA.LS_AGRMNT_BK_TS                                                                         AS CNTRCT_BOOKED_DT,
            LA.LS_AGRMNT_STTS_CD                                                                       AS CNTRCT_STATUS_CD,
            LA.TRM_MNTHS                                                                               AS TERM_MONTHS,
            CASE WHEN DATEDIFF(MONTH, GETDATE(), LA.LS_AGRMNT_MTRTY_TS) < 0            
                 THEN 0            
                 ELSE DATEDIFF(MONTH, GETDATE(), LA.LS_AGRMNT_MTRTY_TS)            
                 END AS REM_TERM_MONTHS,
            CONTRACT_SUMMARY.SUM_ORIG_EQUIP_COST                                                       AS SUM_ORIG_EQUIP_COST,
            CONTRACT_SUMMARY.SUM_ASSET_CNT                                                             AS SUM_ASSET_CNT,
            CONTRACT_SUMMARY.SUM_TERMINATED_ASSET_CNT                                                  AS SUM_TERMINATED_ASSET_CNT,
            CONTRACT_SUMMARY.SUM_RETURNED_ASSET_CNT                                                    AS SUM_RETURNED_ASSET_CNT,
            P.CURR_CD                                                                                  AS CUR_CD,
            CTRY.ISOCountryCode                                                                        AS CNTRY_CD,
            CASE WHEN LA.LS_AGRMNT_STTS_CD = 'TERMINATED'
            THEN 'Y' ELSE 'N' END                                                                      AS CONTRACT_FLAG,
            CASE WHEN CONTRACT_SUMMARY.SUM_TERMINATED_ASSET_CNT > 0            
                        THEN 'Y'            
                        ELSE 'N'            
                        END                                                                            AS RETIRED_FLAG,
            LA.LS_AGRMNT_TYP_CD                                                                        AS AG_LEASE_CLASS,
            'PYRAMID'                                                                                  AS AG_LEASE_TYP,
            CONTRACT_SUMMARY.AVG_RENT_PER_PYMT_AMT,
            CASE WHEN ISNULL(LS_AGRMNT_ADV_IND,'N') = 'Y' THEN 'AD' ELSE 'AR' END                      AS ADV_ARRS_CD,
            CONTRACT_SUMMARY.REM_TERM,
            CAST(CONTRACT_SUMMARY.AVG_RENT_PER_PYMT_AMT  AS decimal(17,2))                             AS REM_RENTAL,
            LI.LS_AGRMNT_ITM_MTR_IND                                                                   AS IS_METERING_CNTRCT,
            NULL                                                                                       AS PURCHASE_OPTION,
            SLSPR.LS_AGRMNT_SLS_PRGM_DN                                                                AS PROGRAM_CODE,
            CASE WHEN ISNULL(LA.LS_AGRMNT_SLS_PRGM_CD,'') = '2004108' THEN 'PT' ELSE '' END            AS BILLING_MODEL_CODE,
            LA.LS_AGRMNT_SLS_PRGM_CD                                                                   AS SALES_PROGRAM_CODE,
            NULL                                                                                       AS PROJECT_BUS_UNIT,
			1                                                                                          AS PYRAMIDONLY,
            GETDATE()                                                                                  AS LASTREFRESHTIME,
            CONCAT(LA.LS_AGRMNT_ID,'_')                                                                AS UID,
            HASHBYTES('MD5', CONCAT (PARTY.emdmPartyID,LA.LS_AGRMNT_ID,LA.LS_AGRMNT_NR,LA.LS_AGRMNT_DN,LA.END_OF_LEASE_NTCE,LA.WBS_NBR,LA.LS_AGRMNT_INV_FRQ_TYP_CD,
            LA.INV_FREQ_CODE_EVERGREEN,LA.LS_AGRMNT_INV_FRQ_TYP_CD,LA.LS_AGRMNT_STRT_TS,LA.LS_AGRMNT_MTRTY_TS,LA.LS_AGRMNT_BK_TS,LA.LS_AGRMNT_STTS_CD,
            LA.TRM_MNTHS,CONTRACT_SUMMARY.SUM_ORIG_EQUIP_COST,CONTRACT_SUMMARY.SUM_ASSET_CNT,CONTRACT_SUMMARY.SUM_TERMINATED_ASSET_CNT,
            CONTRACT_SUMMARY.SUM_RETURNED_ASSET_CNT,P.CURR_CD,CTRY.ISOCountryCode,LA.LS_AGRMNT_TYP_CD,CONTRACT_SUMMARY.AVG_RENT_PER_PYMT_AMT,
            LS_AGRMNT_ADV_IND,CONTRACT_SUMMARY.REM_TERM,SLSPR.LS_AGRMNT_SLS_PRGM_DN,LA.LS_AGRMNT_SLS_PRGM_CD)) AS CRC1

FROM        DBO.LS_AGRMNT LA  WITH(NOLOCK)
			INNER JOIN        #LS_AGRMNT_ITM_CNT LI WITH(NOLOCK) ON LA.LS_AGRMNT_ID =LI.LS_AGRMNT_ID
			INNER JOIN        DBO.XREF_BUS_EXTNSN XREF_BUS_EXTNSN WITH(NOLOCK) ON XREF_BUS_EXTNSN.XREF_BUS_EXTNSN_ID =  LA.XREF_BUS_EXTNSN_ID
			INNER JOIN        DBO.LS_PTFL P WITH(NOLOCK) ON LA.LS_PTFL_ID = P.LS_PTFL_ID  
			INNER JOIN        DBO.CTRY CTRY WITH(NOLOCK) ON CTRY.CTRY_CD = P.CTRY_CD AND MIGRATEDFLAG='Y' 
			INNER JOIN        party.party PARTY WITH(NOLOCK) ON PARTY.emdmPartyID = ISNULL(XREF_BUS_EXTNSN.SBL_GLOB_CSTMR_ID,XREF_BUS_EXTNSN.ORIG_MDCP_ORG_ID)
			LEFT JOIN         party.party PARTY_SP WITH(NOLOCK) ON PARTY_SP.emdmPartyID = XREF_BUS_EXTNSN.ORIG_MDCP_ORG_ID
			LEFT JOIN         DBO.LS_AGRMNT_SLS_PRGM SLSPR WITH(NOLOCK) ON SLSPR.LS_AGRMNT_SLS_PRGM_CD = LA.LS_AGRMNT_SLS_PRGM_CD
			LEFT JOIN         DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CT WITH(NOLOCK) ON CT.SEQUENCENUMBER = LA.LS_AGRMNT_NR
			LEFT JOIN         DBO.REPORT_CONTRACT_SUMMARY CONTRACT_SUMMARY WITH(NOLOCK) ON CONTRACT_SUMMARY.CH_ID = LI.LS_AGRMNT_ID AND CONTRACT_SUMMARY.SUM_RETURNED_ASSET_CNT=0 AND CONTRACT_SUMMARY.SUM_ASSET_CNT=0 AND CONTRACT_SUMMARY.AVG_RENT_PER_PYMT_AMT=0 AND CONTRACT_SUMMARY.REM_TERM=0
			WHERE      
                              CT.SEQUENCENUMBER IS NULL AND 0=@LegacyRowsCountCNT) CNTCT

	   --------------DUPLICATE DELETE---------------------------------
	   IF OBJECT_ID(N'TEMPDB..#V_CP_CONTRACT')  IS NOT NULL  
        BEGIN  
           DROP TABLE #V_CP_CONTRACT 
        END  
 		SELECT * INTO #V_CP_CONTRACT FROM 
		(SELECT   
        ROW_NUMBER() OVER (PARTITION BY UID ORDER BY LASTREFRESHTIME DESC) AS RID
           ,CSTMR_CD 
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
           ,LASTREFRESHTIME
		   ,UID
		   ,CRC1
		   FROM 
		   #REPORT_V_CP_CONTRACT) CONT
		   WHERE RID=1

		   CREATE CLUSTERED INDEX [REPORT_V_CP_CONTRACT_ASSET_INDX1_UID]  
					ON #V_CP_CONTRACT ([UID])  
	   
	      DELETE FROM     #V_CP_CONTRACT  WHERE UID IN (SELECT SUMRY.UID FROM DBO.REPORT_V_CP_CONTRACT SUMRY
                                                          INNER JOIN #V_CP_CONTRACT IDS WITH(NOLOCK) 
														  ON SUMRY.UID = IDS.UID AND SUMRY.CRC = IDS.CRC1) 
	 ---DELETING THE UID FROM MAIN TABLE-----------------
	 DELETE FROM DBO.REPORT_V_CP_CONTRACT  WHERE UID IN (SELECT UID FROM  #V_CP_CONTRACT)  
	  
	    IF  EXISTS (SELECT UID FROM  #V_CP_CONTRACT) 

		INSERT INTO  DBO.REPORT_V_CP_CONTRACT  
       (  
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
		   ,LASTREFRESHTIME
		   ,UID
		   ,CRC
		   ,InsertedByJobEntityInstanceId
		   ,UpdatedByJobEntityInstanceId
       )  
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
           ,LASTREFRESHTIME	
		   ,UID
		   ,CRC1
		   ,1
		   ,1
       FROM   #V_CP_CONTRACT
	   
	   ---UPDATE THE RENTAL INFO IN CONTRACT MAIN TABLE----------------
						 
	   UPDATE CNT SET 
						SUM_ORIG_EQUIP_COST=CNT_SMRY.SUM_ORIG_EQUIP_COST,     
						SUM_ASSET_CNT=CNT_SMRY.SUM_ASSET_CNT,           
						SUM_TERMINATED_ASSET_CNT=CNT_SMRY.SUM_TERMINATED_ASSET_CNT,
						SUM_RETURNED_ASSET_CNT=CNT_SMRY.SUM_RETURNED_ASSET_CNT,
						REM_TERM=CNT_SMRY.REM_TERM,
						REM_RENTAL=CAST(CNT_SMRY.AVG_RENT_PER_PYMT_AMT AS decimal(17,2)),
						AVG_RENT_PER_PYMT_AMT=ISNULL(RNT.RENTAL_AMOUNT,0),
						INV_FREQ_CD_FIRM=       CASE WHEN (CAST(GETDATE() AS DATE) <=LEASEFINANCEDETAILS.MATURITYDATE) OR (CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=0) THEN
                                                       CASE  
 		  	                                  			      WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                                                              WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                                                              WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                                                              WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL'
                                                        END						  
		                                        END,            
                        INV_FREQ_CD_EVERGREEN=  CASE WHEN CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=1 THEN
                                                        CASE
			                                     		     WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                                                             WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                                                             WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                                                             WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL' 
                                                          END						  
		                                        END,            
                        INV_FREQ_CD=            CASE WHEN  (CAST(GETDATE() AS DATE) <=LEASEFINANCEDETAILS.MATURITYDATE) OR (CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=0) THEN
		                                                 CASE
                                                             WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                                                             WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                                                             WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                                                             WHEN LEASEFINANCEDETAILS.PAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL'   
				                                         END
                                                     WHEN  CAST(GETDATE() AS DATE) >LEASEFINANCEDETAILS.MATURITYDATE AND LEASEFINANCEDETAILS.ISOVERTERMLEASE=1 THEN 
		  	                                             CASE
                                                               WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='YEARLY' THEN 'ANNUAL'          
                                                               WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='MONTHLY' THEN 'MONTHLY'          
                                                               WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='QUARTERLY' THEN 'QUARTERLY'          
                                                               WHEN LEASEFINANCEDETAILS.OTPPAYMENTFREQUENCY='HALFYEARLY' THEN 'SEMI ANNUAL'   
		  	                                   	      END
                                                END,    
	                  TERM_MONTHS=CEILING(ROUND(LEASEFINANCEDETAILS.TERMINMONTHS,0)),          
                      REM_TERM_MONTHS=        CASE WHEN DATEDIFF(MONTH, GETDATE(), LEASEFINANCEDETAILS.MATURITYDATE) < 0 THEN 0            
                                                   ELSE DATEDIFF(MONTH, GETDATE(), LEASEFINANCEDETAILS.MATURITYDATE)            
                                              END 
						FROM DBO.REPORT_V_CP_CONTRACT CNT
						     INNER JOIN DBO.REPORT_CONTRACT_SUMMARY(NOLOCK) CNT_SMRY ON CNT_SMRY.CH_ID=CNT.CH_ID
							 INNER JOIN DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LEASEFINANCES WITH (NOLOCK) ON  LEASEFINANCES.CONTRACTID = CNT_SMRY.CH_ID AND LEASEFINANCES.ISCURRENT = 1  AND LEASEFINANCES.BOOKINGSTATUS IN ('COMMENCED','FULLYPAIDOFF')
                             INNER JOIN DATAHUB_ODESSA.ODH.LEASEFINANCEDETAILS_REALTIME LEASEFINANCEDETAILS  WITH(NOLOCK) ON LEASEFINANCEDETAILS.ID = LEASEFINANCES.ID 
							 LEFT OUTER JOIN #RENTAL_AMOUNT(NOLOCK) RNT ON RNT.CH_ID=CNT.CH_ID
	   
	   ----------------------- END -------------------------------------
	   
	   
       SET @RowsProcessed = @RowsProcessed+ ISNULL((SELECT COUNT(*) FROM #V_CP_CONTRACT),0)  
  
       SET @NumRowsInserted = ISNULL((SELECT COUNT(*) FROM #V_CP_CONTRACT),0)  
  
                                                          UPDATE           [dbo].[REPORT_LOGS]  
                                                          SET                      EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = @NumRowsInserted,  
                                                                                      RowsUpdated = @NumRowsUpdated,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = 1  
                                                          WHERE ReportLogId = @ReportLogId  
                             END TRY  
                             BEGIN CATCH  
                                                          SET @RowsProcessed = 0  
                                                          IF OBJECT_ID(N'TEMPDB..#V_CP_CONTRACT')  IS NOT NULL  
                                                          BEGIN  
                                                                SET @RowsProcessed = ISNULL((SELECT COUNT(*) FROM #V_CP_CONTRACT),0)  
                                                          END  
  
                                                          UPDATE              [dbo].[REPORT_LOGS]  
                                                          SET                      EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = 0,  
                                                                                      RowsUpdated = 0,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = -1,  
                                                                                      IsError = 1,  
                                                                                      ErrorMessage =  ERROR_MESSAGE()   
                                                          WHERE ReportLogId = @ReportLogId  
                             END CATCH  
      
  ------------------------------------REPORT_V_CP_CDF_ASSET------------------------------------------------  
     ------------------------------------TEMP REPORT_V_CP_CDF_ASSET------------------------------------------------  
IF OBJECT_ID(N'TEMPDB..#LOADTIMECDF')  IS NOT NULL  
BEGIN  
  DROP TABLE #LOADTIMECDF
END 
SELECT DISTINCT LASTREFRESHTIME INTO #LOADTIMECDF FROM DBO.REPORT_V_CP_CDF_ASSET (NOLOCK) WHERE LASTREFRESHTIME>=GETDATE()-30

DECLARE @PICKUP_DATECDF DATETIME

SELECT @PICKUP_DATECDF=ISNULL(MAX(LASTREFRESHTIME),'01/01/1910')-2 FROM #LOADTIMECDF (NOLOCK)
-------------------#ACTUAL_LOADCDF-----------------------------------------------------------
 IF OBJECT_ID(N'TEMPDB..#ACTUAL_LOADCDF')  IS NOT NULL  
BEGIN  
  DROP TABLE #ACTUAL_LOADCDF
 END 
SELECT        DISTINCT  CONTRACTID  
INTO          #ACTUAL_LOADCDF  
FROM
(
SELECT        DISTINCT   CONTRACTS.ID AS CONTRACTID
FROM          DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CONTRACTS WITH (NOLOCK)
INNER JOIN    DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LEASEFINANCES WITH (NOLOCK) ON LEASEFINANCES.CONTRACTID = CONTRACTS.ID AND ISCURRENT=1
INNER JOIN    DATAHUB_ODESSA.ODH.LEASEFINANCEDETAILS_REALTIME LEASEFINANCEDETAIL_REALTIME WITH (NOLOCK) ON LEASEFINANCEDETAIL_REALTIME.ID = LEASEFINANCES.ID
INNER JOIN    DATAHUB_ODESSA.ODH.LEASEASSETS_REALTIME LEASEASSETS WITH (NOLOCK) ON LEASEASSETS.LEASEFINANCEID = LEASEFINANCES.ID 
INNER JOIN    DATAHUB_ODESSA.ODH.ASSETS_REALTIME ASSETS WITH(NOLOCK) ON ASSETS.ID = LEASEASSETS.ASSETID
WHERE 
CONVERT(DATETIME,(SELECT MAX(T.UPDATEDTIME)  FROM (    
VALUES 
( ISNULL(ASSETS.LASTREFRESHTIME,ASSETS.UPDATEDTIME)),  
( ISNULL(ASSETS.UPDATEDTIME,ASSETS.CREATEDTIME)),    
( ISNULL(LEASEASSETS.LASTREFRESHTIME,LEASEASSETS.UPDATEDTIME)),  
( ISNULL(LEASEASSETS.UPDATEDTIME,LEASEASSETS.CREATEDTIME))) AS T( UPDATEDTIME ))) > @PICKUP_DATECDF  --V9.0

UNION 

SELECT    DISTINCT  CT.ID  AS CONTRACTID
FROM DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CT WITH(NOLOCK) 
INNER JOIN DBO.CDFASSET CDF WITH(NOLOCK) ON CDF.CONTRACTID = CT.ID
WHERE CDF.UpdatedTime > @PICKUP_DATECDF) CONT_CDF

  --------------------------- Create index ---------------------------------------------------  

CREATE NONCLUSTERED INDEX [ACTUAL_LOADCDF_INDX_ID]
ON #ACTUAL_LOADCDF(CONTRACTID)  

  --------------------------- PP_ASSET_DETAILS---------------------------------------------------    
IF OBJECT_ID(N'TEMPDB..#PP_ASSET_DETAILS')  IS NOT NULL  
BEGIN  
DROP TABLE #PP_ASSET_DETAILS  
END
SELECT ORIGINAL_AGMT_KEY,ORIGINAL_ASSETSERIALNUMBERID,ASSETNUMBER,ASET_KEY,ORIGINAL_ASET_KEY,NEW_ASSETID_AFTER_SPLIT
INTO #PP_ASSET_DETAILS
FROM FCT_20210430.PP_ASSET_DETAILS TPP
INNER JOIN #ACTUAL_LOADCDF AL WITH(NOLOCK) ON AL.CONTRACTID = TPP.ORIGINAL_AGMT_KEY
WHERE  ORIGINAL_AGMT_KEY > 0
  --------------------------- Create index ---------------------------------------------------  
CREATE NONCLUSTERED INDEX [#PP_ASSET_DETAILS_INDX_ORIGINAL_AGMT_KEY]  
ON #PP_ASSET_DETAILS (ORIGINAL_AGMT_KEY)  
CREATE NONCLUSTERED INDEX [#PP_ASSET_DETAILS_INDX_ASSETNUMBER]  
ON #PP_ASSET_DETAILS (ASSETNUMBER)  
CREATE NONCLUSTERED INDEX [#PP_ASSET_DETAILS_INDX_ASET_KEY]  
ON #PP_ASSET_DETAILS (ASET_KEY)  
CREATE NONCLUSTERED INDEX [#PP_ASSET_DETAILS_INDX_Original_ASET_KEY]  
ON #PP_ASSET_DETAILS (Original_ASET_KEY)


--------------------------- #TEMP ---------------------------------------------------  
PRINT 'LOAD CDF'  
IF OBJECT_ID(N'TEMPDB..#CDF')  IS NOT NULL  
BEGIN  
 DROP TABLE #CDF  
END  
SELECT             
        CSTMR_CNTRCT.CON_ID                                                   AS 'CH_ID'        
       ,A.ID                                                                  AS 'CD_ID'        
       ,A.ORIGINALASSETID                                                     AS 'ASSET_CD'
	   ,PP.ORIGINAL_ASSETSERIALNUMBERID                                       AS 'ASSETSERIALNUMBERID'
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 1 THEN G.CDFVALUE END)    AS 'CDF1'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 2 THEN G.CDFVALUE END)    AS 'CDF2'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 3 THEN G.CDFVALUE END)    AS 'CDF3'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 4 THEN G.CDFVALUE END)    AS 'CDF4'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 5 THEN G.CDFVALUE END)    AS 'CDF5'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 6 THEN G.CDFVALUE END)    AS 'CDF6'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 7 THEN G.CDFVALUE END)    AS 'CDF7'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 8 THEN G.CDFVALUE END)    AS 'CDF8'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 9 THEN G.CDFVALUE END)    AS 'CDF9'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 10 THEN G.CDFVALUE END)   AS 'CDF10'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 11 THEN G.CDFVALUE END)   AS 'CDF11'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 12 THEN G.CDFVALUE END)   AS 'CDF12'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 13 THEN G.CDFVALUE END)   AS 'CDF13'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 14 THEN G.CDFVALUE END)   AS 'CDF14'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 15 THEN G.CDFVALUE END)   AS 'CDF15'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 16 THEN G.CDFVALUE END)   AS 'CDF16'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 17 THEN G.CDFVALUE END)   AS 'CDF17'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 18 THEN G.CDFVALUE END)   AS 'CDF18'        
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 19 THEN G.CDFVALUE END)   AS 'CDF19'       
       ,MAX(CASE WHEN CDF.CDFDISPLAYCOLUMNORDERNO = 20 THEN G.CDFVALUE END)   AS 'CDF20' 
       ,GETDATE() AS LASTREFRESHTIME 
      INTO #CDF
	  FROM    
      (SELECT            
        
        CASE WHEN CST.NAME IN ('DIRECT','VENDOR') THEN PR.PARTYNUMBER          
           WHEN CST.NAME = 'SERVICEPROVIDER' THEN SP.PARTYNUMBER        
           ELSE PR.PARTYNUMBER END                                                     AS CSTMR_CD          
        
    
        ,CASE WHEN CST.NAME IN ('DIRECT','VENDOR')  THEN  PR.PARTYNUMBER    
           WHEN CST.NAME ='SERVICEPROVIDER' THEN SP.PARTYNUMBER    
           ELSE PR.PARTYNUMBER END                                                     AS PARTYNUMBER    
    
        ,CASE WHEN CST.NAME IN ('DIRECT','VENDOR') THEN  PR.PARTYNUMBER    
           WHEN CST.NAME ='SERVICEPROVIDER' THEN PR.PARTYNUMBER    
           ELSE PR.PARTYNUMBER END                                                     AS ENDPARTYNUMBER    
    
        ,CASE WHEN CST.NAME IN ('DIRECT','VENDOR') THEN  LF.PROJECTNAME    
           WHEN CST.NAME ='SERVICEPROVIDER' THEN SBU.SERVICEPROVIDERBUSINESSUNIT     
           ELSE LF.PROJECTNAME END                                                     AS BUSINESSUNIT    
         
        ,LF.ID                                                                         AS LF_ID    
        ,CON.ID                                                                        AS CON_ID    
      FROM                 DATAHUB_ODESSA.ODH.PARTIES_REALTIME PR WITH (NOLOCK)        
      INNER JOIN           DATAHUB_ODESSA.ODH.CUSTOMERS_REALTIME CUS WITH (NOLOCK) ON CUS.ID = PR.ID         
      INNER JOIN           DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LF WITH (NOLOCK) ON  LF.CUSTOMERID = CUS.ID AND LF.ISCURRENT = 1 AND LF.BOOKINGSTATUS IN ('COMMENCED','FULLYPAIDOFF')      
      INNER JOIN           DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CON WITH (NOLOCK) ON CON.ID = LF.CONTRACTID        
           
      /*SERVICE PROVIDER DETAILS*/        
      LEFT OUTER JOIN      DATAHUB_ODESSA.ODH.CONTRACTORIGINATIONS_REALTIME CO WITH (NOLOCK) ON LF.CONTRACTORIGINATIONID = CO.ID        
      LEFT OUTER JOIN      DATAHUB_ODESSA.ODH.PARTIES_REALTIME SP WITH (NOLOCK) ON SP.ID = CO.ORIGINATIONSOURCEID          
      LEFT OUTER JOIN      DATAHUB_ODESSA.ODH.ORIGINATIONSOURCETYPES_REALTIME CST WITH (NOLOCK) ON CO.ORIGINATIONSOURCETYPEID = CST.ID         
      LEFT OUTER JOIN      DATAHUB_ODESSA.ODH.SERVICELEDBUSINESSUNITS_REALTIME SBU WITH (NOLOCK) ON SBU.ID=LF.SERVICELEDBUSINESSUNITID        
      ) CSTMR_CNTRCT    
      INNER JOIN     DATAHUB_ODESSA.ODH.LEASEASSETS_REALTIME LA WITH (NOLOCK) ON LA.LEASEFINANCEID = CSTMR_CNTRCT.LF_ID AND LA.ISACTIVE = 1        
      INNER JOIN     DATAHUB_ODESSA.ODH.ASSETS_REALTIME A WITH (NOLOCK) ON A.ID = LA.ASSETID  
      INNER JOIN     DBO.CDFASSET G WITH (NOLOCK) ON G.CONTRACTID=CSTMR_CNTRCT.CON_ID AND SUBSTRING(G.ASSETID,0,CHARINDEX('_',G.ASSETID,1))= A.ORIGINALASSETID    
	  INNER JOIN     DBO.CUSTOMERCDFLABEL CDF WITH (NOLOCK) ON CDF.PARTYNUMBER = CSTMR_CNTRCT.PARTYNUMBER     AND  CDF.ENDPARTYNUMBER = CSTMR_CNTRCT.ENDPARTYNUMBER    
                     AND CDF.CDFLABELID = G.CDFTYPEKEY  
      INNER JOIN      #PP_ASSET_DETAILS PP WITH(NOLOCK) ON PP.ORIGINAL_AGMT_KEY=CSTMR_CNTRCT.CON_ID 
	                 AND PP.ASSETNUMBER=SUBSTRING(G.ASSETID,0,CHARINDEX('_',G.ASSETID,1)) 
					 AND CAST(PP.ASET_KEY AS VARCHAR(500)) = SUBSTRING(G.ASSETID,CHARINDEX('_',G.ASSETID,1)+1,LEN(G.ASSETID))
      GROUP BY       CSTMR_CNTRCT.CON_ID ,A.ORIGINALASSETID,A.ID,PP.ORIGINAL_ASSETSERIALNUMBERID,PP.ASSETNUMBER,PP.ORIGINAL_AGMT_KEY

--------------------------- #TEMP2 Without CDF asset migrated ---------------------------------------------------    
PRINT 'LOAD WITHOUT_CDF'  
IF OBJECT_ID(N'TEMPDB..#WITHOUT_CDF')  IS NOT NULL  
BEGIN  
 DROP TABLE #WITHOUT_CDF  
END  
SELECT DISTINCT             
        PP.ORIGINAL_AGMT_KEY                      AS 'CH_ID'        
       ,A.ID                                      AS 'CD_ID'        
       ,A.ORIGINALASSETID                         AS 'ASSET_CD'
	   ,PP.ORIGINAL_ASSETSERIALNUMBERID           AS 'ASSETSERIALNUMBERID'
       ,''   AS 'CDF1'        
       ,''   AS 'CDF2'        
       ,''   AS 'CDF3'        
       ,''   AS 'CDF4'        
       ,''   AS 'CDF5'        
       ,''   AS 'CDF6'        
       ,''   AS 'CDF7'        
       ,''   AS 'CDF8'        
       ,''   AS 'CDF9'        
       ,''   AS 'CDF10'        
       ,''   AS 'CDF11'        
       ,''   AS 'CDF12'        
       ,''   AS 'CDF13'        
       ,''   AS 'CDF14'        
       ,''   AS 'CDF15'        
       ,''   AS 'CDF16'        
       ,''   AS 'CDF17'        
       ,''   AS 'CDF18'        
       ,''   AS 'CDF19'       
       ,''   AS 'CDF20' 
       ,GETDATE() AS LASTREFRESHTIME
       INTO #WITHOUT_CDF
	   FROM #PP_ASSET_DETAILS PP WITH(NOLOCK)
	   INNER JOIN     DATAHUB_ODESSA.ODH.ASSETS_REALTIME A WITH (NOLOCK) ON A.ORIGINALASSETID = PP.Original_ASET_KEY 
	   and a.id = isnull(pp.New_AssetId_After_Split,PP.Original_ASET_KEY) and ORIGINAL_AGMT_KEY>0
	   LEFT JOIN DBO.CDFASSET G WITH(NOLOCK) ON  PP.ORIGINAL_AGMT_KEY=G.ContractID 
       AND PP.ASSETNUMBER=SUBSTRING(G.ASSETID,0,CHARINDEX('_',G.ASSETID,1)) 
       AND CAST(PP.ASET_KEY AS VARCHAR(500)) = SUBSTRING(G.ASSETID,CHARINDEX('_',G.ASSETID,1)+1,LEN(G.ASSETID))
	   LEFT JOIN #CDF T ON T.ASSETSERIALNUMBERID != PP.Original_AssetSerialNumberId
	   WHERE 
	   G.ASSETID IS NULL

	   ----------------------------UNION------------------------------------------------------------------
	   
	    PRINT 'LOAD REPORT_V_CP_CDF_ASSET'  
                             SET @StartTime = GETDATE()  
                             INSERT INTO [dbo].[REPORT_LOGS]  
                             (  
                                                          JobInstanaceId,  
                                                          ProcessName,  
                                                          StartTime,  
                                                          StatusTypeId ,
                                                          JobEntityId														  
                             )               
                             VALUES  
                             (  
                                                          @JOBINSTANCEID,  
                                                          'Sync DBO.REPORT_V_CP_CDF_ASSET',  
                                                          GETDATE(),  
                                                          0  ,
														  18
                             )  
  
                             SET  @ReportLogId = SCOPE_IDENTITY()  
                             BEGIN TRY  
							 
	   PRINT 'LOAD REPORT_V_CP_CDF_ASSET'  
       IF OBJECT_ID(N'TEMPDB..#REPORT_V_CP_CDF_ASSET')  IS NOT NULL  
       BEGIN  
        DROP TABLE #REPORT_V_CP_CDF_ASSET  
       END  
	   SELECT CH_ID, CD_ID,ASSET_CD,ASSETSERIALNUMBERID,CDF1,CDF2,CDF3,CDF4,CDF5,CDF6,CDF7,CDF8,CDF9,CDF10,CDF11,
              CDF12,CDF13,CDF14,CDF15,CDF16,CDF17,CDF18,CDF19,CDF20,LASTREFRESHTIME,UID,CRC1
	   INTO #REPORT_V_CP_CDF_ASSET
	   FROM
	   (
	      SELECT CH_ID, CD_ID,ASSET_CD,ASSETSERIALNUMBERID,CDF1,CDF2,CDF3,CDF4,CDF5,CDF6,CDF7,CDF8,CDF9,CDF10,CDF11,
                  CDF12,CDF13,CDF14,CDF15,CDF16,CDF17,CDF18,CDF19,CDF20,LASTREFRESHTIME,
	      	  CONCAT(CH_ID,CD_ID,ASSET_CD,ASSETSERIALNUMBERID) AS UID,
	      	  HASHBYTES('MD5', CONCAT (CH_ID,CD_ID,ASSET_CD,ASSETSERIALNUMBERID,CDF1,CDF2,CDF3,CDF4,CDF5,CDF6,CDF7,CDF8,CDF9,CDF10,CDF11,CDF12,CDF13,CDF14,CDF15,CDF16,CDF17,CDF18,CDF19,CDF20)) 
	      	  AS CRC1
          FROM    #CDF
	      
          UNION
	      
	      SELECT CH_ID, CD_ID,ASSET_CD,ASSETSERIALNUMBERID,CDF1,CDF2,CDF3,CDF4,CDF5,CDF6,CDF7,CDF8,CDF9,CDF10,CDF11,
                  CDF12,CDF13,CDF14,CDF15,CDF16,CDF17,CDF18,CDF19,CDF20,LASTREFRESHTIME,
	      	  CONCAT(CH_ID,CD_ID,ASSET_CD,ASSETSERIALNUMBERID) AS UID,
	      	  HASHBYTES('MD5', CONCAT (CH_ID,CD_ID,ASSET_CD,ASSETSERIALNUMBERID,CDF1,CDF2,CDF3,CDF4,CDF5,CDF6,CDF7,CDF8,CDF9,CDF10,CDF11,CDF12,CDF13,CDF14,CDF15,CDF16,CDF17,CDF18,CDF19,CDF20)) 
	      	  AS CRC1
          FROM   #WITHOUT_CDF

		) CDF
	  --------------DUPLICATE DELETE--------------	-------------------
	   IF OBJECT_ID(N'TEMPDB..#V_CP_CDF_ASSET')  IS NOT NULL  
        BEGIN  
           DROP TABLE #V_CP_CDF_ASSET 
        END  
 		SELECT * INTO #V_CP_CDF_ASSET FROM 
		(SELECT   
        ROW_NUMBER() OVER (PARTITION BY UID ORDER BY LastRefreshTime DESC) AS RID		
		 ,CH_ID  
         ,CD_ID  
         ,ASSET_CD
         ,ASSETSERIALNUMBERID		 
         ,CDF1  
         ,CDF2  
         ,CDF3  
         ,CDF4  
         ,CDF5  
         ,CDF6  
         ,CDF7  
         ,CDF8  
         ,CDF9  
         ,CDF10  
         ,CDF11  
         ,CDF12  
         ,CDF13  
         ,CDF14  
         ,CDF15  
         ,CDF16  
         ,CDF17  
         ,CDF18  
         ,CDF19  
         ,CDF20 
         ,LASTREFRESHTIME
		 ,UID
		 ,CRC1
		 FROM #REPORT_V_CP_CDF_ASSET) CDF

		 WHERE RID=1

		 CREATE CLUSTERED INDEX [V_CP_CDF_ASSET_INDX1_UID]  
					ON #V_CP_CDF_ASSET ([UID])  
	   
	      DELETE FROM     #V_CP_CDF_ASSET  WHERE UID IN (SELECT SUMRY.UID FROM DBO.REPORT_V_CP_CDF_ASSET SUMRY
                                                          INNER JOIN #V_CP_CDF_ASSET IDS WITH(NOLOCK) 
														  ON SUMRY.UID = IDS.UID AND SUMRY.CRC = IDS.CRC1) 
	 
	 ---DELETING THE UID FROM MAIN TABLE-----------------
		DELETE FROM DBO.REPORT_V_CP_CDF_ASSET  WHERE UID IN (SELECT UID FROM  #V_CP_CDF_ASSET)  
	  
	    IF  EXISTS (SELECT UID FROM  #V_CP_CDF_ASSET)  

		INSERT INTO    DBO.REPORT_V_CP_CDF_ASSET  
       (  
         CH_ID  
         ,CD_ID  
         ,ASSET_CD
         ,ASSETSERIALNUMBERID		 
         ,CDF1  
         ,CDF2  
         ,CDF3  
         ,CDF4  
         ,CDF5  
         ,CDF6  
         ,CDF7  
         ,CDF8  
         ,CDF9  
         ,CDF10  
         ,CDF11  
         ,CDF12  
         ,CDF13  
         ,CDF14  
         ,CDF15  
         ,CDF16  
         ,CDF17  
         ,CDF18  
         ,CDF19  
         ,CDF20 
        ,LASTREFRESHTIME
		,UID
		,CRC
		,InsertedByJobEntityInstanceId
		,UpdatedByJobEntityInstanceId
         )  
         SELECT CH_ID  
         ,CD_ID  
         --,ASSET_CD 
		 ,CAST(ASSET_CD AS VARCHAR(100)) AS ASSET_CD
         ,ASSETSERIALNUMBERID		 
         ,CDF1  
         ,CDF2  
         ,CDF3  
         ,CDF4  
         ,CDF5  
         ,CDF6  
         ,CDF7  
         ,CDF8  
         ,CDF9  
         ,CDF10  
         ,CDF11  
         ,CDF12  
         ,CDF13  
         ,CDF14  
         ,CDF15  
         ,CDF16  
         ,CDF17  
         ,CDF18  
         ,CDF19  
         ,CDF20   
		 ,LASTREFRESHTIME
		 ,UID
		 ,CRC1
		 ,1
		 ,1
         FROM #V_CP_CDF_ASSET 
		 SET @RowsProcessed = @RowsProcessed+ ISNULL((SELECT COUNT(*) FROM #V_CP_CDF_ASSET),0)  
  
       SET @NumRowsInserted = ISNULL((SELECT COUNT(*) FROM #V_CP_CDF_ASSET),0)  
  
                                                          UPDATE           [dbo].[REPORT_LOGS]  
                                                          SET                      EndTime = GETDATE(),  
                                                                               TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = @NumRowsInserted,  
                                                                                      RowsUpdated = @NumRowsUpdated,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = 1  
                                                          WHERE ReportLogId = @ReportLogId  
                             END TRY  
                             BEGIN CATCH  
                                                          SET @RowsProcessed = 0  
                                                          IF OBJECT_ID(N'TEMPDB..#V_CP_CDF_ASSET')  IS NOT NULL  
                                                          BEGIN  
                                                               SET @RowsProcessed = ISNULL((SELECT COUNT(*) FROM #V_CP_CDF_ASSET),0)  
                                                          END  
  
                                                          UPDATE              [dbo].[REPORT_LOGS]  
                                                          SET                      EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = 0,  
                                                                                      RowsUpdated = 0,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = -1,  
                                                                                      IsError = 1,  
                                                                                      ErrorMessage =  ERROR_MESSAGE()   
                                                          WHERE ReportLogId = @ReportLogId  
                             END CATCH  
 
       --------------------------------------------------------LOAD REPORT_V_ADDR--------------------------------------------------------------------

 ----------------------------LOADING OF ASSETLOCATIONS_REALTIME TABLE--------------------------------------
IF OBJECT_ID(N'TEMPDB..#ASSETLOCATIONS_REALTIME')  IS NOT NULL  
        BEGIN  
           DROP TABLE #ASSETLOCATIONS_REALTIME  
        END    
SELECT LOCATIONID,ASSETID,ISCURRENT
INTO #ASSETLOCATIONS_REALTIME
FROM (
SELECT  ALC.LOCATIONID,ALC.ASSETID,ALC.ISCURRENT 
FROM DATAHUB_ODESSA.ODH.ASSETLOCATIONS_REALTIME ALC (NOLOCK)
WHERE ALC.ISCURRENT = 1
UNION
SELECT  AL.LOCATIONID,AL.ASSETID,AL.ISCURRENT 
FROM DATAHUB_ODESSA.ODH.ASSETLOCATIONS_REALTIME AL (NOLOCK)
WHERE AL.LOCATIONID IN 
	   (SELECT LOCATIONID FROM DATAHUB_ODESSA.ODH.ASSETLOCATIONS_REALTIME  GROUP BY LOCATIONID HAVING COUNT(1)=1) AND ISCURRENT = 0) P
	   

--------------------------- Create index ---------------------------------------------------
CREATE NONCLUSTERED INDEX [ASSETLOCATIONS_REALTIME_INDX_LOCATIONID]
ON #ASSETLOCATIONS_REALTIME (LOCATIONID)
CREATE NONCLUSTERED INDEX [ASSETLOCATIONS_REALTIME_INDX_ASSETID]
ON #ASSETLOCATIONS_REALTIME (ASSETID)

 ----------------------------LOADING OF LEASEASSETS_REALTIME TABLE--------------------------------------
IF OBJECT_ID(N'TEMPDB..#LEASEASSETS_REALTIME')  IS NOT NULL  
        BEGIN  
           DROP TABLE #LEASEASSETS_REALTIME  
        END 
SELECT ASSETID,BILLTOID
INTO #LEASEASSETS_REALTIME
FROM
(SELECT ASSETID,BILLTOID,
ROW_NUMBER() OVER(PARTITION BY LA.ASSETID ORDER BY LA.CreatedTime DESC) AS ROWID
FROM DATAHUB_ODESSA.ODH.LEASEASSETS_REALTIME LA
WHERE (LA.ISACTIVE  =  1 OR LA.TERMINATIONDATE IS NOT NULL)) TEMPLA
WHERE ROWID = 1

--------------------------- Create index ---------------------------------------------------
CREATE NONCLUSTERED INDEX [LEASEASSETS_REALTIME_INDX_ASSETID]
ON #LEASEASSETS_REALTIME (ASSETID)
CREATE NONCLUSTERED INDEX [LEASEASSETS_REALTIME_INDX_BILLTOID]
ON #LEASEASSETS_REALTIME (BILLTOID)

	   
        PRINT 'LOAD REPORT_V_ADDR'  
                             SET @StartTime = GETDATE()  
                             INSERT INTO [dbo].[REPORT_LOGS]  
                             (  
                                                          JobInstanaceId,  
                                                          ProcessName,  
                                                          StartTime,  
                                                          StatusTypeId,
                                                          JobEntityId														  
                             )               
                             VALUES  
                            (  
                                                          @JOBINSTANCEID,  
                                                          'Sync DBO.REPORT_V_ADDR',  
                                                          GETDATE(),  
                                                          0,
                                                          18														  
                             )  
  
                             SET  @ReportLogId = SCOPE_IDENTITY()  
                             BEGIN TRY  
  
      PRINT 'LOAD REPORT_V_ADDR'  
      IF OBJECT_ID(N'TEMPDB..#REPORT_V_ADDR')  IS NOT NULL  
      BEGIN  
      DROP TABLE #REPORT_V_ADDR  
      END  
	  
	  DECLARE @LegacyADDRRowsCount BIGINT = 0   
      SELECT @LegacyADDRRowsCount=COUNT(1) FROM DBO.REPORT_V_ADDR WHERE PHONE2='0000000' 

	  IF OBJECT_ID(N'TEMPDB..#LS_AGRMNT_ITM')  IS NOT NULL  
      BEGIN  
      DROP TABLE #LS_AGRMNT_ITM  
      END 

      SELECT DISTINCT LS_AGRMNT_SHP_TO_ADDR
      INTO
      #LS_AGRMNT_ITM
      FROM DBO.LS_AGRMNT_ITM LI WITH(NOLOCK)
	  INNER JOIN  DBO.LS_AGRMNT LA WITH(NOLOCK) ON LI.LS_AGRMNT_ID=LA.LS_AGRMNT_ID
	  WHERE 0=@LegacyADDRRowsCount

--------------------------- Create index ---------------------------------------------------
CREATE NONCLUSTERED INDEX [LS_AGRMNT_ITM_LS_AGRMNT_SHP_TO_ADDR]
ON #LS_AGRMNT_ITM (LS_AGRMNT_SHP_TO_ADDR)

	  IF OBJECT_ID(N'TEMPDB..#LGCY_ADDR')  IS NOT NULL  
      BEGIN  
      DROP TABLE #LGCY_ADDR  
      END 

	  SELECT *
	  INTO
      #LGCY_ADDR
	  FROM
	  (
           SELECT  ROW_NUMBER() OVER (PARTITION BY ADDR_CD ORDER BY LGCY_ADDR_ID DESC) AS ROWNUM,LGCY_ADDR_ID,ADDR_CD,ADDR_1,ADDR_2,CTY,CNTY_NM,ST_CD,PSTL_CD,ISOCOUNTRYCODE
		   FROM [dbo].[LGCY_ADDR] ADDR WITH(NOLOCK) 
		   INNER JOIN #LS_AGRMNT_ITM LI WITH(NOLOCK) ON LI.LS_AGRMNT_SHP_TO_ADDR=ADDR.ADDR_CD
		   LEFT OUTER JOIN DBO.CTRY CTRY WITH(NOLOCK) ON ADDR.CTRY_CD=CTRY.CTRY_CD
		   WHERE  0=@LegacyADDRRowsCount
	  )ADR 
	  WHERE ROWNUM=1
	  
      SELECT DISTINCT ADDR_ID  
		,ADDR_CD   
		,ADDRESS1   
		,ADDRESS2   
		,CITY   
		,COUNTY_NAME 
		,STATE_CODE  
		,ZIP_CODE   
		,COUNTRY_CODE
		,ADDR_STR 
		,PHONE1   
		,PHONE2
		,PHONE_FAX
		,LASTREFRESHTIME
		,CONCAT(ADDR_ID,ADDR_CD) AS UID
		,HASHBYTES('MD5', CONCAT (ADDR_ID,ADDR_CD,ADDRESS1,ADDRESS2,CITY,COUNTY_NAME,STATE_CODE,ZIP_CODE,
		COUNTRY_CODE,ADDR_STR,PHONE1,PHONE2,PHONE_FAX)) AS CRC1
 INTO #REPORT_V_ADDR
 FROM (
            SELECT DISTINCT  
             TEMPLOCATION.ID                                                                    AS    ADDR_ID  
            ,TEMPLOCATION.CODE                                                                  AS    ADDR_CD   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.ADDRESSLINE1,'')   END                                    AS    ADDRESS1   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.ADDRESSLINE2,'') END                                      AS    ADDRESS2   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.CITY,'') END                                              AS    CITY   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.COUNTRY,'')  END                                          AS    COUNTY_NAME  
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.STATE,'')  END                                            AS    STATE_CODE  
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.POSTALCODE,'') END                                        AS    ZIP_CODE   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(TEMPLOCATION.COUNTRY,'')  END                                          AS    COUNTRY_CODE  
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE CONCAT_WS(', ',NULLIF(ISNULL(TEMPLOCATION.ADDRESSLINE1,''),'')   
                            ,NULLIF(ISNULL(TEMPLOCATION.ADDRESSLINE2,''),'')  
                            ,NULLIF(ISNULL(TEMPLOCATION.CITY,''),'')  
                            ,NULLIF(ISNULL(TEMPLOCATION.STATE,''),'')  
                            ,NULLIF(ISNULL(TEMPLOCATION.POSTALCODE,''),'')  
                            ,NULLIF(ISNULL(TEMPLOCATION.COUNTRY,''),''))  END                   AS    ADDR_STR   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(PARTYCONTACTS.PHONENUMBER1,'') END                                     AS    PHONE1   
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(PARTYCONTACTS.PHONENUMBER2,'') END                                     AS    PHONE2  
            ,CASE WHEN TEMPLOCATION.ISCURRENT = 0 THEN '' 
			 ELSE ISNULL(PARTYCONTACTS.FAXNUMBER,'')   END                                      AS    PHONE_FAX 
            ,GETDATE() LASTREFRESHTIME			
            
			
            FROM           #LEASEASSETS_REALTIME LEASEASSETS WITH (NOLOCK)  
            INNER JOIN      DATAHUB_ODESSA.ODH.ASSETS_REALTIME ASSETS WITH(NOLOCK) ON ASSETS.ID = LEASEASSETS.ASSETID
            INNER JOIN      DATAHUB_ODESSA.ODH.BILLTOES_REALTIME BILLTOES WITH (NOLOCK) ON BILLTOES.ID = LEASEASSETS.BILLTOID  
            INNER JOIN  
            (  
            SELECT          ASSETLOCATION.LOCATIONID,ASSETLOCATION.ASSETID AS ASSETID  ,ASSETLOCATION.ISCURRENT
                            ,LOCATION_REALTIME.ID,LOCATION_REALTIME.CODE,LOCATION_REALTIME.ADDRESSLINE1,LOCATION_REALTIME.ADDRESSLINE2,LOCATION_REALTIME.CITY  
                            ,LOCATION_REALTIME.POSTALCODE,COUNTRIES.SHORTNAME AS COUNTRY,STATES.SHORTNAME AS STATE  
            FROM            #ASSETLOCATIONS_REALTIME ASSETLOCATION WITH (NOLOCK)   
            INNER JOIN      DATAHUB_ODESSA.ODH.LOCATIONS_REALTIME LOCATION_REALTIME WITH (NOLOCK) ON LOCATION_REALTIME.ID = ASSETLOCATION.LOCATIONID AND LOCATION_REALTIME.ISACTIVE = 1   
            AND             LOCATION_REALTIME.APPROVALSTATUS='APPROVED'  
            INNER JOIN      DATAHUB_ODESSA.ODH.STATES_REALTIME STATES WITH (NOLOCK) ON LOCATION_REALTIME.STATEID = STATES.ID AND STATES.ISACTIVE = 1   
            INNER JOIN      DATAHUB_ODESSA.ODH.COUNTRIES_REALTIME COUNTRIES WITH (NOLOCK) ON STATES.COUNTRYID = COUNTRIES.ID AND COUNTRIES.ISACTIVE = 1  
            GROUP BY        ASSETLOCATION.LOCATIONID,ASSETLOCATION.ASSETID  
                           ,LOCATION_REALTIME.ID,LOCATION_REALTIME.CODE,LOCATION_REALTIME.ADDRESSLINE1,LOCATION_REALTIME.ADDRESSLINE2,   LOCATION_REALTIME.CITY   
                           ,LOCATION_REALTIME.POSTALCODE,COUNTRIES.SHORTNAME,STATES.SHORTNAME,ASSETLOCATION.ISCURRENT) TEMPLOCATION
			ON              TEMPLOCATION.ASSETID = ASSETS.ID  
			
            LEFT  JOIN      DATAHUB_ODESSA.ODH.PARTYCONTACTS_REALTIME PARTYCONTACTS WITH (NOLOCK) ON PARTYCONTACTS.ID = BILLTOES.BILLINGCONTACTPERSONID  

			UNION ALL --- No Address detail for Return assets -----


            SELECT               
             ''                                                         AS    ADDR_ID  
            ,''                                                         AS    ADDR_CD   
            ,''                                                         AS    ADDRESS1   
            ,''                                                         AS    ADDRESS2   
            ,''                                                         AS    CITY   
            ,''                                                         AS    COUNTY_NAME  
            ,''                                                         AS    STATE_CODE  
            ,''                                                         AS    ZIP_CODE   
            ,''                                                         AS    COUNTRY_CODE  
            ,''                                                         AS    ADDR_STR   
            ,''                                                         AS    PHONE1   
            ,''                                                         AS    PHONE2  
            ,''                                                         AS    PHONE_FAX 
            ,GETDATE() LASTREFRESHTIME			
            
			UNION ALL  --- Address detail for LEGECY TERMINATED ASSET  -----

			SELECT               
             CAST(LGCY_ADDR_ID AS VARCHAR(50))                          AS    ADDR_ID  
            ,ADDR_CD                                                    AS    ADDR_CD   
            ,ADDR_1                                                     AS    ADDRESS1   
            ,ADDR_2                                                     AS    ADDRESS2   
            ,CTY                                                        AS    CITY   
            ,CNTY_NM                                                    AS    COUNTY_NAME  
            ,ST_CD                                                      AS    STATE_CODE  
            ,PSTL_CD                                                    AS    ZIP_CODE   
            ,ISOCOUNTRYCODE                                             AS    COUNTRY_CODE  
            ,CONCAT_WS(', ',NULLIF(ISNULL(ADDR_1,''),'')   
                            ,NULLIF(ISNULL(ADDR_2,''),'')  
                            ,NULLIF(ISNULL(CTY,''),'')  
                            ,NULLIF(ISNULL(ST_CD,''),'')  
                            ,NULLIF(ISNULL(PSTL_CD,''),'')  
                            ,NULLIF(ISNULL(ISOCOUNTRYCODE,''),''))      AS    ADDR_STR   
            ,''                                                         AS    PHONE1   
            ,'0000000'                                                  AS    PHONE2  
            ,''                                                         AS    PHONE_FAX 
            ,GETDATE() LASTREFRESHTIME	
			FROM #LGCY_ADDR LG_ADDR WITH(NOLOCK)
			
            ) P
  
  ----------------------- Delete LEGECY Record if data already exist in table-----------------------
  DELETE FROM #REPORT_V_ADDR WHERE PHONE2='0000000' AND 0<>@LegacyADDRRowsCount
  
  --------------DUPLICATE DELETE---------------------------------
	   IF OBJECT_ID(N'TEMPDB..#V_ADDR')  IS NOT NULL  
        BEGIN  
           DROP TABLE #V_ADDR 
        END  
 		SELECT * INTO #V_ADDR FROM 
		(SELECT   
        ROW_NUMBER() OVER (PARTITION BY UID ORDER BY LastRefreshTime DESC) AS RID	
		  ,ADDR_ID  
          ,ADDR_CD  
          ,ADDRESS1  
          ,ADDRESS2  
          ,CITY  
          ,COUNTY_NAME  
          ,STATE_CODE  
          ,ZIP_CODE  
          ,COUNTRY_CODE  
          ,ADDR_STR  
          ,PHONE1  
          ,PHONE2  
          ,PHONE_FAX 
          ,LASTREFRESHTIME
          ,UID
          ,CRC1
        FROM #REPORT_V_ADDR) ADDR
		WHERE RID = 1
		
		CREATE CLUSTERED INDEX [REPORT_V_ADDR_INDX1_UID]  
					ON #V_ADDR ([UID])  
	   
	      DELETE FROM     #V_ADDR  WHERE UID IN (SELECT SUMRY.UID FROM DBO.REPORT_V_ADDR SUMRY
                                                          INNER JOIN #V_ADDR IDS WITH(NOLOCK) 
														  ON SUMRY.UID = IDS.UID AND SUMRY.CRC = IDS.CRC1) 
	 
	 ---DELETING THE UID FROM MAIN TABLE-----------------
		DELETE FROM DBO.REPORT_V_ADDR  WHERE UID IN (SELECT UID FROM  #V_ADDR)  
	  
	    IF  EXISTS (SELECT UID FROM  #V_ADDR) 
		
        INSERT INTO DBO.REPORT_V_ADDR  
        (  
           ADDR_ID  
          ,ADDR_CD  
          ,ADDRESS1  
          ,ADDRESS2  
          ,CITY  
          ,COUNTY_NAME  
          ,STATE_CODE  
          ,ZIP_CODE  
          ,COUNTRY_CODE  
          ,ADDR_STR  
          ,PHONE1  
          ,PHONE2  
          ,PHONE_FAX 
          ,LASTREFRESHTIME	
          ,UID
          ,CRC
          ,InsertedByJobEntityInstanceId
		  ,UpdatedByJobEntityInstanceId		  
        )  
        SELECT   
          ADDR_ID  
          ,ADDR_CD  
          ,ADDRESS1  
          ,ADDRESS2  
          ,CITY  
          ,COUNTY_NAME  
          ,STATE_CODE  
          ,ZIP_CODE  
          ,COUNTRY_CODE  
          ,LEFT(ADDR_STR,250) AS ADDR_STR   --V9.0
          ,PHONE1  
          ,PHONE2  
          ,PHONE_FAX 
          ,LASTREFRESHTIME
		  ,UID
          ,CRC1
		  ,1
		  ,1
        FROM    #V_ADDR  
  
       SET @RowsProcessed = @RowsProcessed+ ISNULL((SELECT COUNT(*) FROM #V_ADDR),0)  
  
       SET @NumRowsInserted = ISNULL((SELECT COUNT(*) FROM #V_ADDR),0)  
  
                                                          UPDATE           [dbo].[REPORT_LOGS]  
                                                          SET                         EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = @NumRowsInserted,  
                                                                                      RowsUpdated = @NumRowsUpdated,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = 1  
                                                          WHERE ReportLogId = @ReportLogId  
                             END TRY  
                             BEGIN CATCH  
                                                          SET @RowsProcessed = 0  
                                                          IF OBJECT_ID(N'TEMPDB..#V_ADDR')  IS NOT NULL  
                                                          BEGIN  
                                                                SET @RowsProcessed = ISNULL((SELECT COUNT(*) FROM #V_ADDR),0)  
                                                          END  
  
                                                          UPDATE              [dbo].[REPORT_LOGS]  
                                                          SET                         EndTime = GETDATE(),  
                                                                                      TimeTaken = convert(char(8),dateadd(s,datediff(s,StartTime,GETDATE()),'1900-1-1'),8),  
                                                                                      RowsProcessed = @RowsProcessed,  
                                                                                      RowsInserted = 0,  
                                                                                      RowsUpdated = 0,  
                                                                                      RowsDeleted = 0,  
                                                                                      StatusTypeId = -1,  
                                                                                      IsError = 1,  
                                                                                      ErrorMessage =  ERROR_MESSAGE()   
                                                          WHERE ReportLogId = @ReportLogId  
                             END CATCH  
--------------------------------------------------------------------------------------------------------------------------------------------------
 ----------------------DELETE FROM 1 YEAR TERMINATED DATA-----------------------------------
 PRINT 'LOAD TERMINATEDCONTRACT'              
  IF OBJECT_ID(N'TEMPDB..#TERMINATEDCONTRACT')  IS NOT NULL              
 BEGIN              
   DROP TABLE #TERMINATEDCONTRACT              
  END      
  

 SELECT   
 CONTRACTID,  SEQUENCENUMBER,  TerminationDate  
  INTO     #TERMINATEDCONTRACT              
  FROM    
  (
  
	  SELECT CT.Id AS CONTRACTID,CT.SEQUENCENUMBER, MAX(LA.TerminationDate) AS TerminationDate   
	  FROM DATAHUB_ODESSA.ODH.Contracts_Realtime CT WITH (NOLOCK) 
	  JOIN DATAHUB_ODESSA.ODH.LeaseFinances_Realtime LF WITH (NOLOCK) ON LF.CONTRACTID=CT.ID AND LF.IsCurrent = 1 
	  JOIN DATAHUB_ODESSA.ODH.LeaseAssets_Realtime LA WITH (NOLOCK) ON LA.LeaseFinanceId = LF.Id 
	  WHERE LF.BookingStatus  IN ('FullyPaidOff','TERMINATED') GROUP BY CT.ID,CT.SEQUENCENUMBER
	  
	  UNION --- Pick Terminated contracts from legacy which was not migrated to odessa for migarated GEO

	  SELECT LA.LS_AGRMNT_ID AS CONTRACTID,LA.LS_AGRMNT_NR AS SEQUENCENUMBER,MAX(LA.LS_AGRMNT_TRMN_DT) AS TerminationDate   
	  FROM DBO.LS_AGRMNT LA  WITH(NOLOCK)
	  LEFT  JOIN DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CT WITH(NOLOCK) ON CT.SEQUENCENUMBER = LA.LS_AGRMNT_NR
	  WHERE CT.SEQUENCENUMBER IS NULL AND DATEDIFF(MONTH, ISNULL(LA.LS_AGRMNT_TRMN_DT, CAST(GETDATE() AS DATE)), GETDATE()) >= 13 AND LA.LS_AGRMNT_STTS_CD='TERMINATED'
	  GROUP BY  LA.LS_AGRMNT_ID,LA.LS_AGRMNT_NR
  
  ) ABC
  WHERE DATEDIFF(MONTH, ISNULL(TERMINATIONDATE,CAST(GETDATE() AS DATE)), GETDATE()) >= 13;  
  


 DELETE FROM DBO.REPORT_V_CP_CONTRACT WHERE CNTRCT_NO IN (SELECT SEQUENCENUMBER FROM #TERMINATEDCONTRACT)
 
  --------------------------------------------------------------------------------------------------------------------------------------------------
  SELECT   
    1         AS JOBSTATUSTYPEID  
   ,0         AS ISERROR  
   ,NULL        AS ERRORDESCRIPTION  
   ,0         AS NUMROWSUPDATED  
   ,@RowsProcessed         AS NUMROWSINSERTED       
  
 END TRY   
 BEGIN CATCH  
  INSERT INTO [DATAHUBETL].[JOBERRORLOGS]   
  (  
   JOBENTITYID  
   ,ERRORDESCRIPTION  
   ,ERRORCODE  
   ,STACKTRACE  
   ,ACTIVITYSTATUS  
   ,VALIDATIONSTATUS  
   ,USERCREATEDID  
   ,USERCREATEDTIMESTAMP  
   ,INSERTEDBYJOBENTITYINSTANCEID  
     )  
  VALUES   
  (  
   18  
   ,ERROR_MESSAGE()  
   ,ERROR_NUMBER()  
   ,'ERROR BLOCK'  
   ,'FAIL'  
   ,'FAIL'  
   ,CURRENT_USER  
   ,GETDATE()  
   ,@JOBINSTANCEID  
  )  
  
  SELECT   
   - 1 AS JOBSTATUSTYPEID  
   ,1 AS ISERROR  
   ,ERROR_MESSAGE() AS ERRORDESCRIPTION  
   ,0 AS NUMROWSUPDATED  
   ,@RowsProcessed AS NUMROWSINSERTED  
 END CATCH  
END