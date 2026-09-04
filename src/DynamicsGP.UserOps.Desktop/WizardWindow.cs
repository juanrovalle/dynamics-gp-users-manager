using System.Collections.ObjectModel;
using System.Data;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using DynamicsGP.UserOps.Core;
namespace DynamicsGP.UserOps.Desktop;

public sealed class WizardWindow:Window
{
    private readonly bool demo;
    private DatabaseSession? session;private InstallerService? installer;
    private ConnectionProfile profile=new();
    private readonly ContentControl body=new();private readonly StackPanel sidebar=new();private readonly TextBlock feedback=Ui.Text("");
    private readonly ScrollViewer bodyScroller=new();private readonly Button back,next;
    private int step=1;private bool busy,installed,provisioned,testSent,observed,configured;
    private IReadOnlyList<CheckResult> checks=[];private IReadOnlyList<JobChoice> jobs=[];private JobChoice? keep;
    private readonly List<AccessGrant> grants=[];private string runtimeLogin="",jobOwner="";
    private ComboBox? jobPicker;private CheckBox? observedBox;
    private TextBox? server,user;private ComboBox? manager,gp;private PasswordBox? password;private CheckBox? windows,trust;
    public WizardWindow(bool demo=false)
    {
        this.demo=demo;Title=ProductInfo.Name+" · Setup and upgrade";Width=1160;Height=870;MinWidth=980;MinHeight=740;WindowStartupLocation=WindowStartupLocation.CenterOwner;
        var root=new DockPanel{Background=new SolidColorBrush(Color.FromRgb(244,247,250))};
        var head=new Border{Background=new SolidColorBrush(Color.FromRgb(16,42,67)),Padding=new(26,14,26,14),Height=76};
        var identity=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};identity.Children.Add(Ui.Logo());
        var brand=Ui.Stack(Ui.Text(ProductInfo.Name,21,true),Ui.Text("IT SETUP & DEPLOYMENT",10,true));
        foreach(var text in brand.Children.OfType<TextBlock>()){text.Foreground=text.FontSize>15?Brushes.White:new SolidColorBrush(Color.FromRgb(174,196,217));text.Margin=text.FontSize>15?new(0,0,0,2):new(0);}
        identity.Children.Add(brand);head.Child=identity;DockPanel.SetDock(head,Dock.Top);root.Children.Add(head);
        back=Ui.Button("Back",async()=>await Run(async()=>{step--;await RenderAsync();}));
        next=Ui.Button("Continue",async()=>await Run(AdvanceAsync),true);
        feedback.Foreground=new SolidColorBrush(Color.FromRgb(64,86,105));
        var foot=Ui.Stack(feedback,Ui.Row(back,next));var footer=new Border{Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(216,225,234)),BorderThickness=new(0,1,0,0),Padding=new(24,8,24,8),Child=foot};DockPanel.SetDock(footer,Dock.Bottom);root.Children.Add(footer);
        var sidebarHost=new Border{Width=232,Background=new SolidColorBrush(Color.FromRgb(248,250,252)),BorderBrush=new SolidColorBrush(Color.FromRgb(216,225,234)),BorderThickness=new(0,0,1,0),Padding=new(16,24,16,16),Child=sidebar};DockPanel.SetDock(sidebarHost,Dock.Left);root.Children.Add(sidebarHost);
        bodyScroller.Content=body;bodyScroller.Padding=new(26,28,30,16);bodyScroller.VerticalScrollBarVisibility=ScrollBarVisibility.Auto;root.Children.Add(bodyScroller);Content=root;
        Loaded+=async(_,_)=>await Run(RenderAsync);Closed+=(_,_)=>session?.Dispose();
        Closing+=(_,e)=>{if(busy){e.Cancel=true;feedback.Text="Wait for the current operation to finish before closing.";}};
    }
    private async Task Run(Func<Task> work)
    {
        if(busy)return;busy=true;body.IsEnabled=false;back.IsEnabled=false;next.IsEnabled=false;feedback.Text="Working…";
        try{await work();feedback.Text=demo?"DEMO · No server changes":"Changes apply to the selected server and database.";}
        catch(Exception ex){feedback.Text="The step could not be completed.";MessageBox.Show(this,ex.Message,"UserOps setup",MessageBoxButton.OK,MessageBoxImage.Warning);}
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
            if(checks.Any(c=>!c.Passed))throw new InvalidOperationException("Resolve all verification items before installing.");
            if(jobPicker!.SelectedItem==null)throw new InvalidOperationException("Explicitly select which job to retain or create.");
            keep=jobPicker.SelectedItem as JobChoice;
            if(keep!=null&&keep.Steps!=1)throw new InvalidOperationException("This job has multiple steps. Create the product job and leave the previous job disabled.");
        }
        if(step==3&&!installed)throw new InvalidOperationException("Select Install / upgrade objects before continuing.");
        if(step==4&&!provisioned)throw new InvalidOperationException("Configure the identities and select Apply permissions before continuing.");
        if(step==5)
        {
            var settings=(await session!.SettingsAsync()).Rows[0];
            if(settings.Flag("notify_in_gp")&&(!testSent||observedBox!.IsChecked!=true))throw new InvalidOperationException("Send a test message and confirm delivery in GP before continuing.");
            observed=observedBox?.IsChecked==true;
        }
        step++;await RenderAsync();
    }
    public async Task RenderStepForSmokeAsync(int value){step=value;await RenderAsync();}
    private async Task RenderAsync()
    {
        sidebar.Children.Clear();
        var names=new[]{"Connect","Verify","Install","Configure","Test","Activate"};
        for(int i=0;i<names.Length;i++){sidebar.Children.Add(Ui.Step(i+1,names[i],i+1==step));}
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
        bodyScroller.ScrollToTop();
    }
    private void Connect()
    {
        server=Ui.Input(profile.Server);manager=new ComboBox{IsEditable=true,Text=profile.ManagerDatabase};gp=new ComboBox{IsEditable=true,Text=profile.GPDatabase};
        windows=new CheckBox{Content="Windows authentication",IsChecked=profile.WindowsAuthentication};user=Ui.Input(profile.Username);password=new();
        trust=new CheckBox{Content="Explicitly trust the SQL certificate",IsChecked=profile.TrustCertificate};
        user.IsEnabled=!profile.WindowsAuthentication;password.IsEnabled=!profile.WindowsAuthentication;
        windows.Checked+=(_,_)=>{user.IsEnabled=false;password.IsEnabled=false;};windows.Unchecked+=(_,_)=>{user.IsEnabled=true;password.IsEnabled=true;};
        body.Content=Ui.Stack(Ui.PageHeader("Connect as a SQL administrator","These credentials are used only during installation. They are not stored or assigned to the automation engine."),
            Ui.Card(Ui.Stack(Ui.Field("Server / instance",server),windows,Ui.Field("SQL login",user),Ui.Field("Password",password),trust,
                Action("List databases",async()=>{
                    var p=new ConnectionProfile(server.Text.Trim(),manager.Text.Trim(),gp.Text.Trim(),windows.IsChecked==true,user.Text.Trim(),trust.IsChecked==true);
                    using var temporary=new DatabaseSession(p,password.Password);var t=await new InstallerService(temporary).DatabasesAsync();
                    var list=t.Rows.Cast<DataRow>().Select(r=>r.Text("name")).ToArray();manager.ItemsSource=list;gp.ItemsSource=list;
                }),Ui.Field("GP system database",gp),Ui.Field("UserOps database (existing or new)",manager))),
            Ui.Text("To migrate the original schema, select its existing database, commonly DEVELOPMENT. New installations default to DynamicsGPUserOps.",12));
    }
    private async Task Verify()
    {
        checks=demo?[new("Encrypted connection",true,"Available"),new("SQL Server Agent",true,"Running"),new("GP schema / SY30000",true,"Compatible; delivery test pending")]:await installer!.PreflightAsync();
        jobs=demo?[]:await installer!.JobsAsync();
        var t=Tables.Create(("Check",typeof(string)),("Result",typeof(string)),("Details",typeof(string)));
        foreach(var check in checks)t.Rows.Add(check.Name,check.Passed?"Passed":"Review",check.Detail);
        jobPicker=new ComboBox();jobPicker.Items.Add("Create the Dynamics GP UserOps job");
        foreach(var job in jobs)jobPicker.Items.Add(job);
        if(jobs.Count==0)jobPicker.SelectedIndex=0;
        else if(keep!=null)jobPicker.SelectedItem=jobs.FirstOrDefault(j=>j.Id==keep.Id);
        body.Content=Ui.Stack(Ui.Text("Verify before installation",27,true),Ui.Grid(t,310),Ui.Card(Ui.Stack(Ui.Field("Job to retain",jobPicker),
            Ui.Text(jobs.Count==0?"No quota jobs were detected for this database.":"Other detected jobs will be disabled only during the confirmed final step."),
            Ui.Text("Detection looks for commands that mention SP_LOGOUTGPUSER_BY_QUOTE. IT must review custom jobs that invoke other procedures indirectly.",12))),
            Action("Run verification again",Verify));
    }
    private void Install()
    {
        var log=Ui.Text(installed?"Objects installed. You can continue.":"Installation pending.");
        body.Content=Ui.Stack(Ui.Text("Install or upgrade the engine",27,true),Ui.Card(Ui.Stack(
            Ui.Text("Server: "+(demo?"SQL-DEMO":profile.Server),17,true),Ui.Text("UserOps: "+profile.ManagerDatabase+" · GP: "+profile.GPDatabase),
            Ui.Text("Existing users, departments, and settings are preserved. New installations remain paused. IT must have a verified backup before upgrading."),
            Action("Install / upgrade objects",async()=>{
                await installer!.InstallSchemaAsync(keep,new Progress<string>(s=>{log.Text=s;feedback.Text=s;}));installed=true;log.Text="Installation complete. Configure departments and permissions.";
            },true),log)));
    }
    private async Task Configure()
    {
        var identities=demo?new[]{"CONTOSO\\UserOpsAdmin","UserOps_Engine","SqlAdministrator"}:(await installer!.LoginsAsync()).Rows.Cast<DataRow>().Select(r=>r.Text("name")).ToArray();
        var login=Ui.Combo(identities);var role=Ui.Combo(new[]{"Reader","Administrator"});role.SelectedIndex=1;
        var runtime=Ui.Combo(identities);var owner=Ui.Combo(identities);runtime.SelectedItem=runtimeLogin;owner.SelectedItem=jobOwner;
        var list=new ListBox{Height=90,Margin=new(0,3,0,8)};
        void Refresh(){list.Items.Clear();foreach(var g in grants)list.Items.Add(g.Login+" — "+g.Role);}
        Refresh();
        runtime.SelectionChanged+=(_,_)=>provisioned=false;owner.SelectionChanged+=(_,_)=>provisioned=false;
        var panel=Ui.Stack(Ui.Text("Daily operations",18,true),Ui.Field("Existing identity",login),Ui.Field("Role",role),
            Ui.Row(Action("Add identity",()=>{
                if(login.SelectedItem==null)throw new InvalidOperationException("Select an identity.");
                grants.RemoveAll(g=>g.Login==login.SelectedItem.ToString());grants.Add(new(login.SelectedItem.ToString()!,role.SelectedItem.ToString()!));provisioned=false;Refresh();return Task.CompletedTask;
            }),Action("Remove from selection",()=>{
                if(list.SelectedIndex>=0){grants.RemoveAt(list.SelectedIndex);provisioned=false;Refresh();}return Task.CompletedTask;
            })),list,Ui.Text("This wizard adds permissions. Removing an identity from this selection does not revoke permissions that already exist.",11),
            Ui.Field("Engine identity (individual non-administrator login)",runtime),
            Ui.Field("SQL Agent owner (administrator, explicitly selected)",owner),
            Ui.Text("The owner restores tempdb permissions after restarts; quota enforcement impersonates the restricted engine identity.",12),
            Action("Apply permissions",async()=>{
                if(runtime.SelectedItem==null||owner.SelectedItem==null)throw new InvalidOperationException("Select both job identities.");
                var selectedOwner=owner.SelectedItem.ToString()!;
                var auth=await session!.QueryAsync("SELECT IS_SRVROLEMEMBER('sysadmin',@login)",new(){["@login"]=selectedOwner},"master");
                if(auth.Rows[0][0]==DBNull.Value||Convert.ToInt32(auth.Rows[0][0])!=1)throw new InvalidOperationException("The SQL Agent owner must be a SQL administrator.");
                await installer!.ProvisionAsync(grants,runtime.SelectedItem.ToString()!);
                runtimeLogin=runtime.SelectedItem.ToString()!;jobOwner=selectedOwner;provisioned=true;feedback.Text="Identities configured.";
            },true));
        body.Content=Ui.Stack(Ui.Text("Configure users and permissions",27,true),
            Ui.Button("Open departments, quotas, and customer registration",()=>{var console=new MainWindow(demo?null:session,demo){Owner=this};console.ShowDialog();}),
            Ui.Card(panel));
    }
    private async Task Test()
    {
        var preview=demo?Demo.Sessions():await session!.ProcedureAsync("SP_PREVIEW_GP_QUOTA",new());
        var userField=Ui.Input();var companies=demo?Tables.Create(("id",typeof(int)),("name",typeof(string))):await session!.CompaniesAsync();
        if(demo)companies.Rows.Add(1,"Summit Foods");
        var company=new ComboBox{ItemsSource=companies.DefaultView,DisplayMemberPath="name",SelectedValuePath="id"};
        observedBox=new CheckBox{Content="I confirmed that the user received the message in GP",IsChecked=observed};
        body.Content=Ui.Stack(Ui.PageHeader("Test without removing sessions","This list is a preview of over-capacity candidates only."),Ui.Grid(preview,210),
            Ui.Card(Ui.Stack(Ui.Field("Target GP user (enter explicitly)",userField),Ui.Field("Company",company),
                Action("Send test message",async()=>{
                    if(string.IsNullOrWhiteSpace(userField.Text)||company.SelectedValue==null)throw new InvalidOperationException("Enter a user and company.");
                    if(!Ui.Confirm(this,"Send a test message to "+userField.Text+"? This action will not remove the session."))return;
                    await session!.ProcedureAsync("SP_GPUM_TEST_MESSAGE",new(){["@Username"]=userField.Text.Trim(),["@CompanyID"]=company.SelectedValue});
                    testSent=true;observed=false;observedBox.IsChecked=false;feedback.Text="Message queued. Confirm delivery in the GP client.";
                },true),observedBox,Ui.Text("The SQL row does not prove delivery. Verify it with the test user before activation.",12))));
    }
    private void RenderActivation()
    {
        var accept=new CheckBox{Content="I confirm the removal policy and job selection",IsChecked=false};
        var description=keep?.Name??"New product job (every minute)";
        var disable=jobs.Where(j=>keep==null||j.Id!=keep.Id).Select(j=>j.Name).ToArray();
        body.Content=Ui.Stack(Ui.Text("Review and activate",27,true),Ui.Card(Ui.Stack(
            Ui.Text(description,19,true),Ui.Text("Engine identity: "+(demo?"UserOps_Engine":runtimeLogin)),Ui.Text("SQL Agent owner: "+(demo?"SqlAdministrator":jobOwner)),
            Ui.Text("Jobs to disable: "+(disable.Length==0?"none":string.Join(", ",disable))),
            Ui.Text("Enforcement removes one session per execution. Forced removal changes GP records and is not a graceful client sign-out. Existing policies will be preserved."),
            accept,Ui.Row(Action("Activate and finish",async()=>{
                if(accept.IsChecked!=true)throw new InvalidOperationException("Confirm the policy and jobs before activation.");
                if(!configured){await installer!.ConfigureJobAsync(keep,jobs,jobOwner,runtimeLogin);configured=true;}
                await session!.ProcedureAsync("SP_GPUM_SET_AUTOMATION",new(){["@Enabled"]=true,["@ConfirmMessageObserved"]=observed});
                MessageBox.Show(this,"Automation is active. Close this IT session and connect with an operating identity.","Installation complete");busy=false;Close();
            },true),Action("Finish with automation paused",async()=>{
                if(accept.IsChecked!=true)throw new InvalidOperationException("Confirm which jobs will be retained.");
                await session!.ProcedureAsync("SP_GPUM_SET_AUTOMATION",new(){["@Enabled"]=false,["@ConfirmMessageObserved"]=observed});
                if(!configured){await installer!.ConfigureJobAsync(keep,jobs,jobOwner,runtimeLogin);configured=true;}
                busy=false;Close();
            })))));
    }
}
