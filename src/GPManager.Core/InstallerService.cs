using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
namespace GPManager.Core;

public sealed class InstallerService(DatabaseSession session)
{
    private ConnectionProfile P=>session.Profile;
    public async Task<DataTable> DatabasesAsync()=>await session.QueryAsync("SELECT name FROM sys.databases WHERE database_id>4 AND state=0 ORDER BY name",database:"master");
    public async Task<DataTable> LoginsAsync()=>await session.QueryAsync("SELECT name,type_desc FROM sys.server_principals WHERE type IN('S','U','G') AND is_disabled=0 AND name NOT LIKE '##%' ORDER BY name",database:"master");
    public async Task<IReadOnlyList<JobChoice>> JobsAsync()
    {
        var t=await session.QueryAsync("""
            SELECT j.job_id,j.name,j.enabled,SUSER_SNAME(j.owner_sid) AS owner,s.command,s.step_id,
              (SELECT COUNT(*) FROM msdb.dbo.sysjobsteps t WHERE t.job_id=j.job_id) AS steps
            FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobsteps s ON s.job_id=j.job_id
            WHERE s.command LIKE '%SP_LOGOUTGPUSER_BY_QUOTE%'
              AND (s.database_name=@database OR CHARINDEX(@database,s.command)>0)
            ORDER BY j.name,s.step_id
            """,new(){["@database"]=P.ManagerDatabase},"master");
        return t.Rows.Cast<DataRow>().GroupBy(r=>(Guid)r["job_id"]).Select(g=>g.First()).Select(r=>new JobChoice(
            (Guid)r["job_id"],r.Text("name"),r.Flag("enabled"),r.Text("command"),Convert.ToInt32(r["steps"]),r.Text("owner"),Convert.ToInt32(r["step_id"]))).ToArray();
    }
    public async Task<IReadOnlyList<CheckResult>> PreflightAsync()
    {
        var results=new List<CheckResult>();
        async Task Check(string name,Func<Task<string>> action)
        {try{results.Add(new(name,true,await action()));}catch(Exception ex){results.Add(new(name,false,ex.Message));}}
        await Check("Permisos de instalación",async()=>{
            var t=await session.QueryAsync("SELECT IS_SRVROLEMEMBER('sysadmin')",database:"master");
            if(Convert.ToInt32(t.Rows[0][0])!=1)throw new InvalidOperationException("El asistente de TI requiere una cuenta administradora de SQL Server. La consola usará otra identidad.");
            return "Administrador SQL verificado; no se guardará la contraseña.";});
        await Check("Versión de SQL Server",async()=>{
            var t=await session.QueryAsync("SELECT CONVERT(varchar(64),SERVERPROPERTY('ProductVersion')),CONVERT(nvarchar(128),SERVERPROPERTY('Edition'))",database:"master");
            var v=Version.Parse((string)t.Rows[0][0]);
            if(v<new Version(13,0,4001)||t.Rows[0][1].ToString()!.Contains("Express",StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Se requiere SQL Server 2016 SP1 o posterior, con SQL Server Agent.");
            return v.ToString();});
        await Check("SQL Server Agent",async()=>{
            var t=await session.QueryAsync("SELECT status_desc FROM sys.dm_server_services WHERE servicename LIKE '%SQL Server Agent%'",database:"master");
            if(t.Rows.Count==0||t.Rows.Cast<DataRow>().All(r=>r[0].ToString()!="Running"))throw new InvalidOperationException("SQL Server Agent no está en ejecución. TI debe iniciarlo.");
            return "En ejecución";});
        await Check("Tablas de GP y Dexterity",async()=>{
            var db=SqlNames.Quote(P.GPDatabase);
            foreach(var sql in new[]{
                $"SELECT TOP(0) USERID,SQLSESID,LOGINDAT,LOGINTIM,CMPNYNAM FROM {db}.dbo.ACTIVITY",
                $"SELECT TOP(0) USERID FROM {db}.dbo.SY00800",$"SELECT TOP(0) USERID FROM {db}.dbo.SY00801",
                $"SELECT TOP(0) USERID,USERNAME FROM {db}.dbo.SY01400",$"SELECT TOP(0) CMPANYID,CMPNYNAM FROM {db}.dbo.SY01500",
                "SELECT TOP(0) session_id,sqlsvr_spid FROM tempdb.dbo.DEX_SESSION","SELECT TOP(0) session_id FROM tempdb.dbo.DEX_LOCK"})
                await session.QueryAsync(sql,database:"master");
            return "Columnas necesarias disponibles";});
        await Check("Mensajes nativos de GP",async()=>{
            var db=SqlNames.Quote(P.GPDatabase);
            await session.QueryAsync($"SELECT TOP(0) USERID,CMPANYID,SEQNUMBR,Offline_Message FROM {db}.dbo.SY30000",database:"master");
            var t=await session.QueryAsync($"""
                SELECT c.name,c.system_type_id,c.max_length,c.is_nullable,c.is_identity,c.is_computed,c.default_object_id
                FROM {db}.sys.columns c JOIN {db}.sys.objects o ON c.object_id=o.object_id
                JOIN {db}.sys.schemas s ON s.schema_id=o.schema_id WHERE s.name='dbo' AND o.name='SY30000'
                """,database:"master");
            foreach(DataRow r in t.Rows)
            {
                if(!new[]{"USERID","CMPANYID","SEQNUMBR","Offline_Message"}.Contains(r.Text("name"))
                    &&!r.Flag("is_nullable")&&!r.Flag("is_identity")&&!r.Flag("is_computed")&&Convert.ToInt32(r["default_object_id"])==0&&Convert.ToInt32(r["system_type_id"])!=189)
                    throw new InvalidOperationException("SY30000 tiene columnas obligatorias adicionales: requiere revisión de compatibilidad.");
                if(r.Text("name")=="Offline_Message"&&(!new[]{167,175,231,239}.Contains(Convert.ToInt32(r["system_type_id"]))||
                    (Convert.ToInt32(r["max_length"])!=-1&&Convert.ToInt32(r["max_length"])<230)))
                    throw new InvalidOperationException("Tipo o longitud de Offline_Message incompatible.");
            }
            return "Esquema compatible con el adaptador; recepción en GP pendiente de prueba.";});
        await Check("Destino y actualización",async()=>{
            var t=await session.QueryAsync("SELECT DB_ID(@database)",new(){["@database"]=P.ManagerDatabase},"master");
            if(t.Rows[0][0]==DBNull.Value)return "Nueva instalación: quedará pausada.";
            var q=await session.QueryAsync("SELECT OBJECT_ID('dbo.gpManagerDepartment'),(SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)");
            if(q.Rows[0][0]==DBNull.Value&&Convert.ToInt32(q.Rows[0][1])>0)throw new InvalidOperationException("La base destino contiene otros objetos y no es una instalación del gestor.");
            var v=await session.QueryAsync("IF OBJECT_ID('dbo.gpManagerSchemaVersion') IS NOT NULL SELECT MAX(version) FROM dbo.gpManagerSchemaVersion; ELSE SELECT 1");
            if(v.Rows[0][0]!=DBNull.Value&&Convert.ToInt32(v.Rows[0][0])>SqlScripts.Manifest.Version)throw new InvalidOperationException("La base es más nueva que este instalador.");
            return "Instalación existente: conservar datos y configuración.";});
        return results;
    }
    public async Task InstallSchemaAsync(JobChoice? selectedLegacy,IProgress<string> progress)
    {
        var checks=await PreflightAsync();
        if(checks.Any(c=>!c.Passed))throw new InvalidOperationException("Hay verificaciones pendientes. Revise el paso Verificar.");
        await using var master=await session.OpenAsync("master");
        await DatabaseSession.QueryOnAsync(master,"IF DB_ID(@database) IS NULL EXEC(N'CREATE DATABASE '+QUOTENAME(@database))",new(){["@database"]=P.ManagerDatabase});
        await using var cn=await session.OpenAsync();
        await using var tx=(SqlTransaction)await cn.BeginTransactionAsync();
        try
        {
            await DatabaseSession.QueryOnAsync(cn,"SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'gpManager.install',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000; IF @r<0 THROW 51500,'Another installation is running.',1;",tx:tx);
            var existing=await DatabaseSession.QueryOnAsync(cn,"SELECT OBJECT_ID('dbo.gpManagerSettings')",tx:tx);
            bool hadSettings=existing.Rows[0][0]!=DBNull.Value;
            foreach(var file in SqlScripts.Manifest.Scripts)
            {
                progress.Report("Aplicando "+file);
                foreach(var batch in SqlScripts.Batches(SqlScripts.Substitute(SqlScripts.Read(file),P.GPDatabase)))
                    await DatabaseSession.QueryOnAsync(cn,batch,tx:tx);
            }
            if(!hadSettings&&selectedLegacy!=null)
            {
                static bool Policy(string cmd,string key,bool fallback)
                {var m=Regex.Match(cmd,@"@"+key+@"\s*=\s*([01])",RegexOptions.IgnoreCase);return m.Success?m.Groups[1].Value=="1":fallback;}
                await DatabaseSession.QueryOnAsync(cn,"UPDATE dbo.gpManagerSettings SET automation_enabled=@enabled,protect_transactions=@protect,notify_in_gp=@notify,message_confirmed=@enabled WHERE ID=1",
                    new(){["@enabled"]=selectedLegacy.Enabled,["@protect"]=Policy(selectedLegacy.Command,"ProtectActiveTransactions",false),["@notify"]=Policy(selectedLegacy.Command,"NotifyInGP",true)},tx);
            }
            await DatabaseSession.QueryOnAsync(cn,"IF NOT EXISTS(SELECT 1 FROM dbo.gpManagerSchemaVersion WHERE version=3) INSERT dbo.gpManagerSchemaVersion(version) VALUES(3)",tx:tx);
            await tx.CommitAsync();progress.Report("Objetos instalados. La configuración existente se conservó.");
        }
        catch{await tx.RollbackAsync();throw;}
    }
    public async Task ProvisionAsync(IReadOnlyList<AccessGrant> grants,string automationLogin)
    {
        if(grants.Count==0)throw new InvalidOperationException("Seleccione al menos una identidad de operación.");
        var identities=await LoginsAsync();
        var names=identities.Rows.Cast<DataRow>().Select(r=>r.Text("name")).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if(!names.Contains(automationLogin))throw new InvalidOperationException("Seleccione un login existente para el job.");
        var owner=await session.QueryAsync("SELECT IS_SRVROLEMEMBER('sysadmin',@login),ORIGINAL_LOGIN(),(SELECT type FROM sys.server_principals WHERE name=@login)",new(){["@login"]=automationLogin},"master");
        if(owner.Rows[0][0]==DBNull.Value||Convert.ToInt32(owner.Rows[0][0])!=0||owner.Rows[0][1].ToString()!.Equals(automationLogin,StringComparison.OrdinalIgnoreCase)||owner.Rows[0][2].ToString()=="G")
            throw new InvalidOperationException("El job requiere un login individual no sysadmin, diferente de la cuenta instaladora.");
        await using var cn=await session.OpenAsync();
        await using var tx=(SqlTransaction)await cn.BeginTransactionAsync();
        async Task<string> User(string database,string login)
        {
            var q=await DatabaseSession.QueryOnAsync(cn,$"SELECT name FROM {SqlNames.Quote(database)}.sys.database_principals WHERE sid=SUSER_SID(@login)",new(){["@login"]=login},tx);
            if(q.Rows.Count>0)return q.Rows[0][0].ToString()!;
            var name=SqlNames.Principal(login);
            await DatabaseSession.QueryOnAsync(cn,$"USE {SqlNames.Quote(database)}; CREATE USER {name} FOR LOGIN {name}; USE {SqlNames.Quote(P.ManagerDatabase)};",tx:tx);
            return login;
        }
        async Task Grant(string database,string user,string statements)
            =>await DatabaseSession.QueryOnAsync(cn,$"USE {SqlNames.Quote(database)}; "+statements.Replace("{user}",SqlNames.Principal(user))+$" USE {SqlNames.Quote(P.ManagerDatabase)};",tx:tx);
        try
        {
            foreach(var grant in grants)
            {
                if(!names.Contains(grant.Login)||!new[]{"Lector","Administrador"}.Contains(grant.Role))throw new InvalidOperationException("Identidad o rol no válido.");
                var user=await User(P.ManagerDatabase,grant.Login);
                await Grant(P.ManagerDatabase,user,"ALTER ROLE gpManagerReader ADD MEMBER {user};"+(grant.Role=="Administrador"?"ALTER ROLE gpManagerAdmin ADD MEMBER {user};":""));
                var gpUser=await User(P.GPDatabase,grant.Login);
                await Grant(P.GPDatabase,gpUser,"GRANT SELECT ON dbo.ACTIVITY TO {user}; GRANT SELECT ON dbo.SY00800 TO {user}; GRANT SELECT ON dbo.SY00801 TO {user}; GRANT SELECT ON dbo.SY01400 TO {user}; GRANT SELECT ON dbo.SY01500 TO {user};"
                    +(grant.Role=="Administrador"?" GRANT SELECT,INSERT,VIEW DEFINITION ON dbo.SY30000 TO {user};":""));
                await DatabaseSession.QueryOnAsync(cn,"INSERT dbo.gpManagerAudit(username,dry_run,outcome,reason) VALUES(@login,0,'ACCESS_GRANTED',@role)",new(){["@login"]=grant.Login,["@role"]=grant.Role},tx);
            }
            var auto=await User(P.ManagerDatabase,automationLogin);
            await Grant(P.ManagerDatabase,auto,"ALTER ROLE gpManagerAutomation ADD MEMBER {user};");
            var gpAuto=await User(P.GPDatabase,automationLogin);
            await Grant(P.GPDatabase,gpAuto,"GRANT SELECT,DELETE ON dbo.ACTIVITY TO {user}; GRANT SELECT,DELETE ON dbo.SY00800 TO {user}; GRANT SELECT,DELETE ON dbo.SY00801 TO {user}; GRANT SELECT ON dbo.SY01500 TO {user}; GRANT SELECT,INSERT,VIEW DEFINITION ON dbo.SY30000 TO {user};");
            var dex=await User("tempdb",automationLogin);
            await Grant("tempdb",dex,"GRANT SELECT,DELETE ON dbo.DEX_SESSION TO {user}; GRANT SELECT,DELETE ON dbo.DEX_LOCK TO {user};");
            await tx.CommitAsync();
        }
        catch{await tx.RollbackAsync();throw;}
    }
    public async Task ConfigureJobAsync(JobChoice? keep,IReadOnlyList<JobChoice> reviewed,string owner,string runtimeLogin)
    {
        var authority=await session.QueryAsync("SELECT IS_SRVROLEMEMBER('sysadmin',@owner),IS_SRVROLEMEMBER('sysadmin',@runtime)",new(){["@owner"]=owner,["@runtime"]=runtimeLogin},"master");
        if(authority.Rows[0][0]==DBNull.Value||Convert.ToInt32(authority.Rows[0][0])!=1||authority.Rows[0][1]==DBNull.Value||Convert.ToInt32(authority.Rows[0][1])!=0)
            throw new InvalidOperationException("Seleccione explícitamente un propietario administrador para SQL Agent y una identidad de motor no administradora.");
        var jobCommand=JobCommands.Create(runtimeLogin);
        var current=await JobsAsync();
        if(current.Count!=reviewed.Count||current.Any(j=>!reviewed.Contains(j)))throw new InvalidOperationException("Los jobs cambiaron. Vuelva a verificar antes de continuar.");
        if(keep!=null&&keep.Steps!=1)throw new InvalidOperationException("El job elegido tiene varios pasos. Cree el job del producto y deshabilite el anterior.");
        await using var cn=await session.OpenAsync("msdb");await using var tx=(SqlTransaction)await cn.BeginTransactionAsync();
        try
        {
            foreach(var job in reviewed.Where(j=>keep==null||j.Id!=keep.Id))
                await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_update_job @job_id=@id,@enabled=0; IF @r<>0 THROW 51501,'Cannot disable previous job.',1;",new(){["@id"]=job.Id},tx);
            Guid id;
            if(keep==null)
            {
                var name="GPUM - "+P.ManagerDatabase[..Math.Min(100,P.ManagerDatabase.Length)]+" - "+Guid.NewGuid().ToString("N")[..8];
                if(name.Length>128)throw new InvalidOperationException("Nombre demasiado largo para SQL Agent.");
                var t=await DatabaseSession.QueryOnAsync(cn,"DECLARE @id uniqueidentifier,@r int; EXEC @r=dbo.sp_add_job @job_name=@name,@enabled=0,@owner_login_name=@owner,@description=N'GPUM managed quota enforcement v3',@job_id=@id OUTPUT; IF @r<>0 THROW 51501,'Cannot create job.',1; SELECT @id",
                    new(){["@name"]=name,["@owner"]=owner},tx);id=(Guid)t.Rows[0][0];
                await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_add_jobstep @job_id=@id,@step_name=N'Control de cupos y aviso GP',@subsystem=N'TSQL',@database_name=@db,@command=@command,@on_success_action=1,@on_fail_action=2,@retry_attempts=0; IF @r<>0 THROW 51501,'Cannot create job step.',1;",
                    new(){["@id"]=id,["@db"]=P.ManagerDatabase,["@command"]=jobCommand},tx);
                await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_add_jobschedule @job_id=@id,@name=N'Cada minuto',@enabled=1,@freq_type=4,@freq_interval=1,@freq_subday_type=4,@freq_subday_interval=1,@active_start_time=0; IF @r<>0 THROW 51501,'Cannot schedule job.',1; EXEC @r=dbo.sp_add_jobserver @job_id=@id,@server_name=N'(LOCAL)'; IF @r<>0 THROW 51501,'Cannot attach job server.',1;",new(){["@id"]=id},tx);
            }
            else
            {
                id=keep.Id;
                await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_update_job @job_id=@id,@owner_login_name=@owner,@start_step_id=@step; IF @r<>0 THROW 51501,'Cannot update job owner.',1; EXEC @r=dbo.sp_update_jobstep @job_id=@id,@step_id=@step,@subsystem=N'TSQL',@database_name=@db,@database_user_name=N'dbo',@command=@command,@on_success_action=1,@on_fail_action=2,@retry_attempts=0; IF @r<>0 THROW 51501,'Cannot update job step.',1;",
                    new(){["@id"]=id,["@step"]=keep.StepId,["@owner"]=owner,["@db"]=P.ManagerDatabase,["@command"]=jobCommand},tx);
                var schedules=await DatabaseSession.QueryOnAsync(cn,"SELECT schedule_id FROM dbo.sysjobschedules WHERE job_id=@id",new(){["@id"]=id},tx);
                foreach(DataRow schedule in schedules.Rows)
                    await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_detach_schedule @job_id=@id,@schedule_id=@schedule,@delete_unused_schedule=0; IF @r<>0 THROW 51501,'Cannot detach previous schedule.',1;",new(){["@id"]=id,["@schedule"]=schedule[0]},tx);
                await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_add_jobschedule @job_id=@id,@name=N'Cada minuto GPUM',@enabled=1,@freq_type=4,@freq_interval=1,@freq_subday_type=4,@freq_subday_interval=1,@active_start_time=0; IF @r<>0 THROW 51501,'Cannot schedule retained job.',1;",new(){["@id"]=id},tx);
            }
            await DatabaseSession.QueryOnAsync(cn,"DECLARE @r int; EXEC @r=dbo.sp_update_job @job_id=@id,@enabled=1; IF @r<>0 THROW 51501,'Cannot enable job.',1;",new(){["@id"]=id},tx);
            await tx.CommitAsync();
        }
        catch{await tx.RollbackAsync();throw;}
    }
}
