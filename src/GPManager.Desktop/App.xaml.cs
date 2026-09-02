using System.Windows;
namespace GPManager.Desktop;
public partial class App:Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if(e.Args.Contains("--smoke-test"))
        {
            var index=Array.IndexOf(e.Args,"--smoke-test");var folder=e.Args.ElementAtOrDefault(index+1)??"artifacts/screenshots";
            try {await Smoke.RunAsync(folder);Shutdown(0);}catch(Exception ex){System.IO.Directory.CreateDirectory(folder);System.IO.File.WriteAllText(System.IO.Path.Combine(folder,"error.txt"),ex.ToString());Shutdown(1);}
            return;
        }
        var window=new MainWindow(demo:e.Args.Contains("--demo"));MainWindow=window;window.Show();
    }
}
