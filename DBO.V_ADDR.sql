

-- ---------------------------------------------------------------------------------------------  
--  
-- Purpose: Return a listing of Customer information.  
--  
--    Date        Version    Who        Control        Comment  
-- ----------    -------    -------    -----------    ----------------------------------------------------  
-- 15/02/2023       V1       Rashami                   Initial Version   
-- 20/01/2025       V5       Automation                Testing   
-- -----------------------------------------------------------------------------------------------
CREATE VIEW DBO.V_ADDR
AS
SELECT * FROM DBO.REPORT_V_ADDR(NOLOCK)          
