
USE [master]
GO
CREATE DATABASE [DEVELOPMENT]
GO

--Tables For Departments and Quote of users
USE [DEVELOPMENT]

CREATE TABLE [dbo].[gpManagerDepartment](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[limit] [int] NOT NULL,
	[name] [nchar](25) NOT NULL,
	[enabled] [bit] NOT NULL,
 CONSTRAINT [PK_gpManagerDepartment] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[gpManagerDepartment] ADD  CONSTRAINT [DF_gpManagerDepartment_limit]  DEFAULT ((0)) FOR [limit]
GO

ALTER TABLE [dbo].[gpManagerDepartment] ADD  CONSTRAINT [DF_gpManagerDepto_enabled]  DEFAULT ((1)) FOR [enabled]
GO

GO
CREATE TABLE [dbo].[gpManagerUser](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[name] [nchar](30) NULL,
	[username] [nchar](15) NULL,
	[department_id] [int] NOT NULL,
 CONSTRAINT [PK_gpManagerUser] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[gpManagerUser]  WITH CHECK ADD  CONSTRAINT [FK_gpManagerUser_gpManagerDepartment] FOREIGN KEY([department_id])
REFERENCES [dbo].[gpManagerDepartment] ([ID])
GO

ALTER TABLE [dbo].[gpManagerUser] CHECK CONSTRAINT [FK_gpManagerUser_gpManagerDepartment]
GO

-- StoredProcedures 
-- Logout By Department Quote
USE [DEVELOPMENT]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  	Juan R Ovalle
-- Create date: 6-11-2019
-- Permite la eliminacion completa de un usuario por limite grupos
-- de Sesion de SQL, de Actividad transaccional y de bloqueo de registros
-- =============================================
CREATE PROCEDURE [dbo].[SP_LOGOUTGPUSER_BY_QUOTE]
-- Add the parameters for the stored procedure here
AS
BEGIN
  DECLARE @USERID varchar(max),
   @TIME datetime,
   @APPID int
  DECLARE cur CURSOR LOCAL FOR
 SELECT  top 1 u.username UserID ,
   --    d.NAME, 
      a.logintim,
	  0
FROM   development.dbo.gpmanageruser u 
       JOIN dynamics.dbo.activity a 
         ON a.userid = u.username 
       JOIN development.dbo.gpmanagerdepartment d 
         ON d.id = u.department_id 
		 	 where u.department_id 
	 IN (SELECT tp.departamento 
                           FROM  (SELECT u.department_id     departamento, 
                                          d.NAME              nombre, 
                                         d.limit  - Count (*)  disponibles, 
                                          Count (*)           activos, 
                                          d.limit             limite 
                                   FROM   development.dbo.gpmanageruser u 
                                          JOIN dynamics.dbo.activity a 
                                            ON a.userid = u.username 
                                          JOIN 
                                  development.dbo.gpmanagerdepartment d 
                                            ON d.id = u.department_id 
                                   GROUP  BY u.department_id, 
                                             d.limit, 
                                             d.NAME 
                                   HAVING    d.limit  - Count (*)   < 0 )  tp) 
								   	 order by  a.logintim desc 
  OPEN cur
  FETCH NEXT FROM cur INTO @USERID, @TIME ,@APPID

  WHILE @@FETCH_STATUS = 0
  BEGIN
    --execute your SP on each row
    EXEC development.[dbo].[SP_LOGOUTGPUSER_TRAN] @USERID, @APPID
    FETCH NEXT FROM cur INTO @USERID
  END
  CLOSE cur
  DEALLOCATE cur
END


/****** Object:  StoredProcedure [dbo].[SP_LOGOUTGPUSER_TRAN]    Script Date: 7/5/2024 9:21:40 a. m. ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Juan R Ovalle
-- Create date: 25-10-2017
-- Description:	To logout one GP user
-- RETURNS 
---0 OK  
---3 Active USER
-- Permite la eliminacion completa de un usuario cuyo proceso tuvo alguna 
-- desconexion con el servidor Not Responding, de las tablas de Actividad, 
-- de Sesion de SQL, de Actividad transaccional y de bloqueo de registros
-- =============================================
CREATE PROCEDURE [dbo].[SP_LOGOUTGPUSER_TRAN]
  -- Add the parameters for the stored procedure here
  @USERID AS CHAR(15),
  @AppID  AS INT --Id usuario GP
AS
  BEGIN
      DECLARE @SQLSESID  AS INT,--Interno
              @ACTIVIDAD AS INT

      SET @SQLSESID = (SELECT sqlsesid
                       FROM   dynamics.dbo.activity
                       WHERE  userid = @UserId)
      SET @ACTIVIDAD = (SELECT Sum(CASE
                                     WHEN gb.accion = NULL THEN 0
                                     ELSE 1
                                   END)
                        FROM   (SELECT [userid],
                                       Min(bachnumb) accion,
                                       Getdate()     fecha
                                FROM   [DYNAMICS].[dbo].[sy00800]
                                WHERE  [userid] NOT IN (SELECT userid
                                                        FROM
                                       [DYNAMICS].[dbo].[sy00801])
                                GROUP  BY userid) AS gb
                               RIGHT JOIN dynamics.dbo.activity a
                                       ON gb.userid = a.userid
                        WHERE  gb.userid = @USERID
                        GROUP  BY gb.accion)

    
      IF ( @AppID = 0 )
        BEGIN
            PRINT'GP'

            DELETE dynamics.dbo.activity
            WHERE  userid = @UserId

            DELETE tempdb.dbo.dex_session
            WHERE  session_id = @SQLSESID

            DELETE tempdb.dbo.dex_lock
            WHERE  session_id = @SQLSESID

            DELETE dynamics.dbo.sy00800
            WHERE  userid = @UserId

            DELETE dynamics.dbo.sy00801
            WHERE  userid = @UserId
			return 0
        END
      ELSE if(@AppID=1)
        BEGIN
            delete dynamics.dbo.spActiveUsers
			where username = @USERID
		
			
			return 0
        END
  END 
GO

