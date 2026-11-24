param([string]$proc = "craft-anything", [int]$procid = 0, [string]$text = "", [string]$action, [string]$out = "", [int]$x1 = 0, [int]$y1 = 0, [int]$x2 = 0, [int]$y2 = 0, [string]$key = "")
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;using System.Runtime.InteropServices;
public class G{
[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT r);
[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);
[DllImport("user32.dll")]public static extern bool IsIconic(IntPtr h);
[DllImport("user32.dll")]public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int hh,bool r);
[DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
[DllImport("user32.dll")]public static extern void mouse_event(int f,int x,int y,int d,int e);
[DllImport("user32.dll")]public static extern void keybd_event(byte k,byte s,int f,int e);
public struct RECT{public int L,T,R,B;}}
"@
[G]::SetProcessDPIAware() | Out-Null
$p = if ($procid) { Get-Process -Id $procid -ErrorAction SilentlyContinue } else { Get-Process $proc -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending }
$p = $p | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "no window"; exit 1 }
$h = $p.MainWindowHandle
if ([G]::IsIconic($h)) { [G]::ShowWindow($h, 9) | Out-Null; Start-Sleep -Milliseconds 800 }
[G]::keybd_event(0x12,0,0,0); [G]::keybd_event(0x12,0,2,0)
[G]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
if ([G]::GetForegroundWindow() -ne $h) { Write-Output "not in front, refusing to click"; exit 2 }
$r = New-Object G+RECT; [G]::GetWindowRect($h, [ref]$r) | Out-Null
switch ($action) {
  "rclick" { [G]::SetCursorPos($r.L + $x1, $r.T + $y1) | Out-Null; Start-Sleep -Milliseconds 150; [G]::mouse_event(8,0,0,0,0); Start-Sleep -Milliseconds 80; [G]::mouse_event(16,0,0,0,0); Start-Sleep -Milliseconds 400 }
  "move" { [G]::ShowWindow($h, 9) | Out-Null; Start-Sleep -Milliseconds 300; [G]::MoveWindow($h, $x1, $y1, $x2, $y2, $true) | Out-Null; Start-Sleep -Milliseconds 800 }
  "info" {
    $wa = [System.Windows.Forms.Screen]::FromHandle($h).WorkingArea
    $b = [System.Windows.Forms.Screen]::FromHandle($h).Bounds
    Write-Output "window $($r.L),$($r.T) $($r.R - $r.L)x$($r.B - $r.T); work area $($wa.X),$($wa.Y) $($wa.Width)x$($wa.Height); screen $($b.Width)x$($b.Height)"
  }
  "click" {
    [G]::SetCursorPos($r.L + $x1, $r.T + $y1) | Out-Null; Start-Sleep -Milliseconds 150
    [G]::mouse_event(2,0,0,0,0); Start-Sleep -Milliseconds 80; [G]::mouse_event(4,0,0,0,0); Start-Sleep -Milliseconds 400
  }
  "drag" {
    [G]::SetCursorPos($r.L + $x1, $r.T + $y1) | Out-Null; Start-Sleep -Milliseconds 150
    [G]::mouse_event(2,0,0,0,0); Start-Sleep -Milliseconds 120
    for ($i = 1; $i -le 20; $i++) {
      [G]::SetCursorPos($r.L + $x1 + ($x2 - $x1) * $i / 20, $r.T + $y1 + ($y2 - $y1) * $i / 20) | Out-Null; Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 150; [G]::mouse_event(4,0,0,0,0); Start-Sleep -Milliseconds 700
  }
  "paste" { Set-Clipboard -Value $text; [G]::SetCursorPos($r.L + $x1, $r.T + $y1) | Out-Null; [G]::mouse_event(2,0,0,0,0); [G]::mouse_event(4,0,0,0,0); Start-Sleep -Milliseconds 200; [G]::keybd_event(0x11,0,0,0); [G]::keybd_event(0x41,0,0,0); [G]::keybd_event(0x41,0,2,0); [G]::keybd_event(0x56,0,0,0); [G]::keybd_event(0x56,0,2,0); [G]::keybd_event(0x11,0,2,0); Start-Sleep -Milliseconds 300 }
  "key" {
    [G]::SetCursorPos($r.L + 900, $r.T + 300) | Out-Null
    $vk = [byte][int]$key
    [G]::keybd_event($vk,0,0,0); Start-Sleep -Milliseconds 60; [G]::keybd_event($vk,0,2,0); Start-Sleep -Milliseconds 200
  }
}
if ($out -ne "") {
  [G]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = $r.R - $r.L; $hh = $r.B - $r.T
  $bmp = New-Object System.Drawing.Bitmap $w, $hh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $bmp.Save($out)
  Write-Output "saved $w x $hh"
}
