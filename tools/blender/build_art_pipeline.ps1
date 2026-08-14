param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$BlenderPath = '',
    [string]$GodotPath = ''
)

$ErrorActionPreference = 'Stop'

if (-not $BlenderPath) {
    $command = Get-Command blender -ErrorAction SilentlyContinue
    if ($command) {
        $BlenderPath = $command.Source
    } else {
        $candidates = @(
            'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
            'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe',
            'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe'
        )
        $BlenderPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
}

if (-not $BlenderPath -or -not (Test-Path -LiteralPath $BlenderPath)) {
    throw 'Blender 4.5+ was not found. Pass -BlenderPath with an absolute blender.exe path.'
}

& (Join-Path $PSScriptRoot 'fetch_source_assets.ps1') -ProjectRoot $ProjectRoot

$builder = Join-Path $PSScriptRoot 'build_environment_kit.py'
& $BlenderPath --background --factory-startup --python-exit-code 1 --python $builder
if ($LASTEXITCODE -ne 0) { throw "Blender asset build failed with exit code $LASTEXITCODE." }

if (-not $GodotPath) {
    $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        $GodotPath = $command.Source
    } else {
        $candidates = @(
            (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'),
            (Join-Path $env:LOCALAPPDATA 'Temp\skyroll-godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe')
        )
        $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
}

if ($GodotPath -and (Test-Path -LiteralPath $GodotPath)) {
    & $GodotPath --headless --path $ProjectRoot --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
    & $GodotPath --headless --path $ProjectRoot -s res://tests/test_runner.gd
    if ($LASTEXITCODE -ne 0) { throw 'Godot validation tests failed.' }
} else {
    Write-Warning 'Godot was not found. GLB files were built, but Godot import/tests were skipped.'
}

Write-Host 'Skyroll art pipeline completed successfully.'
