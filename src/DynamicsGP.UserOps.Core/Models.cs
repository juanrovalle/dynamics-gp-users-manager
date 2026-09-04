using System.Data;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace DynamicsGP.UserOps.Core;

public static class ProductInfo
{
    public const string Name="Dynamics GP UserOps";
    public const string Version="4.0.0";
    public const string DefaultManagerDatabase="DynamicsGPUserOps";
    public const string ProfileFolder="DynamicsGPUserOps";
    public const string LegacyProfileFolder="GPUsersManager";
}

public sealed record ConnectionProfile(string Server="", string ManagerDatabase=ProductInfo.DefaultManagerDatabase,
    string GPDatabase="DYNAMICS", bool WindowsAuthentication=true, string Username="", bool TrustCertificate=false)
{
    public string ConnectionString(string database, string password="")
    {
        var b=new SqlConnectionStringBuilder { DataSource=Server, InitialCatalog=database, IntegratedSecurity=WindowsAuthentication,
            Encrypt=SqlConnectionEncryptOption.Mandatory, TrustServerCertificate=TrustCertificate, ConnectTimeout=12,
            ApplicationName=ProductInfo.Name, PersistSecurityInfo=false };
        if(!WindowsAuthentication) { b.UserID=Username; b.Password=password; }
        return b.ConnectionString;
    }
    public void Validate()
    {
        if(string.IsNullOrWhiteSpace(Server)) throw new ArgumentException("Enter the SQL Server name.");
        SqlNames.Validate(ManagerDatabase); SqlNames.Validate(GPDatabase);
        if(new[]{"master","model","msdb","tempdb",GPDatabase}.Contains(ManagerDatabase,StringComparer.OrdinalIgnoreCase))
            throw new ArgumentException("The UserOps database must be separate from GP and the SQL system databases.");
        if(!WindowsAuthentication && string.IsNullOrWhiteSpace(Username)) throw new ArgumentException("Enter the SQL login.");
    }
}

public static partial class SqlNames
{
    [GeneratedRegex("^[A-Za-z][A-Za-z0-9_]{0,127}$")] private static partial Regex IdentifierPattern();
    public static string Validate(string name) => IdentifierPattern().IsMatch(name) ? name : throw new ArgumentException("Invalid database name.");
    public static string Quote(string name) => "["+Validate(name)+"]";
    public static string Principal(string name)
    {
        if(string.IsNullOrWhiteSpace(name)||name.Length>128) throw new ArgumentException("Invalid identity.");
        return "["+name.Replace("]","]]")+"]";
    }
}

public sealed record JobChoice(Guid Id,string Name,bool Enabled,string Command,int Steps,string Owner,int StepId)
{
    public override string ToString()=>Name+(Enabled?" (enabled)":" (disabled)");
}
public sealed record CheckResult(string Name,bool Passed,string Detail);
public sealed record AccessGrant(string Login,string Role);
public sealed record MigrationManifest(int Version,string[] Scripts);
public static class Health
{
    public static string Describe(bool enabled,DateTime? completedUtc,DateTime nowUtc)
        =>!enabled?"Automation paused":completedUtc is null||nowUtc-completedUtc.Value>TimeSpan.FromMinutes(3)
        ?"No recent execution":"Automation active";
}
public sealed class ProfileStore
{
    private readonly string path;
    private readonly string? legacyPath;
    public bool ImportedLegacyProfile {get;private set;}
    public ProfileStore(string? path=null,string? legacyPath=null)
    {
        var local=Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        this.path=path??Path.Combine(local,ProductInfo.ProfileFolder,"connection.json");
        this.legacyPath=path is null?legacyPath??Path.Combine(local,ProductInfo.LegacyProfileFolder,"connection.json"):legacyPath;
    }
    public ConnectionProfile? Load()
    {
        if(File.Exists(path)){try{return JsonSerializer.Deserialize<ConnectionProfile>(File.ReadAllText(path));}catch{return null;}}
        if(string.IsNullOrWhiteSpace(legacyPath)||!File.Exists(legacyPath))return null;
        try
        {
            var profile=JsonSerializer.Deserialize<ConnectionProfile>(File.ReadAllText(legacyPath));
            if(profile is null)return null;
            Save(profile);ImportedLegacyProfile=true;return profile;
        }
        catch{return null;}
    }
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
