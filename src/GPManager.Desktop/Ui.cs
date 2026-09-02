using System.Data;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Automation;
namespace GPManager.Desktop;
internal static class Ui
{
    public static TextBlock Text(string text,double size=14,bool bold=false)=>new(){Text=text,FontSize=size,FontWeight=bold?FontWeights.SemiBold:FontWeights.Normal,TextWrapping=TextWrapping.Wrap,Margin=new(0,0,0,10)};
    public static StackPanel Stack(params UIElement[] children){var p=new StackPanel();foreach(var c in children)p.Children.Add(c);return p;}
    public static WrapPanel Row(params UIElement[] children){var p=new WrapPanel();foreach(var c in children)p.Children.Add(c);return p;}
    public static Button Button(string text,Action action,bool primary=false)
    {var b=new Button{Content=text};if(primary)b.SetResourceReference(FrameworkElement.StyleProperty,"Primary");b.Click+=(_,_)=>action();return b;}
    public static FrameworkElement Field(string label,FrameworkElement control)
    {AutomationProperties.SetName(control,label);return Stack(Text(label,12,true),control);}
    public static Border Card(UIElement child)=>new(){Background=Brushes.White,CornerRadius=new(8),Padding=new(22),Margin=new(0,0,0,16),Child=child};
    public static DataGrid Grid(DataTable data,double height=280)
    {
        var g=new DataGrid{ItemsSource=data.DefaultView,Height=height,Margin=new(0,8,0,14)};
        g.AutoGeneratingColumn+=(_,e)=>{if(e.PropertyName is "revision" or "can_admin" or "ID")e.Cancel=true;
            var names=new Dictionary<string,string>{{"name","Departamento"},{"department","Departamento"},{"quota","Cupo"},{"enabled","Habilitado"},{"username","Usuario"},{"display_name","Nombre"},{"outcome","Resultado"},{"status","Estado"},{"occurred_at","Fecha UTC"},{"created_at","Creado UTC"},{"message","Mensaje"},{"actor","Responsable"},{"last_completed_at","Última ejecución UTC"},{"company","Compañía"},{"session_id","Sesión"},{"company_id","Compañía ID"},{"department_id","Departamento ID"},{"queued_at","Encolado UTC"},{"reason","Motivo"}};
            if(names.TryGetValue(e.PropertyName,out var title))e.Column.Header=title;
            if(e.Column is DataGridTextColumn tc&&e.PropertyType==typeof(DateTime))tc.Binding=new System.Windows.Data.Binding(e.PropertyName){StringFormat="yyyy-MM-dd HH:mm:ss"};
        };return g;
    }
    public static DataRow? Selected(DataGrid grid)=>(grid.SelectedItem as DataRowView)?.Row;
    public static bool Confirm(Window owner,string text)=>MessageBox.Show(owner,text,"GP Users Manager",MessageBoxButton.YesNo,MessageBoxImage.Question)==MessageBoxResult.Yes;
    public static TextBox Input(string value="")=>new(){Text=value};
    public static ComboBox Combo(IEnumerable<string> values){var box=new ComboBox();foreach(var value in values)box.Items.Add(value);return box;}
}

