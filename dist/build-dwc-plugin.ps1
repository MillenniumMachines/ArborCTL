<#
.SYNOPSIS
    Build the ArborCTL DuetWebControl plugin ZIP.

.DESCRIPTION
    Stages the ArborCTL system / macro files into the DWC plugin layout
    (plugin.json + dwc-src/ + sd/...) and invokes DuetWebControl's
    scripts/build-plugin-pkg.js to produce an installable DWC plugin ZIP.

    The resulting ZIP is copied into ArborCTL/dist/.

.PARAMETER DwcRepo
    Path to the DuetWebControl source tree (must have node_modules
    installed). Defaults to C:\Users\jonat\Downloads\DuetWebControl-3.6.1.

.PARAMETER Version
    Optional version string to embed into plugin.json and all .g files.
    Defaults to the output of `git describe` (falling back to "dev").

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\dist\build-dwc-plugin.ps1
#>

[CmdletBinding()]
param(
    [string]$DwcRepo = 'C:\Users\jonat\Downloads\DuetWebControl-3.6.1',
    [string]$Version
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$PluginSrc = Join-Path $RepoRoot 'dwc-plugin'
$DistDir  = Join-Path $RepoRoot 'dist'

if (-not (Test-Path $PluginSrc)) {
    throw "Plugin source not found at $PluginSrc"
}

if (-not (Test-Path $DwcRepo)) {
    throw "DuetWebControl repo not found at $DwcRepo"
}

$DwcRepo = (Resolve-Path $DwcRepo).Path

if (-not (Test-Path (Join-Path $DwcRepo 'node_modules'))) {
    throw "node_modules not found in $DwcRepo - run 'npm install' there first"
}

if (-not $Version) {
    try {
        Push-Location $RepoRoot
        $raw = (& git describe --tags --exclude 'release-*' --always --dirty 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            $Version = 'dev'
        } else {
            $Version = ($raw.Trim()) -replace '^v', ''
        }
    } finally {
        Pop-Location
    }
}

Write-Host "Building ArborCTL DWC plugin version '$Version'" -ForegroundColor Cyan
Write-Host "Using DWC repo at: $DwcRepo"

# Create staging directory
$Staging = Join-Path ([System.IO.Path]::GetTempPath()) ("arborctl-dwc-" + [System.Guid]::NewGuid().ToString('N'))
Write-Verbose "Staging at $Staging"
New-Item -ItemType Directory -Path $Staging | Out-Null

try {
    # 1) Copy plugin skeleton (plugin.json, dwc-src/)
    Copy-Item -Path (Join-Path $PluginSrc '*') -Destination $Staging -Recurse -Force

    # 2) Stage SD layout that mirrors ArborCTL's release.sh mapping
    $Sd = Join-Path $Staging 'sd'
    $SdSys = Join-Path $Sd 'sys'
    $SdArbor = Join-Path $SdSys 'arborctl'
    $SdMacros = Join-Path $Sd 'macros\ArborCtl'
    New-Item -ItemType Directory -Path $SdSys, $SdArbor, $SdMacros -Force | Out-Null

    # sys/* -> sd/sys/
    Copy-Item -Path (Join-Path $RepoRoot 'sys\*') -Destination $SdSys -Recurse -Force

    # macro/gcodes/* -> sd/sys/
    Copy-Item -Path (Join-Path $RepoRoot 'macro\gcodes\*') -Destination $SdSys -Recurse -Force

    # macro/private/* -> sd/sys/arborctl/
    Copy-Item -Path (Join-Path $RepoRoot 'macro\private\*') -Destination $SdArbor -Recurse -Force

    # macro/public/* -> sd/macros/ArborCtl/
    Copy-Item -Path (Join-Path $RepoRoot 'macro\public\*') -Destination $SdMacros -Recurse -Force

    # 3) Replace %%ARBORCTL_VERSION%% in plugin.json and all .g files
    $targets = @()
    $targets += Get-ChildItem -Path $Staging -Filter 'plugin.json' -File
    $targets += Get-ChildItem -Path $Sd -Filter '*.g' -File -Recurse
    $targets += Get-ChildItem -Path $Sd -Filter '*.example' -File -Recurse

    foreach ($file in $targets) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($text -match '%%ARBORCTL_VERSION%%') {
            $text = $text -replace '%%ARBORCTL_VERSION%%', $Version
            Set-Content -LiteralPath $file.FullName -Value $text -NoNewline
        }
    }

    # 4) Run DWC's build-plugin-pkg.js with our staging dir
    Push-Location $DwcRepo
    try {
        $nodeArgs = @('scripts/build-plugin-pkg.js', $Staging)
        Write-Host "Invoking node $($nodeArgs -join ' ')" -ForegroundColor DarkGray
        & node @nodeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "DWC build-plugin-pkg exited with code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    # 5) Copy resulting zip from DWC dist/ into our dist/
    $expected = Join-Path $DwcRepo ("dist\ArborCTL-" + $Version + ".zip")
    if (-not (Test-Path $expected)) {
        # Fallback: pick the newest ArborCTL-*.zip in the DWC dist folder
        $found = Get-ChildItem -Path (Join-Path $DwcRepo 'dist') -Filter 'ArborCTL-*.zip' -File |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1
        if (-not $found) {
            throw "Could not locate built plugin zip in $DwcRepo\dist"
        }
        $expected = $found.FullName
    }

    $outName = ("ArborCTL-" + $Version + ".zip")
    $outPath = Join-Path $DistDir $outName
    Copy-Item -LiteralPath $expected -Destination $outPath -Force

    Write-Host ""
    Write-Host "Built DWC plugin: $outPath" -ForegroundColor Green
}
finally {
    if (Test-Path $Staging) {
        Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue
    }
}
