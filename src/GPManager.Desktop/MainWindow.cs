using System.Data;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using GPManager.Core;
using Microsoft.Win32;
namespace GPManager.Desktop;

public sealed class MainWindow:Window
{
    private DatabaseSession? session;private readonly bool borrowed;private bool demo,busy,canAdmin;
    private readonly ContentControl workspace=new();private readonly StackPanel navigation=new();private readonly TextBlock status=Ui.Text("");
    private readonly TextBlock subtitle=Ui.Text("Consola de administración",12);private readonly DispatcherTimer timer=new(){Interval=TimeSpan.FromSeconds(30)};
    private readonly ProfileStore profiles=new();private string page="Resumen";
    public MainWindow(DatabaseSession? existing=null,bool demo=false)
    {
        this.demo=demo;session=existing;borrowed=existing!=null;
        Title="GP Users Manager";Width=1220;Height=840;MinWidth=960;MinHeight=700;WindowStartupLocation=WindowStartupLocation.CenterScreen;
        var root=new DockPanel();
        var header=new Border{Background=new SolidColorBrush(Color.FromRgb(20,43,64)),Padding=new(28,18,28,16)};
        var branding=Ui.Stack(Ui.Text("GP USERS MANAGER",21,true),subtitle);branding.Children.OfType<TextBlock>().ToList().ForEach(t=>t.Foreground=Brushes.White);
        header.Child=branding;DockPanel.SetDock(header,Dock.Top);root.Children.Add(header);
        status.Margin=new(22,8,22,8);status.Foreground=Brushes.DarkSlateGray;DockPanel.SetDock(status,Dock.Bottom);root.Children.Add(status);
        navigation.Width=205;navigation.Margin=new(18,22,10,0);DockPanel.SetDock(navigation,Dock.Left);root.Children.Add(navigation);
        var scroller=new ScrollViewer{Content=workspace,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,Padding=new(20,24,26,20)};
        root.Children.Add(scroller);Content=root;
        Loaded+=async(_,_)=>{if(session!=null||demo)await Run(()=>NavigateAsync("Resumen"));else ShowConnection();};
        Closed+=(_,_)=>{timer.Stop();if(!borrowed)session?.Dispose();};
        timer.Tick+=async(_,_)=>{if(!busy&&page=="Resumen"&&(session!=null||demo))await Run(()=>NavigateAsync("Resumen"));};
        timer.Start();
    }
    private async Task Run(Func<Task> work)
    {
        if(busy)return;busy=true;workspace.IsEnabled=false;navigation.IsEnabled=false;status.Text="Procesando…";
        try{await work();status.Text=demo?"DEMOSTRACIÓN · Datos ficticios · Sin conexión a SQL Server":"Listo · GP procesa los avisos encolados; no hay confirmación de lectura.";}
        catch(Exception ex){status.Text="No se completó la operación.";MessageBox.Show(this,ex.Message,"GP Users Manager",MessageBoxButton.OK,MessageBoxImage.Warning);}
        finally{busy=false;workspace.IsEnabled=true;navigation.IsEnabled=true;}
    }
    private Button Action(string title,Func<Task> action,bool primary=false)=>Ui.Button(title,async()=>await Run(action),primary);
    private void ShowConnection()
    {
        navigation.Children.Clear();page="Conexión";subtitle.Text="Instalación local · Sin servicios en la nube";
        var p=profiles.Load()??new();
        var server=Ui.Input(p.Server);var manager=Ui.Input(p.ManagerDatabase);var gp=Ui.Input(p.GPDatabase);
        var windows=new CheckBox{Content="Autenticación de Windows",IsChecked=p.WindowsAuthentication};var user=Ui.Input(p.Username);var secret=new PasswordBox();
        var trust=new CheckBox{Content="Confiar explícitamente en el certificado del servidor",IsChecked=p.TrustCertificate};
        user.IsEnabled=!p.WindowsAuthentication;secret.IsEnabled=!p.WindowsAuthentication;
        windows.Checked+=(_,_)=>{user.IsEnabled=false;secret.IsEnabled=false;};windows.Unchecked+=(_,_)=>{user.IsEnabled=true;secret.IsEnabled=true;};
        workspace.Content=Ui.Stack(Ui.Text("Conectar al gestor",30,true),Ui.Text("Use su cuenta de operación. Las credenciales de TI se solicitan por separado en el asistente."),
            Ui.Card(Ui.Stack(Ui.Field("Servidor SQL",server),Ui.Row(Ui.Field("Base del gestor",manager),Ui.Field("Base de sistema GP",gp)),windows,
                Ui.Field("Login SQL",user),Ui.Field("Contraseña (solo durante esta sesión)",secret),trust,
                Ui.Row(Action("Conectar",async()=>{
                    var profile=new ConnectionProfile(server.Text.Trim(),manager.Text.Trim(),gp.Text.Trim(),windows.IsChecked==true,user.Text.Trim(),trust.IsChecked==true);
                    var candidate=new DatabaseSession(profile,secret.Password);
                    try {var result=await candidate.SettingsAsync();if(result.Rows.Count!=1)throw new InvalidOperationException("Instalación incompleta.");}
                    catch{candidate.Dispose();throw;}
                    session?.Dispose();session=candidate;secret.Clear();profiles.Save(profile);demo=false;await NavigateAsync("Resumen");
                },true),Ui.Button("Asistente de instalación / actualización",()=>new WizardWindow{Owner=this}.ShowDialog()),Action("Ver demostración",async()=>{demo=true;await NavigateAsync("Resumen");})))),
            Ui.Text("La conexión está cifrada. La opción de confiar en el certificado debe habilitarse solo por decisión de TI.",12));
    }
    public async Task NavigateAsync(string selected)
    {
        page=selected;var settings=demo?Demo.Settings():await session!.SettingsAsync();canAdmin=!demo&&settings.Rows[0].Flag("can_admin");
        subtitle.Text=demo?"DEMOSTRACIÓN · Datos ficticios":session!.Profile.Server+" / "+session.Profile.ManagerDatabase;
        navigation.Children.Clear();
        foreach(var name in new[]{"Resumen","Departamentos","Usuarios","Historial","Configuración"})
        {var b=Action(name,()=>NavigateAsync(name),name==selected);b.Width=180;navigation.Children.Add(b);}
        if(!borrowed)navigation.Children.Add(Ui.Button("Cambiar conexión",()=>{session?.Dispose();session=null;demo=false;ShowConnection();}));
        navigation.Children.Add(Ui.Text("v3.0.1 · Windows / Server\nMotor: SQL Server Agent",11));
        switch(selected)
        {
            case "Resumen":await Summary(settings.Rows[0]);break;
            case "Departamentos":await Departments();break;
            case "Usuarios":await Users();break;
            case "Historial":await History();break;
            case "Configuración":Settings(settings.Rows[0]);break;
        }
    }
    private async Task Summary(DataRow settings)
    {
        var usage=demo?Demo.Usage():await session!.UsageAsync();var sessions=demo?Demo.Sessions():await session!.SessionsAsync();
        var last=settings.Value("last_completed_at")==DBNull.Value?(DateTime?)null:DateTime.SpecifyKind((DateTime)settings["last_completed_at"],DateTimeKind.Utc);
        var state=Health.Describe(settings.Flag("automation_enabled"),last,DateTime.UtcNow);
        var cards=Ui.Row(Metric("SESIONES GP",sessions.Rows.Count.ToString()),Metric("CUPOS CONFIGURADOS",usage.Rows.Cast<DataRow>().Sum(r=>Convert.ToInt32(r["Limite"])).ToString()),
            Metric("EXCESOS",usage.Rows.Cast<DataRow>().Sum(r=>Convert.ToInt32(r["Exceso"])).ToString()));
        var pause=Action(settings.Flag("automation_enabled")?"Pausar automatización":"Reactivar automatización",async()=>{
            var enable=!settings.Flag("automation_enabled");
            if(Ui.Confirm(this,enable?"¿Reactivar el control automático de cupos?":"¿Pausar los retiros automáticos? El calendario seguirá registrando su estado."))
            {await session!.ProcedureAsync("SP_GPUM_SET_AUTOMATION",new(){["@Enabled"]=enable});await NavigateAsync("Resumen");}
        },true);pause.IsEnabled=canAdmin;
        workspace.Content=Ui.Stack(Ui.Text("Control de sesiones",30,true),Ui.Text("El job trabaja cada minuto, incluso cuando esta consola está cerrada."),
            cards,Ui.Card(Ui.Stack(Ui.Text(state,20,true),Ui.Text("Última ejecución UTC: "+(last?.ToString("yyyy-MM-dd HH:mm:ss")??"Sin registro")+" · Resultado: "+settings.Text("last_outcome")),Ui.Row(pause,Action("Actualizar",()=>NavigateAsync("Resumen"))))),
            Ui.Text("Ocupación por departamento",20,true),Ui.Grid(usage,200),Ui.Text("Sesiones actuales",20,true),Ui.Grid(sessions,230));
    }
    private Border Metric(string title,string value){var card=Ui.Card(Ui.Stack(Ui.Text(title,11,true),Ui.Text(value,32,true)));card.Width=225;card.Margin=new(0,0,14,16);return card;}
    private async Task Departments()
    {
        var data=demo?Demo.Departments():await session!.DepartmentsAsync();var grid=Ui.Grid(data,280);
        var name=Ui.Input();name.MaxLength=25;var quota=Ui.Input("0");var enabled=new CheckBox{Content="Departamento habilitado",IsChecked=true};DataRow? chosen=null;
        grid.SelectionChanged+=(_,_)=>{chosen=Ui.Selected(grid);if(chosen!=null){name.Text=chosen.Text("name");quota.Text=chosen.Text("quota");enabled.IsChecked=chosen.Flag("enabled");}};
        var form=Ui.Stack(Ui.Field("Nombre (máximo 25 caracteres)",name),Ui.Field("Cupo de sesiones",quota),enabled,
            Ui.Row(Ui.Button("Nuevo",()=>{chosen=null;grid.SelectedItem=null;name.Clear();quota.Text="0";enabled.IsChecked=true;}),Action("Guardar departamento",async()=>{
                if(!int.TryParse(quota.Text,out var count)||count<0)throw new InvalidOperationException("Indique un cupo entero mayor o igual a cero.");
                await session!.ProcedureAsync("SP_GPUM_SAVE_DEPARTMENT",new(){["@Name"]=name.Text,["@Quota"]=count,["@Enabled"]=enabled.IsChecked==true,["@ID"]=chosen?.Value("ID"),["@Revision"]=chosen?.Value("revision")});
                await NavigateAsync("Departamentos");
            },true)));form.IsEnabled=canAdmin;
        workspace.Content=Ui.Stack(Ui.Text("Departamentos y cupos",30,true),Ui.Text("Deshabilitar un departamento lo excluye del control automático. Sus asignaciones se conservan."),grid,Ui.Card(form));
    }
    private async Task Users(string search="")
    {
        var users=demo?Demo.Users():await session!.ProcedureAsync("SP_GPUM_USERS",new(){["@Search"]=search});
        var departments=demo?Demo.Departments():await session!.DepartmentsAsync();
        var field=Ui.Input(search);field.Width=320;
        var grid=Ui.Grid(users,320);var dept=new ComboBox{ItemsSource=departments.DefaultView,DisplayMemberPath="name",SelectedValuePath="ID",Width=300};
        grid.SelectionChanged+=(_,_)=>dept.SelectedValue=Ui.Selected(grid)?.Value("department_id");
        var controls=Ui.Row(Ui.Field("Asignar a departamento",dept),Action("Guardar asignación",async()=>{
            var row=Ui.Selected(grid)??throw new InvalidOperationException("Seleccione un usuario.");
            if(dept.SelectedValue==null)throw new InvalidOperationException("Seleccione un departamento.");
            await session!.ProcedureAsync("SP_GPUM_ASSIGN_USER",new(){["@Username"]=row.Text("username"),["@DepartmentID"]=dept.SelectedValue,["@Revision"]=row.Value("revision")});
            await Users(field.Text);
        },true),Action("Quitar asignación",async()=>{
            var row=Ui.Selected(grid)??throw new InvalidOperationException("Seleccione un usuario.");
            if(Ui.Confirm(this,"¿Quitar la asignación de "+row.Text("username")+"? Su cuenta de GP se conservará."))
            {await session!.ProcedureAsync("SP_GPUM_UNASSIGN_USER",new(){["@Username"]=row.Text("username"),["@Revision"]=row.Value("revision")});await Users(field.Text);}
        }));controls.IsEnabled=canAdmin;
        workspace.Content=Ui.Stack(Ui.Text("Usuarios de Dynamics GP",30,true),Ui.Text("Asigne cuentas existentes a departamentos. La consola no crea ni elimina cuentas de GP."),
            Ui.Row(field,Action("Buscar",()=>Users(field.Text.Trim()))),Ui.Text("Hasta 500 resultados. Refine la búsqueda para localizar otras cuentas.",12),grid,Ui.Card(controls));
    }
    private async Task History()
    {
        var audit=demo?Demo.Audit():await session!.AuditAsync();var notices=demo?Demo.Notifications():await session!.NotificationsAsync();
        workspace.Content=Ui.Stack(Ui.Text("Historial operativo",30,true),Ui.Text("Últimos 500 eventos por lista. Fechas en UTC."),Ui.Text("Operaciones",20,true),Ui.Grid(audit,290),
            Ui.Text("Avisos de GP",20,true),Ui.Text("QUEUED_GP confirma la publicación en la cola nativa; no significa que el usuario lo haya leído.",12),Ui.Grid(notices,240));
    }
    private void Settings(DataRow row)
    {
        var protect=new CheckBox{Content="Proteger sesiones con actividad transaccional registrada",IsChecked=row.Flag("protect_transactions")};
        var notify=new CheckBox{Content="Publicar avisos nativos en GP",IsChecked=row.Flag("notify_in_gp")};
        var customer=Ui.Input(row.Text("customer_name"));customer.MaxLength=150;var contact=Ui.Input(row.Text("customer_contact"));contact.MaxLength=200;
        var purchased=new DatePicker{SelectedDate=row.Value("purchased_on")==DBNull.Value?null:(DateTime?)row["purchased_on"],Margin=new(0,3,20,12)};
        var maintenance=new DatePicker{SelectedDate=row.Value("maintenance_until")==DBNull.Value?null:(DateTime?)row["maintenance_until"],Margin=new(0,3,0,12)};
        var form=Ui.Stack(Ui.Text("Política de operación",20,true),protect,notify,Ui.Text("El retiro forzado modifica registros SQL y no es un cierre ordenado del cliente GP.",12),
            Ui.Text("Registro comercial",20,true),Ui.Field("Cliente",customer),Ui.Field("Contacto",contact),
            Ui.Row(Ui.Field("Fecha de compra",purchased),Ui.Field("Mantenimiento hasta",maintenance)),Ui.Text("El mantenimiento no limita el funcionamiento de la versión adquirida.",12),
            Action("Guardar configuración",async()=>{
                await session!.ProcedureAsync("SP_GPUM_SAVE_SETTINGS",new(){["@ProtectTransactions"]=protect.IsChecked==true,["@NotifyInGP"]=notify.IsChecked==true,
                    ["@Customer"]=customer.Text,["@Contact"]=contact.Text,["@PurchasedOn"]=purchased.SelectedDate,["@MaintenanceUntil"]=maintenance.SelectedDate,["@Revision"]=row.Value("revision")});
                await NavigateAsync("Configuración");
            },true));form.IsEnabled=canAdmin;
        var export=Action("Exportar diagnóstico",async()=>{
            var dialog=new SaveFileDialog{Filter="Diagnóstico JSON|*.json",FileName="GPManager-diagnostico.json"};
            if(dialog.ShowDialog(this)==true)await System.IO.File.WriteAllTextAsync(dialog.FileName,await session!.DiagnosticsAsync());
        });export.IsEnabled=!demo;
        workspace.Content=Ui.Stack(Ui.Text("Configuración",30,true),Ui.Card(form),Ui.Card(Ui.Stack(Ui.Text("Soporte",20,true),Ui.Text("El diagnóstico incluye versiones y estado operativo. Excluye contraseñas, datos comerciales y textos libres del historial."),export)),
            Ui.Text("Para identidades, permisos, actualización o prueba de mensajes, use el asistente de TI desde la pantalla de conexión.",12));
    }
}
