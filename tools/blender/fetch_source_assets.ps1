param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PSScriptRoot 'asset_manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
foreach ($source in $manifest.source_assets) {
    $relativeDestination = if ($source.destination) {
        [string]$source.destination
    } else {
        'assets\source\textures\polyhaven\rough_block_wall'
    }
    $destination = Join-Path $ProjectRoot $relativeDestination
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    foreach ($file in $source.files) {
        $target = Join-Path $destination ([string]$file.name)
        $targetDirectory = Split-Path -Parent $target
        New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
        $valid = $false
        if (Test-Path -LiteralPath $target) {
            $actual = (Get-FileHash -LiteralPath $target -Algorithm MD5).Hash.ToLowerInvariant()
            $valid = $actual -eq $file.md5.ToLowerInvariant()
        }
        if (-not $valid) {
            Write-Host "Downloading $($file.name) from $($source.provider)..."
            Invoke-WebRequest -Uri $file.url -OutFile $target -Headers @{ 'User-Agent' = 'ProjectSkyroll-Pipeline/1.0' }
            $actual = (Get-FileHash -LiteralPath $target -Algorithm MD5).Hash.ToLowerInvariant()
            if ($actual -ne $file.md5.ToLowerInvariant()) {
                throw "Checksum mismatch for $target (expected $($file.md5), got $actual)"
            }
        }
        Write-Host "Verified $($source.id)/$($file.name)"
    }
}

Write-Host 'Source textures are present and checksum-verified.'
