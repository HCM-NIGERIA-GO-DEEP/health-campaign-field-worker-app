<#
.SYNOPSIS
  Collect a failure bundle (screenshot, UI dump, logs, versions) from the connected
  device into a zip you can send to the dev team. Pure adb - no AI, no cost.

.EXAMPLE
  .\collect-failure-bundle.ps1 -Label TC-005
#>
param(
    [string]$Label = "failure",
    [string]$Serial
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pkg = "com.digit.hcm"

# --- locate adb ---
$adb = $null
$cmd = Get-Command adb -ErrorAction SilentlyContinue
if ($cmd) { $adb = $cmd.Source }
elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe") { $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" }
if (-not $adb) { Write-Error "adb not found. Install Android platform-tools." }

# --- pick device ---
$devices = @((& $adb devices) | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" } | ForEach-Object { ($_ -split "\t")[0] })
if ($devices.Count -eq 0) { Write-Error "No device connected." }
if ($devices.Count -gt 1 -and -not $Serial) { Write-Error ("Multiple devices: " + ($devices -join ", ") + ". Use -Serial.") }
if (-not $Serial) { $Serial = $devices[0] }

$stamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$outDir = Join-Path $kitRoot "reports\bundle-$Label-$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null
Write-Host "Collecting from $Serial into $outDir ..."

# --- screenshot + UI dump (device-side write, then pull: piping binaries through
#     PowerShell corrupts them) ---
& $adb -s $Serial shell screencap -p /sdcard/bundle-screen.png
& $adb -s $Serial pull /sdcard/bundle-screen.png (Join-Path $outDir "screen.png") | Out-Null
& $adb -s $Serial shell rm /sdcard/bundle-screen.png
& $adb -s $Serial shell uiautomator dump /sdcard/bundle-ui.xml | Out-Null
& $adb -s $Serial pull /sdcard/bundle-ui.xml (Join-Path $outDir "ui.xml") | Out-Null
& $adb -s $Serial shell rm /sdcard/bundle-ui.xml

# --- logs ---
& $adb -s $Serial logcat -d -t 800 | Out-File (Join-Path $outDir "logcat-tail.txt") -Encoding utf8
& $adb -s $Serial logcat -d | Select-String -Pattern "FATAL|Exception|flutter.*[Ee]rror" | Out-File (Join-Path $outDir "log-highlights.txt") -Encoding utf8

# --- versions + device info + clock ---
$info = @()
$info += "label:        $Label"
$info += "collected:    $stamp (host time)"
$info += ("device clock: " + ((& $adb -s $Serial shell date) | Out-String).Trim())
$info += ("device:       " + ((& $adb -s $Serial shell getprop ro.product.model) | Out-String).Trim() + " / Android " + ((& $adb -s $Serial shell getprop ro.build.version.release) | Out-String).Trim() + " / serial $Serial")
$ver = (& $adb -s $Serial shell dumpsys package $pkg) | Select-String -Pattern "versionName|versionCode" | Select-Object -First 2
foreach ($v in $ver) { $info += ("app " + $v.ToString().Trim()) }
$info | Out-File (Join-Path $outDir "info.txt") -Encoding utf8

# --- zip it ---
$zipPath = "$outDir.zip"
Compress-Archive -Path "$outDir\*" -DestinationPath $zipPath -Force
Write-Host ""
Write-Host "Bundle ready: $zipPath" -ForegroundColor Green
Write-Host "Send this to the dev team along with WHICH test case / flow failed and what you expected to see."
