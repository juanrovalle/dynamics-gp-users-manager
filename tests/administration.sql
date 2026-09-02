:On Error exit
USE GPManagerTest;
SET NOCOUNT ON;
DECLARE @rev binary(8),@failed bit=0,@count int;
SELECT @rev=revision FROM dbo.gpManagerDepartment WHERE ID=3;
EXEC dbo.SP_GPUM_SAVE_DEPARTMENT @Name=N'Edited',@Quota=4,@Enabled=0,@ID=3,@Revision=@rev;
IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerDepartment WHERE ID=3 AND [limit]=4 AND enabled=0) THROW 52200,'Department edit failed.',1;
BEGIN TRY
 EXEC dbo.SP_GPUM_SAVE_DEPARTMENT @Name=N'Stale',@Quota=9,@Enabled=1,@ID=3,@Revision=@rev;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51402 THROW; SET @failed=1;
END CATCH;
IF @failed=0 OR @@TRANCOUNT<>0 THROW 52201,'Stale edit was accepted or leaked a transaction.',1;
EXEC dbo.SP_GPUM_ASSIGN_USER @Username=N'unassigned',@DepartmentID=3;
SELECT @rev=revision FROM dbo.gpManagerUser WHERE username=N'unassigned';
EXEC dbo.SP_GPUM_UNASSIGN_USER @Username=N'unassigned',@Revision=@rev;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY01400 WHERE USERID='unassigned') THROW 52202,'GP account removed.',1;
SELECT @rev=revision FROM dbo.gpManagerSettings WHERE ID=1;
EXEC dbo.SP_GPUM_SAVE_SETTINGS @ProtectTransactions=1,@NotifyInGP=0,@Customer=N'Pilot',@Contact=N'',
 @PurchasedOn='20200101',@MaintenanceUntil='20210101',@Revision=@rev;
EXEC dbo.SP_GPUM_SET_AUTOMATION @Enabled=1;
IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerSettings WHERE automation_enabled=1 AND maintenance_until='20210101') THROW 52203,'Expired maintenance restricted operation.',1;
EXEC dbo.SP_GPUM_SET_AUTOMATION @Enabled=0;
SELECT @count=COUNT(*) FROM GPManagerTestGP.dbo.ACTIVITY;
EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE;
IF @count<>(SELECT COUNT(*) FROM GPManagerTestGP.dbo.ACTIVITY) OR NOT EXISTS(SELECT 1 FROM dbo.gpManagerRuntime WHERE last_outcome='PAUSED') THROW 52204,'Pause failed.',1;
SELECT @rev=revision FROM dbo.gpManagerSettings WHERE ID=1;
EXEC dbo.SP_GPUM_SAVE_SETTINGS @ProtectTransactions=1,@NotifyInGP=1,@Customer=N'Pilot',@Contact=N'',@Revision=@rev;
SET @failed=0;
BEGIN TRY
 EXEC dbo.SP_GPUM_SET_AUTOMATION @Enabled=1,@ConfirmMessageObserved=NULL;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51410 THROW; SET @failed=1;
END CATCH;
IF @failed=0 THROW 52205,'NULL confirmation accepted.',1;
SET @failed=0;
BEGIN TRY
 EXEC dbo.SP_GPUM_SET_AUTOMATION @Enabled=1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51411 THROW; SET @failed=1;
END CATCH;
IF @failed=0 OR @@TRANCOUNT<>0 THROW 52206,'Unconfirmed activation accepted or leaked a transaction.',1;
EXEC dbo.SP_GPUM_TEST_MESSAGE @Username=N'alice',@CompanyID=1;
EXEC dbo.SP_GPUM_SET_AUTOMATION @Enabled=1,@ConfirmMessageObserved=1;
IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerAudit WHERE outcome='DEPARTMENT_SAVED')
 OR NOT EXISTS(SELECT 1 FROM dbo.gpManagerAudit WHERE outcome='USER_ASSIGNED')
 OR NOT EXISTS(SELECT 1 FROM dbo.gpManagerAudit WHERE outcome='USER_UNASSIGNED')
 THROW 52207,'Administration audit missing.',1;
-- Reader cannot modify configuration through direct DML or procedures.
CREATE USER GPUMTestReader WITHOUT LOGIN;
ALTER ROLE gpManagerReader ADD MEMBER GPUMTestReader;
EXECUTE AS USER='GPUMTestReader';
SET @failed=0;
BEGIN TRY
 EXEC dbo.SP_GPUM_SAVE_DEPARTMENT @Name=N'Denied',@Quota=1,@Enabled=1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>229 THROW; SET @failed=1;
END CATCH;
REVERT;
IF @failed=0 THROW 52208,'Reader modified department.',1;
DROP USER GPUMTestReader;
PRINT 'ALL ADMINISTRATION TESTS PASSED';
GO

