/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/

IF NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'[AssetList]' AND ss.name = N'[DIMN]')
BEGIN

CREATE TYPE [dbo].[TestType] AS TABLE(
	[TestColumn] [nvarchar](10)
	)
go


CREATE TYPE [DIMN].[AssetList] AS TABLE(
	[AssetKey] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[AssetKey] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
end







GO
GRANT EXECUTE ON type::[DIMN].[AssetList] TO DMUsr01;
GO
