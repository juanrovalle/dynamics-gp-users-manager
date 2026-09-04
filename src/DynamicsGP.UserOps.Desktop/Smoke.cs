using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
namespace DynamicsGP.UserOps.Desktop;
internal static class Smoke
{
    public static async Task RunAsync(string folder,double scale=1)
    {
        Directory.CreateDirectory(folder);
        Application.Current.ShutdownMode=ShutdownMode.OnExplicitShutdown;
        var console=new MainWindow(demo:true){Width=1240,Height=1320,Left=-20000,Top=-20000,WindowStartupLocation=WindowStartupLocation.Manual,ShowInTaskbar=false};
        console.Show();
        foreach(var page in new[]{"Overview","Departments","Users","Activity","Settings"})
        {await console.NavigateAsync(page);await SaveAsync(console,Path.Combine(folder,page+".png"),scale);}
        console.Close();
        var wizard=new WizardWindow(demo:true){Width=1160,Height=1120,Left=-20000,Top=-20000,WindowStartupLocation=WindowStartupLocation.Manual,ShowInTaskbar=false};
        wizard.Show();
        for(var i=1;i<=6;i++){await wizard.RenderStepForSmokeAsync(i);await SaveAsync(wizard,Path.Combine(folder,"Setup-"+i+".png"),scale);}
        wizard.Close();File.WriteAllText(Path.Combine(folder,"result.txt"),$"PASS: 5 console screens and 6 setup steps rendered at {scale:P0} without a SQL connection.");
    }
    private static async Task SaveAsync(Window window,string path,double scale)
    {
        await window.Dispatcher.InvokeAsync(()=>{window.InvalidateVisual();window.UpdateLayout();},DispatcherPriority.Render);
        var visual=(FrameworkElement)window.Content;
        var bitmap=new RenderTargetBitmap((int)Math.Ceiling(visual.ActualWidth*scale),(int)Math.Ceiling(visual.ActualHeight*scale),96*scale,96*scale,PixelFormats.Pbgra32);
        bitmap.Render(visual);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file=File.Create(path);encoder.Save(file);
    }
}
