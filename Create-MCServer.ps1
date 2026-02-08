& {
# ============================================================
#  Minecraft Server Creator Script
#  Creates a Minecraft Java Edition server with custom settings
#
#  Run directly:  .\Create-MCServer.ps1
#  Run via pipe:  irm https://raw.githubusercontent.com/RuhaabS/mc-server-creator/main/Create-MCServer.ps1 | iex
# ============================================================

param(
    [string]$ServerPath,
    [string]$Version,
    [switch]$AcceptEula,
    [switch]$AutoInstallJava,

    # Server settings
    [string]$ServerName,
    [int]$ServerPort      = 0,
    [int]$MaxPlayers      = 0,
    [string]$OnlineMode,
    [string]$Pvp,

    # Gameplay
    [string]$Hardcore,
    [string]$CommandBlocks,
    [string]$AllowFlight,
    [string]$AllowNether,
    [string]$SpawnNpcs,
    [string]$SpawnAnimals,
    [string]$SpawnMonsters,

    # World
    [string]$Difficulty,
    [string]$Gamemode,
    [string]$LevelType,
    [string]$LevelName,
    [string]$LevelSeed,

    # Performance
    [int]$MaxRam           = 0,
    [string]$Whitelist
)

# Determine if running non-interactively (at least Version and ServerPath provided)
$nonInteractive = (-not [string]::IsNullOrWhiteSpace($Version)) -and (-not [string]::IsNullOrWhiteSpace($ServerPath))

# Helper to parse bool-like parameter strings ("true"/"false"/"yes"/"no")
function Parse-BoolParam {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    switch ($Value.Trim().ToLower()) {
        "true"  { return $true  }
        "yes"   { return $true  }
        "1"     { return $true  }
        "false" { return $false }
        "no"    { return $false }
        "0"     { return $false }
        default { return $null  }
    }
}

# --- Helper Functions ---

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       Minecraft Server Creator  v1.0         ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Ask-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $false
    )
    $defaultText = if ($Default) { "Y/n" } else { "y/N" }
    do {
        $answer = Read-Host "$Prompt [$defaultText]"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $Default
        }
        switch ($answer.Trim().ToLower()) {
            "y"   { return $true  }
            "yes" { return $true  }
            "n"   { return $false }
            "no"  { return $false }
            default {
                Write-Host "  Please enter y or n." -ForegroundColor Yellow
            }
        }
    } while ($true)
}

function Ask-Choice {
    param(
        [string]$Prompt,
        [string[]]$Options,
        [int]$Default = 0
    )
    Write-Host ""
    Write-Host "  $Prompt" -ForegroundColor White
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $marker = if ($i -eq $Default) { " (default)" } else { "" }
        Write-Host "    [$($i + 1)] $($Options[$i])$marker" -ForegroundColor Gray
    }
    do {
        $input = Read-Host "  Choice [1-$($Options.Count)]"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        $num = 0
        if ([int]::TryParse($input, [ref]$num) -and $num -ge 1 -and $num -le $Options.Count) {
            return ($num - 1)
        }
        Write-Host "  Invalid choice. Try again." -ForegroundColor Yellow
    } while ($true)
}

function Ask-String {
    param(
        [string]$Prompt,
        [string]$Default
    )
    $answer = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim()
}

function Ask-Int {
    param(
        [string]$Prompt,
        [int]$Default,
        [int]$Min = 0,
        [int]$Max = [int]::MaxValue
    )
    do {
        $answer = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
        $num = 0
        if ([int]::TryParse($answer, [ref]$num) -and $num -ge $Min -and $num -le $Max) {
            return $num
        }
        Write-Host "  Please enter a number between $Min and $Max." -ForegroundColor Yellow
    } while ($true)
}

# --- Fetch available versions from Mojang ---

function Get-MinecraftVersions {
    Write-Host "  Fetching available Minecraft versions..." -ForegroundColor DarkGray
    try {
        $manifest = Invoke-RestMethod -Uri "https://launchermeta.mojang.com/mc/game/version_manifest.json" -UseBasicParsing
        return $manifest
    }
    catch {
        Write-Host "  ERROR: Could not fetch version manifest from Mojang." -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-ServerJarUrl {
    param([string]$VersionUrl)
    try {
        $wc = New-Object System.Net.WebClient
        $json = $wc.DownloadString($VersionUrl)
        $versionData = $json | ConvertFrom-Json
        if ($versionData.downloads -and $versionData.downloads.server) {
            return $versionData.downloads.server.url
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-RequiredJavaVersion {
    <#
    .SYNOPSIS
        Returns the minimum Java major version required for a given Minecraft version.
        MC Version        → Java Required
        ─────────────────────────────────
        1.20.5+  / 1.21+  → Java 21
        1.18 – 1.20.4      → Java 17
        1.17 – 1.17.1      → Java 16
        1.12 – 1.16.5      → Java 8
        < 1.12             → Java 8
        Snapshots          → inferred from nearest release cycle
    #>
    param([string]$McVersion)

    # Try to parse major.minor.patch from version string
    $parts = $McVersion -split '\.'
    $major = 0; $minor = 0; $patch = 0

    if ($parts.Count -ge 1) { [int]::TryParse($parts[0], [ref]$major) | Out-Null }
    if ($parts.Count -ge 2) { [int]::TryParse($parts[1], [ref]$minor) | Out-Null }
    if ($parts.Count -ge 3) { [int]::TryParse($parts[2], [ref]$patch) | Out-Null }

    # Snapshot / pre-release detection — try to infer from the year-week format (e.g. 24w14a)
    if ($McVersion -match '^(\d{2})w') {
        $snapYear = [int]$Matches[1]
        # 24w14a+ corresponds to 1.20.5+ cycle → Java 21
        if ($snapYear -ge 24) { return 21 }
        # 23wXX, 22wXX → 1.19/1.20 cycle → Java 17
        if ($snapYear -ge 21) { return 17 }
        return 8
    }

    # Non-numeric version (e.g. "1.21-pre1", "1.20.5-rc1") — strip suffix and re-parse
    if ($McVersion -match '^(\d+\.\d+(?:\.\d+)?)') {
        $cleaned = $Matches[1]
        $parts = $cleaned -split '\.'
        if ($parts.Count -ge 1) { [int]::TryParse($parts[0], [ref]$major) | Out-Null }
        if ($parts.Count -ge 2) { [int]::TryParse($parts[1], [ref]$minor) | Out-Null }
        if ($parts.Count -ge 3) { [int]::TryParse($parts[2], [ref]$patch) | Out-Null }
    }

    if ($major -ne 1) { return 21 }  # future-proof: unknown major → latest LTS

    # 1.21+ → Java 21
    if ($minor -ge 21) { return 21 }

    # 1.20.5+ → Java 21
    if ($minor -eq 20 -and $patch -ge 5) { return 21 }

    # 1.18 – 1.20.4 → Java 17
    if ($minor -ge 18) { return 17 }

    # 1.17 – 1.17.1 → Java 16
    if ($minor -eq 17) { return 16 }

    # 1.12 – 1.16.5 → Java 8
    return 8
}

function Get-RecommendedJdkVersion {
    <#
    .SYNOPSIS
        Maps a minimum required Java version to the best Adoptium LTS to install.
        We only install LTS releases (8, 17, 21) since those have Adoptium MSI installers.
    #>
    param([int]$MinJava)
    if ($MinJava -le 8)  { return 8  }
    if ($MinJava -le 17) { return 17 }
    return 21
}

# ============================================================
#  MAIN SCRIPT
# ============================================================

Write-Banner

# --- Check for Java ---
function Install-Java {
    <#
    .SYNOPSIS
        Downloads and installs Eclipse Temurin (Adoptium) JDK via the official MSI installer.
        Accepts a JdkVersion parameter (8, 17, or 21).
    #>
    param(
        [int]$JdkVersion = 21
    )

    $arch = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $jdkVersion = $JdkVersion
    $apiUrl = "https://api.adoptium.net/v3/assets/latest/$jdkVersion/hotspot?architecture=$arch&image_type=jdk&os=windows&vendor=eclipse"

    Write-Host ""
    Write-Host "  Downloading Eclipse Temurin JDK $jdkVersion ($arch)..." -ForegroundColor Cyan
    Write-Host "  Source: adoptium.net (Eclipse Foundation)" -ForegroundColor DarkGray

    try {
        $wc = New-Object System.Net.WebClient
        $json = $wc.DownloadString($apiUrl)
        $assets = $json | ConvertFrom-Json
        # Pick the .msi installer
        $msiAsset = $assets | Where-Object {
            $_.binary.installer -and $_.binary.installer.link -like "*.msi"
        } | Select-Object -First 1

        if (-not $msiAsset) {
            # Fallback — just grab any package link
            $msiAsset = $assets | Select-Object -First 1
        }

        $downloadUrl  = $msiAsset.binary.installer.link
        $fileName     = $msiAsset.binary.installer.name
        if (-not $downloadUrl) {
            $downloadUrl = $msiAsset.binary.package.link
            $fileName    = $msiAsset.binary.package.name
        }

        $tempDir  = Join-Path $env:TEMP "mc-server-java-setup"
        if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
        $msiPath = Join-Path $tempDir $fileName

        Write-Host "  Downloading installer ($fileName)..." -ForegroundColor White
        (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $msiPath)

        $sizeMB = [math]::Round((Get-Item $msiPath).Length / 1MB, 1)
        Write-Host "  Downloaded ($sizeMB MB). Installing..." -ForegroundColor Green

        # Silent install via msiexec — adds Java to PATH automatically
        Write-Host "  Running installer (this may take a minute)..." -ForegroundColor Yellow
        Write-Host "  You may see a UAC prompt — please accept it." -ForegroundColor Yellow

        $msiArgs = "/i `"$msiPath`" ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome,FeatureOracleJavaSoft INSTALLDIR=`"C:\Program Files\Eclipse Adoptium\jdk-$jdkVersion`" /qb /norestart"
        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -Verb RunAs

        if ($proc.ExitCode -ne 0) {
            Write-Host "  Installer exited with code $($proc.ExitCode)." -ForegroundColor Red
            return $false
        }

        # Refresh PATH for the current session
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path    = "$machinePath;$userPath"

        # Also check common install location
        $adoptiumBin = "C:\Program Files\Eclipse Adoptium\jdk-$jdkVersion\bin"
        if ((Test-Path $adoptiumBin) -and ($env:Path -notlike "*$adoptiumBin*")) {
            $env:Path = "$adoptiumBin;$env:Path"
        }

        # Verify
        $javaCheck = Get-Command java -ErrorAction SilentlyContinue
        if ($javaCheck) {
            $ver = & java -version 2>&1 | Select-Object -First 1
            Write-Host "  Java installed successfully: $ver" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Java was installed but isn't on PATH yet." -ForegroundColor Yellow
            Write-Host "  You may need to restart your terminal/PC." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  ERROR: Failed to download or install Java." -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        # Clean up temp installer
        if ($msiPath -and (Test-Path $msiPath)) {
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# Detect current Java (will validate compatibility after MC version is chosen)
Write-Host "  Detecting Java..." -ForegroundColor DarkGray
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
$currentJavaMajor = 0
if ($javaCmd) {
    $javaVersionStr = & java -version 2>&1 | Select-Object -First 1
    Write-Host "  Found: $javaVersionStr" -ForegroundColor Green
    $verMatch = [regex]::Match($javaVersionStr, '(\d+)')
    if ($verMatch.Success) { $currentJavaMajor = [int]$verMatch.Groups[1].Value }
} else {
    Write-Host "  Java not found on PATH." -ForegroundColor Yellow
}

# --- Choose server directory ---
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         Server Location                      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ServerPath)) {
    # Build suggested paths
    $desktopPath  = Join-Path ([Environment]::GetFolderPath("Desktop")) "minecraft-server"
    $documentsPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "minecraft-server"
    $currentPath  = Join-Path (Get-Location).Path "minecraft-server"

    $pathChoice = Ask-Choice "Where would you like to set up the server?" @(
        "Current directory  ($currentPath)",
        "Desktop            ($desktopPath)",
        "Documents          ($documentsPath)",
        "Enter a custom path"
    ) 0

    $ServerPath = switch ($pathChoice) {
        0 { $currentPath }
        1 { $desktopPath }
        2 { $documentsPath }
        3 {
            $customPath = Ask-String "  Enter full path for the server" $currentPath
            $customPath
        }
    }

    # Let the user name the server folder if they want
    $folderName = Split-Path $ServerPath -Leaf
    $parentDir  = Split-Path $ServerPath -Parent
    $newFolderName = Ask-String "  Server folder name" $folderName
    if ($newFolderName -ne $folderName) {
        $ServerPath = Join-Path $parentDir $newFolderName
    }
}

$ServerPath = [System.IO.Path]::GetFullPath($ServerPath)
Write-Host ""
Write-Host "  Server will be set up at:" -ForegroundColor White
Write-Host "  $ServerPath" -ForegroundColor Cyan

if (Test-Path (Join-Path $ServerPath "server.jar")) {
    Write-Host ""
    Write-Host "  A server.jar already exists at this location." -ForegroundColor Yellow
    if (-not $nonInteractive) {
        if (-not (Ask-YesNo "  Overwrite existing server files?")) {
            Write-Host "  Exiting." -ForegroundColor Gray
            return
        }
    } else {
        Write-Host "  Overwriting (non-interactive mode)." -ForegroundColor Yellow
    }
}

if (-not (Test-Path $ServerPath)) {
    New-Item -ItemType Directory -Path $ServerPath -Force | Out-Null
    Write-Host "  Created directory: $ServerPath" -ForegroundColor Green
} else {
    Write-Host "  Directory exists. ✓" -ForegroundColor Green
}

# --- Select Minecraft Version ---
Write-Host ""
$manifest = Get-MinecraftVersions
if (-not $manifest) { return }

$latestRelease  = $manifest.latest.release
$latestSnapshot = $manifest.latest.snapshot

Write-Host ""
Write-Host "  Latest release:  $latestRelease" -ForegroundColor Green
Write-Host "  Latest snapshot: $latestSnapshot" -ForegroundColor DarkYellow

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $selectedVersion = $Version
} else {
    $versionChoice = Ask-Choice "Select version type:" @("Latest release ($latestRelease)", "Latest snapshot ($latestSnapshot)", "Enter a specific version") 0

    $selectedVersion = switch ($versionChoice) {
        0 { $latestRelease }
        1 { $latestSnapshot }
        2 { Ask-String "  Enter version (e.g. 1.20.4)" $latestRelease }
    }
}

Write-Host ""
Write-Host "  Selected version: $selectedVersion" -ForegroundColor Cyan

# Find the version in the manifest
$versionEntry = $manifest.versions | Where-Object { $_.id -eq $selectedVersion } | Select-Object -First 1
if (-not $versionEntry) {
    Write-Host "  ERROR: Version '$selectedVersion' not found in Mojang's manifest." -ForegroundColor Red
    return
}

# --- Check Java compatibility for selected MC version ---
$requiredJava   = Get-RequiredJavaVersion -McVersion $selectedVersion
$recommendedJdk = Get-RecommendedJdkVersion -MinJava $requiredJava

Write-Host ""
Write-Host "  Minecraft $selectedVersion requires Java $requiredJava+" -ForegroundColor White

$needsJava = $false
$javaReason = ""

if ($currentJavaMajor -eq 0) {
    $needsJava = $true
    $javaReason = "missing"
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────┐" -ForegroundColor Red
    Write-Host "  │  Java was NOT found on your system!                  │" -ForegroundColor Red
    Write-Host "  │  Minecraft $($selectedVersion.PadRight(10)) requires Java $requiredJava+ to run.     │" -ForegroundColor Red
    Write-Host "  └──────────────────────────────────────────────────────┘" -ForegroundColor Red
} elseif ($currentJavaMajor -lt $requiredJava) {
    $needsJava = $true
    $javaReason = "outdated"
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  Java $currentJavaMajor is installed, but MC $($selectedVersion.PadRight(10)) needs $requiredJava+  │" -ForegroundColor Yellow
    Write-Host "  └──────────────────────────────────────────────────────┘" -ForegroundColor Yellow
} else {
    Write-Host "  Java $currentJavaMajor is compatible. ✓" -ForegroundColor Green
}

if ($needsJava) {
    Write-Host ""
    if ($nonInteractive) {
        if ($AutoInstallJava) {
            Write-Host "  Auto-installing Java $recommendedJdk (non-interactive mode)..." -ForegroundColor Cyan
            $installed = Install-Java -JdkVersion $recommendedJdk
            if (-not $installed) {
                Write-Host "  Java installation had issues. Continuing anyway." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Skipping Java install (non-interactive mode, use -AutoInstallJava to auto-install)." -ForegroundColor Yellow
        }
    } else {
    $wantInstall = Ask-YesNo "  Would you like to install Java?"
    
    if ($wantInstall) {
        # Let the user pick which JDK version to install
        # Mark the recommended one for their MC version
        $jdkOptions = @(
            "JDK 21  — Best for MC 1.20.5+ / 1.21+  (latest LTS)",
            "JDK 17  — Best for MC 1.18 – 1.20.4",
            "JDK 8   — Best for MC 1.16.5 and older"
        )

        # Determine which option to default-select based on recommendation
        $defaultJdk = switch ($recommendedJdk) {
            21 { 0 }
            17 { 1 }
            8  { 2 }
            default { 0 }
        }

        # Add a recommended tag to the matching option
        $jdkOptions[$defaultJdk] = $jdkOptions[$defaultJdk] + "  ← recommended for MC $selectedVersion"

        $jdkChoice = Ask-Choice "Which Java version would you like to install?" $jdkOptions $defaultJdk

        $chosenJdk = switch ($jdkChoice) {
            0 { 21 }
            1 { 17 }
            2 { 8  }
        }

        # Warn if they pick a version lower than what's required
        if ($chosenJdk -lt $requiredJava) {
            Write-Host ""
            Write-Host "  WARNING: JDK $chosenJdk may not work with MC $selectedVersion (needs Java $requiredJava+)." -ForegroundColor Yellow
            if (-not (Ask-YesNo "  Install JDK $chosenJdk anyway?")) {
                Write-Host "  Cancelled. Falling back to recommended JDK $recommendedJdk." -ForegroundColor Cyan
                $chosenJdk = $recommendedJdk
            }
        }

        Write-Host ""
        $installed = Install-Java -JdkVersion $chosenJdk
        if (-not $installed) {
            Write-Host ""
            Write-Host "  Java installation had issues." -ForegroundColor Yellow
            if (-not (Ask-YesNo "  Continue creating the server anyway?")) {
                Write-Host "  Exiting." -ForegroundColor Gray
                return
            }
        }
    } else {
        # User declined Java install
        Write-Host ""
        Write-Host "  Skipping Java install." -ForegroundColor Yellow
        if ($javaReason -eq "missing") {
            Write-Host "  You'll need Java $requiredJava+ before starting the server." -ForegroundColor Yellow
        } else {
            Write-Host "  Your Java $currentJavaMajor may not work \u2014 MC $selectedVersion needs Java $requiredJava+." -ForegroundColor Yellow
        }
        Write-Host "  Download from: https://adoptium.net/" -ForegroundColor Cyan
        if (-not (Ask-YesNo "  Continue creating the server?")) {
            Write-Host "  Exiting." -ForegroundColor Gray
            return
        }
    }
    } # end interactive else
}

# Get server JAR download URL
Write-Host "  Fetching download URL for $selectedVersion..." -ForegroundColor DarkGray
$jarUrl = Get-ServerJarUrl -VersionUrl $versionEntry.url
if (-not $jarUrl) {
    Write-Host "  ERROR: No server JAR available for version $selectedVersion." -ForegroundColor Red
    return
}

# Download the JAR
$jarPath = Join-Path $ServerPath "server.jar"
Write-Host "  Downloading server.jar..." -ForegroundColor White
try {
    (New-Object System.Net.WebClient).DownloadFile($jarUrl, $jarPath)
    $sizeMB = [math]::Round((Get-Item $jarPath).Length / 1MB, 2)
    Write-Host "  Downloaded server.jar ($sizeMB MB)" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR: Failed to download server.jar" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    return
}

# --- Accept EULA ---
Write-Host ""
if ($AcceptEula -or $nonInteractive) {
    if (-not $AcceptEula) {
        Write-Host "  ERROR: You must pass -AcceptEula in non-interactive mode." -ForegroundColor Red
        Write-Host "  EULA: https://aka.ms/MinecraftEULA" -ForegroundColor Yellow
        return
    }
    Write-Host "  EULA accepted via -AcceptEula parameter." -ForegroundColor Green
} else {
    Write-Host "  ┌──────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  Minecraft EULA                               │" -ForegroundColor Yellow
    Write-Host "  │  https://aka.ms/MinecraftEULA                 │" -ForegroundColor Yellow
    Write-Host "  │  You must agree to the EULA to run a server.  │" -ForegroundColor Yellow
    Write-Host "  └──────────────────────────────────────────────┘" -ForegroundColor Yellow

    $eulaAnswer = Ask-YesNo "  Do you accept the Minecraft EULA?"
    if (-not $eulaAnswer) {
        Write-Host "  You must accept the EULA to create a server. Exiting." -ForegroundColor Red
        return
    }
}
$eulaPath = Join-Path $ServerPath "eula.txt"
Set-Content -Path $eulaPath -Value "# Minecraft EULA - accepted via Create-MCServer.ps1`neula=true" -Force
Write-Host "  EULA accepted and saved." -ForegroundColor Green

# --- Server Configuration ---
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║         Server Configuration                 ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Helper: use parameter value if set, otherwise prompt interactively
function Resolve-BoolSetting {
    param([string]$ParamValue, [string]$Prompt, [bool]$Default)
    $parsed = Parse-BoolParam $ParamValue
    if ($null -ne $parsed) { return $parsed }
    if ($nonInteractive) { return $Default }
    return (Ask-YesNo $Prompt $Default)
}

function Resolve-IntSetting {
    param([int]$ParamValue, [string]$Prompt, [int]$Default, [int]$Min, [int]$Max, [int]$Unset = 0)
    if ($ParamValue -ne $Unset) { return $ParamValue }
    if ($nonInteractive) { return $Default }
    return (Ask-Int $Prompt $Default $Min $Max)
}

function Resolve-StringSetting {
    param([string]$ParamValue, [string]$Prompt, [string]$Default)
    if (-not [string]::IsNullOrWhiteSpace($ParamValue)) { return $ParamValue }
    if ($nonInteractive) { return $Default }
    return (Ask-String $Prompt $Default)
}

# General
$serverName   = Resolve-StringSetting $ServerName  "  Server name (MOTD)" "A Minecraft Server"
$serverPort   = Resolve-IntSetting    $ServerPort  "  Server port" 25565 1 65535
$maxPlayers   = Resolve-IntSetting    $MaxPlayers  "  Max players" 20 1 1000
$onlineMode   = Resolve-BoolSetting   $OnlineMode  "  Online mode (authenticate with Mojang)?" $true
$pvp          = Resolve-BoolSetting   $Pvp         "  Enable PvP?" $true

if (-not $nonInteractive) {
    Write-Host ""
    Write-Host "  --- Gameplay ---" -ForegroundColor Magenta
}

# Gameplay
$hardcore     = Resolve-BoolSetting   $Hardcore      "  Hardcore mode?" $false
$commandBlocks = Resolve-BoolSetting  $CommandBlocks "  Enable command blocks?" $true
$allowFlight  = Resolve-BoolSetting   $AllowFlight   "  Allow flight?" $true
$allowNether  = Resolve-BoolSetting   $AllowNether   "  Allow the Nether?" $true
$spawnNpcs    = Resolve-BoolSetting   $SpawnNpcs     "  Spawn NPCs (villagers)?" $true
$spawnAnimals = Resolve-BoolSetting   $SpawnAnimals  "  Spawn animals?" $true
$spawnMonsters = Resolve-BoolSetting  $SpawnMonsters "  Spawn monsters?" $true

if (-not $nonInteractive) {
    Write-Host ""
    Write-Host "  --- World ---" -ForegroundColor Magenta
}

# Difficulty
$validDifficulties = @("peaceful", "easy", "normal", "hard")
if (-not [string]::IsNullOrWhiteSpace($Difficulty) -and $Difficulty.ToLower() -in $validDifficulties) {
    $difficulty = $Difficulty.ToLower()
} elseif ($nonInteractive) {
    $difficulty = "normal"
} else {
    $diffChoice = Ask-Choice "Select difficulty:" @("Peaceful", "Easy", "Normal", "Hard") 2
    $difficulty = $validDifficulties[$diffChoice]
}

# Gamemode
$validGamemodes = @("survival", "creative", "adventure", "spectator")
if (-not [string]::IsNullOrWhiteSpace($Gamemode) -and $Gamemode.ToLower() -in $validGamemodes) {
    $gamemode = $Gamemode.ToLower()
} elseif ($nonInteractive) {
    $gamemode = "survival"
} else {
    $gmChoice = Ask-Choice "Select default gamemode:" @("Survival", "Creative", "Adventure", "Spectator") 0
    $gamemode = $validGamemodes[$gmChoice]
}

# World type
$validLevelTypes = @{ "normal" = "minecraft:normal"; "flat" = "minecraft:flat"; "largebiomes" = "minecraft:large_biomes"; "amplified" = "minecraft:amplified" }
if (-not [string]::IsNullOrWhiteSpace($LevelType)) {
    $ltKey = $LevelType.ToLower() -replace '[\s_-]',''
    if ($validLevelTypes.ContainsKey($ltKey)) {
        $levelType = $validLevelTypes[$ltKey]
    } elseif ($LevelType -like "minecraft:*") {
        $levelType = $LevelType  # already in minecraft: format
    } else {
        $levelType = "minecraft:normal"
    }
} elseif ($nonInteractive) {
    $levelType = "minecraft:normal"
} else {
    $wtChoice = Ask-Choice "Select world type:" @("Normal", "Flat", "Large Biomes", "Amplified") 0
    $levelType = @("minecraft:normal", "minecraft:flat", "minecraft:large_biomes", "minecraft:amplified")[$wtChoice]
}

$levelName  = Resolve-StringSetting $LevelName  "  World/level name" "world"
$levelSeed  = Resolve-StringSetting $LevelSeed  "  World seed (leave blank for random)" ""
if (-not $nonInteractive) {
    Write-Host ""
    Write-Host "  --- Performance / Network ---" -ForegroundColor Magenta
}

$maxRamMB     = Resolve-IntSetting  $MaxRam "  Max RAM for server (MB)" 2048 512 32768

# White-list
$whitelist    = Resolve-BoolSetting $Whitelist "  Enable whitelist?" $false

# --- Build server.properties ---
Write-Host ""
Write-Host "  Generating default server.properties..." -ForegroundColor DarkGray

$boolStr = { param($v) if ($v) { "true" } else { "false" } }
$propsPath = Join-Path $ServerPath "server.properties"

# Run the server once so Minecraft generates its own default server.properties
if (-not (Test-Path $propsPath)) {
    Write-Host "  Running server once to generate defaults (this may take a moment)..." -ForegroundColor DarkGray
    $originalDir = Get-Location
    Set-Location $ServerPath
    $genProc = Start-Process -FilePath "java" -ArgumentList "-Xmx256M -Xms256M -jar server.jar nogui" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "NUL" -RedirectStandardError "NUL" -ErrorAction SilentlyContinue
    Set-Location $originalDir

    # If it still doesn't exist (e.g. no Java), create a minimal one
    if (-not (Test-Path $propsPath)) {
        Write-Host "  Could not auto-generate defaults, creating server.properties from scratch." -ForegroundColor Yellow
        Set-Content -Path $propsPath -Value "#Minecraft server properties" -Force
    }
}

# Build a hashtable of only the properties the user configured
$userSettings = @{
    "motd"                = $serverName
    "server-port"         = [string]$serverPort
    "max-players"         = [string]$maxPlayers
    "online-mode"         = (&$boolStr $onlineMode)
    "pvp"                 = (&$boolStr $pvp)
    "white-list"          = (&$boolStr $whitelist)
    "enforce-whitelist"   = (&$boolStr $whitelist)
    "hardcore"            = (&$boolStr $hardcore)
    "enable-command-block"= (&$boolStr $commandBlocks)
    "allow-flight"        = (&$boolStr $allowFlight)
    "allow-nether"        = (&$boolStr $allowNether)
    "spawn-npcs"          = (&$boolStr $spawnNpcs)
    "spawn-animals"       = (&$boolStr $spawnAnimals)
    "spawn-monsters"      = (&$boolStr $spawnMonsters)
    "difficulty"          = $difficulty
    "gamemode"            = $gamemode
    "level-name"          = $levelName
    "level-seed"          = $levelSeed
    "level-type"          = $levelType
}

# Read the existing file line by line and replace only matching keys
Write-Host "  Updating server.properties with your settings..." -ForegroundColor DarkGray
$lines = Get-Content -Path $propsPath
$keysWritten = @{}

$updatedLines = $lines | ForEach-Object {
    $line = $_
    # Match property lines like "key=value"
    if ($line -match '^\s*([a-zA-Z0-9\-]+)\s*=') {
        $key = $Matches[1]
        if ($userSettings.ContainsKey($key)) {
            $keysWritten[$key] = $true
            "$key=$($userSettings[$key])"
        } else {
            $line  # leave untouched
        }
    } else {
        $line  # comments / blank lines stay as-is
    }
}

# Append any user settings whose keys weren't found in the file
$missingKeys = $userSettings.Keys | Where-Object { -not $keysWritten.ContainsKey($_) }
if ($missingKeys.Count -gt 0) {
    $updatedLines += ""
    $updatedLines += "# Added by Create-MCServer.ps1"
    foreach ($key in $missingKeys) {
        $updatedLines += "$key=$($userSettings[$key])"
    }
}

Set-Content -Path $propsPath -Value $updatedLines -Force

$changedCount  = $keysWritten.Count
$appendedCount = $missingKeys.Count
Write-Host "  server.properties saved ($changedCount updated, $appendedCount added)." -ForegroundColor Green

# --- Create start script ---
Write-Host "  Generating start scripts..." -ForegroundColor DarkGray

# PowerShell start script
$startPs1 = @"
# Start Minecraft Server
# Generated by Create-MCServer.ps1

`$Host.UI.RawUI.WindowTitle = "Minecraft Server - $serverName"
Set-Location "`$PSScriptRoot"

Write-Host "Starting Minecraft Server..." -ForegroundColor Green
Write-Host "RAM: ${maxRamMB}MB | Port: $serverPort | Version: $selectedVersion" -ForegroundColor Cyan
Write-Host "Press Ctrl+C or type 'stop' to shut down." -ForegroundColor Yellow
Write-Host ""

java -Xmx${maxRamMB}M -Xms${maxRamMB}M -jar server.jar nogui
"@

$startPs1Path = Join-Path $ServerPath "start.ps1"
Set-Content -Path $startPs1Path -Value $startPs1 -Force

# Batch start script
$startBat = @"
@echo off
title Minecraft Server - $serverName
cd /d "%~dp0"
echo Starting Minecraft Server...
echo RAM: ${maxRamMB}MB ^| Port: $serverPort ^| Version: $selectedVersion
echo Press Ctrl+C or type 'stop' to shut down.
echo.
java -Xmx${maxRamMB}M -Xms${maxRamMB}M -jar server.jar nogui
pause
"@

$startBatPath = Join-Path $ServerPath "start.bat"
Set-Content -Path $startBatPath -Value $startBat -Force

Write-Host "  start.ps1 and start.bat created." -ForegroundColor Green

# --- Summary ---
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║         Server Created Successfully!         ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Location:       $ServerPath" -ForegroundColor White
Write-Host "  Version:        $selectedVersion" -ForegroundColor White
Write-Host "  Port:           $serverPort" -ForegroundColor White
Write-Host "  Gamemode:       $gamemode" -ForegroundColor White
Write-Host "  Difficulty:     $difficulty" -ForegroundColor White
Write-Host "  Hardcore:       $(&$boolStr $hardcore)" -ForegroundColor $(if($hardcore){"Red"}else{"White"})
Write-Host "  Command Blocks: $(&$boolStr $commandBlocks)" -ForegroundColor White
Write-Host "  Allow Flight:   $(&$boolStr $allowFlight)" -ForegroundColor White
Write-Host "  Max RAM:        ${maxRamMB}MB" -ForegroundColor White
Write-Host ""
Write-Host "  To start your server:" -ForegroundColor Yellow
Write-Host "    cd `"$ServerPath`"" -ForegroundColor Gray
Write-Host "    .\start.ps1       (PowerShell)" -ForegroundColor Gray
Write-Host "    .\start.bat       (Command Prompt)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Happy crafting! ⛏️" -ForegroundColor Green
Write-Host ""
}
