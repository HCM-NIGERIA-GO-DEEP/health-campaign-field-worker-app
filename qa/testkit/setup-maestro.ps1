<#
.SYNOPSIS
  One-time Maestro setup for this test kit (Windows).
  Checks Java 17+, downloads the free Maestro CLI, adds it to your PATH.

.EXAMPLE
  .\setup-maestro.ps1
#>

$ErrorActionPreference = "Stop"

# --- 1. Find Java 17+ ---
Write-Host "[1/4] Checking for Java 17+ ..."
$javaHome = $null
$candidates = @()
if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
$candidates += @(
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr",
    "C:\Program Files\Android\Android Studio\jbr"
)
if (Test-Path "C:\Program Files\Java") {
    Get-ChildItem "C:\Program Files\Java" -Directory | ForEach-Object { $candidates += $_.FullName }
}
foreach ($c in $candidates) {
    $exe = Join-Path $c "bin\java.exe"
    if (Test-Path $exe) {
        # java -version prints to stderr; redirect inside cmd to avoid PS 5.1 error-wrapping
        $verLine = (cmd /c "`"$exe`" -version 2>&1" | Select-Object -First 1) | Out-String
        if ($verLine -match '"(\d+)') {
            $major = [int]$Matches[1]
            if ($major -eq 1 -and $verLine -match '"1\.(\d+)') { $major = [int]$Matches[1] }
            if ($major -ge 17) { $javaHome = $c; Write-Host ("  Found Java " + $major + " at " + $c); break }
        }
    }
}
if (-not $javaHome) {
    Write-Error "No Java 17+ found. Install Android Studio (bundles one) or a JDK 17 from https://adoptium.net, then re-run."
}
if ($env:JAVA_HOME -ne $javaHome) {
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
    $env:JAVA_HOME = $javaHome
    Write-Host "  JAVA_HOME set for your user account."
}

# --- 2. Download + extract Maestro (skipped if already installed) ---
$dest = "$env:USERPROFILE\.maestro"
if (Test-Path "$dest\bin\maestro.bat") {
    Write-Host "[2/4] Maestro already installed at $dest - skipping download."
} else {
    Write-Host "[2/4] Downloading Maestro CLI (about 300 MB, one time) ..."
    $tmpZip = Join-Path $env:TEMP "maestro.zip"
    Invoke-WebRequest -Uri "https://github.com/mobile-dev-inc/maestro/releases/latest/download/maestro.zip" -OutFile $tmpZip -UseBasicParsing
    $tmpDir = Join-Path $env:TEMP "maestro-extract"
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force -Confirm:$false }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
    $inner = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
    Move-Item $inner.FullName $dest
    Remove-Item $tmpZip -Force -Confirm:$false
    Write-Host "  Installed to $dest"
}

# --- 3. PATH + privacy opt-out ---
Write-Host "[3/4] Configuring PATH ..."
$binPath = "$dest\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binPath*") {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $binPath), "User")
    Write-Host "  Added to PATH (new terminals will have 'maestro')."
}
$env:Path = "$env:Path;$binPath"
[Environment]::SetEnvironmentVariable("MAESTRO_CLI_NO_ANALYTICS", "1", "User")
$env:MAESTRO_CLI_NO_ANALYTICS = "1"

# --- 4. Verify ---
Write-Host "[4/4] Verifying ..."
& "$binPath\maestro.bat" --version
Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Green
Write-Host "  1. Connect a device/emulator and check:  adb devices"
Write-Host "  2. Copy maestro.env.example to maestro.env and fill in credentials."
Write-Host "  3. Run:  .\run-maestro.ps1 -Apk <path-to-your.apk>"
