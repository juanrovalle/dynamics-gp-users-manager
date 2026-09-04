:On Error exit
USE GPManagerTest;
SET NOCOUNT ON;
-- Recreate the two externally visible parts of a v3 installation while preserving test data.
DELETE dbo.gpManagerSchemaVersion WHERE version=4;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_TEST_MESSAGE @Username nvarchar(128),@CompanyID int
AS
BEGIN
    THROW 52997,'Legacy v3 test-message procedure marker.',1;
END;
GO
IF OBJECT_ID(N'dbo.test_fail_v4_schema',N'TR') IS NOT NULL DROP TRIGGER dbo.test_fail_v4_schema;
GO
CREATE TRIGGER dbo.test_fail_v4_schema ON dbo.gpManagerSchemaVersion AFTER INSERT
AS
BEGIN
    IF EXISTS(SELECT 1 FROM inserted WHERE version=4)
        THROW 52996,'Injected schema-v4 migration failure.',1;
END;
GO
PRINT 'Schema-v3 rollback fixture prepared.';
