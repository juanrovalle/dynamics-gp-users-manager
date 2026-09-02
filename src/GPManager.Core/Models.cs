using System.Data;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace GPManager.Core;

public sealed record ConnectionProfile(string Server="", string ManagerDatabase="GPUsersManager",
    string GPDatabase="DYNAMICS", bool WindowsAuthentication=true, string Username="", bool TrustCertificate=false)
{
    public string ConnectionString(string database, string password="")
    {
        var b=new SqlConnectionStringBuilder { DataSource=Server, InitialCatalog=database, IntegratedSecurity=WindowsAuthentication,
            Encrypt=SqlConnectionEncryptOption.Mandatory, TrustServerCertificate=TrustCertificate, ConnectTimeout=12,
            ApplicationName="GP Users Manager", PersistSecurityInfo=false };
        if(!WindowsAuthentication) { b.UserID=Username; b.Password=password; }
        return b.ConnectionString;
    }
    public void Validate()
    {
        if(string.IsNullOrWhiteSpace(Server)) throw new ArgumentException("Indique el servidor SQL.");
        SqlNames.Validate(ManagerDatabase); SqlNames.Validate(GPDatabase);
        if(new[]{"master","model","msdb","tempdb",GPDatabase}.Contains(ManagerDatabase,StringComparer.OrdinalIgnoreCase))
            throw new ArgumentException("La base del gestor debe estar separada de GP y las bases de sistema.");
        if(!WindowsAuthentication && string.IsNullOrWhiteSpace(Username)) throw new ArgumentException("Indique el login SQL.");
    }
}

public static partial class SqlNames
{
    [GeneratedRegex("^[A-Za-z][A-Za-z0-9_]{0,127}$")] private static partial Regex IdentifierPattern();
    public static string Validate(string name) => IdentifierPattern().IsMatch(name) ? name : throw new ArgumentException("Nombre de base inválido.");
    public static string Quote(string name) => "["+Validate(name)+"]";
    public static string Principal(string name)
    {
        if(string.IsNullOrWhiteSpace(name)||name.Length>128) throw new ArgumentException("Identidad inválida.");
        return "["+name.Replace("]","]]")+"]";
    }
}

public sealed record JobChoice(Guid Id,string Name,bool Enabled,string Command,int Steps,string Owner,int StepId)
{
    public override string ToString()=>Name+(Enabled?" (habilitado)":" (deshabilitado)");
}
public sealed record CheckResult(string Name,bool Passed,string Detail);
public sealed record AccessGrant(string Login,string Role);
public sealed record MigrationManifest(int Version,string[] Scripts);
public static class Health
{
    public static string Describe(bool enabled,DateTime? completedUtc,DateTime nowUtc)
        =>!enabled?"Automatización pausada":completedUtc is null||nowUtc-completedUtc.Value>TimeSpan.FromMinutes(3)
        ?"Sin ejecución reciente":"Automatización activa";
}
public sealed class ProfileStore
{
    private readonly string path;
    public ProfileStore(string? path=null) => this.path=path??Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"GPUsersManager","connection.json");
    public ConnectionProfile? Load(){try{return File.Exists(path)?JsonSerializer.Deserialize<ConnectionProfile>(File.ReadAllText(path)):null;}catch{return null;}}
    public void Save(ConnectionProfile profile){Directory.CreateDirectory(Path.GetDirectoryName(path)!);File.WriteAllText(path,JsonSerializer.Serialize(profile));}
}

public static class Tables
{
    public static DataTable Create(params (string Name,Type Type)[] columns)
    {var table=new DataTable();foreach(var col in columns)table.Columns.Add(col.Name,col.Type);return table;}
    public static object Value(this DataRow row,string name)=>row.Table.Columns.Contains(name)?row[name]:DBNull.Value;
    public static string Text(this DataRow row,string name)=>Convert.ToString(row.Value(name))??"";
    public static bool Flag(this DataRow row,string name)=>row.Value(name)!=DBNull.Value&&Convert.ToBoolean(row[name]);
}
