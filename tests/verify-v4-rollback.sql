:On Error exit
USE GPManagerTest;
SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM dbo.gpManagerSchemaVersion WHERE version=4)
    THROW 52300,'Failed schema-v4 version row was not rolled back.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_GPUM_TEST_MESSAGE')) NOT LIKE '%Legacy v3 test-message procedure marker%'
    THROW 52301,'Failed schema-v4 procedure change was not rolled back.',1;
IF (SELECT COUNT(*) FROM dbo.gpManagerUser)<>3 OR (SELECT COUNT(*) FROM dbo.gpManagerDepartment)<>3
    THROW 52302,'Failed schema-v4 migration changed customer data.',1;
IF NOT EXISTS(
    SELECT 1 FROM sys.database_permissions p
    JOIN sys.database_principals r ON r.principal_id=p.grantee_principal_id
    WHERE r.name=N'gpManagerAdmin' AND p.major_id=OBJECT_ID(N'dbo.SP_GPUM_TEST_MESSAGE')
      AND p.permission_name=N'EXECUTE' AND p.state IN ('G','W'))
    THROW 52303,'Failed schema-v4 migration changed the administration grant.',1;
DROP TRIGGER dbo.test_fail_v4_schema;
PRINT 'PASS schema-v4 transaction rollback, data preservation and permissions';
GO
