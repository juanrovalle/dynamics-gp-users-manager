-- Schema v4 keeps the gpManager*/SP_GPUM_* contract and refreshes product-facing text only.
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_TEST_MESSAGE @Username nvarchar(128),@CompanyID int
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 BEGIN RAISERROR('Call administration outside a transaction.',16,1); RETURN 1; END;
    SET XACT_ABORT ON;
    IF @Username IS NULL OR DATALENGTH(@Username)>30 OR NOT EXISTS(SELECT 1 FROM [$(GPDatabase)].dbo.SY01400 WHERE USERID=@Username COLLATE DATABASE_DEFAULT)
        THROW 51412,'Select an existing GP user.',1;
    IF NOT EXISTS(SELECT 1 FROM [$(GPDatabase)].dbo.SY01500 WHERE CMPANYID=@CompanyID) THROW 51413,'Invalid GP company.',1;
    BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason) VALUES(@Username,0,'TEST_MESSAGE',N'Explicitly requested GP notification test; no removal');
    DECLARE @audit bigint=CONVERT(bigint,SCOPE_IDENTITY()),@id bigint;
    INSERT dbo.gpManagerNotification(audit_id,username,session_id,department_id,company_id,message)
        VALUES(@audit,@Username,0,0,@CompanyID,N'Dynamics GP UserOps: test message. Confirm with your administrator that you received this notification. Your session was not removed.');
    SET @id=CONVERT(bigint,SCOPE_IDENTITY());
    EXEC dbo.SP_POST_GP_NOTIFICATION @NotificationID=@id;
    UPDATE dbo.gpManagerSettings SET test_notification_id=@id WHERE ID=1;
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
GRANT EXECUTE ON dbo.SP_GPUM_TEST_MESSAGE TO gpManagerAdmin;
IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerSchemaVersion WHERE version=4)
    INSERT dbo.gpManagerSchemaVersion(version) VALUES(4);
GO
