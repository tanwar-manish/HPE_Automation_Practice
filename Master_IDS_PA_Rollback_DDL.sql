/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/

-- Check DIMN_20210430.LogsForProcDebug is created then if yes then drop it for further logic
IF OBJECT_ID(N'DIMN_20210430.LogsForProcDebug') IS NOT NULL
    BEGIN
		DROP TABLE DIMN_20210430.LogsForProcDebug
	END
	
GO