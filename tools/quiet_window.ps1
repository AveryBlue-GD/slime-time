# Helpers (dot-source this) for opening the game window without disturbing the user: centered
# on the right-most monitor from the very first frame, and without taking keyboard focus, so a
# borderless-fullscreen game on the other screen stays in front until the user clicks over.
#
# How: Godot's --position places the window before it's shown, and a temporary override.cfg
# (display/window/size/no_focus) makes the window open without activating. The game deletes
# that file as soon as it starts and turns focus back on (Progress, --quiet-window), so the
# window is clickable as normal; Remove-NoFocus also cleans it up when the run ends.

$QuietRoot = Split-Path $PSScriptRoot -Parent
$QuietOverride = Join-Path $QuietRoot "override.cfg"

# Godot's console binary (same lookup as godot.ps1).
function Get-GodotExe {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $godot) { throw "Godot console executable not found. Install with: winget install GodotEngine.GodotEngine" }
    return $godot.FullName
}

# --position args that center a window of the given size on the right-most monitor. Reads the
# monitors in physical pixels (DPI aware), which is how Godot measures them.
function Get-RightScreenArgs([int]$Width = 1280, [int]$Height = 720) {
    if (-not ("QuietDpi" -as [type])) {
        Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class QuietDpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }'
    }
    [QuietDpi]::SetProcessDPIAware() | Out-Null
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.X } -Descending | Select-Object -First 1
    $area = $screen.WorkingArea
    $x = $area.X + [math]::Max(0, [int](($area.Width - $Width) / 2))
    $y = $area.Y + [math]::Max(0, [int](($area.Height - $Height) / 2))
    return @("--position", "$x,$y")
}

function Set-NoFocus {
    Set-Content -Path $QuietOverride -Value "[display]`n`nwindow/size/no_focus=true" -Encoding ascii
}

function Remove-NoFocus {
    Remove-Item $QuietOverride -ErrorAction SilentlyContinue
}
