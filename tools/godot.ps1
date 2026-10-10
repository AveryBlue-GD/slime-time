# Runs the Godot console binary installed by winget, passing all arguments through.
# Example: .\tools\godot.ps1 --path . --headless --quit
$godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $godot) { Write-Error "Godot console executable not found. Install with: winget install GodotEngine.GodotEngine"; exit 1 }
& $godot.FullName @args
exit $LASTEXITCODE
