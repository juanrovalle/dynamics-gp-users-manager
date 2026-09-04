:On Error exit
USE GPManagerTest;
SET NOCOUNT ON;
IF DB_NAME()<>N'GPManagerTest' THROW 52001, 'Wrong test database.', 1;
IF (SELECT COUNT(*) FROM dbo.gpManagerUser)<>3 THROW 52002, 'Upgrade did not preserve users.', 1;
IF (SELECT COUNT(*) FROM dbo.gpManagerSchemaVersion WHERE version=4)<>1 THROW 52003, 'Schema-v4 migration is not idempotent.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.vw_gpManagerDepartmentUsage WHERE department_id=3 AND Activos=0 AND Disponible=2)
    THROW 52004, 'Empty departments missing or incorrectly counted.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.vw_gpManagerDepartmentUsage WHERE department_id=1 AND Activos=2 AND Disponible=-1 AND Exceso=1)
    THROW 52005, 'Quota totals incorrect.', 1;
CREATE TABLE #quota(username nchar(15),department_id int,department nvarchar(25),session_id int,login_date datetime,login_time datetime,quota int,active_sessions int,excess_sessions int,dry_run bit);
INSERT #quota EXEC dbo.SP_PREVIEW_GP_QUOTA;
IF (SELECT COUNT(*) FROM #quota)<>1 OR NOT EXISTS(SELECT 1 FROM #quota WHERE username=N'bob' AND session_id=102)
    THROW 52006, 'Quota selection/date ordering/disabled filtering incorrect.', 1;
PRINT 'PASS migration, reporting and quota selection';

DECLARE @rc int, @failed bit=0;
BEGIN TRY
    EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE @DryRun=NULL;
END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>51110 THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 THROW 52007, 'NULL execution flag must be refused.', 1;
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0;
IF @rc<>0 OR NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='bob')
    THROW 52008, 'Default preview changed GP data.', 1;
IF (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'PREVIEW' THROW 52009, 'Preview audit missing.', 1;
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0;
IF @rc<>3 OR (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'CONFIRMATION_REQUIRED'
    THROW 52010, 'Missing confirmation allowed.', 1;
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test',999,'20260102','19000101 01:00:00';
IF @rc<>3 OR (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'STALE_SELECTION'
    THROW 52011, 'Stale selection allowed.', 1;
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test',102,'20260101','19000101 01:00:00';
IF @rc<>3 THROW 52012, 'Reused session ID with different login allowed.', 1;
PRINT 'PASS preview, confirmation and stale selection';

INSERT GPManagerTestGP.dbo.SY00800 VALUES('bob');
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test',102,'20260102','19000101 01:00:00';
IF @rc<>3 OR (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'ACTIVITY_BLOCKED'
    THROW 52013, 'Batch activity was not protected.', 1;
DELETE GPManagerTestGP.dbo.SY00800 WHERE USERID='bob';
INSERT GPManagerTestGP.dbo.SY00801 VALUES('bob');
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test',102,'20260102','19000101 01:00:00';
IF @rc<>3 THROW 52014, 'Resource activity was not protected.', 1;
DELETE GPManagerTestGP.dbo.SY00801 WHERE USERID='bob';
UPDATE GPManagerTestDex.dbo.DEX_SESSION SET sqlsvr_spid=@@SPID WHERE session_id=102;
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test',102,'20260102','19000101 01:00:00';
IF @rc<>3 OR (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'LIVE_SESSION_BLOCKED'
    THROW 52015, 'Live SQL session was not protected.', 1;
UPDATE GPManagerTestDex.dbo.DEX_SESSION SET sqlsvr_spid=-1 WHERE session_id=102;
INSERT GPManagerTestGP.dbo.ACTIVITY(USERID,SQLSESID,LOGINDAT,LOGINTIM) VALUES('bob',104,'20260102','19000101 03:00:00');
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob';
IF @rc<>3 OR (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'AMBIGUOUS_SESSION'
    THROW 52016, 'Multiple GP sessions not rejected.', 1;
DELETE GPManagerTestGP.dbo.ACTIVITY WHERE SQLSESID=104;
INSERT GPManagerTestGP.dbo.ACTIVITY(USERID,SQLSESID,LOGINDAT,LOGINTIM) VALUES('other',102,'20260102','19000101 03:00:00');
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob';
IF @rc<>3 OR (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'SHARED_SESSION'
    THROW 52017, 'Shared session was not protected.', 1;
DELETE GPManagerTestGP.dbo.ACTIVITY WHERE USERID='other';
PRINT 'PASS active, live, multiple and shared sessions';

EXEC GPManagerTestDex.sys.sp_executesql N'CREATE TRIGGER dbo.test_fail_delete ON dbo.DEX_SESSION AFTER DELETE AS BEGIN THROW 52999, ''Injected failure'', 1; END;';
SET @failed=0;
BEGIN TRY
    EXEC dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test rollback',102,'20260102','19000101 01:00:00';
END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>52999 THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 THROW 52018, 'Injected failure was not raised.', 1;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='bob')
    OR NOT EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_SESSION WHERE session_id=102)
    OR NOT EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_LOCK WHERE session_id=102)
    THROW 52019, 'Partial cleanup was not rolled back.', 1;
IF (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'ERROR' THROW 52020, 'Error audit missing.', 1;
EXEC GPManagerTestDex.sys.sp_executesql N'DROP TRIGGER dbo.test_fail_delete;';
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'bob',0,0,1,N'Test successful cleanup',102,'20260102','19000101 01:00:00';
IF @rc<>0 OR EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='bob')
    OR EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_SESSION WHERE session_id=102)
    OR EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_LOCK WHERE session_id=102)
    THROW 52021, 'Confirmed orphan cleanup failed.', 1;
IF (SELECT TOP(1) outcome FROM dbo.gpManagerAudit ORDER BY ID DESC)<>'CLEANED' THROW 52022, 'Success audit missing.', 1;
IF (SELECT COUNT(*) FROM GPManagerTestGP.dbo.ACTIVITY)<>2
    OR (SELECT COUNT(*) FROM GPManagerTestDex.dbo.DEX_LOCK)<>2 THROW 52023, 'Cleanup touched other users.', 1;
EXEC @rc=dbo.SP_LOGOUTGPUSER_TRAN N'absent';
IF @rc<>2 THROW 52024, 'Missing user return code incorrect.', 1;
PRINT 'PASS atomic rollback, audit and isolated cleanup';

SET @failed=0;
BEGIN TRY
    INSERT dbo.gpManagerUser(username,department_id) VALUES(N'alice',1);
END TRY BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 THROW 52025, 'Duplicate user accepted.', 1;
SET @failed=0;
BEGIN TRY
    UPDATE dbo.gpManagerDepartment SET [limit]=-1 WHERE ID=1;
END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>547 THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 THROW 52026, 'Negative quota accepted.', 1;
SET @failed=0;
BEGIN TRY
    INSERT dbo.gpManagerUser(username,department_id) VALUES(NULL,1);
END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>547 THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 THROW 52027, 'Null username accepted.', 1;
PRINT 'PASS constraints';
SET @failed=0;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.SP_LOGOUTGPUSER_TRAN N'alice';
END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>50000 THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1
    THROW 52029, 'Caller transaction was not preserved.', 1;
ROLLBACK;
PRINT 'PASS caller transaction preservation';
PRINT 'ALL INTEGRATION TESTS PASSED';
GO
