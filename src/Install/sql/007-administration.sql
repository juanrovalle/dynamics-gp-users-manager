IF DATABASE_PRINCIPAL_ID(N'gpManagerAdmin') IS NULL CREATE ROLE gpManagerAdmin;
GRANT SELECT ON dbo.gpManagerSettings TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerSchemaVersion TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerRuntime TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerDepartment TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerUser TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerAudit TO gpManagerReader;
GRANT SELECT ON dbo.gpManagerNotification TO gpManagerReader;
GRANT EXECUTE ON dbo.SP_PREVIEW_GP_QUOTA TO gpManagerAdmin;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_SAVE_DEPARTMENT
    @Name nvarchar(128),@Quota int,@Enabled bit,@ID int=NULL,@Revision binary(8)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 BEGIN RAISERROR('Call administration outside a transaction.',16,1); RETURN 1; END;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Name)),N'') IS NULL OR DATALENGTH(@Name)>50 OR @Quota IS NULL OR @Quota<0 OR @Enabled IS NULL
        THROW 51401,'Department requires a name of at most 25 characters, a nonnegative quota and enabled state.',1;
    BEGIN TRY
    BEGIN TRANSACTION;
    IF @ID IS NULL
    BEGIN
        INSERT dbo.gpManagerDepartment([name],[limit],enabled) VALUES(LTRIM(RTRIM(@Name)),@Quota,@Enabled);
        SET @ID=CONVERT(int,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.gpManagerDepartment SET [name]=LTRIM(RTRIM(@Name)),[limit]=@Quota,enabled=@Enabled
        WHERE ID=@ID AND revision=@Revision;
        IF @@ROWCOUNT<>1 THROW 51402,'Department changed or no longer exists. Refresh before saving.',1;
    END;
    INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason,detail)
        VALUES(N'(configuration)',0,'DEPARTMENT_SAVED',@Name,CONCAT(N'ID=',@ID,N'; quota=',@Quota,N'; enabled=',@Enabled));
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_USERS @Search nvarchar(65)=N''
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(500) RTRIM(g.USERID) AS username,RTRIM(g.USERNAME) AS display_name,u.department_id,
        RTRIM(d.[name]) AS department,u.revision
    FROM [$(GPDatabase)].dbo.SY01400 g
    LEFT JOIN dbo.gpManagerUser u ON u.username=g.USERID COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.gpManagerDepartment d ON d.ID=u.department_id
    WHERE @Search=N'' OR CHARINDEX(@Search,g.USERID)>0 OR CHARINDEX(@Search,g.USERNAME)>0
    ORDER BY g.USERID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_ASSIGN_USER
    @Username nvarchar(128),@DepartmentID int,@Revision binary(8)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 BEGIN RAISERROR('Call administration outside a transaction.',16,1); RETURN 1; END;
    SET XACT_ABORT ON;
    IF @Username IS NULL OR DATALENGTH(@Username)>30 OR NULLIF(LTRIM(RTRIM(@Username)),N'') IS NULL
        THROW 51403,'Invalid GP username.',1;
    DECLARE @name nvarchar(65);
    SELECT @name=USERNAME FROM [$(GPDatabase)].dbo.SY01400 WHERE USERID=@Username COLLATE DATABASE_DEFAULT;
    IF @name IS NULL THROW 51404,'The user does not exist in GP.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerDepartment WHERE ID=@DepartmentID)
        THROW 51405,'Department does not exist.',1;
    BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS(SELECT 1 FROM dbo.gpManagerUser WITH(UPDLOCK,HOLDLOCK) WHERE username=@Username)
    BEGIN
        UPDATE dbo.gpManagerUser SET department_id=@DepartmentID WHERE username=@Username AND revision=@Revision;
        IF @@ROWCOUNT<>1 THROW 51406,'Assignment changed. Refresh before saving.',1;
    END
    ELSE
    BEGIN
        IF @Revision IS NOT NULL THROW 51406,'Assignment changed. Refresh before saving.',1;
        INSERT dbo.gpManagerUser(username,[name],department_id) VALUES(@Username,LEFT(@name,30),@DepartmentID);
    END;
    INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason) VALUES(@Username,0,'USER_ASSIGNED',CONCAT(N'Department ',@DepartmentID));
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_UNASSIGN_USER @Username nvarchar(128),@Revision binary(8)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 BEGIN RAISERROR('Call administration outside a transaction.',16,1); RETURN 1; END;
    SET XACT_ABORT ON; BEGIN TRY
    BEGIN TRANSACTION;
    DELETE dbo.gpManagerUser WHERE username=@Username AND revision=@Revision;
    IF @@ROWCOUNT<>1 THROW 51406,'Assignment changed. Refresh before removing.',1;
    INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason) VALUES(@Username,0,'USER_UNASSIGNED',N'GP account was not modified');
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_SAVE_SETTINGS
    @ProtectTransactions bit,@NotifyInGP bit,@Customer nvarchar(150),@Contact nvarchar(200),
    @PurchasedOn date=NULL,@MaintenanceUntil date=NULL,@Revision binary(8)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 BEGIN RAISERROR('Call administration outside a transaction.',16,1); RETURN 1; END;
    SET XACT_ABORT ON;
    IF @ProtectTransactions IS NULL OR @NotifyInGP IS NULL THROW 51407,'Policy flags cannot be NULL.',1;
    BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @lock int;
    EXEC @lock=sys.sp_getapplock @Resource=N'gpManager.cleanup',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
    IF @lock<0 THROW 51408,'Automation is busy. Retry later.',1;
    UPDATE dbo.gpManagerSettings SET protect_transactions=@ProtectTransactions,notify_in_gp=@NotifyInGP,
        customer_name=COALESCE(@Customer,N''),customer_contact=COALESCE(@Contact,N''),
        purchased_on=@PurchasedOn,maintenance_until=@MaintenanceUntil,
        test_notification_id=CASE WHEN notify_in_gp=0 AND @NotifyInGP=1 THEN NULL ELSE test_notification_id END,
        message_confirmed=CASE WHEN notify_in_gp=0 AND @NotifyInGP=1 THEN 0 ELSE message_confirmed END
    WHERE ID=1 AND revision=@Revision;
    IF @@ROWCOUNT<>1 THROW 51409,'Settings changed. Refresh before saving.',1;
    -- Turning notifications on requires a test before resuming an installation.
    UPDATE dbo.gpManagerSettings SET automation_enabled=0 WHERE ID=1 AND notify_in_gp=1 AND message_confirmed=0;
    INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason) VALUES(N'(configuration)',0,'SETTINGS_SAVED',N'Policy and customer registration');
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.SP_GPUM_SET_AUTOMATION @Enabled bit,@ConfirmMessageObserved bit=0
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 BEGIN RAISERROR('Call administration outside a transaction.',16,1); RETURN 1; END;
    SET XACT_ABORT ON;
    IF @Enabled IS NULL OR @ConfirmMessageObserved IS NULL THROW 51410,'Enabled must be specified.',1;
    BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @lock int;
    EXEC @lock=sys.sp_getapplock @Resource=N'gpManager.cleanup',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
    IF @lock<0 THROW 51408,'Automation is busy. Retry later.',1;
    IF @Enabled=1 AND EXISTS(SELECT 1 FROM dbo.gpManagerSettings WHERE ID=1 AND notify_in_gp=1 AND message_confirmed=0
        AND NOT(@ConfirmMessageObserved=1 AND test_notification_id IS NOT NULL))
        THROW 51411,'Send a test message and confirm that the GP client displayed it before activation.',1;
    UPDATE dbo.gpManagerSettings SET automation_enabled=@Enabled,
        message_confirmed=CASE WHEN @ConfirmMessageObserved=1 AND test_notification_id IS NOT NULL THEN 1 ELSE message_confirmed END WHERE ID=1;
    INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason) VALUES(N'(configuration)',0,'AUTOMATION_CHANGED',CONCAT(N'Enabled=',@Enabled));
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
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
        VALUES(@audit,@Username,0,0,@CompanyID,N'GP Users Manager: mensaje de prueba. Confirme con el administrador que recibio este aviso. No se ha retirado su sesion.');
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
GRANT EXECUTE ON dbo.SP_GPUM_USERS TO gpManagerReader;
GRANT EXECUTE ON dbo.SP_GPUM_SAVE_DEPARTMENT TO gpManagerAdmin;
GRANT EXECUTE ON dbo.SP_GPUM_ASSIGN_USER TO gpManagerAdmin;
GRANT EXECUTE ON dbo.SP_GPUM_UNASSIGN_USER TO gpManagerAdmin;
GRANT EXECUTE ON dbo.SP_GPUM_SAVE_SETTINGS TO gpManagerAdmin;
GRANT EXECUTE ON dbo.SP_GPUM_SET_AUTOMATION TO gpManagerAdmin;
GRANT EXECUTE ON dbo.SP_GPUM_TEST_MESSAGE TO gpManagerAdmin;
GO
