:On Error exit
-- ONLY for an empty, isolated SQL Server instance. Never touches DYNAMICS/tempdb.
USE master;
IF DB_ID(N'GPManagerTest') IS NOT NULL OR DB_ID(N'GPManagerTestGP') IS NOT NULL OR DB_ID(N'GPManagerTestDex') IS NOT NULL
    THROW 52000, 'Test databases already exist. Use a new isolated instance.', 1;
CREATE DATABASE GPManagerTest;
CREATE DATABASE GPManagerTestGP;
CREATE DATABASE GPManagerTestDex;
GO
USE GPManagerTest;
-- Legacy schema exercises migration with existing customer data.
CREATE TABLE dbo.gpManagerDepartment(ID int IDENTITY PRIMARY KEY, [limit] int NOT NULL DEFAULT(0), [name] nchar(25) NOT NULL, enabled bit NOT NULL DEFAULT(1));
CREATE TABLE dbo.gpManagerUser(ID int IDENTITY PRIMARY KEY, [name] nchar(30) NULL, username nchar(15) NULL, department_id int NOT NULL);
INSERT dbo.gpManagerDepartment([limit],[name],enabled) VALUES(1,N'Sales',1),(0,N'Disabled',0),(2,N'Empty',1);
INSERT dbo.gpManagerUser(username,department_id) VALUES(N'alice',1),(N'bob',1),(N'carol',2);
GO
USE GPManagerTestGP;
CREATE TABLE dbo.ACTIVITY(USERID char(15) NOT NULL, SQLSESID int NOT NULL, LOGINDAT datetime NOT NULL, LOGINTIM datetime NOT NULL, CMPNYNAM char(65) NOT NULL DEFAULT('Test company'));
CREATE TABLE dbo.SY00800(USERID char(15) NOT NULL);
CREATE TABLE dbo.SY00801(USERID char(15) NOT NULL);
CREATE TABLE dbo.SY01500(CMPANYID smallint NOT NULL PRIMARY KEY,CMPNYNAM char(65) NOT NULL);
CREATE TABLE dbo.SY01400(USERID char(15) NOT NULL PRIMARY KEY,USERNAME char(65) NOT NULL);
INSERT dbo.SY01400 VALUES('alice','Alice'),('bob','Bob'),('carol','Carol'),('unassigned','Unassigned user');
INSERT dbo.SY01500 VALUES(1,'Test company');
CREATE TABLE dbo.SY30000(USERID char(15) NOT NULL,CMPANYID smallint NOT NULL,SEQNUMBR int NOT NULL,
    Offline_Message char(255) NOT NULL,DEX_ROW_ID int IDENTITY NOT NULL,
    PRIMARY KEY(USERID,CMPANYID,SEQNUMBR));
INSERT dbo.ACTIVITY(USERID,SQLSESID,LOGINDAT,LOGINTIM) VALUES
 ('alice',101,'20260101','19000101 23:00:00'),('bob',102,'20260102','19000101 01:00:00'),('carol',103,'20260102','19000101 02:00:00');
GO
USE GPManagerTestDex;
CREATE TABLE dbo.DEX_SESSION(session_id int NOT NULL, sqlsvr_spid int NOT NULL);
CREATE TABLE dbo.DEX_LOCK(session_id int NOT NULL);
INSERT dbo.DEX_SESSION VALUES(101,-1),(102,-1),(103,-1);
INSERT dbo.DEX_LOCK VALUES(101),(102),(103);
GO
