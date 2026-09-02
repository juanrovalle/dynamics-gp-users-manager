-- Membership and cross-database permissions are provisioned separately by a DBA.
IF DATABASE_PRINCIPAL_ID(N'gpManagerReader') IS NULL CREATE ROLE gpManagerReader;
IF DATABASE_PRINCIPAL_ID(N'gpManagerOperator') IS NULL CREATE ROLE gpManagerOperator;
IF DATABASE_PRINCIPAL_ID(N'gpManagerAutomation') IS NULL CREATE ROLE gpManagerAutomation;
GRANT SELECT ON dbo.vw_gpManagerDepartmentUsage TO gpManagerReader;
GRANT SELECT ON dbo.vw_gpManagerSessions TO gpManagerReader;
REVOKE EXECUTE ON dbo.SP_LOGOUTGPUSER_BY_QUOTE FROM gpManagerReader;
GRANT EXECUTE ON dbo.SP_PREVIEW_GP_QUOTA TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerAudit TO gpManagerOperator;
GRANT EXECUTE ON dbo.SP_LOGOUTGPUSER_TRAN TO gpManagerOperator;
GRANT EXECUTE ON dbo.SP_LOGOUTGPUSER_BY_QUOTE TO gpManagerAutomation;
GRANT SELECT ON dbo.gpManagerNotification TO gpManagerOperator;
GO
