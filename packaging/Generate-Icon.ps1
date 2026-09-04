[CmdletBinding()]
param([string]$Output)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(-not $Output){$Output=Join-Path $root 'assets/DynamicsGPUserOps.ico'}
Add-Type -AssemblyName System.Drawing

function New-RoundedPath([float]$Size,[float]$Radius)
{
    $path=[System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter=$Radius*2
    $path.AddArc(0,0,$diameter,$diameter,180,90)
    $path.AddArc($Size-$diameter,0,$diameter,$diameter,270,90)
    $path.AddArc($Size-$diameter,$Size-$diameter,$diameter,$diameter,0,90)
    $path.AddArc(0,$Size-$diameter,$diameter,$diameter,90,90)
    $path.CloseFigure()
    return $path
}

$images=@()
try
{
    foreach($size in @(16,32,48,256))
    {
        $bitmap=[System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
        try
        {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
            $path=New-RoundedPath $size ($size*0.19);$navy=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(16,42,67))
            try{$graphics.FillPath($navy,$path)}finally{$navy.Dispose();$path.Dispose()}
            $rail=[System.Drawing.RectangleF]::new($size*0.105,$size*0.11,[Math]::Max(1,$size*0.052),$size*0.78)
            $blue=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(23,105,224));try{$graphics.FillRectangle($blue,$rail)}finally{$blue.Dispose()}
            $font=[System.Drawing.Font]::new('Segoe UI Semibold',$size*0.34,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
            try{$graphics.DrawString('UO',$font,[System.Drawing.Brushes]::White,[System.Drawing.PointF]::new($size*0.25,$size*0.31))}finally{$font.Dispose()}
            $stream=[System.IO.MemoryStream]::new();$bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
            $images+=,[pscustomobject]@{Size=$size;Bytes=$stream.ToArray()};$stream.Dispose()
        }
        finally{$graphics.Dispose();$bitmap.Dispose()}
    }
    $directory=Split-Path $Output -Parent;if($directory){[System.IO.Directory]::CreateDirectory($directory)|Out-Null}
    $file=[System.IO.File]::Create($Output);$writer=[System.IO.BinaryWriter]::new($file)
    try
    {
        $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$images.Count)
        $offset=6+16*$images.Count
        foreach($image in $images)
        {
            $sizeByte=if($image.Size -eq 256){[byte]0}else{[byte]$image.Size}
            $writer.Write($sizeByte);$writer.Write($sizeByte)
            $writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([uint16]1);$writer.Write([uint16]32)
            $writer.Write([uint32]$image.Bytes.Length);$writer.Write([uint32]$offset);$offset+=$image.Bytes.Length
        }
        foreach($image in $images){$writer.Write($image.Bytes)}
    }
    finally{$writer.Dispose();$file.Dispose()}
}
finally{ }
Write-Output "Generated icon: $Output"
