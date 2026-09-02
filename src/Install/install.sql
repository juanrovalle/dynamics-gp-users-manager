:On Error exit
-- SQLCMD mode required. Prefer Install.ps1, which validates substitutions.
USE [master];
GO
IF DB_ID(N'$(ManagerDatabase)') IS NULL
    EXEC(N'CREATE DATABASE [$(ManagerDatabase)]');
GO
USE [$(ManagerDatabase)];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
BEGIN TRANSACTION;
DECLARE @lock int;
EXEC @lock = sys.sp_getapplock @Resource=N'gpManager.install',
    @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
IF @lock < 0 THROW 51000, 'Another installation is running.', 1;
IF DB_ID(N'$(GPDatabase)') IS NULL OR DB_ID(N'$(DexDatabase)') IS NULL
    THROW 51001, 'GP or Dexterity database does not exist.', 1;
GO
-- Force dependency/column checks now; procedure compilation can defer them.
SELECT TOP (0) USERID, SQLSESID, LOGINDAT, LOGINTIM, CMPNYNAM FROM [$(GPDatabase)].dbo.ACTIVITY;
SELECT TOP (0) USERID FROM [$(GPDatabase)].dbo.SY00800;
SELECT TOP (0) USERID FROM [$(GPDatabase)].dbo.SY00801;
SELECT TOP (0) session_id, sqlsvr_spid FROM [$(DexDatabase)].dbo.DEX_SESSION;
SELECT TOP (0) session_id FROM [$(DexDatabase)].dbo.DEX_LOCK;
GO
:r sql/001-schema.sql
:r sql/006-console-schema.sql
:r sql/002-reporting.sql
:r sql/005-notifications.sql
:r sql/003-operations.sql
:r sql/004-roles.sql
:r sql/007-administration.sql
IF NOT EXISTS (SELECT 1 FROM dbo.gpManagerSchemaVersion WHERE version = 3)
    INSERT dbo.gpManagerSchemaVersion(version) VALUES (3);
COMMIT;
PRINT 'GP Users Manager v3 installed. New installations remain paused until activation.';
GO

