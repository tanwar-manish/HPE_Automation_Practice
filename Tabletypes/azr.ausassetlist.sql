/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/

IF NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'[AUSAssetList]' AND ss.name = N'[AZR]')
BEGIN

CREATE TYPE [dbo].[TestType] AS TABLE(
	[TestColumn] [nvarchar](10)
	)
go
IF NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'AUSAssetList' AND ss.name = N'AZR')
begin
CREATE TYPE [AZR].[AUSAssetList] AS TABLE(
	[AssetId] [nvarchar](40) NULL,
	[AssetStatusName] [nvarchar](120) NULL,
	[CustomerAccountNumber] [nvarchar](80) NULL,
	[ItemQuantity] [numeric](17, 0) NULL,
	[LocalSOWId] [nvarchar](20) NULL,
	[GlobalSOWId] [nvarchar](20) NULL,
	[SOWDesc] [nvarchar](50) NULL,
	[PPRequestId] [nvarchar](100) NULL,
	[CollectionRequestId] [nvarchar](40) NULL,
	[EndCustomerAccountNumber] [nvarchar](80) NULL,
	[ParentAssetId] [nvarchar](40) NULL,
	[ItemNumber] [nvarchar](80) NULL,
	[ProductTypeName] [nvarchar](508) NULL,
	[ProductDescription] [nvarchar](2000) NULL,
	[SerialNumber] [nvarchar](100) NULL,
	[ManufactCode] [nvarchar](200) NULL,
	[SourceRecordTimeStamp] [datetime] NULL,
	[CountryCode] [char](3) NULL
)
end


GO
GRANT EXECUTE ON type::[AZR].[AUSAssetList] TO DMUsr01;
GO
