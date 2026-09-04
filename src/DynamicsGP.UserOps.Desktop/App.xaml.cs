using System.Windows;
namespace DynamicsGP.UserOps.Desktop;
public partial class App:Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if(e.Args.Contains("--smoke-test"))
        {
            var index=Array.IndexOf(e.Args,"--smoke-test");var folder=e.Args.ElementAtOrDefault(index+1)??"artifacts/screenshots";
            var scaleIndex=Array.IndexOf(e.Args,"--smoke-scale");var scaleText=scaleIndex<0?"1":e.Args.ElementAtOrDefault(scaleIndex+1);
            var scale=double.TryParse(scaleText,System.Globalization.NumberStyles.Number,System.Globalization.CultureInfo.InvariantCulture,out var parsed)&&parsed is >=1 and <=2?parsed:1;
            try {await Smoke.RunAsync(folder,scale);Shutdown(0);}catch(Exception ex){System.IO.Directory.CreateDirectory(folder);System.IO.File.WriteAllText(System.IO.Path.Combine(folder,"error.txt"),ex.ToString());Shutdown(1);}
            return;
        }
        var window=new MainWindow(demo:e.Args.Contains("--demo"));MainWindow=window;window.Show();
    }
}
