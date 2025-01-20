


    
CREATE   PROCEDURE [dbo].[LOAD_CP_OPEN_CLOSED_INVOICES]              
--ADD THE PARAMETERS FOR THE STORED PROCEDURE HERE                  
 @JOBINSTANCEID BIGINT               
---------------- Modification Log ----------------------------------------------------------------------------------------------                                              
-- DATE            Release                   WHO        Comments                                                                                           
-- ---------    -------              ----------        ----------                                                                                   
-- 04/07/2023    V1.0                DH team (RS)    Initial Version of SP             
-- 18/07/2023    V2.0                DH team (SP)    Added New Logic of StartDate and EndDate             
-- 02/08/2023    V3.0                DH team (SP)    Added New Logic for Invoice Type and Begin date and End Date         
-- 09/08/2023    V4.0                DH team (SP)    Added OBI Invoices exclude logic        
-- 17/08/2023    V5.0                DH team (BM)    Added Terminated contract logic      
-- 23/08/2023    V6.0                DH team (SN)    Removal OBI Invoices exclusion logic     
-- 26/09/2023    V6.0                DH team (PN)    Added OBI Invoices exclusion logic (OBI_STATUS <> NO IMAGE,NO DELIVER)    
-- 26/09/2023    V7.0                DH team (SP)    Added New logic for last received date field  
-- 29/09/2023    V8.0                DH team (RS)    Physicalized the Customer details all status view into table  
-- 06/19/2023    V9.0                DH team (PN)    Added OBI Invoices  logic (OBI_STATUS = Generated,Delivered)  
-- 16/05/2024	 v10.0				 DH team (RS)	 Added Active filter for invoices - Isactive=1 - New change during May MTP
-- 25/06/2024    V11.0				 DH team (RS)	 Added logic for consolidated invoice Issue476
---------------- End Modification Log ------------------------------------------------------------------------------------------                                               
--------------------------------------------------------------------------------------------------------------------------------                           
              
            
AS                
BEGIN                
            
            
 BEGIN TRY          
 DECLARE @NUMBEROFROWPROCESSED BIGINT = 0  
 
 
/************************* 06/10/2023 *******************************************/

	    
  IF OBJECT_ID(N'TEMPDB..#OBI_INVOICES')  IS NOT NULL                
  BEGIN                
   DROP TABLE #OBI_INVOICES                
  END     
    
  SELECT * INTO #OBI_INVOICES FROM    
  (    
   SELECT *   
   FROM DATAHUB_ODESSA.ODH.RECEIVABLEINVOICES_REALTIME RI    
   WHERE RI.LEGACYINVOICENUMBER IS NOT NULL AND ISACTIVE=1 
     
   UNION ALL     
   /*LOGIC FOR ALL NON MIGRATED INVOICES (WITHOUT A LEGACY INVOICE NUMBER) THAT HAVE A STATUS GENERATED OR WERE DELIVERED */   
     
   SELECT RI.*   
   FROM DATAHUB_ODESSA.ODH.RECEIVABLEINVOICES_REALTIME RI   
   LEFT JOIN DATAHUB_ODESSA.ODH.OBISTATUSCONFIGS OSC ON RI.OBISTATUSID = OSC.ID    
   WHERE RI.LEGACYINVOICENUMBER IS NULL AND RI.ISACTIVE=1     
   AND RI.INVOICEPREFERENCE = 'GENERATEANDDELIVER'     
   AND ( (OSC.STATUS ='Generated' AND ISNULL(DeliveryPreference,'') NOT LIKE ('%Deliver%'))
    OR (OSC.STATUS = 'Delivered' AND ISNULL(DeliveryPreference,'') LIKE ('%Deliver%')) )  
  )A  
    
-------------------------------------------JOB PART 1                
 PRINT 'LOAD CP_OPEN_CLOSED_INVOICES'                
  IF OBJECT_ID(N'TEMPDB..#CP_OPEN_CLOSED_INVOICES')  IS NOT NULL                
  BEGIN                
   DROP TABLE #CP_OPEN_CLOSED_INVOICES                
  END                
       
       DECLARE @MIGRATIONEFFECTIVEDATE DATE                 
       -- STORING THE MIGRATIVE EFFECTIVE DATE AS PART OF MIGRATION                
       SELECT @MIGRATIONEFFECTIVEDATE = MIGRATIONEFFECTIVEDATE            
                    
       FROM                
       (SELECT TOP 1 MIGRATIONEFFECTIVEDATE                 
       FROM DBO.CTRY A WITH(NOLOCK)                
       JOIN DATAHUB_ODESSA.ODH.COUNTRIES_REALTIME B WITH(NOLOCK)            
       ON A.ISOCOUNTRYCODE = B.SHORTNAME                
       WHERE A.MIGRATEDFLAG='Y') ABC                 
                
        ------- JOB PART 1                
                
        SELECT DISTINCT                 
         CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN CAST(CI.INVOICE_STATEMENT_NUMBER AS VARCHAR(20))                
               WHEN RI.LEGACYINVOICENUMBER IS NULL THEN CAST(RI.NUMBER AS VARCHAR(20))                
          ELSE CAST(RI.NUMBER AS VARCHAR(20)) END                 
          + '|' +                
          CASE WHEN CST.NAME  IN('DIRECT', 'VENDOR') THEN PR.PARTYNUMBER                 
               WHEN CST.NAME = 'SERVICEPROVIDER' THEN SP.PARTYNUMBER                
          ELSE PR.PARTYNUMBER END                 
          + '_' +                 
          ISNULL(BU.NAME,'')                 
          + '|' +                 
          CAST(CASE WHEN CONT.ID = CPI.ID THEN 'Y' ELSE 'N' END AS VARCHAR(20))                                                   AS PID                
                        
        , CASE WHEN CST.NAME IN('DIRECT', 'VENDOR') THEN  PR.PARTYNAME                
                    WHEN CST.NAME = 'SERVICEPROVIDER' THEN SP.PARTYNAME + '/' + PR.PARTYNAME                
                    ELSE PR.PARTYNAME END                                                                                         AS CSTMR_NM                                  
        , CASE WHEN CST.NAME IN('DIRECT', 'VENDOR') THEN PR.PARTYNUMBER                
                    WHEN CST.NAME = 'SERVICEPROVIDER' THEN SP.PARTYNUMBER                
                    ELSE PR.PARTYNUMBER END                                                                                       AS CSTMR_CD                                    
        , BU.NAME                                                                                                                 AS GEO_CD                
        , COU.ISO_COUNTRYCODE                                                                                                     AS CNTRY_CD                
        , RI.CURRENCYISO                                                                                                          AS CUR_CD                
        , CONT.SEQUENCENUMBER                                         															  AS CNTRCT_NO                
                  
        , CASE WHEN CST.NAME IN('DIRECT', 'VENDOR') THEN  LF.PROJECTNAME                
            WHEN CST.NAME = 'SERVICEPROVIDER' THEN SBU.SERVICEPROVIDERBUSINESSUNIT                
          ELSE LF.PROJECTNAME END                                                                                                 AS B_UNIT                
                        
        , CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN CAST(CI.INVOICE_STATEMENT_NUMBER AS VARCHAR(20))                
                    WHEN RI.LEGACYINVOICENUMBER IS NULL THEN CAST(RI.NUMBER AS VARCHAR(20))                
                    ELSE CAST(RI.NUMBER AS VARCHAR(20)) END                                                                       AS INV_STMT_NBR                
                        
        , CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN CI.CREATE_DATE                
                    WHEN RI.LEGACYINVOICENUMBER IS NULL THEN RI.INVOICERUNDATE                
                    ELSE RI.INVOICERUNDATE END                                                                                    AS CREATE_DT                
               
        , CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN CI.DUE_DATE                
                    WHEN RI.LEGACYINVOICENUMBER IS NULL THEN RI.DUEDATE                
                    ELSE RI.DUEDATE  END                                                                                          AS DUE_DT            
      
        , CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN CI.statement_type      
               ELSE NULL END                                            AS TRAN_TYPE         
                        
        , CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN CI.INVOICE_AMOUNT_DUE                
                    WHEN RI.LEGACYINVOICENUMBER IS NULL THEN RI.INVOICEAMOUNT_AMOUNT + RI.INVOICETAXAMOUNT_AMOUNT                
                    END                                                                                                            AS ORIG_STMT_AMT                
                        
        , CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN RII.BALANCE_AMOUNT + RII.TAXBALANCE_AMOUNT                
                    WHEN RI.LEGACYINVOICENUMBER IS NULL THEN RI.BALANCE_AMOUNT + RI.TAXBALANCE_AMOUNT                 
                    END                                                                                                            AS OPEN_BAL_AMT                
                
                        
        , CASE WHEN CONT.ID = CPI.ID THEN 'Y' ELSE 'N' END                                                                        AS IS_METERING_CNTRCT                
                        
        , CASE WHEN CST.NAME IN('DIRECT', 'VENDOR') THEN  PR.PARTYNUMBER                
                    WHEN CST.NAME = 'SERVICEPROVIDER' THEN SP.PARTYNUMBER                
                    ELSE PR.PARTYNUMBER END                                                                                       AS PARTYNUMBER_DIRECT                
                        
        , CASE WHEN CST.NAME IN('DIRECT', 'VENDOR') THEN  PR.PARTYNUMBER                
                    WHEN CST.NAME = 'SERVICEPROVIDER' THEN PR.PARTYNUMBER                
                    ELSE PR.PARTYNUMBER END                                                                                       AS PARTYNUMBER_SP                
                              
     ,COALESCE(              
    CASE WHEN CI.INVOICE_STATEMENT_NUMBER=RI.LEGACYINVOICENUMBER THEN               
     CASE               
      WHEN DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,CI.DUE_DATE), GETDATE()) < = 30              
      AND DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,CI.DUE_DATE), GETDATE()) > 0              
      THEN RII.BALANCE_AMOUNT + RII.TAXBALANCE_AMOUNT              
      END              
             ELSE               
    CASE               
      WHEN DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,RI.DUEDATE), GETDATE()) < = 30              
       AND DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,RI.DUEDATE), GETDATE()) > 0              
       THEN RI.BALANCE_AMOUNT + RI.TAXBALANCE_AMOUNT              
      END               
     END, NULL,0)                                                               AS CP_0_30              
              
    ,COALESCE(              
     CASE WHEN CI.INVOICE_STATEMENT_NUMBER=RI.LEGACYINVOICENUMBER THEN               
      CASE               
       WHEN DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,CI.DUE_DATE), GETDATE()) < = 60              
       AND DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,CI.DUE_DATE), GETDATE()) > 30              
       THEN RII.BALANCE_AMOUNT + RII.TAXBALANCE_AMOUNT              
      END              
    ELSE               
      CASE               
       WHEN DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,RI.DUEDATE), GETDATE()) < = 60              
       AND DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,RI.DUEDATE), GETDATE()) > 30              
       THEN RI.BALANCE_AMOUNT + RI.TAXBALANCE_AMOUNT   
      END               
      END, NULL,0)                                                              AS CP_31_60              
              
    ,COALESCE(              
     CASE WHEN CI.INVOICE_STATEMENT_NUMBER=RI.LEGACYINVOICENUMBER THEN               
       CASE               
       WHEN DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,CI.DUE_DATE), GETDATE()) > 60              
       THEN RII.BALANCE_AMOUNT + RII.TAXBALANCE_AMOUNT              
    END              
    ELSE               
      CASE               
       WHEN DATEDIFF(DAY, DATEADD(DD,LE.THRESHOLDDAYS,RI.DUEDATE), GETDATE()) > 60              
       THEN RI.BALANCE_AMOUNT + RI.TAXBALANCE_AMOUNT              
      END                                      
     END, NULL,0)                                                               AS CP_60              
                    
   ,CASE      WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN RII.BALANCE_AMOUNT + RII.TAXBALANCE_AMOUNT                
        WHEN RI.LEGACYINVOICENUMBER IS NULL THEN RI.BALANCE_AMOUNT + RI.TAXBALANCE_AMOUNT                
      END                                                   AS AMOUNT            
               
      ,BIL.NAME AS BILTONAME              
      ,CI.PERIOD_BEGIN_DATE  AS LEGACY_BEGIN_DT                
      ,CI.PERIOD_END_DATE  AS LEGACY_END_DT              
      ,CI.INVOICE_STATEMENT_NUMBER AS LEGACY_INVOICE_NUMBER              
      ,RI.LEGACYINVOICENUMBER AS RI_LEGACYINVOICENUMBER            
      --,RI.LASTRECEIVEDDATE AS RI_LAST_RECEIVED_DATE      
      ,CASE WHEN CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER THEN COALESCE (RII.LASTRECEIVEDDATE, RII.DUE_DATE)     
         ELSE COALESCE (RI.LASTRECEIVEDDATE , RI.DUEDATE) END                    AS RI_LAST_RECEIVED_DATE   
	 
  
        INTO #CP_OPEN_CLOSED_INVOICES                
        FROM                 
        (        
   SELECT * FROM  #OBI_INVOICES WITH (NOLOCK)                
   WHERE INVOICERUNDATE >= @MIGRATIONEFFECTIVEDATE         
        
     /*AND NUMBER NOT IN (SELECT NUMBER FROM #EXCLUDED_OBI_INVOICES)  */      
        
        ) RI      
        
        INNER JOIN       DATAHUB_ODESSA.ODH.BILLTOES_REALTIME BIL WITH (NOLOCK) ON BIL.ID = RI.BILLTOID                
        INNER JOIN       DATAHUB_ODESSA.ODH.PARTIES_REALTIME PR WITH(NOLOCK) ON PR.ID = RI.CUSTOMERID                
        INNER JOIN                
        (SELECT DISTINCT    SEQUENCENUMBER, RECEIVABLEINVOICEID                
                FROM  DATAHUB_ODESSA.ODH.RECEIVABLEINVOICEDETAILS_REALTIME WITH(NOLOCK)                 
        ) RID ON RI.ID = RID.RECEIVABLEINVOICEID                
                        
        /*CONTRACT DETAIL*/                
        LEFT OUTER JOIN  DATAHUB_ODESSA.ODH.CONTRACTS_REALTIME CONT WITH(NOLOCK) ON RID.SEQUENCENUMBER=CONT.SEQUENCENUMBER                
        LEFT OUTER JOIN  DATAHUB_ODESSA.ODH.LEASEFINANCES_REALTIME LF WITH(NOLOCK) ON LF.CUSTOMERID=PR.ID AND LF.CONTRACTID=CONT.ID AND LF.ISCURRENT = 1                 
                        
        INNER JOIN       DATAHUB_ODESSA.ODH.LEGALENTITIES_REALTIME LE WITH(NOLOCK) ON LE.ID=RI.LEGALENTITYID                
        INNER JOIN       DATAHUB_ODESSA.ODH.BUSINESSUNITS BU WITH(NOLOCK) ON BU.ID=LE.BUSINESSUNITID                 
                        
        /*COUNTRY*/                
        INNER JOIN      DATAHUB_ODESSA.ODH.CUSTOMERS_REALTIME C WITH(NOLOCK) ON PR.ID = C.ID                
        INNER JOIN      DATAHUB_ODESSA.ODH.PARTYADDRESSES_REALTIME PA WITH(NOLOCK) ON C.ID = PA.PARTYID /*AND PA.ISACTIVE = 1*/ AND PA.ISMAIN = 1                
        INNER JOIN      DATAHUB_ODESSA.ODH.STATES_REALTIME ST  WITH(NOLOCK)  ON PA.STATEID = ST.ID                
        INNER JOIN      DATAHUB_ODESSA.ODH.COUNTRIES_REALTIME COU  WITH(NOLOCK) ON COU.ID = ST.COUNTRYID                 
                        
        /*PYRAMID MIGARTION DATA*/                
        LEFT OUTER JOIN DBO.CUSTOMERINVOICE CI  WITH(NOLOCK) ON CI.INVOICE_STATEMENT_NUMBER = RI.LEGACYINVOICENUMBER                
                        AND CI.PARTYNUMBER = PR.PARTYNUMBER AND CI.CONTRACT_NUMBER = CONT.SEQUENCENUMBER     
        
        /*MULTIPLE ENTRY FOR SAME LEGACY INVOICE NUMBER*/                
        LEFT OUTER JOIN(SELECT                
                                LEGACYINVOICENUMBER,                
                                SUM(BALANCE_AMOUNT) AS BALANCE_AMOUNT,                
                                SUM(TAXBALANCE_AMOUNT) AS TAXBALANCE_AMOUNT,       
                                MAX(LASTRECEIVEDDATE) AS LASTRECEIVEDDATE  ,    
								MAX(DUEDATE) AS DUE_DATE    
                           FROM DATAHUB_ODESSA.ODH.RECEIVABLEINVOICES_REALTIME  WITH(NOLOCK)                
                           WHERE LEGACYINVOICENUMBER IS NOT NULL AND ISACTIVE=1               
                           GROUP BY LEGACYINVOICENUMBER
						) RII ON RII.LEGACYINVOICENUMBER = CI.INVOICE_STATEMENT_NUMBER                    
              
                            
        /*IS METERED FLAG*/                
        LEFT JOIN DATAHUB_ODESSA.ODH.CPICONTRACTS_REALTIME CPI  WITH(NOLOCK) ON CONT.ID = CPI.CONTRACTID                
                        
        /*SERVICE PROVIDER DETAILS*/                
        LEFT OUTER JOIN DATAHUB_ODESSA.ODH.CONTRACTORIGINATIONS_REALTIME CO  WITH(NOLOCK) ON LF.CONTRACTORIGINATIONID = CO.ID                
        LEFT OUTER JOIN DATAHUB_ODESSA.ODH.PARTIES_REALTIME SP  WITH(NOLOCK) ON SP.ID = CO.ORIGINATIONSOURCEID                
        LEFT OUTER JOIN DATAHUB_ODESSA.ODH.ORIGINATIONSOURCETYPES_REALTIME CST  WITH(NOLOCK) ON CO.ORIGINATIONSOURCETYPEID = CST.ID AND CST.NAME IN('DIRECT', 'VENDOR', 'SERVICEPROVIDER')                
        LEFT OUTER JOIN DATAHUB_ODESSA.ODH.SERVICELEDBUSINESSUNITS_REALTIME SBU  WITH(NOLOCK) ON SBU.ID = LF.SERVICELEDBUSINESSUNITID               
              
              
  DECLARE @NUMBEROFROWTOBEDELETE BIGINT            
  SET  @NUMBEROFROWTOBEDELETE  = ISNULL((SELECT COUNT(*) FROM DBO.CP_OPEN_CLOSED_INVOICES),0)            
            
    TRUNCATE TABLE  DBO.CP_OPEN_CLOSED_INVOICES                
       INSERT INTO    DBO.CP_OPEN_CLOSED_INVOICES   
       (                
            PID                    
           ,CSTMR_NM                   
           ,CSTMR_CD                   
           ,GEO_CD                   
           ,CNTRY_CD         
           ,CUR_CD                   
           ,CNTRCT_NO                   
           ,B_UNIT                      
           ,INV_STMT_NBR                  
           ,CREATE_DT                   
           ,DUE_DT        
           ,TRAN_TYPE      
           ,ORIG_STMT_AMT                  
           ,OPEN_BAL_AMT                  
           ,LEGACY_BEGIN_DT                   
           ,LEGACY_END_DT                   
           ,IS_METERING_CNTRCT                
           ,PARTYNUMBER_DIRECT                
           ,PARTYNUMBER_SP                    
           ,CP_0_30                           
           ,CP_31_60                          
           ,CP_60                 
           ,AMOUNT               
     ,BILTONAME              
     ,LEGACY_INVOICE_NUMBER              
     ,RI_LEGACYINVOICENUMBER       
     ,RI_LAST_RECEIVED_DATE        
           )                
            SELECT DISTINCT                 
             PID                    
            ,CSTMR_NM                   
            ,CSTMR_CD                   
            ,GEO_CD                   
            ,CNTRY_CD                   
            ,CUR_CD                         
			,CNTRCT_NO_NEW AS CNTRCT_NO
            ,B_UNIT                      
            ,INV_STMT_NBR                  
            ,CREATE_DT                   
            ,DUE_DT        
            ,TRAN_TYPE           
            ,ORIG_STMT_AMT                  
            ,OPEN_BAL_AMT                  
            ,LEGACY_BEGIN_DT                   
            ,LEGACY_END_DT                   
            ,IS_METERING_CNTRCT                
            ,PARTYNUMBER_DIRECT                
            ,PARTYNUMBER_SP                    
            ,CP_0_30                           
            ,CP_31_60                          
            ,CP_60                 
            ,AMOUNT              
            ,BILTONAME              
            ,LEGACY_INVOICE_NUMBER              
            ,RI_LEGACYINVOICENUMBER              
            ,RI_LAST_RECEIVED_DATE
			FROM
			   ( SELECT ROW_NUMBER() OVER (PARTITION BY CSTMR_CD,INV_STMT_NBR ORDER BY CNTRCT_NO) AS RN
				 ,CASE WHEN COUNT(INV_STMT_NBR) OVER (PARTITION BY CSTMR_CD,INV_STMT_NBR) > 1 THEN 'Multiple'
				  ELSE CNTRCT_NO END AS CNTRCT_NO_NEW  
				 ,CP_INV.*
				  FROM #CP_OPEN_CLOSED_INVOICES CP_INV              
				  WHERE CSTMR_CD=SUBSTRING(BILTONAME,1,CHARINDEX('-',BILTONAME,1)-1) 
			   )  B WHERE RN=1 
					 
                  
  DECLARE @NUMBEROFROWINSERTED BIGINT = 0            
  SET  @NUMBEROFROWINSERTED =  @NUMBEROFROWINSERTED + ISNULL((SELECT COUNT(*) FROM DBO.CP_OPEN_CLOSED_INVOICES),0)                
                        
        --------------------------------------------JOB PART 2=V_INVOIVE_TYPES------------------------------------------------                
                  
  PRINT 'LOAD CP_INVOICE_TYPES'                
  IF OBJECT_ID(N'TEMPDB..#CP_INVOICE_TYPES')  IS NOT NULL                
   BEGIN                
         DROP TABLE #CP_INVOICE_TYPES                
   END                
            
          
/* ABOVE QUERY IS UPDATED FOR BEGIN DATE, END DATE AND INVOICE TYPE LOGIC */          
          
    SELECT                 
    INVOICE_NUMBER,                
    INVOICETYPE,            
    MIN(STARTDATE) AS STARTDATE,            
    MAX(ENDDATE) AS ENDDATE            
    INTO     #CP_INVOICE_TYPES                
  FROM                 
  (                 
   SELECT                 
    INVOICE_NUMBER,                               
    CASE  WHEN COUNT(INVOICE_NUMBER) OVER (PARTITION BY INVOICE_NUMBER) > 1 THEN RC_CATEGORY                
     ELSE DERIVED_INVOICETYPE                 
    END AS INVOICETYPE          
    ,STARTDATE           
    ,ENDDATE             
   FROM                 
   (                 
    SELECT              DISTINCT                   
     RI.NUMBER AS INVOICE_NUMBER,                  
        R.RECEIVABLECODEID   AS RECEIVABLECODEID,             
        --BTIP.RECEIVABLETYPELANGUAGELABELID AS BTIP_RECEIVABLETYPELANGUAGELABELID,          
        RT.NAME RT_NAME,        
  --,RTLC.NAME AS RTLC_NAME,RTLL.INVOICELABEL AS RTLL_INVOICELABEL,RCD.NAME AS RCD_NAME,RCLL.INVOICELABEL AS RCLL_INVOICELABEL,                      
        RC.NAME RC_CATEGORY,               
    LPS.STARTDATE ,LPS.ENDDATE ,              
                 
     CASE                       
        WHEN RT.NAME NOT IN ('SUNDRY','SUNDRYSEPARATE','LATEFEE','PROPERTYTAX','PROPERTYTAXESCROW','SecurityDeposit') AND BTIP.RECEIVABLETYPELANGUAGELABELID IS NULL                       
        THEN RTLC.NAME                      
                                 
        WHEN RT.NAME NOT IN ('SUNDRY','SUNDRYSEPARATE','LATEFEE','PROPERTYTAX','PROPERTYTAXESCROW','SecurityDeposit') AND BTIP.RECEIVABLETYPELANGUAGELABELID IS NOT NULL                      
        THEN RTLL.INVOICELABEL                       
                                   
        WHEN RT.NAME IN ('SUNDRY','SUNDRYSEPARATE','LATEFEE','PROPERTYTAX','PROPERTYTAXESCROW','SecurityDeposit') AND RCLL.LANGUAGECONFIGID IS NULL                      
        THEN RCD.NAME          
                  
        WHEN RT.NAME IN ('SUNDRY','SUNDRYSEPARATE','LATEFEE','PROPERTYTAX','PROPERTYTAXESCROW','SecurityDeposit') AND RCLL.LANGUAGECONFIGID IS NOT NULL AND RCLL.INVOICELABEL IS NULL                    
        THEN RCD.NAME          
                                  
        WHEN RT.NAME IN ('SUNDRY','SUNDRYSEPARATE','LATEFEE','PROPERTYTAX','PROPERTYTAXESCROW','SecurityDeposit') AND RCLL.LANGUAGECONFIGID IS NOT NULL                      
        THEN RCLL.INVOICELABEL                      
      END AS DERIVED_INVOICETYPE                
                  
    FROM               DATAHUB_ODESSA.ODH.RECEIVABLEINVOICES_REALTIME RI                 
    INNER JOIN         DATAHUB_ODESSA.ODH.RECEIVABLEINVOICEDETAILS_REALTIME RID ON RI.ID=RID.RECEIVABLEINVOICEID                       
    INNER JOIN         DATAHUB_ODESSA.ODH.RECEIVABLEDETAILS_REALTIME RD ON RD.ID=RID.RECEIVABLEDETAILID                       
    INNER JOIN         DATAHUB_ODESSA.ODH.RECEIVABLES_REALTIME R ON R.ID=RD.RECEIVABLEID AND R.ISACTIVE = 1                      
    INNER JOIN         DATAHUB_ODESSA.ODH.RECEIVABLECODES_REALTIME RCD WITH(NOLOCK) ON RCD.ID = R.RECEIVABLECODEID                       
    INNER JOIN         DATAHUB_ODESSA.ODH.RECEIVABLETYPES_REALTIME RT WITH(NOLOCK) ON RT.ID = RCD.RECEIVABLETYPEID                 
    INNER JOIN         DATAHUB_ODESSA.ODH.RECEIVABLECATEGORIES RC WITH(NOLOCK) ON RC.ID = RID.RECEIVABLECATEGORYID                
                 
    /*BELOW CODE IS TO START AND END DATE FOR ANY INVOICE*/                
                
   LEFT OUTER JOIN DATAHUB_ODESSA.ODH.LEASEPAYMENTSCHEDULES LPS ON R.PAYMENTSCHEDULEID = LPS.ID                
              
    LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.BILLTOES_REALTIME  BT WITH(NOLOCK)  ON BT.ID = RI.BILLTOID                      
    LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.RECEIVABLECODELANGUAGELABELS_REALTIME RCLL WITH(NOLOCK) ON RCLL.RECEIVABLECODEID = RCD.ID AND RCLL.ISACTIVE=1                      
    LEFT OUTER JOIN    (SELECT NAME, RECEIVABLETYPEID,ID                       
						FROM DATAHUB_ODESSA.ODH.RECEIVABLETYPELABELCONFIGS_REALTIME                      
						WHERE ISACTIVE = 1                       
					    ) RTLC                      
             ON RTLC.RECEIVABLETYPEID = RT.ID                       
    LEFT OUTER JOIN    DATAHUB_ODESSA.ODH.RECEIVABLETYPELANGUAGELABELS_REALTIME RTLL WITH(NOLOCK)                       
        ON RTLL.RECEIVABLETYPELABELCONFIGID = RTLC.ID AND RTLL.ISACTIVE=1                      
                 
    LEFT OUTER JOIN    (SELECT  DISTINCT RECEIVABLETYPELABELID,RECEIVABLETYPELANGUAGELABELID                      
         FROM    DATAHUB_ODESSA.ODH.BILLTOINVOICEPARAMETERS_REALTIME  WITH(NOLOCK)) BTIP                       
         ON      BTIP.RECEIVABLETYPELABELID = RTLC.ID AND BTIP.RECEIVABLETYPELANGUAGELABELID = RTLL.ID 
    WHERE RI.ISACTIVE=1		 
                
  ) A                
  ) AA           
  GROUP BY INVOICE_NUMBER, INVOICETYPE          
          
          
                
 SET @NUMBEROFROWTOBEDELETE = @NUMBEROFROWTOBEDELETE + ISNULL((SELECT COUNT(*) FROM DBO.CP_INVOICE_TYPES),0)            
            
    TRUNCATE TABLE  DBO.CP_INVOICE_TYPES                 
    INSERT INTO    DBO.CP_INVOICE_TYPES                 
                    (                
                     INVOICE_NUMBER,                
      INVOICETYPE  ,              
      STARTDATE,              
      ENDDATE               
                    )                
         SELECT         
         INVOICE_NUMBER,                         
         INVOICETYPE,              
         STARTDATE ,              
         ENDDATE               
         FROM  #CP_INVOICE_TYPES             
              
 SET @NUMBEROFROWINSERTED = @NUMBEROFROWINSERTED + ISNULL((SELECT COUNT(*) FROM DBO.CP_INVOICE_TYPES),0)            
            
 SET @NUMBEROFROWPROCESSED = @NUMBEROFROWINSERTED + @NUMBEROFROWTOBEDELETE            
       
 /* --------------------------------------------TERMINATEDCONTRACT------------------------------------------------------------*/      
PRINT 'LOAD TERMINATEDCONTRACT'         
               
  IF OBJECT_ID(N'TEMPDB..#TERMINATEDCONTRACT')  IS NOT NULL                  
 BEGIN                  
   DROP TABLE #TERMINATEDCONTRACT                  
  END          
      
    SELECT       
          CONTRACTID,      
          SEQUENCENUMBER,      
          BookingStatus,      
          TerminationDate      
    INTO  #TERMINATEDCONTRACT                  
  FROM        
   (SELECT   
       CT.Id AS CONTRACTID,      
       CT.SEQUENCENUMBER,      
       LF.BookingStatus,       
       MAX(LA.TerminationDate) AS TerminationDate        
     FROM DATAHUB_ODESSA.ODH.Contracts_Realtime CT WITH (NOLOCK)       
     JOIN DATAHUB_ODESSA.ODH.LeaseFinances_Realtime LF WITH (NOLOCK) ON LF.CONTRACTID=CT.ID AND LF.IsCurrent = 1       
     JOIN DATAHUB_ODESSA.ODH.LeaseAssets_Realtime LA WITH (NOLOCK) ON LA.LeaseFinanceId = LF.Id      
     WHERE LF.BookingStatus  IN ('FullyPaidOff','TERMINATED')      
     GROUP BY CT.ID,CT.SEQUENCENUMBER,LF.BookingStatus       
   ) ABC      
     WHERE datediff(month, TerminationDate,getdate()) > 12 ;      
      
SET @NUMBEROFROWTOBEDELETE = @NUMBEROFROWTOBEDELETE + ISNULL((SELECT COUNT(*) FROM DBO.TERMINATEDCONTRACT),0)       
       
TRUNCATE TABLE DBO.TERMINATEDCONTRACT       
INSERT INTO DBO.TERMINATEDCONTRACT (CONTRACTID,      
         SEQUENCENUMBER,      
         BookingStatus,      
         TerminationDate      
         )      
          SELECT       
          CONTRACTID,      
          SEQUENCENUMBER,      
          BookingStatus,      
          TerminationDate      
        FROM   #TERMINATEDCONTRACT      
      
 SET @NUMBEROFROWINSERTED =  @NUMBEROFROWINSERTED + ISNULL((SELECT COUNT(*) FROM TERMINATEDCONTRACT),0)      
 SET @NUMBEROFROWPROCESSED = @NUMBEROFROWINSERTED + @NUMBEROFROWTOBEDELETE        
       
/* --------------------------------------------TERMINATEDCONTRACT------------------------------------------------------------*/     
  
  
/* --------------------------------------------CUSTOMER_DETAILS_ALL_CNT_STATUS------------------------------------------------------------*/     
TRUNCATE TABLE DBO.CUSTOMER_DETAILS_ALL_CNT_STATUS ;  
      
INSERT INTO DBO.CUSTOMER_DETAILS_ALL_CNT_STATUS   
  (PARTYNUMBER,      
         ID,  
   CSTMR_NM,  
   END_PARYID,  
   END_ID,  
   CONTRACT_NUMBER,  
   CSTNAME,  
   BUSINESS_UNIT,  
   ORIGINATIONSOURCETYPE,  
   COMBINATIONID,  
   BOOKINGSTATUS     
        )      
        SELECT       
        PARTYNUMBER,      
        ID,  
  CSTMR_NM,  
  END_PARYID,  
  END_ID,  
  CONTRACT_NUMBER,  
  CSTNAME,  
  BUSINESS_UNIT,  
  ORIGINATIONSOURCETYPE,  
  COMBINATIONID,  
  BOOKINGSTATUS     
        FROM DBO.V_CUSTOMER_DETAILS_ALL_CNT_STATUS    
  
 SET @NUMBEROFROWINSERTED =  @NUMBEROFROWINSERTED + ISNULL((SELECT COUNT(*) FROM DBO.CUSTOMER_DETAILS_ALL_CNT_STATUS),0)      
 SET @NUMBEROFROWPROCESSED = @NUMBEROFROWINSERTED + @NUMBEROFROWTOBEDELETE        
         
    
/* --------------------------------------------CUSTOMER_DETAILS_ALL_CNT_STATUS------------------------------------------------------------*/     
  
----------------------------------------------------------------------------------------------------------                
  DECLARE @NUMROWSINSERTED INT = 0     
  SELECT                 
    1         AS JOBSTATUSTYPEID                
   ,0         AS ISERROR                
   ,NULL        AS ERRORDESCRIPTION                
   ,0         AS NUMROWSUPDATED            
   ,@NUMBEROFROWTOBEDELETE AS NUMBEROFROWTOBEDELETE            
   ,@NUMBEROFROWINSERTED AS NUMBEROFROWINSERTED            
   ,@NUMBEROFROWPROCESSED AS NUMBEROFROWPROCESSED               
            
--DECLARE  @JOBINSTANCEID BIGINT                  
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
   19                
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
   ,@NUMBEROFROWTOBEDELETE AS NUMBEROFROWTOBEDELETE            
   ,@NUMBEROFROWINSERTED AS NUMBEROFROWINSERTED            
   ,@NUMBEROFROWPROCESSED AS NUMBEROFROWPROCESSED                
 END CATCH                
END;                                             
