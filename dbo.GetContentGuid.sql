
  
CREATE FUNCTION dbo.GetContentGuid(@ContentBinary VARBINARY(MAX))    
RETURNS UNIQUEIDENTIFIER    
AS     
BEGIN    
DECLARE @ContentGUID NVARCHAR(50)    
                SET @ContentGUID = CONVERT(NVARCHAR(50), @ContentBinary)                
    
                RETURN CONVERT(UNIQUEIDENTIFIER, SUBSTRING(@ContentGUID, CHARINDEX(':', @ContentGUID,0) + 1, 36)  
)    
END;  