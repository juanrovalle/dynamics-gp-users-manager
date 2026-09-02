using GPManager.Core;
using Microsoft.Data.SqlClient;
using Microsoft.SqlServer.TransactSql.ScriptDom;
using System.Text.Json;

int count=0;
void Test(string name,Action test){test();count++;Console.WriteLine("PASS "+name);}
void Assert(bool condition,string message="Assertion failed"){if(!condition)throw new Exception(message);}
void Throws(Action action){try{action();}catch(ArgumentException){return;}catch(InvalidOperationException){return;}throw new Exception("Expected validation failure");}
var now=new DateTime(2026,9,1,12,0,0,DateTimeKind.Utc);
Test("Paused state takes precedence",()=>Assert(Health.Describe(false,null,now)=="Automatización pausada"));
Test("Never run is stale",()=>Assert(Health.Describe(true,null,now)=="Sin ejecución reciente"));
Test("Three minute boundary",()=>Assert(Health.Describe(true,now.AddMinutes(-3),now)=="Automatización activa"));
Test("Stale after three minutes",()=>Assert(Health.Describe(true,now.AddSeconds(-181),now)=="Sin ejecución reciente"));
Test("Database identifier validation",()=>{foreach(var s in new[]{"x];DROP DATABASE x","a b","_x","1x",new string('a',129)})Throws(()=>SqlNames.Validate(s));Assert(SqlNames.Quote("GP_Test1")=="[GP_Test1]");});
Test("Separate manager database",()=>{foreach(var s in new[]{"master","MODEL","tempdb","msdb","DYNAMICS"})Throws(()=>new ConnectionProfile("server",s).Validate());});
Test("Principal quoting",()=>Assert(SqlNames.Principal("DOMAIN\\a]b")=="[DOMAIN\\a]]b]"));
Test("Windows auth omits SQL password",()=>{var b=new SqlConnectionStringBuilder(new ConnectionProfile("server").ConnectionString("db","secret"));Assert(b.IntegratedSecurity&&b.Password=="");});
Test("SQL auth safely encodes credentials",()=>{var b=new SqlConnectionStringBuilder(new ConnectionProfile("server",WindowsAuthentication:false,Username:"user").ConnectionString("db","x;Password=other"));Assert(!b.IntegratedSecurity&&b.Password=="x;Password=other"&&!b.PersistSecurityInfo&&!b.TrustServerCertificate);Assert(b.Encrypt==SqlConnectionEncryptOption.Mandatory);});
Test("Profile has no password member",()=>{var json=JsonSerializer.Serialize(new ConnectionProfile("server",WindowsAuthentication:false,Username:"user"));Assert(!json.Contains("password",StringComparison.OrdinalIgnoreCase));});
Test("Profile round trip",()=>{var folder=Path.Combine(Path.GetTempPath(),"GPUM-tests-"+Guid.NewGuid().ToString("N"));var path=Path.Combine(folder,"connection.json");try{var p=new ConnectionProfile("server");var store=new ProfileStore(path);store.Save(p);Assert(store.Load()==p);}finally{if(File.Exists(path))File.Delete(path);if(Directory.Exists(folder))Directory.Delete(folder);}});
Test("Batch separator respects strings",()=>Assert(SqlScripts.Batches("SELECT 'a\nGO\nb';\nGO\nSELECT 2;").Count==2));
Test("Batch separator respects nested comments",()=>Assert(SqlScripts.Batches("/* outer\n/* inner */\nGO\n*/\nSELECT 1;\nGO -- next\nSELECT 2;").Count==2));
Test("Escaped quotes",()=>Assert(SqlScripts.Batches("SELECT 'it''s';\nGO\nSELECT 2;").Count==2));
Test("Unterminated scripts rejected",()=>{Throws(()=>SqlScripts.Batches("SELECT 'broken"));Throws(()=>SqlScripts.Batches("/* broken"));});
Test("SQLCMD directives rejected",()=>{Throws(()=>SqlScripts.Substitute(":r evil.sql","DYNAMICS"));Throws(()=>SqlScripts.Substitute("SELECT $(Unexpected)","DYNAMICS"));});
Test("Substitution validates database",()=>Throws(()=>SqlScripts.Substitute("SELECT * FROM [$(GPDatabase)].dbo.X","bad]")));
Test("Versioned embedded manifest",()=>{Assert(SqlScripts.Manifest.Version==3);Assert(SqlScripts.Manifest.Scripts.Distinct().Count()==7);foreach(var name in SqlScripts.Manifest.Scripts)Assert(SqlScripts.Read(name).Length>0);});
var parser=new TSql160Parser(true);
Test("Agent command with quoted login",()=>{var command=JobCommands.Create("DOMAIN\\engine]'test");parser.Parse(new StringReader(command),out var errors);Assert(errors.Count==0,string.Join("; ",errors.Select(e=>e.Message)));Assert(command.Contains("SUSER_SID")&&command.Contains("REVERT"));});
foreach(var script in SqlScripts.Manifest.Scripts)
Test("T-SQL syntax "+script,()=>{
    int batch=0;
    foreach(var sql in SqlScripts.Batches(SqlScripts.Substitute(SqlScripts.Read(script),"GPTest","DexTest"))){
        batch++;parser.Parse(new StringReader(sql),out var errors);
        Assert(errors.Count==0,script+" batch "+batch+": "+string.Join("; ",errors.Select(e=>$"line {e.Line}: {e.Message}")));
    }
});
Console.WriteLine($"ALL {count} TESTS PASSED. SQL parsing does not replace execution against SQL Server/GP.");
