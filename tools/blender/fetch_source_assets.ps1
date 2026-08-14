param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PSScriptRoot 'asset_manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$destination = Join-Path $ProjectRoot 'assets\source\textures\polyhaven\rough_block_wall'
New-Item -ItemType Directory -Force -Path $destination | Out-Null

foreach ($source in $manifest.source_assets) {
    foreach ($file in $source.files) {
        $target = Join-Path $destination $file.name
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
        Write-Host "Verified $($file.name)"
    }
}

Write-Host 'Source textures are present and checksum-verified.'
