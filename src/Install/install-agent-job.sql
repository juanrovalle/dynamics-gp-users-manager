:On Error exit
-- Explicit optional deployment: creates an ENABLED SQL Server Agent job.
-- Run through Install.ps1 -InstallAgentJob; no job is started immediately.
USE msdb;
GO
SET XACT_ABORT ON;
DECLARE @name sysname=N'GPUM - $(ManagerDatabase)', @job uniqueidentifier,
    @schedule sysname=N'GPUM - $(ManagerDatabase) - 1min', @owner sysname=ORIGINAL_LOGIN(), @rc int;
IF LEN(N'$(ManagerDatabase)')>96 THROW 51300, 'Manager database name is too long for the generated job name.', 1;
IF OBJECT_ID(N'$(ManagerDatabase).dbo.SP_LOGOUTGPUSER_BY_QUOTE',N'P') IS NULL
    THROW 51301, 'Install the manager procedures first.', 1;
IF EXISTS(SELECT 1 FROM dbo.sysjobs WHERE name=@name)
BEGIN
    IF EXISTS(SELECT 1 FROM dbo.sysjobs WHERE name=@name AND description<>N'GPUM managed quota enforcement v2')
        THROW 51302, 'A different job already uses this name. No changes made.', 1;
    PRINT 'The GPUM job already exists; its schedule, owner and settings were preserved.';
    RETURN;
END;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @rc=dbo.sp_add_job @job_name=@name,@enabled=1,@owner_login_name=@owner,
        @description=N'GPUM managed quota enforcement v2',@job_id=@job OUTPUT;
    IF @rc<>0 THROW 51303, 'Could not create quota job.', 1;
    EXEC @rc=dbo.sp_add_jobstep @job_id=@job,@step_name=N'Enforce quota and queue GP message',
        @subsystem=N'TSQL',@database_name=N'$(ManagerDatabase)',
        @command=N'EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE @DryRun=0, @ProtectActiveTransactions=0, @NotifyInGP=1;',
        @on_success_action=1,@on_fail_action=2,@retry_attempts=0;
    IF @rc<>0 THROW 51304, 'Could not create quota job step.', 1;
    EXEC @rc=dbo.sp_add_jobschedule @job_id=@job,@name=@schedule,@enabled=1,
        @freq_type=4,@freq_interval=1,@freq_subday_type=4,@freq_subday_interval=1,
        @active_start_date=20200101,@active_start_time=0;
    IF @rc<>0 THROW 51305, 'Could not create one-minute schedule.', 1;
    EXEC @rc=dbo.sp_add_jobserver @job_id=@job,@server_name=N'(LOCAL)';
    IF @rc<>0 THROW 51306, 'Could not assign quota job to this server.', 1;
    COMMIT;
    PRINT 'Enabled quota job created: every minute, one removal per run, native GP notification.';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO
