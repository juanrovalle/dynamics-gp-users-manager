namespace GPManager.Core;

/// <summary>Only trusted, quoted identifiers/literals are interpolated into the Agent step.</summary>
public static class JobCommands
{
    public static string Create(string runtimeLogin)
    {
        var principal=SqlNames.Principal(runtimeLogin);
        var literal="N'"+runtimeLogin.Replace("'","''")+"'";
        // Resolve by SID because an existing database user may have a different name.
        // A conflicting username makes CREATE USER fail rather than granting another identity.
        var bootstrap=$"USE tempdb; DECLARE @u sysname,@sql nvarchar(max); SELECT @u=name FROM sys.database_principals WHERE sid=SUSER_SID({literal}); IF @u IS NULL BEGIN CREATE USER {principal} FOR LOGIN {principal}; SET @u={literal}; END; SET @sql=N'GRANT SELECT,DELETE ON dbo.DEX_SESSION TO '+QUOTENAME(@u)+N'; GRANT SELECT,DELETE ON dbo.DEX_LOCK TO '+QUOTENAME(@u)+N';'; EXEC sys.sp_executesql @sql;";
        return "EXEC(N'"+bootstrap.Replace("'","''")+"'); EXECUTE AS LOGIN="+literal+"; BEGIN TRY EXEC dbo.SP_LOGOUTGPUSER_BY_QUOTE; REVERT; END TRY BEGIN CATCH REVERT; THROW; END CATCH;";
    }
}

