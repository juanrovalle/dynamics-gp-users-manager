using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;
namespace GPManager.Core;

public sealed class DatabaseSession : IDisposable
{
    public ConnectionProfile Profile {get;}
    private string password;
    public DatabaseSession(ConnectionProfile profile,string password){profile.Validate();Profile=profile;this.password=password;}
    public async Task<SqlConnection> OpenAsync(string? database=null,CancellationToken ct=default)
    {
        var cn=new SqlConnection(Profile.ConnectionString(database??Profile.ManagerDatabase,password));
        try {await cn.OpenAsync(ct);return cn;}catch{await cn.DisposeAsync();throw;}
    }
    public async Task<DataTable> QueryAsync(string sql,Dictionary<string,object?>? parameters=null,string? database=null,CancellationToken ct=default)
    {
        await using var cn=await OpenAsync(database,ct);return await QueryOnAsync(cn,sql,parameters,null,ct);
    }
    internal static async Task<DataTable> QueryOnAsync(SqlConnection cn,string sql,Dictionary<string,object?>? parameters=null,SqlTransaction? tx=null,CancellationToken ct=default)
    {
        await using var cmd=new SqlCommand(sql,cn,tx){CommandTimeout=120};
        if(parameters!=null)foreach(var p in parameters)cmd.Parameters.AddWithValue(p.Key,p.Value??DBNull.Value);
        await using var reader=await cmd.ExecuteReaderAsync(ct);var table=new DataTable();table.Load(reader);return table;
    }
    public Task<DataTable> ProcedureAsync(string name,Dictionary<string,object?> parameters)
    {
        if(!name.StartsWith("SP_GPUM_",StringComparison.Ordinal)&&name!="SP_PREVIEW_GP_QUOTA")throw new ArgumentException("Operación no permitida desde la consola.");
        var call="EXEC dbo."+SqlNames.Quote(name)+" "+string.Join(",",parameters.Keys.Select(k=>k+"="+k));
        return QueryAsync(call,parameters);
    }
    public Task<DataTable> SettingsAsync()=>QueryAsync("IF EXISTS(SELECT 1 FROM dbo.gpManagerSchemaVersion WHERE version>3) THROW 51502,'Update the console before using this newer database.',1; IF EXISTS(SELECT 1 FROM dbo.gpManagerSettings WHERE gp_database<>@gp) THROW 51503,'The selected GP database differs from the installation binding.',1; SELECT s.*,r.last_completed_at,r.last_outcome,r.last_error_number,CONVERT(bit,CASE WHEN IS_MEMBER('gpManagerAdmin')=1 OR IS_SRVROLEMEMBER('sysadmin')=1 OR IS_MEMBER('db_owner')=1 THEN 1 ELSE 0 END) AS can_admin FROM dbo.gpManagerSettings s CROSS JOIN dbo.gpManagerRuntime r",new(){["@gp"]=Profile.GPDatabase});
    public Task<DataTable> UsageAsync()=>QueryAsync("SELECT * FROM dbo.vw_gpManagerDepartmentUsage ORDER BY name");
    public Task<DataTable> SessionsAsync()=>QueryAsync("SELECT * FROM dbo.vw_gpManagerSessions ORDER BY logInDate DESC,logInTime DESC");
    public Task<DataTable> DepartmentsAsync()=>QueryAsync("SELECT ID,RTRIM(name) AS name,[limit] AS quota,enabled,revision FROM dbo.gpManagerDepartment ORDER BY name");
    public Task<DataTable> CompaniesAsync()=>QueryAsync("SELECT CMPANYID AS id,RTRIM(CMPNYNAM) AS name FROM "+SqlNames.Quote(Profile.GPDatabase)+".dbo.SY01500 ORDER BY CMPNYNAM");
    public Task<DataTable> AuditAsync()=>QueryAsync("SELECT TOP(500) occurred_at,actor,username,session_id,outcome,reason,detail FROM dbo.gpManagerAudit ORDER BY ID DESC");
    public Task<DataTable> NotificationsAsync()=>QueryAsync("SELECT TOP(500) created_at,username,company_id,status,queued_at,message FROM dbo.gpManagerNotification ORDER BY ID DESC");
    public async Task<string> DiagnosticsAsync()
    {
        var settings=(await SettingsAsync()).Rows[0];
        var version=await QueryAsync("SELECT MAX(version) AS version FROM dbo.gpManagerSchemaVersion");
        // Explicit allowlist: no connection string, password, customer contact or free-text audit content.
        return JsonSerializer.Serialize(new{application="GP Users Manager",version="3.0.1",schema=version.Rows[0][0],
            generatedUtc=DateTime.UtcNow,server=Profile.Server,database=Profile.ManagerDatabase,
            enabled=settings.Flag("automation_enabled"),lastCompleted=NullableValue(settings.Value("last_completed_at")),
            outcome=settings.Text("last_outcome"),errorNumber=NullableValue(settings.Value("last_error_number"))},new JsonSerializerOptions{WriteIndented=true});
    }
    private static object? NullableValue(object value)=>value==DBNull.Value?null:value;
    public void Dispose(){password="";SqlConnection.ClearAllPools();}
}
