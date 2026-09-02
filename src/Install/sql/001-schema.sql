-- Upgrade in place: retain legacy column types, IDs and customer data.
IF OBJECT_ID(N'dbo.gpManagerSchemaVersion', N'U') IS NULL
    CREATE TABLE dbo.gpManagerSchemaVersion (
        version int NOT NULL PRIMARY KEY,
        installed_at datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME()
    );
IF EXISTS (SELECT 1 FROM dbo.gpManagerSchemaVersion WHERE version > 3)
    THROW 51002, 'Database is newer than this installer. Downgrade refused.', 1;
IF OBJECT_ID(N'dbo.gpManagerDepartment', N'U') IS NULL
    CREATE TABLE dbo.gpManagerDepartment (
        ID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_gpManagerDepartment PRIMARY KEY,
        [limit] int NOT NULL CONSTRAINT DF_gpManagerDepartment_limit DEFAULT (0),
        [name] nchar(25) NOT NULL,
        enabled bit NOT NULL CONSTRAINT DF_gpManagerDepto_enabled DEFAULT (1)
    );
IF OBJECT_ID(N'dbo.gpManagerUser', N'U') IS NULL
    CREATE TABLE dbo.gpManagerUser (
        ID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_gpManagerUser PRIMARY KEY,
        [name] nchar(30) NULL,
        username nchar(15) NULL,
        department_id int NOT NULL
    );
-- Never silently delete or merge invalid legacy records.
IF EXISTS (SELECT 1 FROM dbo.gpManagerDepartment WHERE [limit] < 0 OR LTRIM(RTRIM([name])) = N'')
    THROW 51003, 'Correct negative limits or blank department names before upgrading.', 1;
IF EXISTS (SELECT 1 FROM dbo.gpManagerUser WHERE username IS NULL OR LTRIM(RTRIM(username)) = N'')
    THROW 51004, 'Correct null or blank usernames before upgrading.', 1;
IF EXISTS (SELECT username FROM dbo.gpManagerUser GROUP BY username HAVING COUNT(*) > 1)
    THROW 51005, 'Resolve duplicate usernames before upgrading.', 1;
IF EXISTS (SELECT 1 FROM dbo.gpManagerUser u LEFT JOIN dbo.gpManagerDepartment d ON d.ID=u.department_id WHERE d.ID IS NULL)
    THROW 51006, 'Correct orphan department references before upgrading.', 1;
IF OBJECT_ID(N'dbo.CK_gpManagerDepartment_limit', N'C') IS NULL
    ALTER TABLE dbo.gpManagerDepartment WITH CHECK ADD CONSTRAINT CK_gpManagerDepartment_limit CHECK ([limit] >= 0);
IF OBJECT_ID(N'dbo.CK_gpManagerDepartment_name', N'C') IS NULL
    ALTER TABLE dbo.gpManagerDepartment WITH CHECK ADD CONSTRAINT CK_gpManagerDepartment_name CHECK (LTRIM(RTRIM([name])) <> N'');
IF OBJECT_ID(N'dbo.CK_gpManagerUser_username', N'C') IS NULL
    ALTER TABLE dbo.gpManagerUser WITH CHECK ADD CONSTRAINT CK_gpManagerUser_username CHECK (username IS NOT NULL AND LTRIM(RTRIM(username)) <> N'');
IF OBJECT_ID(N'dbo.FK_gpManagerUser_gpManagerDepartment', N'F') IS NULL
    ALTER TABLE dbo.gpManagerUser WITH CHECK ADD CONSTRAINT FK_gpManagerUser_gpManagerDepartment
        FOREIGN KEY (department_id) REFERENCES dbo.gpManagerDepartment(ID);
ALTER TABLE dbo.gpManagerUser WITH CHECK CHECK CONSTRAINT FK_gpManagerUser_gpManagerDepartment, CK_gpManagerUser_username;
ALTER TABLE dbo.gpManagerDepartment WITH CHECK CHECK CONSTRAINT CK_gpManagerDepartment_limit, CK_gpManagerDepartment_name;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.gpManagerUser') AND name=N'UX_gpManagerUser_username')
    CREATE UNIQUE INDEX UX_gpManagerUser_username ON dbo.gpManagerUser(username);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.gpManagerUser') AND name=N'IX_gpManagerUser_department')
    CREATE INDEX IX_gpManagerUser_department ON dbo.gpManagerUser(department_id) INCLUDE(username);
IF OBJECT_ID(N'dbo.gpManagerAudit', N'U') IS NULL
    CREATE TABLE dbo.gpManagerAudit (
        ID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_gpManagerAudit PRIMARY KEY,
        occurred_at datetime2(3) NOT NULL CONSTRAINT DF_gpManagerAudit_time DEFAULT SYSUTCDATETIME(),
        actor sysname NOT NULL CONSTRAINT DF_gpManagerAudit_actor DEFAULT ORIGINAL_LOGIN(),
        username nvarchar(128) NOT NULL,
        session_id int NULL,
        dry_run bit NOT NULL,
        outcome varchar(32) NOT NULL,
        reason nvarchar(400) NULL,
        detail nvarchar(2048) NULL
    );
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.gpManagerAudit') AND name=N'IX_gpManagerAudit_time')
    CREATE INDEX IX_gpManagerAudit_time ON dbo.gpManagerAudit(occurred_at DESC) INCLUDE(username, outcome);
IF OBJECT_ID(N'dbo.gpManagerNotification',N'U') IS NULL
    CREATE TABLE dbo.gpManagerNotification (
        ID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_gpManagerNotification PRIMARY KEY,
        audit_id bigint NOT NULL CONSTRAINT UQ_gpManagerNotification_audit UNIQUE
            CONSTRAINT FK_gpManagerNotification_audit REFERENCES dbo.gpManagerAudit(ID),
        created_at datetime2(3) NOT NULL CONSTRAINT DF_gpManagerNotification_time DEFAULT SYSUTCDATETIME(),
        username nvarchar(15) NOT NULL,
        session_id int NOT NULL,
        department_id int NOT NULL,
        company_id int NULL,
        message nvarchar(600) NOT NULL,
        [status] varchar(16) NOT NULL CONSTRAINT DF_gpManagerNotification_status DEFAULT('PENDING'),
        queued_at datetime2(3) NULL,
        gp_sequence int NULL,
        last_error nvarchar(2048) NULL,
        CONSTRAINT CK_gpManagerNotification_status CHECK ([status] IN ('PENDING','QUEUED_GP','FAILED'))
    );
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.gpManagerNotification') AND name=N'IX_gpManagerNotification_pending')
    CREATE INDEX IX_gpManagerNotification_pending ON dbo.gpManagerNotification([status],ID);
GO
