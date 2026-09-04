using System.Data;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using DynamicsGP.UserOps.Core;
using Microsoft.Win32;
namespace DynamicsGP.UserOps.Desktop;

public sealed class MainWindow:Window
{
    private DatabaseSession? session;private readonly bool borrowed;private bool demo,busy,canAdmin;
    private readonly ContentControl workspace=new();private readonly StackPanel navigation=new();private readonly TextBlock status=Ui.Text("");
    private readonly TextBlock subtitle=Ui.Text("Administration console",12);private readonly ScrollViewer workspaceScroller=new();
    private readonly DispatcherTimer timer=new(){Interval=TimeSpan.FromSeconds(30)};
    private readonly ProfileStore profiles=new();private string page="Overview";
    public MainWindow(DatabaseSession? existing=null,bool demo=false)
    {
        this.demo=demo;session=existing;borrowed=existing!=null;
        Title=ProductInfo.Name;Width=1240;Height=860;MinWidth=1000;MinHeight=720;WindowStartupLocation=WindowStartupLocation.CenterScreen;
        var root=new DockPanel{Background=new SolidColorBrush(Color.FromRgb(244,247,250))};
        var header=new Border{Background=new SolidColorBrush(Color.FromRgb(16,42,67)),Padding=new(28,16,28,16),Height=80};
        var headerGrid=new Grid();headerGrid.ColumnDefinitions.Add(new(){Width=new GridLength(1,GridUnitType.Star)});headerGrid.ColumnDefinitions.Add(new(){Width=GridLength.Auto});
        var identity=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};identity.Children.Add(Ui.Logo());
        var brand=Ui.Stack(Ui.Text(ProductInfo.Name,22,true),Ui.Text("SESSION GOVERNANCE FOR MICROSOFT DYNAMICS GP",10,true));
        foreach(var text in brand.Children.OfType<TextBlock>()){text.Foreground=text.FontSize>15?Brushes.White:new SolidColorBrush(Color.FromRgb(174,196,217));text.Margin=text.FontSize>15?new(0,0,0,2):new(0);}
        identity.Children.Add(brand);headerGrid.Children.Add(identity);
        subtitle.Foreground=new SolidColorBrush(Color.FromRgb(212,224,235));subtitle.HorizontalAlignment=HorizontalAlignment.Right;subtitle.VerticalAlignment=VerticalAlignment.Center;subtitle.Margin=new(20,0,0,0);Grid.SetColumn(subtitle,1);headerGrid.Children.Add(subtitle);
        header.Child=headerGrid;DockPanel.SetDock(header,Dock.Top);root.Children.Add(header);
        status.Foreground=new SolidColorBrush(Color.FromRgb(64,86,105));status.Margin=new(24,10,24,10);
        var statusBar=new Border{Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(216,225,234)),BorderThickness=new(0,1,0,0),Child=status};DockPanel.SetDock(statusBar,Dock.Bottom);root.Children.Add(statusBar);
        var navigationHost=new Border{Width=232,Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(216,225,234)),BorderThickness=new(0,0,1,0),Padding=new(16,22,16,16)};
        var navigationLayout=Ui.Stack(Ui.Text("OPERATIONS",10,true),navigation);navigationHost.Child=navigationLayout;DockPanel.SetDock(navigationHost,Dock.Left);root.Children.Add(navigationHost);
        workspaceScroller.Content=workspace;workspaceScroller.VerticalScrollBarVisibility=ScrollBarVisibility.Auto;workspaceScroller.Padding=new(28,26,30,24);
        root.Children.Add(workspaceScroller);Content=root;
        Loaded+=async(_,_)=>{if(session!=null||demo)await Run(()=>NavigateAsync("Overview"));else ShowConnection();};
        Closed+=(_,_)=>{timer.Stop();if(!borrowed)session?.Dispose();};
        timer.Tick+=async(_,_)=>{if(!busy&&page=="Overview"&&(session!=null||demo))await Run(()=>NavigateAsync("Overview"));};
        timer.Start();
    }
    private async Task Run(Func<Task> work)
    {
        if(busy)return;busy=true;workspace.IsEnabled=false;navigation.IsEnabled=false;status.Text="Working…";
        try{await work();status.Text=demo?"DEMO · Sample data · No SQL Server connection":"Ready · GP processes queued messages; delivery is not a read receipt.";}
        catch(Exception ex){status.Text="The operation could not be completed.";MessageBox.Show(this,ex.Message,ProductInfo.Name,MessageBoxButton.OK,MessageBoxImage.Warning);}
        finally{busy=false;workspace.IsEnabled=true;navigation.IsEnabled=true;}
    }
    private Button Action(string title,Func<Task> action,bool primary=false)=>Ui.Button(title,async()=>await Run(action),primary);
    private void ShowConnection()
    {
        navigation.Children.Clear();page="Connection";subtitle.Text="Local installation · No cloud services";
        var p=profiles.Load()??new();status.Text=profiles.ImportedLegacyProfile?"GP Users Manager 3.x connection profile imported. No password was copied.":"Ready to connect.";
        var server=Ui.Input(p.Server);var manager=Ui.Input(p.ManagerDatabase);var gp=Ui.Input(p.GPDatabase);
        var windows=new CheckBox{Content="Windows authentication",IsChecked=p.WindowsAuthentication};var user=Ui.Input(p.Username);var secret=new PasswordBox();
        var trust=new CheckBox{Content="Explicitly trust the SQL Server certificate",IsChecked=p.TrustCertificate};
        user.IsEnabled=!p.WindowsAuthentication;secret.IsEnabled=!p.WindowsAuthentication;
        windows.Checked+=(_,_)=>{user.IsEnabled=false;secret.IsEnabled=false;};windows.Unchecked+=(_,_)=>{user.IsEnabled=true;secret.IsEnabled=true;};
        workspace.Content=Ui.Stack(Ui.PageHeader("Connect to Dynamics GP UserOps","Use your operating account. IT installation credentials are requested separately in the setup wizard."),
            Ui.Card(Ui.Stack(Ui.Field("SQL Server",server),Ui.Row(Ui.Field("UserOps database",manager),Ui.Field("GP system database",gp)),windows,
                Ui.Field("SQL login",user),Ui.Field("Password (this session only)",secret),trust,
                Ui.Row(Action("Connect",async()=>{
                    var profile=new ConnectionProfile(server.Text.Trim(),manager.Text.Trim(),gp.Text.Trim(),windows.IsChecked==true,user.Text.Trim(),trust.IsChecked==true);
                    var candidate=new DatabaseSession(profile,secret.Password);
                    try {var result=await candidate.SettingsAsync();if(result.Rows.Count!=1)throw new InvalidOperationException("The installation is incomplete.");}
                    catch{candidate.Dispose();throw;}
                    session?.Dispose();session=candidate;secret.Clear();profiles.Save(profile);demo=false;await NavigateAsync("Overview");
                },true),Ui.Button("Setup / upgrade wizard",()=>new WizardWindow{Owner=this}.ShowDialog()),Action("View demo",async()=>{demo=true;await NavigateAsync("Overview");})))),
            Ui.Text("The connection is encrypted. Trusting the server certificate must be an explicit IT decision.",12));
    }
    public async Task NavigateAsync(string selected)
    {
        page=selected;var settings=demo?Demo.Settings():await session!.SettingsAsync();canAdmin=!demo&&settings.Rows[0].Flag("can_admin");
        subtitle.Text=demo?"DEMO · Sample data":session!.Profile.Server+" / "+session.Profile.ManagerDatabase;
        navigation.Children.Clear();
        foreach(var name in new[]{"Overview","Departments","Users","Activity","Settings"})
        {var b=Action(name,()=>NavigateAsync(name),name==selected);b.SetResourceReference(FrameworkElement.StyleProperty,name==selected?"NavigationSelected":"Navigation");navigation.Children.Add(b);}
        if(!borrowed){var change=Ui.Button("Change connection",()=>{session?.Dispose();session=null;demo=false;ShowConnection();});change.SetResourceReference(FrameworkElement.StyleProperty,"Navigation");navigation.Children.Add(change);}
        navigation.Children.Add(Ui.Text("v4.0.0 · Windows / Server\nEngine: SQL Server Agent",11));
        switch(selected)
        {
            case "Overview":await Summary(settings.Rows[0]);break;
            case "Departments":await Departments();break;
            case "Users":await Users();break;
            case "Activity":await History();break;
            case "Settings":Settings(settings.Rows[0]);break;
        }
        workspaceScroller.ScrollToTop();
    }
    private async Task Summary(DataRow settings)
    {
        var usage=demo?Demo.Usage():await session!.UsageAsync();var sessions=demo?Demo.Sessions():await session!.SessionsAsync();
        var last=settings.Value("last_completed_at")==DBNull.Value?(DateTime?)null:DateTime.SpecifyKind((DateTime)settings["last_completed_at"],DateTimeKind.Utc);
        var state=Health.Describe(settings.Flag("automation_enabled"),last,DateTime.UtcNow);
        var cards=Ui.Row(Metric("GP SESSIONS",sessions.Rows.Count.ToString()),Metric("CONFIGURED CAPACITY",usage.Rows.Cast<DataRow>().Sum(r=>Convert.ToInt32(r["Limite"])).ToString()),
            Metric("OVER CAPACITY",usage.Rows.Cast<DataRow>().Sum(r=>Convert.ToInt32(r["Exceso"])).ToString()));
        var pause=Action(settings.Flag("automation_enabled")?"Pause automation":"Resume automation",async()=>{
            var enable=!settings.Flag("automation_enabled");
            if(Ui.Confirm(this,enable?"Resume automatic quota enforcement?":"Pause automatic removals? The schedule will continue recording its status."))
            {await session!.ProcedureAsync("SP_GPUM_SET_AUTOMATION",new(){["@Enabled"]=enable});await NavigateAsync("Overview");}
        },true);pause.IsEnabled=canAdmin;
        workspace.Content=Ui.Stack(Ui.PageHeader("Session overview","The SQL Server Agent job runs every minute, even when this console is closed."),
            cards,Ui.Card(Ui.Stack(Ui.Badge(state,state=="Automation active"),Ui.Text("Last execution: "+(last is null?"No record":last.Value.ToString("MMM d, yyyy h:mm:ss tt")+" UTC")+" · Outcome: "+settings.Text("last_outcome")),Ui.Row(pause,Action("Refresh",()=>NavigateAsync("Overview"))))),
            Ui.Text("Capacity by department",20,true),Ui.Grid(usage,200),Ui.Text("Current sessions",20,true),Ui.Grid(sessions,230));
    }
    private Border Metric(string title,string value){var card=Ui.Card(Ui.Stack(Ui.Text(title,11,true),Ui.Text(value,32,true)));card.Width=225;card.Margin=new(0,0,14,16);return card;}
    private async Task Departments()
    {
        var data=demo?Demo.Departments():await session!.DepartmentsAsync();var grid=Ui.Grid(data,280);
        var name=Ui.Input();name.MaxLength=25;var quota=Ui.Input("0");var enabled=new CheckBox{Content="Department enabled",IsChecked=true};DataRow? chosen=null;
        grid.SelectionChanged+=(_,_)=>{chosen=Ui.Selected(grid);if(chosen!=null){name.Text=chosen.Text("name");quota.Text=chosen.Text("quota");enabled.IsChecked=chosen.Flag("enabled");}};
        var form=Ui.Stack(Ui.Field("Name (25 characters maximum)",name),Ui.Field("Session quota",quota),enabled,
            Ui.Row(Ui.Button("New",()=>{chosen=null;grid.SelectedItem=null;name.Clear();quota.Text="0";enabled.IsChecked=true;}),Action("Save department",async()=>{
                if(!int.TryParse(quota.Text,out var count)||count<0)throw new InvalidOperationException("Enter a whole-number quota greater than or equal to zero.");
                await session!.ProcedureAsync("SP_GPUM_SAVE_DEPARTMENT",new(){["@Name"]=name.Text,["@Quota"]=count,["@Enabled"]=enabled.IsChecked==true,["@ID"]=chosen?.Value("ID"),["@Revision"]=chosen?.Value("revision")});
                await NavigateAsync("Departments");
            },true)));form.IsEnabled=canAdmin;
        workspace.Content=Ui.Stack(Ui.PageHeader("Departments and capacity","Disabled departments are excluded from automatic enforcement while their user assignments are preserved."),grid,Ui.Card(form));
    }
    private async Task Users(string search="")
    {
        var users=demo?Demo.Users():await session!.ProcedureAsync("SP_GPUM_USERS",new(){["@Search"]=search});
        var departments=demo?Demo.Departments():await session!.DepartmentsAsync();
        var field=Ui.Input(search);field.Width=320;
        var grid=Ui.Grid(users,320);var dept=new ComboBox{ItemsSource=departments.DefaultView,DisplayMemberPath="name",SelectedValuePath="ID",Width=300};
        grid.SelectionChanged+=(_,_)=>dept.SelectedValue=Ui.Selected(grid)?.Value("department_id");
        var controls=Ui.Row(Ui.Field("Assign to department",dept),Action("Save assignment",async()=>{
            var row=Ui.Selected(grid)??throw new InvalidOperationException("Select a user.");
            if(dept.SelectedValue==null)throw new InvalidOperationException("Select a department.");
            await session!.ProcedureAsync("SP_GPUM_ASSIGN_USER",new(){["@Username"]=row.Text("username"),["@DepartmentID"]=dept.SelectedValue,["@Revision"]=row.Value("revision")});
            await Users(field.Text);
        },true),Action("Remove assignment",async()=>{
            var row=Ui.Selected(grid)??throw new InvalidOperationException("Select a user.");
            if(Ui.Confirm(this,"Remove the assignment for "+row.Text("username")+"? The GP account will be preserved."))
            {await session!.ProcedureAsync("SP_GPUM_UNASSIGN_USER",new(){["@Username"]=row.Text("username"),["@Revision"]=row.Value("revision")});await Users(field.Text);}
        }));controls.IsEnabled=canAdmin;
        workspace.Content=Ui.Stack(Ui.PageHeader("Microsoft Dynamics GP users","Assign existing accounts to departments. UserOps does not create or delete GP accounts."),
            Ui.Row(field,Action("Search",()=>Users(field.Text.Trim()))),Ui.Text("Up to 500 results. Refine the search to locate additional accounts.",12),grid,Ui.Card(controls));
    }
    private async Task History()
    {
        var audit=demo?Demo.Audit():await session!.AuditAsync();var notices=demo?Demo.Notifications():await session!.NotificationsAsync();
        workspace.Content=Ui.Stack(Ui.PageHeader("Operational activity","The latest 500 events are shown in each list. All timestamps are UTC."),Ui.Text("Operations",20,true),Ui.Grid(audit,290),
            Ui.Text("GP messages",20,true),Ui.Text("QUEUED_GP confirms insertion into the native queue; it does not mean that the user read the message.",12),Ui.Grid(notices,240));
    }
    private void Settings(DataRow row)
    {
        var protect=new CheckBox{Content="Protect sessions with recorded transactional activity",IsChecked=row.Flag("protect_transactions")};
        var notify=new CheckBox{Content="Publish native GP messages",IsChecked=row.Flag("notify_in_gp")};
        var customer=Ui.Input(row.Text("customer_name"));customer.MaxLength=150;var contact=Ui.Input(row.Text("customer_contact"));contact.MaxLength=200;
        var purchased=new DatePicker{SelectedDate=row.Value("purchased_on")==DBNull.Value?null:(DateTime?)row["purchased_on"],Margin=new(0,3,20,12)};
        var maintenance=new DatePicker{SelectedDate=row.Value("maintenance_until")==DBNull.Value?null:(DateTime?)row["maintenance_until"],Margin=new(0,3,0,12)};
        var form=Ui.Stack(Ui.Text("Enforcement policy",20,true),protect,notify,Ui.Text("Forced removal changes SQL records and is not a graceful GP client sign-out.",12),
            Ui.Text("Customer registration",20,true),Ui.Field("Customer",customer),Ui.Field("Contact",contact),
            Ui.Row(Ui.Field("Purchase date",purchased),Ui.Field("Maintenance through",maintenance)),Ui.Text("Maintenance status does not limit the purchased version.",12),
            Action("Save settings",async()=>{
                await session!.ProcedureAsync("SP_GPUM_SAVE_SETTINGS",new(){["@ProtectTransactions"]=protect.IsChecked==true,["@NotifyInGP"]=notify.IsChecked==true,
                    ["@Customer"]=customer.Text,["@Contact"]=contact.Text,["@PurchasedOn"]=purchased.SelectedDate,["@MaintenanceUntil"]=maintenance.SelectedDate,["@Revision"]=row.Value("revision")});
                await NavigateAsync("Settings");
            },true));form.IsEnabled=canAdmin;
        var export=Action("Export diagnostics",async()=>{
            var dialog=new SaveFileDialog{Filter="Diagnostic JSON|*.json",FileName="Dynamics-GP-UserOps-diagnostic.json"};
            if(dialog.ShowDialog(this)==true)await System.IO.File.WriteAllTextAsync(dialog.FileName,await session!.DiagnosticsAsync());
        });export.IsEnabled=!demo;
        workspace.Content=Ui.Stack(Ui.PageHeader("Settings","Configure enforcement, customer information, and support diagnostics."),Ui.Card(form),Ui.Card(Ui.Stack(Ui.Text("Support",20,true),Ui.Text("The diagnostic includes versions and operating status. It excludes passwords, customer registration, and free-text activity details."),export)),
            Ui.Text("Use the IT setup wizard from the connection screen to manage identities, permissions, upgrades, or message tests.",12),
            Ui.Text("Dynamics GP UserOps is an independent product and is not affiliated with or endorsed by Microsoft. Microsoft Dynamics GP is a Microsoft product.",11));
    }
}
