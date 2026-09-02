using System.Data;
using GPManager.Core;
namespace GPManager.Desktop;
internal static class Demo
{
    public static DataTable Settings()
    {
        var t=Tables.Create(("automation_enabled",typeof(bool)),("protect_transactions",typeof(bool)),("notify_in_gp",typeof(bool)),("customer_name",typeof(string)),("customer_contact",typeof(string)),("purchased_on",typeof(DateTime)),("maintenance_until",typeof(DateTime)),("revision",typeof(byte[])),("last_completed_at",typeof(DateTime)),("last_outcome",typeof(string)),("can_admin",typeof(bool)));
        t.Rows.Add(true,false,true,"Fabrikam · Demostración","administracion@example.invalid",new DateTime(2026,1,1),new DateTime(2027,1,1),new byte[8],DateTime.UtcNow.AddSeconds(-24),"NO_EXCESS",false);return t;
    }
    public static DataTable Usage()
    {var t=Tables.Create(("name",typeof(string)),("Limite",typeof(int)),("Activos",typeof(int)),("Disponible",typeof(int)),("Exceso",typeof(int)));t.Rows.Add("Administración",5,4,1,0);t.Rows.Add("Ventas",8,9,-1,1);t.Rows.Add("Operaciones",6,3,3,0);return t;}
    public static DataTable Departments()
    {var t=Tables.Create(("ID",typeof(int)),("name",typeof(string)),("quota",typeof(int)),("enabled",typeof(bool)),("revision",typeof(byte[])));t.Rows.Add(1,"Administración",5,true,new byte[8]);t.Rows.Add(2,"Ventas",8,true,new byte[8]);t.Rows.Add(3,"Operaciones",6,true,new byte[8]);return t;}
    public static DataTable Users()
    {var t=Tables.Create(("username",typeof(string)),("display_name",typeof(string)),("department_id",typeof(int)),("department",typeof(string)),("revision",typeof(byte[])));t.Rows.Add("agarcia","Ana García",1,"Administración",new byte[8]);t.Rows.Add("crojas","Carlos Rojas",2,"Ventas",new byte[8]);t.Rows.Add("mlopez","María López",3,"Operaciones",new byte[8]);return t;}
    public static DataTable Sessions()
    {
        var t=Tables.Create(("usuario",typeof(string)),("departamento",typeof(string)),("company",typeof(string)),("session_id",typeof(int)),("activity",typeof(string)));
        var departments=new[]{("Administración",4),("Ventas",9),("Operaciones",3)};
        var id=1100;
        foreach(var (department,count) in departments)
            for(var i=1;i<=count;i++)t.Rows.Add("usuario"+(++id),department,"Fabrikam",id,"Sin actividad registrada");
        return t;
    }
    public static DataTable Audit()
    {var t=Tables.Create(("occurred_at",typeof(DateTime)),("username",typeof(string)),("outcome",typeof(string)),("reason",typeof(string)));t.Rows.Add(DateTime.UtcNow.AddMinutes(-18),"crojas","QUOTA_REMOVED","Cupo de Ventas excedido");t.Rows.Add(DateTime.UtcNow.AddHours(-2),"(configuration)","DEPARTMENT_SAVED","Cupo de Administración actualizado");return t;}
    public static DataTable Notifications()
    {var t=Tables.Create(("created_at",typeof(DateTime)),("username",typeof(string)),("status",typeof(string)),("message",typeof(string)));t.Rows.Add(DateTime.UtcNow.AddMinutes(-18),"crojas","QUEUED_GP","Su sesión fue retirada por exceder el cupo de su departamento.");return t;}
}
