CREATE OR ALTER PROCEDURE dbo.SP_LOGOUTGPUSER_TRAN
    @USERID nvarchar(128),
    @AppID int = 0,
    @DryRun bit = 1,
    @ConfirmDisconnected bit = 0,
    @Reason nvarchar(400) = NULL,
    @ExpectedSessionID int = NULL,
    @ExpectedLoginDate datetime = NULL,
    @ExpectedLoginTime datetime = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Do not commit/roll back a caller's transaction, or lose audit on its rollback.
    -- RAISERROR intentionally does not honor XACT_ABORT in the caller.
    IF @@TRANCOUNT <> 0
    BEGIN
        RAISERROR('Call this procedure outside a transaction.', 16, 1);
        RETURN 1;
    END;
    SET XACT_ABORT ON;
    IF @USERID IS NULL OR LEN(LTRIM(RTRIM(@USERID))) = 0 OR DATALENGTH(@USERID) > 30
        THROW 51101, 'USERID must contain 1 to 15 characters.', 1;
    IF @AppID IS NULL OR @AppID <> 0
        THROW 51102, 'Only Dynamics GP (AppID=0) is supported. Legacy AppID=1 is disabled.', 1;
    IF @DryRun IS NULL OR @ConfirmDisconnected IS NULL
        THROW 51103, 'Safety flags cannot be NULL.', 1;
    SET @USERID=LTRIM(RTRIM(@USERID));
    DECLARE @session int, @count int, @lock int, @loginDate datetime, @loginTime datetime,
        @outcome varchar(32)='PREVIEW', @detail nvarchar(2048), @result int=0;
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @lock=sys.sp_getapplock @Resource=N'gpManager.cleanup',
            @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
        IF @lock < 0 THROW 51104, 'Could not acquire cleanup lock.', 1;
        SELECT @count=COUNT(*), @session=MIN(SQLSESID), @loginDate=MIN(LOGINDAT), @loginTime=MIN(LOGINTIM)
        FROM [$(GPDatabase)].dbo.ACTIVITY WITH (UPDLOCK, HOLDLOCK)
        WHERE USERID=@USERID COLLATE DATABASE_DEFAULT;
        IF @count=0 SELECT @outcome='NOT_FOUND', @result=2;
        ELSE IF @count<>1 OR @session IS NULL OR @session<=0 OR @loginDate IS NULL OR @loginTime IS NULL
            SELECT @outcome='AMBIGUOUS_SESSION', @result=3;
        ELSE IF EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.ACTIVITY WITH (UPDLOCK, HOLDLOCK)
                        WHERE SQLSESID=@session AND USERID<>@USERID COLLATE DATABASE_DEFAULT)
            SELECT @outcome='SHARED_SESSION', @result=3;
        ELSE IF @DryRun=0 AND (@ConfirmDisconnected=0 OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL)
            SELECT @outcome='CONFIRMATION_REQUIRED', @result=3;
        ELSE IF @DryRun=0 AND (@ExpectedSessionID IS NULL OR @ExpectedLoginDate IS NULL OR @ExpectedLoginTime IS NULL
                OR @ExpectedSessionID<>@session OR @ExpectedLoginDate<>@loginDate OR @ExpectedLoginTime<>@loginTime)
            SELECT @outcome='STALE_SELECTION', @result=3;
        ELSE IF EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.SY00800 WITH (UPDLOCK, HOLDLOCK) WHERE USERID=@USERID COLLATE DATABASE_DEFAULT)
             OR EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.SY00801 WITH (UPDLOCK, HOLDLOCK) WHERE USERID=@USERID COLLATE DATABASE_DEFAULT)
            SELECT @outcome='ACTIVITY_BLOCKED', @result=3;
        ELSE
        BEGIN
            -- Fail closed when the operator cannot see every SQL session.
            IF (CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))>=16
                  AND ISNULL(HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER PERFORMANCE STATE'),0)=0)
               OR (CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))<16
                  AND ISNULL(HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER STATE'),0)=0)
                THROW 51105, 'Server session visibility is required to check live connections.', 1;
            IF EXISTS (
                SELECT 1 FROM [$(DexDatabase)].dbo.DEX_SESSION ds WITH (UPDLOCK,HOLDLOCK)
                JOIN sys.dm_exec_sessions s ON s.session_id=ds.sqlsvr_spid
                WHERE ds.session_id=@session
            )
                SELECT @outcome='LIVE_SESSION_BLOCKED', @result=3;
            ELSE IF @DryRun=0
            BEGIN
                DELETE FROM [$(DexDatabase)].dbo.DEX_LOCK WHERE session_id=@session;
                DELETE FROM [$(DexDatabase)].dbo.DEX_SESSION WHERE session_id=@session;
                DELETE FROM [$(GPDatabase)].dbo.ACTIVITY
                    WHERE USERID=@USERID COLLATE DATABASE_DEFAULT AND SQLSESID=@session
                      AND LOGINDAT=@loginDate AND LOGINTIM=@loginTime;
                IF @@ROWCOUNT<>1 THROW 51106, 'Session changed during cleanup.', 1;
                SET @outcome='CLEANED';
            END
        END
        INSERT dbo.gpManagerAudit(username,session_id,dry_run,outcome,reason)
            VALUES (@USERID,@session,@DryRun,@outcome,@Reason);
        COMMIT;
        SELECT @outcome AS outcome, @USERID AS username, @session AS session_id,
            @loginDate AS login_date, @loginTime AS login_time, @DryRun AS dry_run;
        RETURN @result;
    END TRY
    BEGIN CATCH
        SET @detail=ERROR_MESSAGE();
        IF XACT_STATE()<>0 ROLLBACK;
        INSERT dbo.gpManagerAudit(username,session_id,dry_run,outcome,reason,detail)
            VALUES (@USERID,@session,@DryRun,'ERROR',@Reason,@detail);
        THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.SP_PREVIEW_GP_QUOTA
AS
BEGIN
    SET NOCOUNT ON;
    -- Count GP sessions, not SQL connections. Disabled departments are excluded.
    ;WITH ranked AS (
        SELECT u.username, d.ID AS department_id, RTRIM(d.[name]) AS department,
            a.SQLSESID AS session_id, a.LOGINDAT AS login_date, a.LOGINTIM AS login_time,
            d.[limit] AS quota,
            COUNT(*) OVER (PARTITION BY d.ID) AS active_sessions,
            ROW_NUMBER() OVER (PARTITION BY d.ID ORDER BY a.LOGINDAT DESC,a.LOGINTIM DESC,a.SQLSESID DESC,u.username) AS recent_rank
        FROM dbo.gpManagerUser u
        JOIN dbo.gpManagerDepartment d ON d.ID=u.department_id AND d.enabled=1
        JOIN [$(GPDatabase)].dbo.ACTIVITY a ON a.USERID=u.username COLLATE DATABASE_DEFAULT
    )
    SELECT username,department_id,department,session_id,login_date,login_time,quota,active_sessions,
        active_sessions-quota AS excess_sessions, CAST(1 AS bit) AS dry_run
    FROM ranked WHERE recent_rank<=active_sessions-quota
    ORDER BY department_id,recent_rank;
END;
GO
-- Legacy job entry point: no arguments means automatic enforcement, one user/run.
CREATE OR ALTER PROCEDURE dbo.SP_LOGOUTGPUSER_BY_QUOTE
    @DryRun bit = 0,
    @ProtectActiveTransactions bit = NULL,
    @NotifyInGP bit = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @DryRun IS NULL THROW 51110, 'DryRun cannot be NULL.', 1;
    IF @DryRun=1
    BEGIN
        EXEC dbo.SP_PREVIEW_GP_QUOTA;
        RETURN 0;
    END;
    IF @@TRANCOUNT<>0
    BEGIN
        RAISERROR('Call quota enforcement outside a transaction.',16,1);
        RETURN 1;
    END;
    SET XACT_ABORT ON;
    DECLARE @user nvarchar(15), @session int, @date datetime, @time datetime,
        @department nvarchar(25), @departmentID int, @lock int, @result int=0,
        @outcome varchar(32)='QUOTA_REMOVED', @detail nvarchar(2048),
        @auditID bigint, @notificationID bigint, @companyID int, @companyCount int, @companyName nvarchar(65);
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @lock=sys.sp_getapplock @Resource=N'gpManager.cleanup',
            @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
        IF @lock<0 THROW 51111, 'Could not acquire quota enforcement lock.', 1;

        DECLARE @enabled bit;
        SELECT @enabled=automation_enabled,@ProtectActiveTransactions=COALESCE(@ProtectActiveTransactions,protect_transactions),
            @NotifyInGP=COALESCE(@NotifyInGP,notify_in_gp)
        FROM dbo.gpManagerSettings WITH(UPDLOCK,HOLDLOCK) WHERE ID=1;
        IF @enabled IS NULL THROW 51114,'Automation configuration is missing.',1;
        IF @enabled=0
        BEGIN
            UPDATE dbo.gpManagerRuntime SET last_completed_at=SYSUTCDATETIME(),last_outcome='PAUSED',last_error_number=NULL WHERE ID=1;
            COMMIT;
            SELECT 'PAUSED' AS outcome,@user AS username,@session AS session_id,@notificationID AS notification_id;
            RETURN 0;
        END;

        -- Re-evaluate the quota while holding locks, not from an old preview.
        ;WITH candidates AS (
            SELECT u.username,d.ID AS department_id,d.[name] AS department,
                a.SQLSESID,a.LOGINDAT,a.LOGINTIM,a.CMPNYNAM,d.[limit] AS quota,
                COUNT(*) OVER (PARTITION BY d.ID) AS active_sessions
            FROM dbo.gpManagerDepartment d WITH (UPDLOCK,HOLDLOCK)
            JOIN dbo.gpManagerUser u WITH (UPDLOCK,HOLDLOCK) ON u.department_id=d.ID
            JOIN [$(GPDatabase)].dbo.ACTIVITY a WITH (UPDLOCK,HOLDLOCK)
                ON a.USERID=u.username COLLATE DATABASE_DEFAULT
            WHERE d.enabled=1
        )
        SELECT TOP (1) @user=RTRIM(username),@session=SQLSESID,@date=LOGINDAT,@time=LOGINTIM,
            @department=RTRIM(department),@departmentID=department_id,@companyName=CMPNYNAM
        FROM candidates WHERE active_sessions>quota
        ORDER BY LOGINDAT DESC,LOGINTIM DESC,SQLSESID DESC,username;

        IF @user IS NULL
        BEGIN
            UPDATE dbo.gpManagerRuntime SET last_completed_at=SYSUTCDATETIME(),last_outcome='NO_EXCESS',last_error_number=NULL WHERE ID=1;
            COMMIT;
            SELECT 'NO_EXCESS' AS outcome, @user AS username, @session AS session_id,
                @notificationID AS notification_id;
            RETURN 0;
        END;
        IF @session IS NULL OR @session<=0 OR @date IS NULL OR @time IS NULL
           OR (SELECT COUNT(*) FROM [$(GPDatabase)].dbo.ACTIVITY WITH (UPDLOCK,HOLDLOCK)
               WHERE USERID=@user COLLATE DATABASE_DEFAULT)<>1
            SELECT @outcome='AMBIGUOUS_SESSION',@result=3;
        ELSE IF EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.ACTIVITY WITH (UPDLOCK,HOLDLOCK)
                        WHERE SQLSESID=@session AND USERID<>@user COLLATE DATABASE_DEFAULT)
            SELECT @outcome='SHARED_SESSION',@result=3;
        ELSE IF @ProtectActiveTransactions=1 AND (
            EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.SY00800 WITH (UPDLOCK,HOLDLOCK) WHERE USERID=@user COLLATE DATABASE_DEFAULT)
            OR EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.SY00801 WITH (UPDLOCK,HOLDLOCK) WHERE USERID=@user COLLATE DATABASE_DEFAULT))
            SELECT @outcome='ACTIVITY_BLOCKED',@result=3;
        ELSE
        BEGIN
            IF @NotifyInGP=1
            BEGIN
                SELECT @companyID=MIN(CMPANYID),@companyCount=COUNT(*)
                FROM [$(GPDatabase)].dbo.SY01500 WITH (HOLDLOCK)
                WHERE CMPNYNAM=@companyName COLLATE DATABASE_DEFAULT;
                IF @companyCount<>1 OR @companyID IS NULL
                    THROW 51113, 'Cannot uniquely resolve the GP company for the notification.', 1;
            END;
            -- Preserve the original forced-removal policy, including live clients.
            -- This removes GP/Dexterity records; it does not KILL SQL or close GP UI.
            DELETE FROM [$(DexDatabase)].dbo.DEX_LOCK WHERE session_id=@session;
            DELETE FROM [$(DexDatabase)].dbo.DEX_SESSION WHERE session_id=@session;
            DELETE FROM [$(GPDatabase)].dbo.SY00800 WHERE USERID=@user COLLATE DATABASE_DEFAULT;
            DELETE FROM [$(GPDatabase)].dbo.SY00801 WHERE USERID=@user COLLATE DATABASE_DEFAULT;
            DELETE FROM [$(GPDatabase)].dbo.ACTIVITY
                WHERE USERID=@user COLLATE DATABASE_DEFAULT AND SQLSESID=@session AND LOGINDAT=@date AND LOGINTIM=@time;
            IF @@ROWCOUNT<>1 THROW 51112, 'Session changed during quota enforcement.', 1;
        END;
        INSERT dbo.gpManagerAudit(username,session_id,dry_run,outcome,reason)
            VALUES(@user,@session,0,@outcome,N'Automatic departmental quota enforcement');
        SET @auditID=CONVERT(bigint,SCOPE_IDENTITY());
        IF @outcome='QUOTA_REMOVED'
        BEGIN
            INSERT dbo.gpManagerNotification(audit_id,username,session_id,department_id,company_id,message)
            VALUES(@auditID,@user,@session,@departmentID,@companyID,
                N'Su registro de sesion de Dynamics GP fue retirado porque el departamento '+@department+
                N' excedio su cupo de usuarios. Contacte al administrador para revisar el acceso.');
            SET @notificationID=CONVERT(bigint,SCOPE_IDENTITY());
            IF @NotifyInGP=1 EXEC dbo.SP_POST_GP_NOTIFICATION @NotificationID=@notificationID;
        END;
        UPDATE dbo.gpManagerRuntime SET last_completed_at=SYSUTCDATETIME(),last_outcome=@outcome,last_error_number=NULL WHERE ID=1;
        COMMIT;
        SELECT @outcome AS outcome,@user AS username,@session AS session_id,@notificationID AS notification_id;
        RETURN @result;
    END TRY
    BEGIN CATCH
        SET @detail=ERROR_MESSAGE();
        IF XACT_STATE()<>0 ROLLBACK;
        UPDATE dbo.gpManagerRuntime SET last_completed_at=SYSUTCDATETIME(),last_outcome='ERROR',last_error_number=ERROR_NUMBER() WHERE ID=1;
        INSERT dbo.gpManagerAudit(username,session_id,dry_run,outcome,reason,detail)
            VALUES(COALESCE(@user,N'(quota job)'),@session,0,'ERROR',N'Automatic departmental quota enforcement',@detail);
        THROW;
    END CATCH
END;
GO
