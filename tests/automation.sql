:On Error exit
USE GPManagerTest;
SET NOCOUNT ON;
-- Fresh/legacy-without-job installs must not remove sessions before explicit activation.
IF (SELECT automation_enabled FROM dbo.gpManagerSettings WHERE ID=1)<>0 THROW 52112,'New installation was not paused.',1;
EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE;
IF (SELECT last_outcome FROM dbo.gpManagerRuntime WHERE ID=1)<>'PAUSED' THROW 52113,'Paused runtime tick missing.',1;
EXEC dbo.SP_GPUM_TEST_MESSAGE @Username=N'alice',@CompanyID=1;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY30000 WHERE USERID='alice' AND Offline_Message LIKE 'Dynamics GP UserOps:%')
    THROW 52114,'Schema-v4 branded test message was not queued.',1;
EXEC dbo.SP_GPUM_SET_AUTOMATION @Enabled=1,@ConfirmMessageObserved=1;
-- Fixture-only reset: production code never deletes queued native messages.
DELETE dbo.gpManagerNotification WHERE username=N'alice';
DELETE GPManagerTestGP.dbo.SY30000 WHERE USERID='alice';
-- Run after integration.sql, which removed bob. Recreate the excess session.
INSERT GPManagerTestGP.dbo.ACTIVITY(USERID,SQLSESID,LOGINDAT,LOGINTIM) VALUES('bob',102,'20260102','19000101 01:00:00');
INSERT GPManagerTestDex.dbo.DEX_SESSION VALUES(102,@@SPID);
INSERT GPManagerTestDex.dbo.DEX_LOCK VALUES(102);
INSERT GPManagerTestGP.dbo.SY00800 VALUES('bob');
INSERT GPManagerTestGP.dbo.SY00801 VALUES('bob');
DECLARE @rc int,@failed bit=0;
EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE @DryRun=1;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='bob') THROW 52100,'Quota preview removed data.',1;
EXEC @rc=dbo.SP_LOGOUTGPUSER_BY_QUOTE @ProtectActiveTransactions=1;
IF @rc<>3 OR NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY00800 WHERE USERID='bob') THROW 52101,'Optional activity protection failed.',1;
IF EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY30000) THROW 52102,'Blocked removal queued a message.',1;

-- Notification errors must roll back all five deletion targets, not just ACTIVITY.
EXEC GPManagerTestGP.sys.sp_executesql N'CREATE TRIGGER dbo.test_fail_message ON dbo.SY30000 AFTER INSERT AS BEGIN THROW 52998, ''Injected notification failure'', 1; END;';
BEGIN TRY
    EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE;
END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>52998 THROW;
    SET @failed=1;
END CATCH;
IF @failed=0 THROW 52103,'Notification failure was not raised.',1;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='bob')
 OR NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY00800 WHERE USERID='bob')
 OR NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY00801 WHERE USERID='bob')
 OR NOT EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_SESSION WHERE session_id=102)
 OR NOT EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_LOCK WHERE session_id=102)
    THROW 52104,'Notification failure did not roll back removal.',1;
IF EXISTS(SELECT 1 FROM dbo.gpManagerNotification) THROW 52105,'Rolled-back notification persisted.',1;
EXEC GPManagerTestGP.sys.sp_executesql N'DROP TRIGGER dbo.test_fail_message;';

-- Legacy automatic entry point: removes even a live connection's GP records.
EXEC @rc=dbo.SP_LOGOUTGPUSER_BY_QUOTE;
IF @rc<>0 OR EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='bob')
 OR EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY00800 WHERE USERID='bob')
 OR EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY00801 WHERE USERID='bob')
 OR EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_SESSION WHERE session_id=102)
 OR EXISTS(SELECT 1 FROM GPManagerTestDex.dbo.DEX_LOCK WHERE session_id=102)
    THROW 52106,'Legacy automatic removal failed.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerNotification WHERE username='bob' AND [status]='QUEUED_GP' AND company_id=1)
    THROW 52107,'GP queue acknowledgement missing.',1;
IF (SELECT COUNT(*) FROM GPManagerTestGP.dbo.SY30000 WHERE USERID='bob' AND CMPANYID=1)<>1
    THROW 52108,'Expected exactly one GP message.',1;
EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE;
IF (SELECT COUNT(*) FROM GPManagerTestGP.dbo.SY30000)<>1
 OR (SELECT COUNT(*) FROM GPManagerTestGP.dbo.ACTIVITY)<>2 THROW 52109,'At-quota run removed another user or duplicated message.',1;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.ACTIVITY WHERE USERID='carol') THROW 52110,'Disabled department was enforced.',1;

-- Shared messages stay intact; new sequence must not overwrite native messages.
INSERT GPManagerTestGP.dbo.SY30000(USERID,CMPANYID,SEQNUMBR,Offline_Message) VALUES('alice',1,100,'Existing native message');
INSERT GPManagerTestGP.dbo.ACTIVITY(USERID,SQLSESID,LOGINDAT,LOGINTIM) VALUES('bob',102,'20260102','19000101 01:00:00');
INSERT GPManagerTestDex.dbo.DEX_SESSION VALUES(102,-1);
INSERT GPManagerTestDex.dbo.DEX_LOCK VALUES(102);
EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE;
IF NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY30000 WHERE USERID='bob' AND SEQNUMBR=101)
 OR NOT EXISTS(SELECT 1 FROM GPManagerTestGP.dbo.SY30000 WHERE USERID='alice' AND SEQNUMBR=100)
    THROW 52111,'Native message sequence collision or overwrite.',1;
PRINT 'ALL AUTOMATION AND GP NOTIFICATION TESTS PASSED';
GO
