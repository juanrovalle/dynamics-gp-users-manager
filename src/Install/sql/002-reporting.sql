CREATE OR ALTER VIEW dbo.vw_gpManagerDepartmentUsage
AS
    SELECT d.ID AS department_id, RTRIM(d.[name]) AS [name], d.enabled,
        d.[limit] AS Limite, COUNT(a.USERID) AS Activos,
        d.[limit] - COUNT(a.USERID) AS Disponible,
        CASE WHEN COUNT(a.USERID) > d.[limit] THEN COUNT(a.USERID)-d.[limit] ELSE 0 END AS Exceso
    FROM dbo.gpManagerDepartment d
    LEFT JOIN dbo.gpManagerUser u ON u.department_id=d.ID
    LEFT JOIN [$(GPDatabase)].dbo.ACTIVITY a ON a.USERID=u.username COLLATE DATABASE_DEFAULT
    GROUP BY d.ID, d.[name], d.enabled, d.[limit];
GO
CREATE OR ALTER VIEW dbo.vw_gpManagerSessions
AS
    SELECT u.department_id, RTRIM(d.[name]) AS departamento,
        RTRIM(a.USERID) AS usuario, a.CMPNYNAM AS company,
        a.LOGINDAT AS logInDate, a.LOGINTIM AS logInTime, a.SQLSESID AS session_id,
        CASE WHEN EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.SY00800 t WHERE t.USERID=a.USERID)
               OR EXISTS (SELECT 1 FROM [$(GPDatabase)].dbo.SY00801 t WHERE t.USERID=a.USERID)
             THEN 'Actividad registrada' ELSE 'Sin actividad registrada (no implica inactividad)' END AS activity
    FROM [$(GPDatabase)].dbo.ACTIVITY a
    LEFT JOIN dbo.gpManagerUser u ON u.username=a.USERID COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.gpManagerDepartment d ON d.ID=u.department_id;
GO
