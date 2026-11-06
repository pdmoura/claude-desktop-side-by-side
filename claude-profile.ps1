<#
.SYNOPSIS
  Run several Claude Desktop accounts side by side on Windows, each in its own
  window with its own colored icon (desktop, Start menu and taskbar).

.DESCRIPTION
  Unofficial community workaround - not affiliated with or supported by Anthropic.
  Each profile is a separate Claude Desktop instance with its own data folder
  (login, settings, history), started with Electron's --user-data-dir switch.
  Your normal Claude Desktop keeps working as before.

.EXAMPLE
  # One-time setup of a profile called "Work" with a blue icon
  powershell -ExecutionPolicy Bypass -File .\claude-profile.ps1 -Install -Name Work -Color blue

.EXAMPLE
  # Same, plus a "claude-work" command for Claude Code in the terminal (own login and
  # conversations) and the claude-sync command
  powershell -ExecutionPolicy Bypass -File .\claude-profile.ps1 -Install -Name Work -Color blue -Cli

.EXAMPLE
  # Launch it (the shortcuts do this for you)
  powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1" -Name Work

.EXAMPLE
  # Hand a claude:// sign-in link to the "Work" window instead of the main app
  powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1" -Name Work -OpenUrl "claude://..."

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1" -List
  powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1" -Uninstall -Name Work -RemoveData
#>
[CmdletBinding(DefaultParameterSetName = 'Launch')]
param(
  [Parameter(Mandatory = $true, ParameterSetName = 'Launch')]
  [Parameter(Mandatory = $true, ParameterSetName = 'Install')]
  [Parameter(Mandatory = $true, ParameterSetName = 'Uninstall')]
  [ValidatePattern('^[A-Za-z0-9_-]+$')]
  [string]$Name,

  [Parameter(Mandatory = $true, ParameterSetName = 'Install')][switch]$Install,
  [Parameter(ParameterSetName = 'Install')][string]$Color = 'blue',
  [Parameter(ParameterSetName = 'Install')][switch]$Cli,

  [Parameter(ParameterSetName = 'Launch')][string]$OpenUrl,

  [Parameter(Mandatory = $true, ParameterSetName = 'Uninstall')][switch]$Uninstall,
  [Parameter(ParameterSetName = 'Uninstall')][switch]$RemoveData,

  [Parameter(Mandatory = $true, ParameterSetName = 'List')][switch]$List
)

$ErrorActionPreference = 'Stop'

$Root       = Join-Path $env:LOCALAPPDATA 'ClaudeProfiles'
$ScriptCopy = Join-Path $Root 'claude-profile.ps1'
$Colors     = [ordered]@{ red = 0; orange = 25; yellow = 50; green = 140; teal = 180; blue = 210; indigo = 240; purple = 270; pink = 330 }

if ($Name) {
  $ProfileId  = "Claude-$Name"                               # data folder name
  $ProfileDir = Join-Path $Root $Name                        # icon lives here
  $IconPath   = Join-Path $ProfileDir 'icon.ico'
  $DataDir    = Join-Path $env:APPDATA $ProfileId
  $AppId      = "ClaudeProfiles.$Name"                       # taskbar identity
  $LinkName   = "Claude ($Name).lnk"
  $Links      = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) $LinkName),
    (Join-Path ([Environment]::GetFolderPath('Programs')) $LinkName)
  )
  $LaunchArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptCopy`" -Name `"$Name`""
  $CliName    = "claude-$($Name.ToLower())"                  # Claude Code (CLI) command for this account
  $CliConfig  = Join-Path $env:USERPROFILE ".claude-$($Name.ToLower())"
}
$Marker = 'Created by claude-profile.ps1 (github.com/pdmoura/claude-desktop-side-by-side)'

# Folder of the "claude" command (Claude Code CLI). Launchers go next to it, so they are on PATH already.
function Get-ClaudeCliDir {
  $cmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { Split-Path $cmd.Source }
}

function Install-CliCommand {
  $dir = Get-ClaudeCliDir
  if (-not $dir) { Write-Warning "Claude Code (the 'claude' command) isn't installed, so '$CliName' wasn't created. Install it, then run this again with -Cli."; return }
  $launcher = Join-Path $dir "$CliName.cmd"
  if ((Test-Path -LiteralPath $launcher) -and -not (Select-String -LiteralPath $launcher -SimpleMatch $Marker -Quiet)) {
    Write-Warning "$launcher already exists and wasn't created by this script, so it was left alone."; return
  }
  @(
    '@echo off'
    "rem Claude Code with the $Name account. Its login and conversations live in %USERPROFILE%\.claude-$($Name.ToLower())"
    "rem $Marker"
    'setlocal'
    "set `"CLAUDE_CONFIG_DIR=%USERPROFILE%\.claude-$($Name.ToLower())`""
    "title Claude - $Name"
    'call claude %*'
    'endlocal'
  ) | Set-Content -LiteralPath $launcher -Encoding ASCII
  New-Item -ItemType Directory -Force -Path $CliConfig | Out-Null
  Write-Host "  CLI       : $CliName  (works in PowerShell and CMD; first run asks you to log in)"
}

function Install-ClaudeSync {
  $dir = Get-ClaudeCliDir
  if (-not $dir) { return }
  $src = Join-Path $PSScriptRoot 'claude-sync.ps1'
  $dst = Join-Path $Root 'claude-sync.ps1'
  if (-not (Test-Path -LiteralPath $src)) {
    if (-not (Test-Path -LiteralPath $dst)) { Write-Host "  (claude-sync.ps1 wasn't found next to this script, so claude-sync wasn't installed.)" }
    return
  }
  if ($src -ne $dst) { Copy-Item -LiteralPath $src -Destination $dst -Force }
  $launcher = Join-Path $dir 'claude-sync.cmd'
  if ((Test-Path -LiteralPath $launcher) -and -not (Select-String -LiteralPath $launcher -SimpleMatch $Marker -Quiet)) {
    Write-Warning "$launcher already exists and wasn't created by this script, so it was left alone."; return
  }
  @(
    '@echo off'
    'rem claude-sync: pick Claude Code conversations from this folder and send them to another account'
    "rem $Marker"
    "powershell -NoProfile -ExecutionPolicy Bypass -File `"%LOCALAPPDATA%\ClaudeProfiles\claude-sync.ps1`" %*"
  ) | Set-Content -LiteralPath $launcher -Encoding ASCII
  Write-Host "  Sync      : claude-sync  (experimental, see README)"
}

function Get-Claude {
  $pkg = Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue |
         Where-Object { $_.Publisher -like '*Anthropic*' } | Select-Object -First 1
  $exe = (Get-Command 'claude-desktop.exe' -ErrorAction SilentlyContinue).Source   # Store/MSIX alias
  $iconSource = $null
  if ($pkg) {
    $png = Join-Path $pkg.InstallLocation 'assets\Square44x44Logo.targetsize-256.png'
    $iconSource = if (Test-Path $png) { $png } else { Join-Path $pkg.InstallLocation 'app\Claude.exe' }
  }
  if (-not $exe) {                                                                 # classic installer
    $exe = Get-ChildItem "$env:LOCALAPPDATA\AnthropicClaude" -Filter 'claude.exe' -Recurse -ErrorAction SilentlyContinue |
           Where-Object { $_.DirectoryName -match '\\app-[\d.]+$' } |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if ($exe) { $iconSource = $exe }
  }
  if (-not $exe) { throw 'Claude Desktop was not found. Install it from https://claude.ai/download first.' }
  [pscustomobject]@{ Exe = $exe; Package = $pkg; IconSource = $iconSource }
}

function Get-ProfileProcessIds([string]$dir) {
  $pattern = 'user-data-dir="?' + [regex]::Escape($dir) + '("|\s|$)'
  @(Get-CimInstance Win32_Process -Filter "Name='Claude.exe'" |
    Where-Object { $_.CommandLine -match $pattern } | ForEach-Object { [uint32]$_.ProcessId })
}

function Import-Native {
  if ('ClaudeProfilesNative' -as [type]) { return }
  Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class ClaudeProfilesNative {
  // ---------- recolored .ico ----------
  public static void MakeIcon(Bitmap src, double hue, string icoPath) {
    var img = new Bitmap(256, 256, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(img)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.DrawImage(src, 0, 0, 256, 256); }
    for (int y = 0; y < 256; y++) for (int x = 0; x < 256; x++) {
      Color c = img.GetPixel(x, y);
      if (c.A == 0 || c.GetSaturation() < 0.15f) continue;              // keep white/grey/transparent
      img.SetPixel(x, y, FromHsl(c.A, hue % 360, c.GetSaturation(), c.GetBrightness()));
    }
    int[] sizes = { 256, 64, 48, 32, 16 };
    var pngs = new List<byte[]>();
    foreach (int sz in sizes) {
      using (var b = new Bitmap(sz, sz, PixelFormat.Format32bppArgb)) {
        using (var g = Graphics.FromImage(b)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.DrawImage(img, 0, 0, sz, sz); }
        using (var ms = new MemoryStream()) { b.Save(ms, ImageFormat.Png); pngs.Add(ms.ToArray()); }
      }
    }
    img.Dispose();
    using (var w = new BinaryWriter(File.Create(icoPath))) {
      w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)sizes.Length);
      int off = 6 + 16 * sizes.Length;
      for (int i = 0; i < sizes.Length; i++) {
        byte d = (byte)(sizes[i] >= 256 ? 0 : sizes[i]);
        w.Write(d); w.Write(d); w.Write((byte)0); w.Write((byte)0);
        w.Write((ushort)1); w.Write((ushort)32); w.Write((uint)pngs[i].Length); w.Write((uint)off);
        off += pngs[i].Length;
      }
      foreach (var p in pngs) w.Write(p);
    }
  }
  static Color FromHsl(int a, double h, double s, double l) {
    double c = (1 - Math.Abs(2 * l - 1)) * s, hp = h / 60.0, x = c * (1 - Math.Abs(hp % 2 - 1)), m = l - c / 2, r = 0, g = 0, b = 0;
    switch (((int)Math.Floor(hp)) % 6) {
      case 0: r = c; g = x; break; case 1: r = x; g = c; break; case 2: g = c; b = x; break;
      case 3: g = x; b = c; break; case 4: r = x; b = c; break; default: r = c; b = x; break;
    }
    return Color.FromArgb(a, Clamp(r + m), Clamp(g + m), Clamp(b + m));
  }
  static int Clamp(double v) { return Math.Max(0, Math.Min(255, (int)Math.Round(v * 255))); }

  // ---------- per-window taskbar identity + icon ----------
  [StructLayout(LayoutKind.Sequential)] public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
  [StructLayout(LayoutKind.Explicit, Size = 24)] public struct PROPVARIANT { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; }
  [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPropertyStore {
    [PreserveSig] int GetCount(out uint c);
    [PreserveSig] int GetAt(uint i, out PROPERTYKEY k);
    [PreserveSig] int GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
    [PreserveSig] int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v);
    [PreserveSig] int Commit();
  }
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("shell32.dll")] static extern int SHGetPropertyStoreForWindow(IntPtr h, ref Guid iid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore ps);
  [DllImport("ole32.dll")] static extern int PropVariantClear(ref PROPVARIANT pv);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr LoadImage(IntPtr hi, string name, uint type, int cx, int cy, uint flags);
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  static readonly Guid AUM = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");

  static void SetStr(IPropertyStore ps, uint pid, string val) {
    var k = new PROPERTYKEY { fmtid = AUM, pid = pid };
    var v = new PROPVARIANT { vt = 31, p = Marshal.StringToCoTaskMemUni(val) };   // VT_LPWSTR
    ps.SetValue(ref k, ref v);
    PropVariantClear(ref v);
  }

  public static int BrandWindows(uint[] pids, string appId, string icon, string relaunchCmd, string displayName) {
    var set = new HashSet<uint>(pids);
    var wins = new List<IntPtr>();
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (set.Contains(pid) && IsWindowVisible(h) && GetWindowTextLength(h) > 0 && GetWindow(h, 4) == IntPtr.Zero) wins.Add(h);
      return true;
    }, IntPtr.Zero);
    IntPtr big   = LoadImage(IntPtr.Zero, icon, 1, GetSystemMetrics(11), GetSystemMetrics(12), 0x10);
    IntPtr small = LoadImage(IntPtr.Zero, icon, 1, GetSystemMetrics(49), GetSystemMetrics(50), 0x10);
    foreach (var h in wins) {
      Guid iid = typeof(IPropertyStore).GUID;
      IPropertyStore ps;
      if (SHGetPropertyStoreForWindow(h, ref iid, out ps) == 0) {
        SetStr(ps, 2, relaunchCmd);   // RelaunchCommand (used when pinned)
        SetStr(ps, 3, icon);          // RelaunchIconResource
        SetStr(ps, 4, displayName);   // RelaunchDisplayNameResource
        SetStr(ps, 5, appId);         // AppUserModel.ID -> own taskbar button
        ps.Commit();
        Marshal.ReleaseComObject(ps);
      }
      SendMessage(h, 0x80, (IntPtr)1, big);     // WM_SETICON big
      SendMessage(h, 0x80, IntPtr.Zero, small); // WM_SETICON small
    }
    return wins.Count;
  }
}
'@
}

function New-Shortcut([string]$path) {
  $s = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
  $s.TargetPath   = 'powershell.exe'
  $s.Arguments    = $LaunchArgs
  $s.IconLocation = $IconPath
  $s.Description  = "Claude Desktop - $Name profile"
  $s.Save()
}

switch ($PSCmdlet.ParameterSetName) {

  'Install' {
    $hue = 0.0
    if ($Colors.Contains($Color.ToLower())) { $hue = $Colors[$Color.ToLower()] }
    elseif (-not [double]::TryParse($Color, [ref]$hue)) {
      throw "Unknown color '$Color'. Use one of: $($Colors.Keys -join ', '), or a hue number from 0 to 360."
    }
    $claude = Get-Claude
    New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null
    if ($PSCommandPath -ne $ScriptCopy) { Copy-Item -LiteralPath $PSCommandPath -Destination $ScriptCopy -Force }

    Import-Native
    Add-Type -AssemblyName System.Drawing
    $src = if ($claude.IconSource -like '*.png') { New-Object System.Drawing.Bitmap $claude.IconSource }
           else { [System.Drawing.Icon]::ExtractAssociatedIcon($claude.IconSource).ToBitmap() }
    [ClaudeProfilesNative]::MakeIcon($src, $hue, $IconPath)
    $src.Dispose()

    foreach ($l in $Links) { New-Shortcut $l }
    Write-Host "Profile '$Name' installed."
    Write-Host "  Shortcuts : $($Links -join "`n              ")"
    Write-Host "  Data      : $DataDir$(if ($claude.Package) { "  (Store app: redirected to %LOCALAPPDATA%\Packages\$($claude.Package.PackageFamilyName)\LocalCache\Roaming\$ProfileId)" })"
    if ($Cli) { Install-CliCommand; Install-ClaudeSync }
    Write-Host "Open it from the shortcut and sign in with 'Continue with email' (see README)."
  }

  'Launch' {
    $claude = Get-Claude
    $argList = @("--user-data-dir=`"$DataDir`"")
    if ($OpenUrl) { $argList += "`"$OpenUrl`"" }
    Start-Process -FilePath $claude.Exe -ArgumentList $argList

    if (-not (Test-Path $IconPath)) { return }                 # not installed: plain launch, no branding
    Import-Native
    $relaunch = "powershell.exe $LaunchArgs"
    $pids = @()
    for ($i = 0; $i -lt 45; $i++) {                             # wait up to ~90 s for the window
      Start-Sleep -Seconds 2
      $pids = Get-ProfileProcessIds $DataDir
      if ($pids.Count -and [ClaudeProfilesNative]::BrandWindows($pids, $AppId, $IconPath, $relaunch, "Claude ($Name)") -gt 0) { break }
    }
    Start-Sleep -Seconds 6                                      # second pass in case the main window replaced a splash
    if ($pids.Count) { [void][ClaudeProfilesNative]::BrandWindows($pids, $AppId, $IconPath, $relaunch, "Claude ($Name)") }
  }

  'Uninstall' {
    if ((Get-ProfileProcessIds $DataDir).Count) { throw "Close the Claude ($Name) window first (also quit it from the system tray)." }
    foreach ($l in $Links) { Remove-Item -LiteralPath $l -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $ProfileDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed shortcuts and icon for '$Name'."
    $cliDir = Get-ClaudeCliDir
    if ($cliDir) {
      $launcher = Join-Path $cliDir "$CliName.cmd"
      if ((Test-Path -LiteralPath $launcher) -and (Select-String -LiteralPath $launcher -SimpleMatch $Marker -Quiet)) {
        Remove-Item -LiteralPath $launcher -Force
        Write-Host "Removed the '$CliName' command. Its Claude Code login and conversations are kept in $CliConfig (delete that folder yourself if you want)."
      }
    }
    if ($RemoveData) {
      $targets = @($DataDir)
      $pkg = (Get-Claude).Package
      if ($pkg) {
        $cache = Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)\LocalCache"
        $targets += (Join-Path $cache "Roaming\$ProfileId"), (Join-Path $cache "Local\$ProfileId")
      }
      foreach ($t in $targets) { if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Recurse -Force; Write-Host "Deleted $t" } }
    } else {
      Write-Host "Login data kept (re-install with the same name to reuse it, or add -RemoveData to delete it)."
    }
  }

  'List' {
    if (-not (Test-Path $Root)) { Write-Host 'No profiles installed.'; return }
    $cliDir = Get-ClaudeCliDir
    Get-ChildItem -LiteralPath $Root -Directory | ForEach-Object {
      $dir = Join-Path $env:APPDATA "Claude-$($_.Name)"
      $cmd = "claude-$($_.Name.ToLower())"
      [pscustomobject]@{
        Profile = $_.Name
        Running = [bool](Get-ProfileProcessIds $dir).Count
        CLI     = if ($cliDir -and (Test-Path -LiteralPath (Join-Path $cliDir "$cmd.cmd"))) { $cmd } else { '-' }
      }
    } | Format-Table -AutoSize
  }
}
