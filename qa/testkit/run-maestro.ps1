<#
.SYNOPSIS
  Run the Maestro smoke flows against an APK (or the already-installed app).

.EXAMPLES
  # Test whatever build is already installed on the connected device:
  .\run-maestro.ps1

  # Install an APK first, then test it:
  .\run-maestro.ps1 -Apk C:\path\to\app-debug.apk

  # Include the fresh-login flow (requires a logged-OUT app + maestro.env creds):
  .\run-maestro.ps1 -Apk C:\path\to\app.apk -All

  # Pick a device when more than one is connected:
  .\run-maestro.ps1 -Serial ZD2228V65L

.NOTES
  - Credentials/boundary come from maestro.env (copy maestro.env.example). Never
    put them in flow files.
  - By default the fresh-login flow (tag: needs-logged-out) is EXCLUDED because it
    fails on a device that is already logged in. Use -All to include it.
  - Results: a JUnit XML + failure screenshots land in reports\maestro-<timestamp>\.
#>
param(
    [string]$Apk,
    [string]$Serial,
    [string]$Flows = "",
    [switch]$All
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Flows -eq "") { $Flows = Join-Path $kitRoot ".maestro\smoke" }

# --- locate maestro ---
$maestro = $null
$cmd = Get-Command maestro -ErrorAction SilentlyContinue
if ($cmd) { $maestro = $cmd.Source }
elseif (Test-Path "$env:USERPROFILE\.maestro\bin\maestro.bat") { $maestro = "$env:USERPROFILE\.maestro\bin\maestro.bat" }
if (-not $maestro) {
    Write-Error "Maestro CLI not found. Install: download https://github.com/mobile-dev-inc/maestro/releases/latest/download/maestro.zip, extract so that %USERPROFILE%\.maestro\bin\maestro.bat exists, and ensure Java 17+ (set JAVA_HOME). Then re-run."
}

# --- locate adb ---
$adb = $null
$cmd = Get-Command adb -ErrorAction SilentlyContinue
if ($cmd) { $adb = $cmd.Source }
elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe") { $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" }
if (-not $adb) { Write-Error "adb not found. Install Android platform-tools and re-run." }

# --- device check ---
$devices = @((& $adb devices) | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" } | ForEach-Object { ($_ -split "\t")[0] })
if ($devices.Count -eq 0) { Write-Error "No device/emulator connected (adb devices is empty). Start one and re-run." }
if ($devices.Count -gt 1 -and -not $Serial) { Write-Error ("Multiple devices connected: " + ($devices -join ", ") + ". Re-run with -Serial <id>.") }
if (-not $Serial) { $Serial = $devices[0] }
Write-Host "Device: $Serial"

# --- wake + unlock (a locked screen makes every flow fail with black screenshots) ---
& $adb -s $Serial shell input keyevent KEYCODE_WAKEUP | Out-Null
& $adb -s $Serial shell wm dismiss-keyguard | Out-Null
Start-Sleep -Seconds 1
& $adb -s $Serial shell input swipe 360 1400 360 300 200 | Out-Null
Start-Sleep -Seconds 1
$focus = (& $adb -s $Serial shell "dumpsys window | grep mCurrentFocus") | Out-String
if ($focus -match "NotificationShade|Keyguard|StatusBar") {
    Write-Error "Device screen is locked (PIN/pattern?). Unlock it manually and re-run."
}

# --- device clock sanity (campaign gates read the device clock) ---
$deviceDate = (& $adb -s $Serial shell date) | Out-String
Write-Host ("Device clock: " + $deviceDate.Trim() + "  (host: " + (Get-Date) + ")")

# --- optional install ---
if ($Apk) {
    if (-not (Test-Path $Apk)) { Write-Error "APK not found: $Apk" }
    Write-Host "Installing $Apk ..."
    & $adb -s $Serial install -r $Apk
    if ($LASTEXITCODE -ne 0) { Write-Error "adb install failed (signature mismatch? uninstall the existing app first - NOTE: that deletes its local data)." }
}

# --- env vars from maestro.env ---
$envArgs = @()
$setKeys = @()
$envFile = Join-Path $kitRoot "maestro.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $envArgs += "-e"
            $envArgs += $line
            $setKeys += $line.Split("=")[0].Trim()
        }
    }
    Write-Host ("Loaded " + ($envArgs.Count / 2) + " env vars from maestro.env")
} else {
    Write-Host "No maestro.env found - flows that need credentials will fail. Copy maestro.env.example to maestro.env and fill it in."
}

# --- flow defaults (used only when not set in maestro.env) ---
# RUN_STAMP names this run's test data (QATEST <RUN_STAMP> ...), stable across
# all flows of ONE invocation so 04/05/06/07 find what 03 registered.
$defaults = [ordered]@{
    "RUN_STAMP"      = (Get-Date -Format "MMdd-HHmm")
    "HOME_REG"       = "Registration & Delivery"
    "PROJECT_NAME"   = "(?i).*campaign.*"
    "BTN_NEXT"       = "Next"
    "BTN_RECORD"     = "Record Data"
    "BTN_PROCEED"    = "Proceed"
    "OPT_YES"        = "Yes"
    "OPT_NO"         = "No"
    "GENDER_HEAD"    = "Male"
    "GENDER_CHILD"   = "Female"
    "MEMBER_COUNT"   = "3"
    "HEAD_DOB_TEXT"  = "01/01/1990"
    "CHILD_DOB_TEXT" = "01/06/2024"
}
foreach ($k in $defaults.Keys) {
    if ($setKeys -notcontains $k) {
        $envArgs += "-e"
        $envArgs += ($k + "=" + $defaults[$k])
    }
}

# --- tag filter: exclude fresh-login flow unless -All ---
$tagArgs = @()
if (-not $All) { $tagArgs = @("--exclude-tags", "needs-logged-out") }

# --- output dirs ---
$stamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$outDir = Join-Path $kitRoot "reports\maestro-$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null

# --- run ---
Write-Host "Running flows in $Flows ..."
& $maestro --device $Serial test $Flows --format junit --output (Join-Path $outDir "report.xml") --debug-output $outDir @tagArgs @envArgs
$exit = $LASTEXITCODE

Write-Host ""
if ($exit -eq 0) { Write-Host "RESULT: PASS - report in $outDir" -ForegroundColor Green }
else { Write-Host "RESULT: FAIL (exit $exit) - report + screenshots in $outDir" -ForegroundColor Red }
exit $exit
