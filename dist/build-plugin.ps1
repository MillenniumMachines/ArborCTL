$CommitID = (git describe --tags --exclude "release-*" --always --dirty).Trim()
$TmpDir = "dist\plugin_unified"
if (Test-Path $TmpDir) { Remove-Item -Recurse -Force $TmpDir }

# 1. Expand the Vue Web Plugin built by DuetWebControl
Expand-Archive -Path "dwc-env\dist\ArborCtl-0.1.0.zip" -DestinationPath $TmpDir

# 2. Re-create RRF directories inside the plugin
New-Item -ItemType Directory -Force "$TmpDir\sys" | Out-Null
New-Item -ItemType Directory -Force "$TmpDir\macros\ArborCtl" | Out-Null
New-Item -ItemType Directory -Force "$TmpDir\sys\arborctl" | Out-Null

Copy-Item "sys\*" -Destination "$TmpDir\sys\" -Recurse
Copy-Item "macro\public\*" -Destination "$TmpDir\macros\ArborCtl\" -Recurse
Copy-Item "macro\private\*" -Destination "$TmpDir\sys\arborctl\" -Recurse
Copy-Item "macro\gcodes\*" -Destination "$TmpDir\sys\" -Recurse

Get-ChildItem -Path "$TmpDir" -Filter "*.g" -Recurse | ForEach-Object {
    (Get-Content $_.FullName) -replace '%%ARBORCTL_VERSION%%', $CommitID | Set-Content $_.FullName
}

# 3. Smash them all together!
$ZipPath = "dist\ArborCtl-Plugin.zip"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path "$TmpDir\*" -DestinationPath $ZipPath
Remove-Item -Recurse -Force $TmpDir

Write-Output "Successfully rebuilt Unified Plugin Zip at $ZipPath"
