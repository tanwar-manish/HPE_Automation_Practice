/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/

PRINT 'Start Executing : MASTER_IDS_DDL.SQL' 
-----------------Start File-----MASTER_IDS_DDL.SQL-----------------

IF OBJECT_ID(N'DIMN_20210430.LogsForProcDebug') IS NULL
    BEGIN
      CREATE TABLE DIMN_20210430.LogsForProcDebug
		(
			Id BIGINT IDENTITY(1,1),
			ScriptName VARCHAR(MAX),
			SectionAsPerLogic VARCHAR(MAX),
			CreatedOn DATETIME,
			CreatedBy VARCHAR(500)
		)
    END

-----------------End File-----MASTER_IDS_DDL.SQL-----------------
PRINT 'End Executing : MASTER_IDS_DDL.SQL' 
GO