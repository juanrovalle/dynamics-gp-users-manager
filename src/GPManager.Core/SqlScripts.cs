using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;
namespace GPManager.Core;

public static partial class SqlScripts
{
    public static MigrationManifest Manifest => JsonSerializer.Deserialize<MigrationManifest>(Read("migration-manifest.json"),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    public static string Read(string filename)
    {
        var assembly=typeof(SqlScripts).Assembly;
        var resource=assembly.GetManifestResourceNames().Single(n=>n.EndsWith("."+filename,StringComparison.Ordinal));
        using var stream=assembly.GetManifestResourceStream(resource)!;
        using var reader=new StreamReader(stream);return reader.ReadToEnd();
    }
    public static string Substitute(string script,string gpDatabase,string dexDatabase="tempdb")
    {
        SqlNames.Validate(gpDatabase);SqlNames.Validate(dexDatabase);
        script=script.Replace("$(GPDatabase)",gpDatabase,StringComparison.Ordinal).Replace("$(DexDatabase)",dexDatabase,StringComparison.Ordinal);
        if(script.Contains("$(")||Regex.IsMatch(script,@"(?m)^\s*:")) throw new InvalidOperationException("Directiva SQLCMD no permitida en el manifiesto.");
        return script;
    }
    // Repository scripts use standalone GO only. Stateful lexer prevents splitting strings/comments.
    public static IReadOnlyList<string> Batches(string sql)
    {
        var result=new List<string>();var buffer=new System.Text.StringBuilder();bool quoted=false;int comment=0;
        foreach(var line in sql.Replace("\r\n","\n").Split('\n'))
        {
            if(!quoted&&comment==0&&Regex.IsMatch(line,@"^\s*GO\s*(?:--.*)?$",RegexOptions.IgnoreCase))
            {if(!string.IsNullOrWhiteSpace(buffer.ToString()))result.Add(buffer.ToString());buffer.Clear();continue;}
            buffer.AppendLine(line);
            for(int i=0;i<line.Length;i++)
            {
                if(comment>0){if(i+1<line.Length&&line[i]=='*'&&line[i+1]=='/'){comment--;i++;}else if(i+1<line.Length&&line[i]=='/'&&line[i+1]=='*'){comment++;i++;}continue;}
                if(quoted){if(line[i]=='\''){if(i+1<line.Length&&line[i+1]=='\'')i++;else quoted=false;}continue;}
                if(i+1<line.Length&&line[i]=='-'&&line[i+1]=='-')break;
                if(i+1<line.Length&&line[i]=='/'&&line[i+1]=='*'){comment++;i++;continue;}
                if(line[i]=='\'')quoted=true;
            }
        }
        if(quoted||comment!=0)throw new InvalidOperationException("Script SQL incompleto.");
        if(!string.IsNullOrWhiteSpace(buffer.ToString()))result.Add(buffer.ToString());return result;
    }
}

