IF COL_LENGTH(N'dbo.gpManagerDepartment',N'revision') IS NULL
    ALTER TABLE dbo.gpManagerDepartment ADD revision rowversion;
IF COL_LENGTH(N'dbo.gpManagerUser',N'revision') IS NULL
    ALTER TABLE dbo.gpManagerUser ADD revision rowversion;
IF OBJECT_ID(N'dbo.gpManagerSettings',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.gpManagerSettings (
        ID int NOT NULL PRIMARY KEY CHECK(ID=1),
        automation_enabled bit NOT NULL DEFAULT(0),
        protect_transactions bit NOT NULL DEFAULT(0),
        notify_in_gp bit NOT NULL DEFAULT(1),
        gp_database sysname NOT NULL, dex_database sysname NOT NULL,
        installation_id uniqueidentifier NOT NULL DEFAULT NEWID(),
        customer_name nvarchar(150) NOT NULL DEFAULT(N''),
        customer_contact nvarchar(200) NOT NULL DEFAULT(N''),
        purchased_on date NULL, maintenance_until date NULL,
        test_notification_id bigint NULL, message_confirmed bit NOT NULL DEFAULT(0),
        revision rowversion
    );
    -- Preserve the state of a recognizable pre-existing job. Fresh installs pause.
    DECLARE @existingEnabled bit=0;
    SELECT @existingEnabled=MAX(CONVERT(int,j.enabled))
    FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobsteps s ON s.job_id=j.job_id
    WHERE s.database_name=DB_NAME() AND s.command LIKE N'%SP_LOGOUTGPUSER_BY_QUOTE%';
    INSERT dbo.gpManagerSettings(ID,automation_enabled,gp_database,dex_database,message_confirmed)
        VALUES(1,COALESCE(@existingEnabled,0),N'$(GPDatabase)',N'$(DexDatabase)',COALESCE(@existingEnabled,0));
END;
GO
IF OBJECT_ID(N'dbo.gpManagerRuntime',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.gpManagerRuntime(ID int NOT NULL PRIMARY KEY CHECK(ID=1),
        last_completed_at datetime2(3) NULL,last_outcome varchar(32) NULL,last_error_number int NULL);
    INSERT dbo.gpManagerRuntime(ID) VALUES(1);
END;
GO
IF EXISTS(SELECT 1 FROM dbo.gpManagerSettings WHERE gp_database<>N'$(GPDatabase)' OR dex_database<>N'$(DexDatabase)')
    THROW 51400,'This installation is bound to different GP/Dexterity databases.',1;
GO
