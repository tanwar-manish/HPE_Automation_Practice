/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/
------------------------------------------------------------------------------------
-- DATE            	Release    	Who            	Control        Comment 
-- ----------    	-------    	-----------    	-----------    --------------------------------------------
-- 19/12/2022		Intial		Mahesh Mohite	 			   Clean up the branch for 01/15 JAN24 MTP ---CAA+ALD+(PP/CP/PnA/VA Spira Defects)
-- 19/12/2022		V1.1		Mahesh Mohite		CAA & ALD  Added CAA & ALD db scripts
------------------------------------------------------------------------------------

PRINT '=======================================================';
PRINT '   MASTER_IDS_DML.sql Start: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '=======================================================';
PRINT '';
GO



-----==========================================================================================================
--   *******  Customer Asset API DML  Changes ===>> START
-----==========================================================================================================

--------------------------------------------------------------------------------------------
---######### INSERT Scripts - Applications
--------------------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM DatahubEtl.Applications where ApplicationId IN (1,2,3,4,5,6)) 
PRINT '>> Customer Asset API :   Table [DatahubEtl].[Applications]  - master data exists >>'
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.Applications where ApplicationId IN (1,2,3,4,5,6)) 
BEGIN
	SET IDENTITY_INSERT [DatahubEtl].[Applications] ON
	INSERT INTO [DatahubEtl].[Applications]
	(
			[ApplicationId],
			[Name]
	)
	SELECT 1, 'Customer Asset Api'
	UNION ALL SELECT 2, 'Volume Analytics'
	UNION ALL SELECT 3, 'PMR'
	UNION ALL SELECT 4, 'PCT'
	UNION ALL SELECT 5, 'Portal Plus'
	UNION ALL SELECT 6, 'Customer Portal'
	SET IDENTITY_INSERT [DatahubEtl].[Applications] OFF
	PRINT '>> Customer Asset API :   Table [DatahubEtl].[Applications]  - master data inserted >>'
END
GO

--------------------------------------------------------------------------------------------
---######### INSERT Scripts - JobEntities
--------------------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (1,2,3,4)) 
PRINT '>> Customer Asset API :   Table [DatahubEtl].[JobEntities]  - master data exists >>'
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (1,3,4)) 
BEGIN
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] ON
	INSERT INTO [DatahubEtl].[JobEntities]
	(
			[JobEntityId],
			[ApplicationId],
			[JobName],
			[JobProcessName],
			[ParentJobEntityId],
			[IsActive]
	)
	SELECT 1, 1,'Asset_Explosions_Load_IDS_Target', 'Sync asset explosion data from ODH To IDS' , NULL, 1
	UNION ALL SELECT 3, 1,'Customer_Eligibility_Load_IDS_Target', 'Sync customer eligibility data from BEM To IDS' , NULL, 1
	UNION ALL SELECT 4, 1,'Customer_Asset_List_Load_IDS_Target', 'Sync customer asset list data from ODH To IDS' , NULL, 1
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] OFF
	PRINT '>> Customer Asset API :   Table [DatahubEtl].[JobEntities]  - master data inserted >>'
END
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (2)) 
BEGIN
	DELETE FROM  [DatahubEtl].[JobEntities] where [JobEntityId] = 2
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] ON
	INSERT INTO [DatahubEtl].[JobEntities]
	(
			[JobEntityId],
			[ApplicationId],
			[JobName],
			[JobProcessName],
			[ParentJobEntityId],
			[IsActive]
	)
	SELECT 2, 1,'PHX_Invoice_Suppliers_Load_IDS_Target', 'Sync phx_invoices and phx_suppliers from Phoenix To IDS' , NULL, 1
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] OFF
	PRINT '>> Customer Asset API :   Table [DatahubEtl].[JobEntities]  - master data inserted >>'
END
GO

--------------------------------------------------------------------------------------------
---######### INSERT Scripts - JobStatusTypes
--------------------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM DatahubEtl.JobStatusTypes where JobStatusTypeId IN (-2,-1,0,1)) 
PRINT '>> Customer Asset API :   Table [DatahubEtl].[JobStatusTypes]  - master data exists'
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.JobStatusTypes where JobStatusTypeId IN (-2,-1,0,1)) 
BEGIN
	SET IDENTITY_INSERT [DatahubEtl].[JobStatusTypes] ON
	INSERT INTO [DatahubEtl].[JobStatusTypes]
	(
		[JobStatusTypeId],
		[Name],
		[IsActive]
	)
	SELECT -2, 'Aborted', 1
	UNION ALL SELECT -1, 'Error', 1
	UNION ALL SELECT 0, 'Pending', 1
	UNION ALL SELECT 1, 'Success', 1
	SET IDENTITY_INSERT [DatahubEtl].[JobStatusTypes] OFF
	PRINT '>> Customer Asset API :   Table [DatahubEtl].[JobStatusTypes]  - master data inserted >>'
END
GO
-----==========================================================================================================
--   *******  Customer Asset API DML  Changes ===>> END
-----==========================================================================================================


UPDATE  dbo.ctry 
SET
SupplierInvoiceThresholdAmount = 1
GO	


--------------------------------------------------------------------------------------------
---######### ALD - INSERT Scripts - Applications
--------------------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM DatahubEtl.Applications where ApplicationId IN (8)) 
PRINT '>> ALD :   Table [DatahubEtl].[Applications]  - master data exists >>'
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.Applications where ApplicationId IN (8)) 
BEGIN
	SET IDENTITY_INSERT [DatahubEtl].[Applications] ON
	INSERT INTO [DatahubEtl].[Applications]
	(
			[ApplicationId],
			[Name]
	)
	SELECT 8, 'ALD'
	SET IDENTITY_INSERT [DatahubEtl].[Applications] OFF
	PRINT '>> ALD :   Table [DatahubEtl].[Applications]  - master data inserted >>'
END
GO

--------------------------------------------------------------------------------------------
---######### ALD - INSERT Scripts - JobEntities
--------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (33,34)) 
PRINT '>> ALD :   Table [DatahubEtl].[JobEntities]  - master data exists >>'
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (33,34)) 
BEGIN
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] ON
	INSERT INTO [DatahubEtl].[JobEntities]
	(
			[JobEntityId],
			[ApplicationId],
			[JobName],
			[JobProcessName],
			[ParentJobEntityId],
			[IsActive]
	)
	SELECT 33, 8,'ALD_CSV_Data_Migration', 'Loading Prod Related tables from MDC 7 sheets' , NULL, 1
	UNION ALL
	SELECT 34, 8,'ALD_EXCEL_Data_Migration', 'Loading Prod Related tables from CSV 18 files' , NULL, 1
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] OFF
	PRINT '>> ALD :   Table [DatahubEtl].[JobEntities]  - master data inserted >>'
END
GO

-------=======================================================================
------     ALD DML ==> START
-----=======================================================================

IF NOT EXISTS (SELECT 1 FROM dbo.CustomerSupplierMasterdataExtract where CustomerSupplierMasterdataExtractID IN (1)) 
BEGIN
		INSERT INTO [dbo].[CustomerSupplierMasterdataExtract]
		([ExtractProcessName]
		,[ErrorCode]
		,[ErrorMessage]
		,[ExtractLastRunTime]
		,[ExtractLastRunStatus]
		,[UserCreatedId]
		,[UserCreatedTimestamp]
		,[UserModifiedId]
		,[UserModifiedTimestamp])
		VALUES
		('CustomerMasterdataExtract from GPO','0','Normal successful completion',CURRENT_TIMESTAMP,'SUCCESS',
		current_user,CURRENT_TIMESTAMP,current_user,CURRENT_TIMESTAMP
		);
END		   
GO	
	   
IF NOT EXISTS (SELECT 1 FROM dbo.CustomerSupplierMasterdataExtract where CustomerSupplierMasterdataExtractID IN (2)) 
BEGIN
		INSERT INTO [dbo].[CustomerSupplierMasterdataExtract]
		([ExtractProcessName]
		,[ErrorCode]
		,[ErrorMessage]
		,[ExtractLastRunTime]
		,[ExtractLastRunStatus]
		,[UserCreatedId]
		,[UserCreatedTimestamp]
		,[UserModifiedId]
		,[UserModifiedTimestamp])
		VALUES
		('SupplierMasterdataExtract from GPO','0','Normal successful completion',CURRENT_TIMESTAMP,'SUCCESS',
		current_user,CURRENT_TIMESTAMP,current_user,CURRENT_TIMESTAMP
		);
END		   
GO	

IF EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (11,12,13)) 
PRINT '>> PMR :   Table [DatahubEtl].[JobEntities]  - master data exists >>'
GO

IF NOT EXISTS (SELECT 1 FROM DatahubEtl.JobEntities where JobEntityId IN (11,12,13)) 
BEGIN
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] ON
	INSERT INTO [DatahubEtl].[JobEntities]
	(
			[JobEntityId],
			[ApplicationId],
			[JobName],
			[JobProcessName],
			[ParentJobEntityId],
			[IsActive]
	)
	SELECT 11, 3,'Contract_Summary_Load_IDS_Target', 'Sync Contracts data from ODH To IDS' , NULL, 1
	UNION ALL SELECT 12, 3,'Asset_Summary_Load_IDS_Target', 'Sync Asset data from ODH To IDS' , NULL, 1
	UNION ALL SELECT 13, 3,'Product_Summary_Load_IDS_Target', 'Sync Contracts data from ODH To IDS' , NULL, 1
	SET IDENTITY_INSERT [DatahubEtl].[JobEntities] OFF
	PRINT '>> PMR :   Table [DatahubEtl].[JobEntities]  - master data inserted >>'
END
-------=======================================================================
------     ALD DML ==> END
-----=======================================================================


PRINT '';
PRINT '=======================================================';
PRINT '  MASTER_IDS_DML.sql End:    ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '=======================================================';
GO