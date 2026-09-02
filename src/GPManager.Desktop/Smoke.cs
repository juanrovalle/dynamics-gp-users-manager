using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
namespace GPManager.Desktop;
internal static class Smoke
{
    public static async Task RunAsync(string folder)
    {
        Directory.CreateDirectory(folder);
        Application.Current.ShutdownMode=ShutdownMode.OnExplicitShutdown;
        var console=new MainWindow(demo:true){Left=-20000,Top=-20000,WindowStartupLocation=WindowStartupLocation.Manual,ShowInTaskbar=false};
        console.Show();
        foreach(var page in new[]{"Resumen","Departamentos","Usuarios","Historial","Configuración"})
        {await console.NavigateAsync(page);await SaveAsync(console,Path.Combine(folder,page+".png"));}
        console.Close();
        var wizard=new WizardWindow(demo:true){Left=-20000,Top=-20000,WindowStartupLocation=WindowStartupLocation.Manual,ShowInTaskbar=false};
        wizard.Show();
        for(var i=1;i<=6;i++){await wizard.RenderStepForSmokeAsync(i);await SaveAsync(wizard,Path.Combine(folder,"Asistente-"+i+".png"));}
        wizard.Close();File.WriteAllText(Path.Combine(folder,"result.txt"),"PASS: 5 console screens and 6 wizard steps rendered without a SQL connection.");
    }
    private static async Task SaveAsync(Window window,string path)
    {
        await window.Dispatcher.InvokeAsync(()=>window.UpdateLayout(),DispatcherPriority.ApplicationIdle);
        var bitmap=new RenderTargetBitmap((int)window.ActualWidth,(int)window.ActualHeight,96,96,PixelFormats.Pbgra32);
        bitmap.Render(window);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file=File.Create(path);encoder.Save(file);
    }
}
