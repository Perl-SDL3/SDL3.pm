<#
.SYNOPSIS
Captures PNG screenshots and/or animated GIF/MP4 clips of an SDL3.pm demo window on Windows.

.DESCRIPTION
Launches the given demo, waits for its window to appear, then captures frames
using the Win32 PrintWindow API (PW_RENDERFULLCONTENT). This asks the window
itself to render into a bitmap, so it captures hardware-accelerated
(flip-model D3D/Vulkan) windows that ffmpeg's gdigrab sees as black.

Frames are encoded with ffmpeg (must be on PATH) into a PNG screenshot and/or
an animated GIF / MP4.

.PARAMETER Demo
Path to the demo script, relative to the repo root or absolute (e.g. eg/games/meteors.pl).

.PARAMETER Title
Window title to capture. If omitted it is auto-detected from the first literal
SDL_CreateWindow(...) call in the demo source.

.PARAMETER Seconds
Capture duration in seconds (default 5).

.PARAMETER Fps
Frames captured per second (default 10).

.PARAMETER OutDir
Where outputs are written (default <repo>/screenshots).

.PARAMETER Name
Output base name (default: the demo filename without extension).

.PARAMETER Png / Gif / Mp4
Which outputs to produce. If none given, a PNG screenshot is written.

.PARAMETER KeepFrames
Keep the raw BMP frame sequence instead of deleting it after encoding.

.PARAMETER WarmupMs
Delay after the window appears before capture starts (default 1500).

.EXAMPLE
    pwsh tools/capture.ps1 -Demo eg/games/meteors.pl -Seconds 8 -Gif -Mp4

.EXAMPLE
    pwsh tools/capture.ps1 -Demo eg/basics/matrix.pl -Title 'Just Another Perl Matrix,' -Seconds 6 -Gif
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Demo,
    [string]$Title,
    [double]$Seconds = 5,
    [int]$Fps = 10,
    [string]$OutDir,
    [string]$Name,
    [switch]$Png,
    [switch]$Gif,
    [switch]$Mp4,
    [switch]$KeepFrames,
    [int]$WarmupMs = 1500,
    [int]$LaunchTimeoutMs = 15000,
    [string]$Perl = 'perl',
    [string]$Lib
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths -------------------------------------------------------
$Root    = Split-Path -Parent $PSScriptRoot
if (-not $Lib) { $Lib = Join-Path $Root 'lib' }
$DemoFull = if ([IO.Path]::IsPathRooted($Demo)) { $Demo } else { Join-Path $Root $Demo }
if (-not (Test-Path -LiteralPath $DemoFull)) { throw "Demo not found: $DemoFull" }

if (-not $OutDir) { $OutDir = Join-Path $Root 'screenshots' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $Name) { $Name = [IO.Path]::GetFileNameWithoutExtension($Demo) }

# --- Window title: explicit or auto-detected -----------------------------
if (-not $Title) {
    $src = Get-Content -Raw -LiteralPath $DemoFull
    if ($src -match 'SDL_CreateWindow\s*\(\s*("[^"]+"|\x27[^\x27]+\x27)') {
        $Title = $Matches[1].Trim('"', "'")
    }
    if (-not $Title -or $Title -match '\$') {
        throw "Could not auto-detect a literal window title in $Demo. Pass -Title explicitly."
    }
}
Write-Host "Demo   : $DemoFull"
Write-Host "Title  : $Title"
Write-Host "Capture: $Seconds s at ${Fps} fps"

# --- Win32 GDI capture (pure P/Invoke, no System.Drawing) ----------------
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class PW {
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t);
  public static IntPtr FindByTitle(string title) { return FindWindow(null, title); }
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
  [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
  [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr hdc, ref BITMAPINFO bmi, uint usage, out IntPtr bits, IntPtr hSection, uint offset);
  [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
  [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct BITMAPINFOHEADER { public uint biSize; public int biWidth; public int biHeight; public ushort biPlanes; public ushort biBitCount; public uint biCompression; public uint biSizeImage; public int biXPelsPerMeter; public int biYPelsPerMeter; public uint biClrUsed; public uint biClrImportant; }
  [StructLayout(LayoutKind.Sequential)] public struct BITMAPINFO { public BITMAPINFOHEADER bmiHeader; public uint bmiColors; }
  const uint PW_RENDERFULLCONTENT = 2;
  const uint BI_RGB = 0;
  public static string CaptureFile(string title, string path) {
    IntPtr h = FindWindow(null, title);
    if (h == IntPtr.Zero) return "WINDOW NOT FOUND";
    RECT r; GetWindowRect(h, out r);
    int w = r.R - r.L, ht = r.B - r.T;
    if (w <= 0 || ht <= 0) return "BAD RECT " + w + "x" + ht;
    IntPtr dc = CreateCompatibleDC(IntPtr.Zero);
    BITMAPINFO bi = new BITMAPINFO();
    bi.bmiHeader.biSize = (uint)Marshal.SizeOf(typeof(BITMAPINFOHEADER));
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -ht; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    IntPtr bits;
    IntPtr dib = CreateDIBSection(dc, ref bi, 0, out bits, IntPtr.Zero, 0);
    SelectObject(dc, dib);
    bool ok = PrintWindow(h, dc, PW_RENDERFULLCONTENT);
    if (!ok) { DeleteObject(dib); DeleteDC(dc); return "PRINTWINDOW FAILED"; }
    byte[] bytes = new byte[w * ht * 4];
    Marshal.Copy(bits, bytes, 0, bytes.Length);
    DeleteObject(dib); DeleteDC(dc);
    System.IO.File.WriteAllBytes(path, MakeBmp(bytes, w, ht));
    return "OK";
  }
  public static bool IsBlack(string path) {
    try {
      byte[] b = System.IO.File.ReadAllBytes(path);
      if (b.Length <= 54) return true;
      int px = b.Length - 54, dark = 0;
      for (int i = 54; i < b.Length; i++) if (b[i] == 0) dark++;
      return (dark * 100 / Math.Max(1, px)) >= 99;
    } catch { return true; }
  }
  static byte[] MakeBmp(byte[] px, int w, int ht) {
    int rowSize = w * 4;
    int dataSize = rowSize * ht; // 32bpp rows are always 4-byte aligned
    var b = new byte[54 + dataSize];
    b[0] = (byte)'B'; b[1] = (byte)'M';
    BitConverter.GetBytes(54 + dataSize).CopyTo(b, 2);
    BitConverter.GetBytes(54).CopyTo(b, 10);
    b[14] = 40;
    BitConverter.GetBytes(w).CopyTo(b, 18);
    BitConverter.GetBytes(-ht).CopyTo(b, 22); // top-down, matches the DIB
    b[26] = 1; b[28] = 32;
    BitConverter.GetBytes(dataSize).CopyTo(b, 34);
    Array.Copy(px, 0, b, 54, dataSize);
    return b;
  }
}
'@

# --- Launch the demo ------------------------------------------------------
$argLine = '-I "' + $Lib + '" "' + $DemoFull + '"'
Write-Host "Launching: $Perl $argLine"
$proc = Start-Process -FilePath $Perl -ArgumentList $argLine -WorkingDirectory $Root -PassThru

try {
    # --- wait for the window ---------------------------------------------
    $hwnd = [PW]::FindByTitle($Title)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($LaunchTimeoutMs)
    while ($hwnd -eq [IntPtr]::Zero -and [DateTime]::UtcNow -lt $deadline -and -not $proc.HasExited) {
        Start-Sleep -Milliseconds 200
        $hwnd = [PW]::FindByTitle($Title)
    }
    if ($hwnd -eq [IntPtr]::Zero) {
        if ($proc.HasExited) { throw "Demo exited early (code $($proc.ExitCode)) before its window appeared." }
        throw "Window '$Title' did not appear within ${LaunchTimeoutMs} ms."
    }
    Write-Host "Window found (hwnd $hwnd). Warming up ${WarmupMs} ms..."
    Start-Sleep -Milliseconds $WarmupMs

    # --- capture frames --------------------------------------------------
    $framesDir = Join-Path $env:TEMP ("capture_" + $Name + "_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $framesDir | Out-Null
    $n        = [int][Math]::Ceiling($Seconds * $Fps)
    $interval = [int](1000 / $Fps)
    for ($i = 0; $i -lt $n; $i++) {
        $bmp = Join-Path $framesDir ("frame.{0:D4}.bmp" -f $i)
        $res = [PW]::CaptureFile($Title, $bmp)
        if ($res -ne 'OK') { throw "Capture failed on frame $i : $res" }
        if ($i -lt $n - 1) { Start-Sleep -Milliseconds $interval }
    }
    Write-Host "Captured $n frames."

    $first = Join-Path $framesDir ('frame.{0:D4}.bmp' -f 0)
    if ([PW]::IsBlack($first)) {
        Write-Warning "First frame is all black - the window may be minimized or not rendering. Outputs may be useless."
    }

    # --- encode with ffmpeg ----------------------------------------------
    $pattern = Join-Path $framesDir 'frame.%04d.bmp'
    $outBase = Join-Path $OutDir $Name
    $want    = @()
    if ($Png) { $want += 'png' }
    if ($Gif) { $want += 'gif' }
    if ($Mp4) { $want += 'mp4' }
    if ($want.Count -eq 0) { $want = @('png') }

    foreach ($fmt in $want) {
        switch ($fmt) {
            'png' {
                & ffmpeg -y -loglevel error -i $pattern -frames:v 1 "$outBase.png"
                if ($LASTEXITCODE -ne 0) { throw "ffmpeg PNG encode failed (exit $LASTEXITCODE)" }
            }
            'gif' {
                & ffmpeg -y -loglevel error -framerate $Fps -i $pattern `
                    -vf "fps=12,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5" `
                    "$outBase.gif"
                if ($LASTEXITCODE -ne 0) { throw "ffmpeg GIF encode failed (exit $LASTEXITCODE)" }
            }
            'mp4' {
                & ffmpeg -y -loglevel error -framerate $Fps -i $pattern `
                    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" `
                    -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$outBase.mp4"
                if ($LASTEXITCODE -ne 0) { throw "ffmpeg MP4 encode failed (exit $LASTEXITCODE)" }
            }
        }
        Write-Host "Wrote $outBase.$fmt"
    }

    if ($KeepFrames) {
        Write-Host "Frames kept in $framesDir"
    }
    else {
        Remove-Item -Recurse -Force $framesDir
    }
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Write-Host 'Stopped demo.'
    }
}
