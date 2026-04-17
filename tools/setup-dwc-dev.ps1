<#
.SYNOPSIS
    Install ArborCTL's dwc-plugin into a DuetWebControl clone for local hot-reload development.

.DESCRIPTION
    DWC's webpack auto-imports plugin only treats readdir entries with Dirent.isDirectory() as
    plugin folders. On Windows, directory junctions/symlinks report isDirectory=false, so
    Junction mode is SKIPPED for ArborCTL. Use Copy (default) so src/plugins/ArborCTL is a real
    folder and appears in src/plugins/imports.ts after the next compile.

    Optionally patches default DWC settings to load ArborCTL on startup and to use the CNC
    dashboard (DWC UI only; the real machine mode still comes from RRF when connected).

.PARAMETER DwcRepo
    Path to your DuetWebControl repository (must contain package.json).

.PARAMETER Mode
    Copy: recursive copy of dwc-plugin (default; required on Windows for plugin discovery).
    Junction: not recommended; webpack may omit the plugin from imports.ts.

.PARAMETER CncDashboard
    If true (default), sets default dashboardMode to CNC in src/store/settings.ts for dev.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\setup-dwc-dev.ps1 -DwcRepo C:\dev\DuetWebControl-3.6.1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DwcRepo,
    [ValidateSet('Junction', 'Copy')]
    [string]$Mode = 'Copy',
    [bool]$CncDashboard = $true
)

$ErrorActionPreference = 'Stop'

if ($Mode -eq 'Junction') {
    Write-Warning "Junction mode often breaks DWC's plugin scanner on Windows (Node Dirent.isDirectory is false for junctions). Using Copy is strongly recommended."
}

$DwcRepo = (Resolve-Path -LiteralPath $DwcRepo).Path
$Pkg = Join-Path $DwcRepo 'package.json'
if (-not (Test-Path -LiteralPath $Pkg)) {
    throw "Not a DuetWebControl repo (missing package.json): $DwcRepo"
}

$ArborRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$PluginSrc = Join-Path $ArborRoot 'dwc-plugin'
if (-not (Test-Path -LiteralPath $PluginSrc)) {
    throw "Missing dwc-plugin folder: $PluginSrc"
}

$PluginsDir = Join-Path $DwcRepo 'src\plugins'
if (-not (Test-Path -LiteralPath $PluginsDir)) {
    throw "Missing src\plugins - use a full DuetWebControl checkout: $PluginsDir"
}

$PluginDest = Join-Path $PluginsDir 'ArborCTL'
if (Test-Path -LiteralPath $PluginDest) {
    Write-Host "Removing existing: $PluginDest" -ForegroundColor Yellow
    Remove-Item -LiteralPath $PluginDest -Recurse -Force
}

if ($Mode -eq 'Copy') {
    Write-Host "Copying dwc-plugin -> src\plugins\ArborCTL ..." -ForegroundColor Cyan
    Copy-Item -Path $PluginSrc -Destination $PluginDest -Recurse
    $Pj = Join-Path $PluginDest 'plugin.json'
    if (Test-Path -LiteralPath $Pj) {
        $pjText = Get-Content -LiteralPath $Pj -Raw
        $pjText = $pjText -replace '%%ARBORCTL_VERSION%%', 'dev'
        Set-Content -LiteralPath $Pj -Value $pjText -NoNewline
        Write-Host "Set plugin.json version to dev (replace %%ARBORCTL_VERSION%% placeholder)" -ForegroundColor DarkGray
    }
} else {
    Write-Host ('Creating junction: ' + $PluginDest + ' -> ' + $PluginSrc) -ForegroundColor Cyan
    $arg = '/c mklink /J "' + $PluginDest + '" "' + $PluginSrc + '"'
    $exitCode = (Start-Process -FilePath 'cmd.exe' -ArgumentList $arg -Wait -PassThru -NoNewWindow).ExitCode
    if ($exitCode -ne 0) {
        throw "mklink /J failed (exit $exitCode). Try -Mode Copy."
    }
}

$IndexTs = Join-Path $PluginDest 'dwc-src\index.ts'
if (-not (Test-Path -LiteralPath $IndexTs)) {
    throw "Setup incomplete - missing $IndexTs"
}

# Patch default enabled plugins so ArborCTL loads without hunting Settings -> Plugins
$SettingsTs = Join-Path $DwcRepo 'src\store\settings.ts'
if (Test-Path -LiteralPath $SettingsTs) {
    $text = Get-Content -LiteralPath $SettingsTs -Raw
    if ($text -notmatch '"ArborCTL"') {
        $needle = "`"ObjectModelBrowser`"`r`n`t`t]"
        $replacement = "`"ObjectModelBrowser`",`r`n`t`t`t`"ArborCTL`"`r`n`t`t]"
        if ($text.Contains($needle)) {
            $text = $text.Replace($needle, $replacement)
        } else {
            $needleLf = "`"ObjectModelBrowser`"`n`t`t]"
            $replacementLf = "`"ObjectModelBrowser`",`n`t`t`t`"ArborCTL`"`n`t`t]"
            $text = $text.Replace($needleLf, $replacementLf)
        }
        Set-Content -LiteralPath $SettingsTs -Value $text -NoNewline
        Write-Host "Patched default enabledPlugins to include ArborCTL in src/store/settings.ts" -ForegroundColor Green
    } else {
        Write-Host "enabledPlugins already lists ArborCTL in settings.ts" -ForegroundColor DarkGray
    }

    if ($CncDashboard) {
        $text2 = Get-Content -LiteralPath $SettingsTs -Raw
        if ($text2 -match 'dashboardMode:\s*DashboardMode\.default') {
            $text2 = $text2 -replace 'dashboardMode:\s*DashboardMode\.default', 'dashboardMode: DashboardMode.cnc'
            Set-Content -LiteralPath $SettingsTs -Value $text2 -NoNewline
            Write-Host "Patched default dashboardMode to DashboardMode.cnc (DWC UI)" -ForegroundColor Green
        }
    }
} else {
    Write-Warning "Could not find $SettingsTs - skip defaults patch"
}

Write-Host ""
Write-Host "ArborCTL is wired into DWC. Next:" -ForegroundColor Green
Write-Host "  cd `"$DwcRepo`""
Write-Host "  npm install   (if not done yet)"
Write-Host "  npm run dev"
Write-Host ""
Write-Host "Restart the dev server so src/plugins/imports.ts regenerates with ArborCTL."
Write-Host "If the Plugins menu still looks wrong, clear site data for localhost (old dwc settings in localStorage)."
Write-Host "Cross-origin board access: doc/dwc-development.md"
Write-Host ""
