using System.Collections.ObjectModel;
using System.Data;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using GPManager.Core;
namespace GPManager.Desktop;

public sealed class WizardWindow:Window
{
    private readonly bool demo;
    private DatabaseSession? session;private InstallerService? installer;
    private ConnectionProfile profile=new();
    private readonly ContentControl body=new();private readonly StackPanel sidebar=new();private readonly TextBlock feedback=Ui.Text("");
    private readonly Button back,next;
    private int step=1;private bool busy,installed,provisioned,testSent,observed,configured;
    private IReadOnlyList<CheckResult> checks=[];private IReadOnlyList<JobChoice> jobs=[];private JobChoice? keep;
    private readonly List<AccessGrant> grants=[];private string runtimeLogin="",jobOwner="";
    private ComboBox? jobPicker;private CheckBox? observedBox;
    private TextBox? server,user;private ComboBox? manager,gp;private PasswordBox? password;private CheckBox? windows,trust;
    public WizardWindow(bool demo=false)
    {
        this.demo=demo;Title="GP Users Manager · Asistente de TI";Width=1140;Height=850;MinWidth=940;MinHeight=720;WindowStartupLocation=WindowStartupLocation.CenterOwner;
        var root=new DockPanel();
        var banner=Ui.Text("Instalación y actualización",23,true);banner.Foreground=Brushes.White;
        var head=new Border{Background=new SolidColorBrush(Color.FromRgb(20,43,64)),Padding=new(25,20,25,12),Child=banner};DockPanel.SetDock(head,Dock.Top);root.Children.Add(head);
        back=Ui.Button("Anterior",async()=>await Run(async()=>{step--;await RenderAsync();}));
        next=Ui.Button("Continuar",async()=>await Run(AdvanceAsync),true);
        var foot=Ui.Stack(feedback,Ui.Row(back,next));foot.Margin=new(24,10,24,10);DockPanel.SetDock(foot,Dock.Bottom);root.Children.Add(foot);
        sidebar.Width=210;sidebar.Margin=new(20,25,5,0);DockPanel.SetDock(sidebar,Dock.Left);root.Children.Add(sidebar);
        root.Children.Add(new ScrollViewer{Content=body,Padding=new(22,25,26,10),VerticalScrollBarVisibility=ScrollBarVisibility.Auto});Content=root;
        Loaded+=async(_,_)=>await Run(RenderAsync);Closed+=(_,_)=>session?.Dispose();
        Closing+=(_,e)=>{if(busy){e.Cancel=true;feedback.Text="Espere a que termine la operación antes de cerrar.";}};
    }
    private async Task Run(Func<Task> work)
    {
        if(busy)return;busy=true;body.IsEnabled=false;back.IsEnabled=false;next.IsEnabled=false;feedback.Text="Procesando…";
        try{await work();feedback.Text=demo?"DEMOSTRACIÓN · Sin cambios en servidores":"Los cambios se realizan en el servidor y base seleccionados.";}
        catch(Exception ex){feedback.Text="No se completó el paso.";MessageBox.Show(this,ex.Message,"Asistente de TI",MessageBoxButton.OK,MessageBoxImage.Warning);}
        finally{busy=false;body.IsEnabled=true;back.IsEnabled=step>1;next.IsEnabled=step<6&&!demo;}
    }
    private Button Action(string text,Func<Task> work,bool primary=false)
    {var b=Ui.Button(text,async()=>await Run(work),primary);b.IsEnabled=!demo;return b;}
    private async Task AdvanceAsync()
    {
        if(step==1)
        {
            profile=new(server!.Text.Trim(),manager!.Text.Trim(),gp!.Text.Trim(),windows!.IsChecked==true,user!.Text.Trim(),trust!.IsChecked==true);
            profile.Validate();session?.Dispose();session=new(profile,password!.Password);password.Clear();installer=new(session);
            installed=false;provisioned=false;testSent=false;observed=false;configured=false;keep=null;
        }
        if(step==2)
        {
            if(checks.Any(c=>!c.Passed))throw new InvalidOperationException("Resuelva las verificaciones pendientes antes de instalar.");
            if(jobPicker!.SelectedItem==null)throw new InvalidOperationException("Seleccione explícitamente qué job conservar o crear.");
            keep=jobPicker.SelectedItem as JobChoice;
            if(keep!=null&&keep.Steps!=1)throw new InvalidOperationException("Este job tiene varios pasos. Elija crear el job del producto para conservar el anterior deshabilitado.");
        }
        if(step==3&&!installed)throw new InvalidOperationException("Pulse Instalar / actualizar objetos.");
        if(step==4&&!provisioned)throw new InvalidOperationException("Configure las identidades y pulse Aplicar permisos.");
        if(step==5)
        {
            var settings=(await session!.SettingsAsync()).Rows[0];
            if(settings.Flag("notify_in_gp")&&(!testSent||observedBox!.IsChecked!=true))throw new InvalidOperationException("Envíe un aviso de prueba y confirme su recepción en GP.");
            observed=observedBox?.IsChecked==true;
        }
        step++;await RenderAsync();
    }
    public async Task RenderStepForSmokeAsync(int value){step=value;await RenderAsync();}
    private async Task RenderAsync()
    {
        sidebar.Children.Clear();
        var names=new[]{"Conectar","Verificar","Instalar","Configurar","Comprobar","Activar"};
        for(int i=0;i<names.Length;i++){var t=Ui.Text((i+1)+". "+names[i],16,i+1==step);t.Margin=new(8,4,0,20);t.Foreground=i+1==step?new SolidColorBrush(Color.FromRgb(12,115,123)):Brushes.SlateGray;sidebar.Children.Add(t);}
        back.Visibility=step==1?Visibility.Hidden:Visibility.Visible;next.Visibility=step==6?Visibility.Collapsed:Visibility.Visible;
        switch(step)
        {
            case 1:Connect();break;
            case 2:await Verify();break;
            case 3:Install();break;
            case 4:await Configure();break;
            case 5:await Test();break;
            case 6:RenderActivation();break;
        }
    }
    private void Connect()
    {
        server=Ui.Input(profile.Server);manager=new ComboBox{IsEditable=true,Text=profile.ManagerDatabase};gp=new ComboBox{IsEditable=true,Text=profile.GPDatabase};
        windows=new CheckBox{Content="Autenticación Windows",IsChecked=profile.WindowsAuthentication};user=Ui.Input(profile.Username);password=new();
        trust=new CheckBox{Content="Confiar explícitamente en el certificado SQL",IsChecked=profile.TrustCertificate};
        user.IsEnabled=!profile.WindowsAuthentication;password.IsEnabled=!profile.WindowsAuthentication;
        windows.Checked+=(_,_)=>{user.IsEnabled=false;password.IsEnabled=false;};windows.Unchecked+=(_,_)=>{user.IsEnabled=true;password.IsEnabled=true;};
        body.Content=Ui.Stack(Ui.Text("Conectar como administrador de SQL",27,true),Ui.Text("Estas credenciales se usan únicamente durante la instalación. No se guardan ni se asignan al motor automáticamente."),
            Ui.Card(Ui.Stack(Ui.Field("Servidor / instancia",server),windows,Ui.Field("Login SQL",user),Ui.Field("Contraseña",password),trust,
                Action("Listar bases",async()=>{
                    var p=new ConnectionProfile(server.Text.Trim(),manager.Text.Trim(),gp.Text.Trim(),windows.IsChecked==true,user.Text.Trim(),trust.IsChecked==true);
                    using var temporary=new DatabaseSession(p,password.Password);var t=await new InstallerService(temporary).DatabasesAsync();
                    var list=t.Rows.Cast<DataRow>().Select(r=>r.Text("name")).ToArray();manager.ItemsSource=list;gp.ItemsSource=list;
                }),Ui.Field("Base de sistema GP",gp),Ui.Field("Base del gestor (existente o nueva)",manager))),
            Ui.Text("Para migrar la versión original, seleccione DEVELOPMENT. Para una instalación nueva puede utilizar GPUsersManager.",12));
    }
    private async Task Verify()
    {
        checks=demo?[new("Conexión cifrada",true,"Disponible"),new("SQL Server Agent",true,"En ejecución"),new("Esquema GP / SY30000",true,"Compatible; recepción pendiente de prueba")]:await installer!.PreflightAsync();
        jobs=demo?[]:await installer!.JobsAsync();
        var t=Tables.Create(("Verificación",typeof(string)),("Resultado",typeof(string)),("Detalle",typeof(string)));
        foreach(var check in checks)t.Rows.Add(check.Name,check.Passed?"Correcto":"Revisar",check.Detail);
        jobPicker=new ComboBox();jobPicker.Items.Add("Crear el job del producto");
        foreach(var job in jobs)jobPicker.Items.Add(job);
        if(jobs.Count==0)jobPicker.SelectedIndex=0;
        else if(keep!=null)jobPicker.SelectedItem=jobs.FirstOrDefault(j=>j.Id==keep.Id);
        body.Content=Ui.Stack(Ui.Text("Verificar antes de instalar",27,true),Ui.Grid(t,310),Ui.Card(Ui.Stack(Ui.Field("Job que se conservará",jobPicker),
            Ui.Text(jobs.Count==0?"No se detectaron jobs de cuotas para esta base.":"Los otros jobs detectados se deshabilitarán únicamente al finalizar, después de su confirmación."),
            Ui.Text("Se detectan comandos que mencionan SP_LOGOUTGPUSER_BY_QUOTE. TI debe revisar jobs personalizados que invoquen otros procedimientos indirectamente.",12))),
            Action("Repetir verificaciones",Verify));
    }
    private void Install()
    {
        var log=Ui.Text(installed?"Objetos instalados. Puede continuar.":"Instalación pendiente.");
        body.Content=Ui.Stack(Ui.Text("Instalar o actualizar el motor",27,true),Ui.Card(Ui.Stack(
            Ui.Text("Servidor: "+(demo?"SQL-DEMO":profile.Server),17,true),Ui.Text("Gestor: "+profile.ManagerDatabase+" · GP: "+profile.GPDatabase),
            Ui.Text("Se conservan usuarios, departamentos y configuración existente. Una instalación nueva queda pausada. Antes de actualizar, TI debe disponer de un respaldo verificado."),
            Action("Instalar / actualizar objetos",async()=>{
                await installer!.InstallSchemaAsync(keep,new Progress<string>(s=>{log.Text=s;feedback.Text=s;}));installed=true;log.Text="Instalación completada. Configure departamentos y permisos.";
            },true),log)));
    }
    private async Task Configure()
    {
        var identities=demo?new[]{"DOMINIO\\operador","GPUM_Engine","AdministradorSQL"}:(await installer!.LoginsAsync()).Rows.Cast<DataRow>().Select(r=>r.Text("name")).ToArray();
        var login=Ui.Combo(identities);var role=Ui.Combo(new[]{"Lector","Administrador"});role.SelectedIndex=1;
        var runtime=Ui.Combo(identities);var owner=Ui.Combo(identities);runtime.SelectedItem=runtimeLogin;owner.SelectedItem=jobOwner;
        var list=new ListBox{Height=90,Margin=new(0,3,0,8)};
        void Refresh(){list.Items.Clear();foreach(var g in grants)list.Items.Add(g.Login+" — "+g.Role);}
        Refresh();
        runtime.SelectionChanged+=(_,_)=>provisioned=false;owner.SelectionChanged+=(_,_)=>provisioned=false;
        var panel=Ui.Stack(Ui.Text("Operación diaria",18,true),Ui.Field("Identidad existente",login),Ui.Field("Rol",role),
            Ui.Row(Action("Agregar identidad",()=>{
                if(login.SelectedItem==null)throw new InvalidOperationException("Seleccione una identidad.");
                grants.RemoveAll(g=>g.Login==login.SelectedItem.ToString());grants.Add(new(login.SelectedItem.ToString()!,role.SelectedItem.ToString()!));provisioned=false;Refresh();return Task.CompletedTask;
            }),Action("Quitar de esta selección",()=>{
                if(list.SelectedIndex>=0){grants.RemoveAt(list.SelectedIndex);provisioned=false;Refresh();}return Task.CompletedTask;
            })),list,Ui.Text("Este asistente agrega permisos. Quitar una identidad de la selección no revoca permisos que ya existan.",11),
            Ui.Field("Identidad del motor (login individual no administrador)",runtime),
            Ui.Field("Propietario de SQL Agent (administrador, elección explícita)",owner),
            Ui.Text("El propietario restaura los permisos de tempdb tras reinicios; el control de cupos se ejecuta suplantando la identidad restringida del motor.",12),
            Action("Aplicar permisos",async()=>{
                if(runtime.SelectedItem==null||owner.SelectedItem==null)throw new InvalidOperationException("Seleccione las dos identidades del job.");
                var selectedOwner=owner.SelectedItem.ToString()!;
                var auth=await session!.QueryAsync("SELECT IS_SRVROLEMEMBER('sysadmin',@login)",new(){["@login"]=selectedOwner},"master");
                if(auth.Rows[0][0]==DBNull.Value||Convert.ToInt32(auth.Rows[0][0])!=1)throw new InvalidOperationException("El propietario de SQL Agent debe ser administrador SQL.");
                await installer!.ProvisionAsync(grants,runtime.SelectedItem.ToString()!);
                runtimeLogin=runtime.SelectedItem.ToString()!;jobOwner=selectedOwner;provisioned=true;feedback.Text="Identidades configuradas.";
            },true));
        body.Content=Ui.Stack(Ui.Text("Configurar usuarios y permisos",27,true),
            Ui.Button("Abrir departamentos, cupos y registro comercial",()=>{var console=new MainWindow(demo?null:session,demo){Owner=this};console.ShowDialog();}),
            Ui.Card(panel));
    }
    private async Task Test()
    {
        var preview=demo?Demo.Sessions():await session!.ProcedureAsync("SP_PREVIEW_GP_QUOTA",new());
        var userField=Ui.Input();var companies=demo?Tables.Create(("id",typeof(int)),("name",typeof(string))):await session!.CompaniesAsync();
        if(demo)companies.Rows.Add(1,"Fabrikam");
        var company=new ComboBox{ItemsSource=companies.DefaultView,DisplayMemberPath="name",SelectedValuePath="id"};
        observedBox=new CheckBox{Content="Confirmé que el usuario recibió el aviso dentro de GP",IsChecked=observed};
        body.Content=Ui.Stack(Ui.Text("Comprobar sin retirar sesiones",27,true),Ui.Text("La lista siguiente es solo una vista previa de exceso de cupo."),Ui.Grid(preview,210),
            Ui.Card(Ui.Stack(Ui.Field("Usuario GP destinatario (indíquelo explícitamente)",userField),Ui.Field("Compañía",company),
                Action("Enviar mensaje de prueba",async()=>{
                    if(string.IsNullOrWhiteSpace(userField.Text)||company.SelectedValue==null)throw new InvalidOperationException("Indique usuario y compañía.");
                    if(!Ui.Confirm(this,"¿Enviar un aviso de prueba a "+userField.Text+"? Esta acción no retirará su sesión."))return;
                    await session!.ProcedureAsync("SP_GPUM_TEST_MESSAGE",new(){["@Username"]=userField.Text.Trim(),["@CompanyID"]=company.SelectedValue});
                    testSent=true;observed=false;observedBox.IsChecked=false;feedback.Text="Mensaje encolado. Confirme su recepción en el cliente GP.";
                },true),observedBox,Ui.Text("La fila en SQL no demuestra recepción. Compruébelo con el usuario de prueba antes de activar.",12))));
    }
    private void RenderActivation()
    {
        var accept=new CheckBox{Content="Confirmo la política de retiro y la selección de jobs",IsChecked=false};
        var description=keep?.Name??"Nuevo job del producto (cada minuto)";
        var disable=jobs.Where(j=>keep==null||j.Id!=keep.Id).Select(j=>j.Name).ToArray();
        body.Content=Ui.Stack(Ui.Text("Finalizar y activar",27,true),Ui.Card(Ui.Stack(
            Ui.Text(description,19,true),Ui.Text("Identidad del motor: "+(demo?"GPUM_Engine":runtimeLogin)),Ui.Text("Propietario SQL Agent: "+(demo?"AdministradorSQL":jobOwner)),
            Ui.Text("Jobs que se deshabilitarán: "+(disable.Length==0?"ninguno":string.Join(", ",disable))),
            Ui.Text("El control retira una sesión por ejecución. El retiro forzado modifica registros de GP; no equivale a cerrar ordenadamente el cliente. Se conservarán las políticas existentes."),
            accept,Ui.Row(Action("Activar y finalizar",async()=>{
                if(accept.IsChecked!=true)throw new InvalidOperationException("Confirme la política y los jobs antes de activar.");
                if(!configured){await installer!.ConfigureJobAsync(keep,jobs,jobOwner,runtimeLogin);configured=true;}
                await session!.ProcedureAsync("SP_GPUM_SET_AUTOMATION",new(){["@Enabled"]=true,["@ConfirmMessageObserved"]=observed});
                MessageBox.Show(this,"Automatización activada. Cierre esta sesión de TI y conecte la consola con una identidad de operación.","Instalación completada");busy=false;Close();
            },true),Action("Finalizar con automatización pausada",async()=>{
                if(accept.IsChecked!=true)throw new InvalidOperationException("Confirme qué jobs se conservarán.");
                await session!.ProcedureAsync("SP_GPUM_SET_AUTOMATION",new(){["@Enabled"]=false,["@ConfirmMessageObserved"]=observed});
                if(!configured){await installer!.ConfigureJobAsync(keep,jobs,jobOwner,runtimeLogin);configured=true;}
                busy=false;Close();
            })))));
    }
}
