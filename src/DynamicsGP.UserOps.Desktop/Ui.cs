using System.Data;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Automation;
using DynamicsGP.UserOps.Core;
namespace DynamicsGP.UserOps.Desktop;
internal static class Ui
{
    private static readonly Brush BorderBrush=new SolidColorBrush(Color.FromRgb(216,225,234));
    private static readonly Brush MutedBrush=new SolidColorBrush(Color.FromRgb(94,113,132));
    private static readonly Brush AccentBrush=new SolidColorBrush(Color.FromRgb(23,105,224));
    public static TextBlock Text(string text,double size=14,bool bold=false)=>new(){Text=text,FontSize=size,FontWeight=bold?FontWeights.SemiBold:FontWeights.Normal,TextWrapping=TextWrapping.Wrap,Margin=new(0,0,0,10)};
    public static StackPanel Stack(params UIElement[] children){var p=new StackPanel();foreach(var c in children)p.Children.Add(c);return p;}
    public static WrapPanel Row(params UIElement[] children){var p=new WrapPanel();foreach(var c in children)p.Children.Add(c);return p;}
    public static Button Button(string text,Action action,bool primary=false)
    {var b=new Button{Content=text};if(primary)b.SetResourceReference(FrameworkElement.StyleProperty,"Primary");b.Click+=(_,_)=>action();return b;}
    public static FrameworkElement Field(string label,FrameworkElement control)
    {AutomationProperties.SetName(control,label);return Stack(Text(label,12,true),control);}
    public static Border Card(UIElement child)=>new(){Background=Brushes.White,BorderBrush=BorderBrush,BorderThickness=new(1),CornerRadius=new(8),Padding=new(24),Margin=new(0,0,0,18),Child=child};
    public static FrameworkElement PageHeader(string title,string description)
    {var subtitle=Text(description,14);subtitle.Foreground=MutedBrush;subtitle.Margin=new(0,0,0,22);return Stack(Text(title,31,true),subtitle);}
    public static Border Logo()
    {var letters=Text("UO",14,true);letters.Foreground=Brushes.White;letters.Margin=new(0);letters.HorizontalAlignment=HorizontalAlignment.Center;letters.VerticalAlignment=VerticalAlignment.Center;return new Border{Width=42,Height=42,CornerRadius=new(8),Background=AccentBrush,Child=letters,Margin=new(0,0,14,0)};}
    public static Border Badge(string text,bool positive)
    {var label=Text(text.ToUpperInvariant(),11,true);label.Margin=new(0);label.Foreground=positive?new SolidColorBrush(Color.FromRgb(22,101,52)):new SolidColorBrush(Color.FromRgb(146,64,14));return new Border{Background=positive?new SolidColorBrush(Color.FromRgb(220,252,231)):new SolidColorBrush(Color.FromRgb(255,237,213)),CornerRadius=new(12),Padding=new(10,4,10,4),HorizontalAlignment=HorizontalAlignment.Left,Child=label,Margin=new(0,0,0,10)};}
    public static Border Step(int number,string text,bool active)
    {var marker=Text(number.ToString(),12,true);marker.Margin=new(0);marker.HorizontalAlignment=HorizontalAlignment.Center;marker.VerticalAlignment=VerticalAlignment.Center;marker.Foreground=active?Brushes.White:MutedBrush;var circle=new Border{Width=28,Height=28,CornerRadius=new(14),Background=active?AccentBrush:new SolidColorBrush(Color.FromRgb(231,237,243)),Child=marker,Margin=new(0,0,10,0)};var label=Text(text,14,active);label.Margin=new(0);label.VerticalAlignment=VerticalAlignment.Center;label.Foreground=active?new SolidColorBrush(Color.FromRgb(13,87,183)):new SolidColorBrush(Color.FromRgb(52,75,96));var row=new StackPanel{Orientation=Orientation.Horizontal};row.Children.Add(circle);row.Children.Add(label);return new Border{Background=active?new SolidColorBrush(Color.FromRgb(233,242,255)):Brushes.Transparent,BorderBrush=active?new SolidColorBrush(Color.FromRgb(185,212,250)):Brushes.Transparent,BorderThickness=new(1),CornerRadius=new(6),Padding=new(10,8,10,8),Margin=new(0,0,0,6),Child=row};}
    public static DataGrid Grid(DataTable data,double height=280)
    {
        var g=new DataGrid{ItemsSource=data.DefaultView,Height=height,Margin=new(0,8,0,14)};
        g.AutoGeneratingColumn+=(_,e)=>{if(e.PropertyName is "revision" or "can_admin" or "ID")e.Cancel=true;
            var names=new Dictionary<string,string>{{"name","Department"},{"department","Department"},{"departamento","Department"},{"quota","Quota"},{"Limite","Quota"},{"Activos","Active"},{"Disponible","Available"},{"Exceso","Overage"},{"enabled","Enabled"},{"username","User"},{"usuario","User"},{"display_name","Name"},{"outcome","Outcome"},{"status","Status"},{"occurred_at","Date (UTC)"},{"created_at","Created (UTC)"},{"message","Message"},{"actor","Actor"},{"last_completed_at","Last execution (UTC)"},{"company","Company"},{"session_id","Session"},{"company_id","Company ID"},{"department_id","Department ID"},{"queued_at","Queued (UTC)"},{"reason","Reason"},{"activity","Recorded activity"},{"logInDate","Login date"},{"logInTime","Login time"}};
            if(names.TryGetValue(e.PropertyName,out var title))e.Column.Header=title;
            if(e.Column is DataGridTextColumn tc&&e.PropertyType==typeof(DateTime))tc.Binding=new System.Windows.Data.Binding(e.PropertyName){StringFormat="MMM d, yyyy h:mm:ss tt 'UTC'"};
        };return g;
    }
    public static DataRow? Selected(DataGrid grid)=>(grid.SelectedItem as DataRowView)?.Row;
    public static bool Confirm(Window owner,string text)=>MessageBox.Show(owner,text,ProductInfo.Name,MessageBoxButton.YesNo,MessageBoxImage.Question)==MessageBoxResult.Yes;
    public static TextBox Input(string value="")=>new(){Text=value};
    public static ComboBox Combo(IEnumerable<string> values){var box=new ComboBox();foreach(var value in values)box.Items.Add(value);return box;}
}
