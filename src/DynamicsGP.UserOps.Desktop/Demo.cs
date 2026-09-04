using System.Data;
using DynamicsGP.UserOps.Core;
namespace DynamicsGP.UserOps.Desktop;
internal static class Demo
{
    public static DataTable Settings()
    {
        var t=Tables.Create(("automation_enabled",typeof(bool)),("protect_transactions",typeof(bool)),("notify_in_gp",typeof(bool)),("customer_name",typeof(string)),("customer_contact",typeof(string)),("purchased_on",typeof(DateTime)),("maintenance_until",typeof(DateTime)),("revision",typeof(byte[])),("last_completed_at",typeof(DateTime)),("last_outcome",typeof(string)),("can_admin",typeof(bool)));
        t.Rows.Add(true,false,true,"Summit Foods · Demo","operations@example.invalid",new DateTime(2026,1,1),new DateTime(2027,1,1),new byte[8],DateTime.UtcNow.AddSeconds(-24),"NO_EXCESS",false);return t;
    }
    public static DataTable Usage()
    {var t=Tables.Create(("name",typeof(string)),("Limite",typeof(int)),("Activos",typeof(int)),("Disponible",typeof(int)),("Exceso",typeof(int)));t.Rows.Add("Administration",5,4,1,0);t.Rows.Add("Sales",8,9,-1,1);t.Rows.Add("Operations",6,3,3,0);return t;}
    public static DataTable Departments()
    {var t=Tables.Create(("ID",typeof(int)),("name",typeof(string)),("quota",typeof(int)),("enabled",typeof(bool)),("revision",typeof(byte[])));t.Rows.Add(1,"Administration",5,true,new byte[8]);t.Rows.Add(2,"Sales",8,true,new byte[8]);t.Rows.Add(3,"Operations",6,true,new byte[8]);return t;}
    public static DataTable Users()
    {var t=Tables.Create(("username",typeof(string)),("display_name",typeof(string)),("department_id",typeof(int)),("department",typeof(string)),("revision",typeof(byte[])));t.Rows.Add("treed","Taylor Reed",1,"Administration",new byte[8]);t.Rows.Add("jlee","Jordan Lee",2,"Sales",new byte[8]);t.Rows.Add("mchen","Morgan Chen",3,"Operations",new byte[8]);return t;}
    public static DataTable Sessions()
    {
        var t=Tables.Create(("usuario",typeof(string)),("departamento",typeof(string)),("company",typeof(string)),("session_id",typeof(int)),("activity",typeof(string)));
        var departments=new[]{("Administration",4),("Sales",9),("Operations",3)};
        var id=1100;
        foreach(var (department,count) in departments)
            for(var i=1;i<=count;i++)t.Rows.Add("user"+(++id),department,"Summit Foods",id,"No recorded activity");
        return t;
    }
    public static DataTable Audit()
    {var t=Tables.Create(("occurred_at",typeof(DateTime)),("username",typeof(string)),("outcome",typeof(string)),("reason",typeof(string)));t.Rows.Add(DateTime.UtcNow.AddMinutes(-18),"jlee","QUOTA_REMOVED","Sales quota exceeded");t.Rows.Add(DateTime.UtcNow.AddHours(-2),"(configuration)","DEPARTMENT_SAVED","Administration quota updated");return t;}
    public static DataTable Notifications()
    {var t=Tables.Create(("created_at",typeof(DateTime)),("username",typeof(string)),("status",typeof(string)),("message",typeof(string)));t.Rows.Add(DateTime.UtcNow.AddMinutes(-18),"jlee","QUEUED_GP","Your session was removed because the department quota was exceeded.");return t;}
}
