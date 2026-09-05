[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$SourceDirectory,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../.github/media'),
    [ValidateRange(2, 4)]
    [int]$FrameSeconds = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

$slides = @(
    @{ File = 'Setup-1.png'; Caption = 'Connect to the Dynamics GP system database' },
    @{ File = 'Setup-2.png'; Caption = 'Verify SQL Server, Agent, permissions, and schema compatibility' },
    @{ File = 'Setup-4.png'; Caption = 'Configure departments, quotas, users, and operator identities' },
    @{ File = 'Setup-5.png'; Caption = 'Preview candidates and validate a native GP message' },
    @{ File = 'Setup-6.png'; Caption = 'Review the policy and explicitly activate automation' },
    @{ File = 'Overview.png'; Caption = 'Monitor capacity, exceptions, automation, and recent execution' },
    @{ File = 'Departments.png'; Caption = 'Manage departmental capacity without writing SQL' },
    @{ File = 'Users.png'; Caption = 'Assign existing Dynamics GP users to departments' },
    @{ File = 'Activity.png'; Caption = 'Audit removals, blocked operations, errors, and queued messages' },
    @{ File = 'Settings.png'; Caption = 'Control policies and export password-free diagnostics' }
)

$canvasWidth = 960
$canvasHeight = 900
$imageMargin = 20
$captionHeight = 64
$imageAreaHeight = $canvasHeight - $captionHeight - ($imageMargin * 2)

function New-PropertyItem {
    param([int]$Id, [short]$Type, [byte[]]$Value)
    $item = [System.Runtime.CompilerServices.RuntimeHelpers]::GetUninitializedObject(
        [System.Drawing.Imaging.PropertyItem]
    )
    $item.Id = $Id
    $item.Type = $Type
    $item.Len = $Value.Length
    $item.Value = $Value
    return $item
}

function New-DemoFrame {
    param([string]$Path, [string]$Caption)

    $source = [System.Drawing.Image]::FromFile($Path)
    try {
        $frame = [System.Drawing.Bitmap]::new(
            $canvasWidth,
            $canvasHeight,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($frame)
        try {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F4F7FA'))
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

            $scale = [Math]::Min(
                ($canvasWidth - ($imageMargin * 2)) / $source.Width,
                $imageAreaHeight / $source.Height
            )
            $width = [int][Math]::Round($source.Width * $scale)
            $height = [int][Math]::Round($source.Height * $scale)
            $x = [int](($canvasWidth - $width) / 2)
            $y = $imageMargin + [int](($imageAreaHeight - $height) / 2)
            $graphics.DrawImage($source, $x, $y, $width, $height)

            $captionY = $canvasHeight - $captionHeight
            $navy = [System.Drawing.SolidBrush]::new(
                [System.Drawing.ColorTranslator]::FromHtml('#102A43')
            )
            $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
            $font = [System.Drawing.Font]::new('Segoe UI', 16, [System.Drawing.FontStyle]::Regular)
            try {
                $graphics.FillRectangle($navy, 0, $captionY, $canvasWidth, $captionHeight)
                $format = [System.Drawing.StringFormat]::new()
                try {
                    $format.Alignment = [System.Drawing.StringAlignment]::Center
                    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
                    $graphics.DrawString(
                        $Caption,
                        $font,
                        $white,
                        [System.Drawing.RectangleF]::new(20, $captionY, $canvasWidth - 40, $captionHeight),
                        $format
                    )
                }
                finally {
                    $format.Dispose()
                }
            }
            finally {
                $font.Dispose()
                $white.Dispose()
                $navy.Dispose()
            }
        }
        finally {
            $graphics.Dispose()
        }
        return $frame
    }
    finally {
        $source.Dispose()
    }
}

$resolvedSource = (Resolve-Path -LiteralPath $SourceDirectory).Path
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null

$frames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
try {
    foreach ($slide in $slides) {
        $path = Join-Path $resolvedSource $slide.File
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Missing demo screenshot: $path"
        }
        $frames.Add((New-DemoFrame -Path $path -Caption $slide.Caption))
    }

    $delay = [byte[]]::new($frames.Count * 4)
    for ($index = 0; $index -lt $frames.Count; $index++) {
        [BitConverter]::GetBytes($FrameSeconds * 100).CopyTo($delay, $index * 4)
    }
    $frames[0].SetPropertyItem((New-PropertyItem -Id 0x5100 -Type 4 -Value $delay))
    $frames[0].SetPropertyItem((New-PropertyItem -Id 0x5101 -Type 3 -Value ([byte[]](0, 0))))

    $gifCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object MimeType -eq 'image/gif' |
        Select-Object -First 1
    if ($null -eq $gifCodec) { throw 'The GIF encoder is not available.' }

    $saveParameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
    try {
        $saveParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
            [System.Drawing.Imaging.Encoder]::SaveFlag,
            [long][System.Drawing.Imaging.EncoderValue]::MultiFrame
        )
        $gifPath = Join-Path $resolvedOutput 'product-tour.gif'
        $frames[0].Save($gifPath, $gifCodec, $saveParameters)

        $saveParameters.Param[0].Dispose()
        $saveParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
            [System.Drawing.Imaging.Encoder]::SaveFlag,
            [long][System.Drawing.Imaging.EncoderValue]::FrameDimensionTime
        )
        for ($index = 1; $index -lt $frames.Count; $index++) {
            $frames[0].SaveAdd($frames[$index], $saveParameters)
        }

        $saveParameters.Param[0].Dispose()
        $saveParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
            [System.Drawing.Imaging.Encoder]::SaveFlag,
            [long][System.Drawing.Imaging.EncoderValue]::Flush
        )
        $frames[0].SaveAdd($saveParameters)
    }
    finally {
        $saveParameters.Dispose()
    }

    $gallery = @{
        'Overview.png' = 'overview.png'
        'Departments.png' = 'departments.png'
        'Users.png' = 'users.png'
        'Activity.png' = 'activity.png'
    }
    foreach ($entry in $gallery.GetEnumerator()) {
        Copy-Item -LiteralPath (Join-Path $resolvedSource $entry.Key) `
            -Destination (Join-Path $resolvedOutput $entry.Value) -Force
    }

    $duration = $frames.Count * $FrameSeconds
    Write-Output "README media generated in $resolvedOutput ($duration-second GIF)."
}
finally {
    foreach ($frame in $frames) { $frame.Dispose() }
}
