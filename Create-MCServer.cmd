@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Minecraft Server Creator v1.0

:: ============================================================
::  Minecraft Server Creator Script (.cmd)
::  Creates a Minecraft Java Edition server with custom settings
:: ============================================================

:: ---- Default parameter values ----
set "PARAM_PATH="
set "PARAM_VERSION="
set "PARAM_ACCEPT_EULA="
set "PARAM_AUTO_INSTALL_JAVA="
set "PARAM_NAME="
set "PARAM_PORT="
set "PARAM_MAX_PLAYERS="
set "PARAM_ONLINE_MODE="
set "PARAM_PVP="
set "PARAM_HARDCORE="
set "PARAM_COMMAND_BLOCKS="
set "PARAM_ALLOW_FLIGHT="
set "PARAM_ALLOW_NETHER="
set "PARAM_SPAWN_NPCS="
set "PARAM_SPAWN_ANIMALS="
set "PARAM_SPAWN_MONSTERS="
set "PARAM_DIFFICULTY="
set "PARAM_GAMEMODE="
set "PARAM_LEVEL_TYPE="
set "PARAM_LEVEL_NAME="
set "PARAM_LEVEL_SEED="
set "PARAM_MAX_RAM="
set "PARAM_WHITELIST="

:: ---- Parse CLI arguments ----
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--path"              ( set "PARAM_PATH=%~2"            & shift & shift & goto parse_args )
if /i "%~1"=="--version"           ( set "PARAM_VERSION=%~2"         & shift & shift & goto parse_args )
if /i "%~1"=="--accept-eula"       ( set "PARAM_ACCEPT_EULA=true"    & shift & goto parse_args )
if /i "%~1"=="--auto-install-java" ( set "PARAM_AUTO_INSTALL_JAVA=true" & shift & goto parse_args )
if /i "%~1"=="--name"              ( set "PARAM_NAME=%~2"            & shift & shift & goto parse_args )
if /i "%~1"=="--port"              ( set "PARAM_PORT=%~2"            & shift & shift & goto parse_args )
if /i "%~1"=="--max-players"       ( set "PARAM_MAX_PLAYERS=%~2"     & shift & shift & goto parse_args )
if /i "%~1"=="--online-mode"       ( set "PARAM_ONLINE_MODE=%~2"     & shift & shift & goto parse_args )
if /i "%~1"=="--pvp"               ( set "PARAM_PVP=%~2"             & shift & shift & goto parse_args )
if /i "%~1"=="--hardcore"          ( set "PARAM_HARDCORE=%~2"         & shift & shift & goto parse_args )
if /i "%~1"=="--command-blocks"    ( set "PARAM_COMMAND_BLOCKS=%~2"   & shift & shift & goto parse_args )
if /i "%~1"=="--allow-flight"      ( set "PARAM_ALLOW_FLIGHT=%~2"     & shift & shift & goto parse_args )
if /i "%~1"=="--allow-nether"      ( set "PARAM_ALLOW_NETHER=%~2"     & shift & shift & goto parse_args )
if /i "%~1"=="--spawn-npcs"        ( set "PARAM_SPAWN_NPCS=%~2"       & shift & shift & goto parse_args )
if /i "%~1"=="--spawn-animals"     ( set "PARAM_SPAWN_ANIMALS=%~2"    & shift & shift & goto parse_args )
if /i "%~1"=="--spawn-monsters"    ( set "PARAM_SPAWN_MONSTERS=%~2"   & shift & shift & goto parse_args )
if /i "%~1"=="--difficulty"        ( set "PARAM_DIFFICULTY=%~2"        & shift & shift & goto parse_args )
if /i "%~1"=="--gamemode"          ( set "PARAM_GAMEMODE=%~2"          & shift & shift & goto parse_args )
if /i "%~1"=="--level-type"        ( set "PARAM_LEVEL_TYPE=%~2"        & shift & shift & goto parse_args )
if /i "%~1"=="--level-name"        ( set "PARAM_LEVEL_NAME=%~2"        & shift & shift & goto parse_args )
if /i "%~1"=="--level-seed"        ( set "PARAM_LEVEL_SEED=%~2"        & shift & shift & goto parse_args )
if /i "%~1"=="--max-ram"           ( set "PARAM_MAX_RAM=%~2"           & shift & shift & goto parse_args )
if /i "%~1"=="--whitelist"         ( set "PARAM_WHITELIST=%~2"         & shift & shift & goto parse_args )
if /i "%~1"=="--help"              goto show_help
echo Unknown option: %~1
goto show_help
:args_done

:: Non-interactive if both path and version are given
set "NON_INTERACTIVE="
if defined PARAM_PATH if defined PARAM_VERSION set "NON_INTERACTIVE=true"

:: ============================================================
::  BANNER
:: ============================================================
echo.
echo   +================================================+
echo   ^|       Minecraft Server Creator  v1.0 (.cmd)     ^|
echo   +================================================+
echo.

:: ============================================================
::  DETECT JAVA
:: ============================================================
echo   Detecting Java...
set "CURRENT_JAVA_MAJOR=0"
where java >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%a in ('java -version 2^>^&1 ^| findstr /i "version"') do (
        set "JAVA_VER_RAW=%%~a"
    )
    :: Parse major version from e.g. "21.0.1" or "1.8.0_392"
    for /f "tokens=1,2 delims=." %%x in ("!JAVA_VER_RAW!") do (
        if "%%x"=="1" (
            set "CURRENT_JAVA_MAJOR=%%y"
        ) else (
            set "CURRENT_JAVA_MAJOR=%%x"
        )
    )
    echo   Found: Java !CURRENT_JAVA_MAJOR!
) else (
    echo   Java not found on PATH.
)

:: ============================================================
::  DETECT POWERSHELL (needed for JSON parsing / downloads)
:: ============================================================
set "PS_CMD="
where pwsh >nul 2>&1 && (
    set "PS_CMD=pwsh -NoProfile -Command"
    goto ps_found
)
where powershell >nul 2>&1 && (
    set "PS_CMD=powershell -NoProfile -ExecutionPolicy Bypass -Command"
    goto ps_found
)
echo   ERROR: PowerShell is required for JSON parsing and downloads.
echo   Please install PowerShell or use the .ps1 version of this script.
exit /b 1
:ps_found

:: ============================================================
::  SERVER LOCATION
:: ============================================================
echo.
echo   +================================================+
echo   ^|         Server Location                         ^|
echo   +================================================+

if defined PARAM_PATH (
    set "SERVER_PATH=!PARAM_PATH!"
    goto path_done
)

set "CURRENT_PATH=%cd%\minecraft-server"
set "DESKTOP_PATH=%USERPROFILE%\Desktop\minecraft-server"
set "DOCUMENTS_PATH=%USERPROFILE%\Documents\minecraft-server"

echo.
echo   Where would you like to set up the server?
echo     [1] Current directory  (!CURRENT_PATH!^) (default)
echo     [2] Desktop            (!DESKTOP_PATH!^)
echo     [3] Documents          (!DOCUMENTS_PATH!^)
echo     [4] Enter a custom path

set "PATH_CHOICE="
set /p "PATH_CHOICE=  Choice [1-4]: "
if "!PATH_CHOICE!"=="" set "PATH_CHOICE=1"

if "!PATH_CHOICE!"=="1" set "SERVER_PATH=!CURRENT_PATH!"
if "!PATH_CHOICE!"=="2" set "SERVER_PATH=!DESKTOP_PATH!"
if "!PATH_CHOICE!"=="3" set "SERVER_PATH=!DOCUMENTS_PATH!"
if "!PATH_CHOICE!"=="4" (
    set /p "SERVER_PATH=  Enter full path: "
)

:: Ask for folder name
for %%I in ("!SERVER_PATH!") do set "FOLDER_NAME=%%~nxI"
set "NEW_FOLDER="
set /p "NEW_FOLDER=  Server folder name [!FOLDER_NAME!]: "
if "!NEW_FOLDER!"=="" set "NEW_FOLDER=!FOLDER_NAME!"
if not "!NEW_FOLDER!"=="!FOLDER_NAME!" (
    for %%I in ("!SERVER_PATH!") do set "PARENT_DIR=%%~dpI"
    set "SERVER_PATH=!PARENT_DIR!!NEW_FOLDER!"
)

:path_done
echo.
echo   Server will be set up at:
echo   !SERVER_PATH!

if exist "!SERVER_PATH!\server.jar" (
    echo.
    echo   A server.jar already exists at this location.
    if not defined NON_INTERACTIVE (
        call :ask_yesno "  Overwrite existing server files?" "n" OVERWRITE
        if /i "!OVERWRITE!"=="false" (
            echo   Exiting.
            exit /b 0
        )
    ) else (
        echo   Overwriting (non-interactive mode^).
    )
)

if not exist "!SERVER_PATH!" mkdir "!SERVER_PATH!"
echo   Directory ready.

:: ============================================================
::  SELECT MINECRAFT VERSION
:: ============================================================
echo.
echo   Fetching available Minecraft versions...

:: Download manifest and extract latest versions using PowerShell
set "MANIFEST_TEMP=%TEMP%\mc_manifest.json"
!PS_CMD! "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://launchermeta.mojang.com/mc/game/version_manifest.json','!MANIFEST_TEMP!')" >nul 2>&1

if not exist "!MANIFEST_TEMP!" (
    echo   ERROR: Could not fetch version manifest from Mojang.
    exit /b 1
)

:: Extract latest release and snapshot
for /f "usebackq delims=" %%a in (`!PS_CMD! "(Get-Content '!MANIFEST_TEMP!' | ConvertFrom-Json).latest.release"`) do set "LATEST_RELEASE=%%a"
for /f "usebackq delims=" %%a in (`!PS_CMD! "(Get-Content '!MANIFEST_TEMP!' | ConvertFrom-Json).latest.snapshot"`) do set "LATEST_SNAPSHOT=%%a"

echo.
echo   Latest release:  !LATEST_RELEASE!
echo   Latest snapshot: !LATEST_SNAPSHOT!

if defined PARAM_VERSION (
    set "SELECTED_VERSION=!PARAM_VERSION!"
    goto version_done
)

echo.
echo   Select version type:
echo     [1] Latest release (!LATEST_RELEASE!^) (default)
echo     [2] Latest snapshot (!LATEST_SNAPSHOT!^)
echo     [3] Enter a specific version

set "VER_CHOICE="
set /p "VER_CHOICE=  Choice [1-3]: "
if "!VER_CHOICE!"=="" set "VER_CHOICE=1"

if "!VER_CHOICE!"=="1" set "SELECTED_VERSION=!LATEST_RELEASE!"
if "!VER_CHOICE!"=="2" set "SELECTED_VERSION=!LATEST_SNAPSHOT!"
if "!VER_CHOICE!"=="3" (
    set /p "SELECTED_VERSION=  Enter version (e.g. 1.20.4) [!LATEST_RELEASE!]: "
    if "!SELECTED_VERSION!"=="" set "SELECTED_VERSION=!LATEST_RELEASE!"
)

:version_done
echo.
echo   Selected version: !SELECTED_VERSION!

:: Get the version URL from manifest
for /f "usebackq delims=" %%a in (`!PS_CMD! "$m=Get-Content '!MANIFEST_TEMP!' | ConvertFrom-Json; ($m.versions | Where-Object {$_.id -eq '!SELECTED_VERSION!'} | Select-Object -First 1).url"`) do set "VERSION_URL=%%a"

if not defined VERSION_URL (
    echo   ERROR: Version '!SELECTED_VERSION!' not found in Mojang's manifest.
    exit /b 1
)
if "!VERSION_URL!"=="" (
    echo   ERROR: Version '!SELECTED_VERSION!' not found in Mojang's manifest.
    exit /b 1
)

:: ============================================================
::  JAVA COMPATIBILITY
:: ============================================================
call :get_required_java "!SELECTED_VERSION!" REQUIRED_JAVA
call :get_recommended_jdk !REQUIRED_JAVA! RECOMMENDED_JDK

echo.
echo   Minecraft !SELECTED_VERSION! requires Java !REQUIRED_JAVA!+

set "NEEDS_JAVA="
set "JAVA_REASON="

if !CURRENT_JAVA_MAJOR! equ 0 (
    set "NEEDS_JAVA=true"
    set "JAVA_REASON=missing"
    echo.
    echo   +------------------------------------------------------+
    echo   ^|  Java was NOT found on your system!                   ^|
    echo   ^|  Minecraft !SELECTED_VERSION! requires Java !REQUIRED_JAVA!+ to run.
    echo   +------------------------------------------------------+
) else if !CURRENT_JAVA_MAJOR! lss !REQUIRED_JAVA! (
    set "NEEDS_JAVA=true"
    set "JAVA_REASON=outdated"
    echo.
    echo   +------------------------------------------------------+
    echo   ^|  Java !CURRENT_JAVA_MAJOR! is installed, but MC !SELECTED_VERSION! needs !REQUIRED_JAVA!+
    echo   +------------------------------------------------------+
) else (
    echo   Java !CURRENT_JAVA_MAJOR! is compatible.
)

if defined NEEDS_JAVA (
    echo.
    if defined NON_INTERACTIVE (
        if defined PARAM_AUTO_INSTALL_JAVA (
            echo   Auto-installing Java !RECOMMENDED_JDK! (non-interactive mode^)...
            call :install_java !RECOMMENDED_JDK!
        ) else (
            echo   Skipping Java install (use --auto-install-java to auto-install^).
        )
    ) else (
        call :ask_yesno "  Would you like to install Java?" "n" WANT_INSTALL
        if /i "!WANT_INSTALL!"=="true" (
            echo.
            echo   Which Java version would you like to install?
            set "JDK_TAG_1="
            set "JDK_TAG_2="
            set "JDK_TAG_3="
            if !RECOMMENDED_JDK! equ 21 set "JDK_TAG_1=  ^<-- recommended for MC !SELECTED_VERSION!"
            if !RECOMMENDED_JDK! equ 17 set "JDK_TAG_2=  ^<-- recommended for MC !SELECTED_VERSION!"
            if !RECOMMENDED_JDK! equ 8  set "JDK_TAG_3=  ^<-- recommended for MC !SELECTED_VERSION!"
            echo     [1] JDK 21 -- Best for MC 1.20.5+ / 1.21+  (latest LTS^)!JDK_TAG_1!
            echo     [2] JDK 17 -- Best for MC 1.18 - 1.20.4!JDK_TAG_2!
            echo     [3] JDK 8  -- Best for MC 1.16.5 and older!JDK_TAG_3!
            set "JDK_DEFAULT=1"
            if !RECOMMENDED_JDK! equ 17 set "JDK_DEFAULT=2"
            if !RECOMMENDED_JDK! equ 8  set "JDK_DEFAULT=3"
            set "JDK_CHOICE="
            set /p "JDK_CHOICE=  Choice [1-3]: "
            if "!JDK_CHOICE!"=="" set "JDK_CHOICE=!JDK_DEFAULT!"

            set "CHOSEN_JDK=21"
            if "!JDK_CHOICE!"=="2" set "CHOSEN_JDK=17"
            if "!JDK_CHOICE!"=="3" set "CHOSEN_JDK=8"

            if !CHOSEN_JDK! lss !REQUIRED_JAVA! (
                echo.
                echo   WARNING: JDK !CHOSEN_JDK! may not work with MC !SELECTED_VERSION! (needs Java !REQUIRED_JAVA!+^).
                call :ask_yesno "  Install JDK !CHOSEN_JDK! anyway?" "n" CONFIRM_JDK
                if /i "!CONFIRM_JDK!"=="false" (
                    echo   Falling back to recommended JDK !RECOMMENDED_JDK!.
                    set "CHOSEN_JDK=!RECOMMENDED_JDK!"
                )
            )
            echo.
            call :install_java !CHOSEN_JDK!
        ) else (
            echo.
            echo   Skipping Java install.
            if "!JAVA_REASON!"=="missing" (
                echo   You'll need Java !REQUIRED_JAVA!+ before starting the server.
            ) else (
                echo   Your Java !CURRENT_JAVA_MAJOR! may not work -- MC !SELECTED_VERSION! needs Java !REQUIRED_JAVA!+.
            )
            echo   Download from: https://adoptium.net/
            call :ask_yesno "  Continue creating the server?" "n" CONT
            if /i "!CONT!"=="false" (
                echo   Exiting.
                exit /b 1
            )
        )
    )
)

:: ============================================================
::  DOWNLOAD SERVER JAR
:: ============================================================
echo   Fetching download URL for !SELECTED_VERSION!...

:: Download version JSON and extract server JAR URL
set "VERSION_TEMP=%TEMP%\mc_version.json"
!PS_CMD! "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('!VERSION_URL!','!VERSION_TEMP!')" >nul 2>&1

for /f "usebackq delims=" %%a in (`!PS_CMD! "(Get-Content '!VERSION_TEMP!' | ConvertFrom-Json).downloads.server.url"`) do set "JAR_URL=%%a"

if not defined JAR_URL (
    echo   ERROR: No server JAR available for version !SELECTED_VERSION!.
    exit /b 1
)

set "JAR_PATH=!SERVER_PATH!\server.jar"
echo   Downloading server.jar...
!PS_CMD! "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('!JAR_URL!','!JAR_PATH!')" >nul 2>&1

if not exist "!JAR_PATH!" (
    echo   ERROR: Failed to download server.jar.
    exit /b 1
)

for %%F in ("!JAR_PATH!") do set /a "JAR_SIZE_KB=%%~zF / 1024"
set /a "JAR_SIZE_MB=!JAR_SIZE_KB! / 1024"
echo   Downloaded server.jar (!JAR_SIZE_MB! MB^)

:: ============================================================
::  ACCEPT EULA
:: ============================================================
echo.
if defined PARAM_ACCEPT_EULA (
    echo   EULA accepted via --accept-eula flag.
) else if defined NON_INTERACTIVE (
    echo   ERROR: You must pass --accept-eula in non-interactive mode.
    echo   EULA: https://aka.ms/MinecraftEULA
    exit /b 1
) else (
    echo   +----------------------------------------------+
    echo   ^|  Minecraft EULA                               ^|
    echo   ^|  https://aka.ms/MinecraftEULA                 ^|
    echo   ^|  You must agree to the EULA to run a server.  ^|
    echo   +----------------------------------------------+
    call :ask_yesno "  Do you accept the Minecraft EULA?" "n" EULA_ANSWER
    if /i "!EULA_ANSWER!"=="false" (
        echo   You must accept the EULA to create a server. Exiting.
        exit /b 1
    )
)

:: Don't write eula.txt yet -- wait until after server.properties generation

:: ============================================================
::  SERVER CONFIGURATION
:: ============================================================
echo.
echo   +================================================+
echo   ^|         Server Configuration                    ^|
echo   +================================================+
echo.

:: --- General ---
call :resolve_string "PARAM_NAME" "  Server name (MOTD)" "A Minecraft Server" CFG_MOTD
call :resolve_int "PARAM_PORT" "  Server port" "25565" "1" "65535" CFG_PORT
call :resolve_int "PARAM_MAX_PLAYERS" "  Max players" "20" "1" "1000" CFG_MAX_PLAYERS
call :resolve_bool "PARAM_ONLINE_MODE" "  Online mode (authenticate with Mojang)?" "true" CFG_ONLINE_MODE
call :resolve_bool "PARAM_PVP" "  Enable PvP?" "true" CFG_PVP

if not defined NON_INTERACTIVE (
    echo.
    echo   --- Gameplay ---
)

call :resolve_bool "PARAM_HARDCORE" "  Hardcore mode?" "false" CFG_HARDCORE
call :resolve_bool "PARAM_COMMAND_BLOCKS" "  Enable command blocks?" "true" CFG_COMMAND_BLOCKS
call :resolve_bool "PARAM_ALLOW_FLIGHT" "  Allow flight?" "true" CFG_ALLOW_FLIGHT
call :resolve_bool "PARAM_ALLOW_NETHER" "  Allow the Nether?" "true" CFG_ALLOW_NETHER
call :resolve_bool "PARAM_SPAWN_NPCS" "  Spawn NPCs (villagers)?" "true" CFG_SPAWN_NPCS
call :resolve_bool "PARAM_SPAWN_ANIMALS" "  Spawn animals?" "true" CFG_SPAWN_ANIMALS
call :resolve_bool "PARAM_SPAWN_MONSTERS" "  Spawn monsters?" "true" CFG_SPAWN_MONSTERS

if not defined NON_INTERACTIVE (
    echo.
    echo   --- World ---
)

:: Difficulty
set "CFG_DIFFICULTY=normal"
if defined PARAM_DIFFICULTY (
    set "CFG_DIFFICULTY=!PARAM_DIFFICULTY!"
) else if defined NON_INTERACTIVE (
    set "CFG_DIFFICULTY=normal"
) else (
    echo.
    echo   Select difficulty:
    echo     [1] Peaceful
    echo     [2] Easy
    echo     [3] Normal (default^)
    echo     [4] Hard
    set "DIFF_CHOICE="
    set /p "DIFF_CHOICE=  Choice [1-4]: "
    if "!DIFF_CHOICE!"=="" set "DIFF_CHOICE=3"
    if "!DIFF_CHOICE!"=="1" set "CFG_DIFFICULTY=peaceful"
    if "!DIFF_CHOICE!"=="2" set "CFG_DIFFICULTY=easy"
    if "!DIFF_CHOICE!"=="3" set "CFG_DIFFICULTY=normal"
    if "!DIFF_CHOICE!"=="4" set "CFG_DIFFICULTY=hard"
)

:: Gamemode
set "CFG_GAMEMODE=survival"
if defined PARAM_GAMEMODE (
    set "CFG_GAMEMODE=!PARAM_GAMEMODE!"
) else if defined NON_INTERACTIVE (
    set "CFG_GAMEMODE=survival"
) else (
    echo.
    echo   Select default gamemode:
    echo     [1] Survival (default^)
    echo     [2] Creative
    echo     [3] Adventure
    echo     [4] Spectator
    set "GM_CHOICE="
    set /p "GM_CHOICE=  Choice [1-4]: "
    if "!GM_CHOICE!"=="" set "GM_CHOICE=1"
    if "!GM_CHOICE!"=="1" set "CFG_GAMEMODE=survival"
    if "!GM_CHOICE!"=="2" set "CFG_GAMEMODE=creative"
    if "!GM_CHOICE!"=="3" set "CFG_GAMEMODE=adventure"
    if "!GM_CHOICE!"=="4" set "CFG_GAMEMODE=spectator"
)

:: World type
set "CFG_LEVEL_TYPE=minecraft:normal"
if defined PARAM_LEVEL_TYPE (
    set "LT_VAL=!PARAM_LEVEL_TYPE!"
    if /i "!LT_VAL!"=="normal"      set "CFG_LEVEL_TYPE=minecraft:normal"
    if /i "!LT_VAL!"=="flat"        set "CFG_LEVEL_TYPE=minecraft:flat"
    if /i "!LT_VAL!"=="largebiomes" set "CFG_LEVEL_TYPE=minecraft:large_biomes"
    if /i "!LT_VAL!"=="amplified"   set "CFG_LEVEL_TYPE=minecraft:amplified"
) else if defined NON_INTERACTIVE (
    set "CFG_LEVEL_TYPE=minecraft:normal"
) else (
    echo.
    echo   Select world type:
    echo     [1] Normal (default^)
    echo     [2] Flat
    echo     [3] Large Biomes
    echo     [4] Amplified
    set "WT_CHOICE="
    set /p "WT_CHOICE=  Choice [1-4]: "
    if "!WT_CHOICE!"=="" set "WT_CHOICE=1"
    if "!WT_CHOICE!"=="1" set "CFG_LEVEL_TYPE=minecraft:normal"
    if "!WT_CHOICE!"=="2" set "CFG_LEVEL_TYPE=minecraft:flat"
    if "!WT_CHOICE!"=="3" set "CFG_LEVEL_TYPE=minecraft:large_biomes"
    if "!WT_CHOICE!"=="4" set "CFG_LEVEL_TYPE=minecraft:amplified"
)

call :resolve_string "PARAM_LEVEL_NAME" "  World/level name" "world" CFG_LEVEL_NAME
call :resolve_string "PARAM_LEVEL_SEED" "  World seed (leave blank for random)" "" CFG_LEVEL_SEED

if not defined NON_INTERACTIVE (
    echo.
    echo   --- Performance ---
)

call :resolve_int "PARAM_MAX_RAM" "  Max RAM for server (MB)" "2048" "512" "32768" CFG_MAX_RAM
call :resolve_bool "PARAM_WHITELIST" "  Enable whitelist?" "false" CFG_WHITELIST

:: ============================================================
::  BUILD SERVER.PROPERTIES
:: ============================================================
echo.
echo   Generating server.properties...

set "PROPS_PATH=!SERVER_PATH!\server.properties"

:: Run server once to generate defaults (without eula, it will exit immediately)
if not exist "!PROPS_PATH!" (
    :: Make sure eula.txt does NOT exist so the server exits right away
    if exist "!SERVER_PATH!\eula.txt" del /q "!SERVER_PATH!\eula.txt"
    echo   Running server once to generate defaults (will exit automatically^)...
    pushd "!SERVER_PATH!"
    java -Xmx256M -Xms256M -jar server.jar nogui >nul 2>&1
    popd
    if not exist "!PROPS_PATH!" (
        echo   Could not auto-generate defaults, creating from scratch.
        echo #Minecraft server properties> "!PROPS_PATH!"
    )
)

:: Use PowerShell to do the line-by-line replacement (CMD can't handle this well)
echo   Updating server.properties with your settings...

!PS_CMD! ^
  "$settings = @{" ^
    "'motd'='!CFG_MOTD!';" ^
    "'server-port'='!CFG_PORT!';" ^
    "'max-players'='!CFG_MAX_PLAYERS!';" ^
    "'online-mode'='!CFG_ONLINE_MODE!';" ^
    "'pvp'='!CFG_PVP!';" ^
    "'white-list'='!CFG_WHITELIST!';" ^
    "'enforce-whitelist'='!CFG_WHITELIST!';" ^
    "'hardcore'='!CFG_HARDCORE!';" ^
    "'enable-command-block'='!CFG_COMMAND_BLOCKS!';" ^
    "'allow-flight'='!CFG_ALLOW_FLIGHT!';" ^
    "'allow-nether'='!CFG_ALLOW_NETHER!';" ^
    "'spawn-npcs'='!CFG_SPAWN_NPCS!';" ^
    "'spawn-animals'='!CFG_SPAWN_ANIMALS!';" ^
    "'spawn-monsters'='!CFG_SPAWN_MONSTERS!';" ^
    "'difficulty'='!CFG_DIFFICULTY!';" ^
    "'gamemode'='!CFG_GAMEMODE!';" ^
    "'level-name'='!CFG_LEVEL_NAME!';" ^
    "'level-seed'='!CFG_LEVEL_SEED!';" ^
    "'level-type'='!CFG_LEVEL_TYPE!'" ^
  "};" ^
  "$f='!PROPS_PATH!';" ^
  "$lines=Get-Content $f;" ^
  "$written=@{};" ^
  "$out=$lines|ForEach-Object{" ^
    "if($_ -match '^\s*([a-zA-Z0-9\-]+)\s*='){" ^
      "$k=$Matches[1];" ^
      "if($settings.ContainsKey($k)){$written[$k]=1;\"$k=$($settings[$k])\"}" ^
      "else{$_}" ^
    "}else{$_}" ^
  "};" ^
  "$missing=$settings.Keys|Where-Object{-not $written.ContainsKey($_)};" ^
  "if($missing.Count -gt 0){$out+='';$out+='# Added by Create-MCServer.cmd';foreach($k in $missing){$out+=\"$k=$($settings[$k])\"}};" ^
  "Set-Content $f $out -Force;" ^
  "Write-Host \"  server.properties saved ($($written.Count) updated, $($missing.Count) added).\""

:: ============================================================
::  WRITE EULA.TXT (after server.properties so first run exits fast)
:: ============================================================
echo # Minecraft EULA - accepted via Create-MCServer.cmd> "!SERVER_PATH!\eula.txt"
echo eula=true>> "!SERVER_PATH!\eula.txt"
echo   eula.txt written.

:: ============================================================
::  CREATE START SCRIPTS
:: ============================================================
echo   Generating start scripts...

:: start.bat
(
    echo @echo off
    echo title Minecraft Server - !CFG_MOTD!
    echo cd /d "%%~dp0"
    echo echo Starting Minecraft Server...
    echo echo RAM: !CFG_MAX_RAM!MB ^^^| Port: !CFG_PORT! ^^^| Version: !SELECTED_VERSION!
    echo echo Press Ctrl+C or type 'stop' to shut down.
    echo echo.
    echo java -Xmx!CFG_MAX_RAM!M -Xms!CFG_MAX_RAM!M -jar server.jar nogui
    echo pause
) > "!SERVER_PATH!\start.bat"

:: start.ps1
(
    echo # Start Minecraft Server
    echo # Generated by Create-MCServer.cmd
    echo.
    echo $Host.UI.RawUI.WindowTitle = "Minecraft Server - !CFG_MOTD!"
    echo Set-Location "$PSScriptRoot"
    echo.
    echo Write-Host "Starting Minecraft Server..." -ForegroundColor Green
    echo Write-Host "RAM: !CFG_MAX_RAM!MB ^| Port: !CFG_PORT! ^| Version: !SELECTED_VERSION!" -ForegroundColor Cyan
    echo Write-Host "Press Ctrl+C or type 'stop' to shut down." -ForegroundColor Yellow
    echo Write-Host ""
    echo.
    echo java -Xmx!CFG_MAX_RAM!M -Xms!CFG_MAX_RAM!M -jar server.jar nogui
) > "!SERVER_PATH!\start.ps1"

echo   start.bat and start.ps1 created.

:: ============================================================
::  SUMMARY
:: ============================================================
echo.
echo   +================================================+
echo   ^|         Server Created Successfully!             ^|
echo   +================================================+
echo.
echo   Location:       !SERVER_PATH!
echo   Version:        !SELECTED_VERSION!
echo   Port:           !CFG_PORT!
echo   Gamemode:       !CFG_GAMEMODE!
echo   Difficulty:     !CFG_DIFFICULTY!
echo   Hardcore:       !CFG_HARDCORE!
echo   Command Blocks: !CFG_COMMAND_BLOCKS!
echo   Allow Flight:   !CFG_ALLOW_FLIGHT!
echo   Max RAM:        !CFG_MAX_RAM!MB
echo.
echo   To start your server:
echo     cd "!SERVER_PATH!"
echo     start.bat       (Command Prompt^)
echo     .\start.ps1     (PowerShell^)
echo.
echo   Happy crafting!
echo.

:: Clean up temp files
if exist "!MANIFEST_TEMP!" del /q "!MANIFEST_TEMP!" >nul 2>&1
if exist "!VERSION_TEMP!" del /q "!VERSION_TEMP!" >nul 2>&1

exit /b 0

:: ============================================================
::  SUBROUTINES
:: ============================================================

:: ---- ask_yesno ----
:: Usage: call :ask_yesno "prompt" "default(y/n)" RESULT_VAR
:ask_yesno
set "_AYN_PROMPT=%~1"
set "_AYN_DEFAULT=%~2"
set "_AYN_VAR=%~3"
if /i "!_AYN_DEFAULT!"=="y" (
    set "_AYN_TAG=Y/n"
) else (
    set "_AYN_TAG=y/N"
)
:ask_yesno_loop
set "_AYN_INPUT="
set /p "_AYN_INPUT=!_AYN_PROMPT! [!_AYN_TAG!]: "
if "!_AYN_INPUT!"=="" (
    if /i "!_AYN_DEFAULT!"=="y" ( set "!_AYN_VAR!=true" ) else ( set "!_AYN_VAR!=false" )
    goto :eof
)
if /i "!_AYN_INPUT!"=="y"   ( set "!_AYN_VAR!=true"  & goto :eof )
if /i "!_AYN_INPUT!"=="yes" ( set "!_AYN_VAR!=true"  & goto :eof )
if /i "!_AYN_INPUT!"=="n"   ( set "!_AYN_VAR!=false" & goto :eof )
if /i "!_AYN_INPUT!"=="no"  ( set "!_AYN_VAR!=false" & goto :eof )
echo   Please enter y or n.
goto ask_yesno_loop

:: ---- parse_bool ----
:: Usage: call :parse_bool "value" RESULT_VAR
:parse_bool
set "_PB_VAL=%~1"
set "_PB_VAR=%~2"
if /i "!_PB_VAL!"=="true"  ( set "!_PB_VAR!=true"  & goto :eof )
if /i "!_PB_VAL!"=="yes"   ( set "!_PB_VAR!=true"  & goto :eof )
if /i "!_PB_VAL!"=="1"     ( set "!_PB_VAR!=true"  & goto :eof )
if /i "!_PB_VAL!"=="y"     ( set "!_PB_VAR!=true"  & goto :eof )
if /i "!_PB_VAL!"=="false" ( set "!_PB_VAR!=false" & goto :eof )
if /i "!_PB_VAL!"=="no"    ( set "!_PB_VAR!=false" & goto :eof )
if /i "!_PB_VAL!"=="0"     ( set "!_PB_VAR!=false" & goto :eof )
if /i "!_PB_VAL!"=="n"     ( set "!_PB_VAR!=false" & goto :eof )
set "!_PB_VAR!="
goto :eof

:: ---- resolve_bool ----
:: Usage: call :resolve_bool "PARAM_VAR_NAME" "prompt" "default" RESULT_VAR
:resolve_bool
set "_RB_PARAM_NAME=%~1"
set "_RB_PROMPT=%~2"
set "_RB_DEFAULT=%~3"
set "_RB_VAR=%~4"
:: Check if the parameter variable has a value
set "_RB_PARAM_VAL=!%_RB_PARAM_NAME%!"
if defined _RB_PARAM_VAL (
    call :parse_bool "!_RB_PARAM_VAL!" !_RB_VAR!
    if defined !_RB_VAR! goto :eof
)
if defined NON_INTERACTIVE (
    set "!_RB_VAR!=!_RB_DEFAULT!"
    goto :eof
)
:: Map default to y/n for ask_yesno
if /i "!_RB_DEFAULT!"=="true" (
    call :ask_yesno "!_RB_PROMPT!" "y" !_RB_VAR!
) else (
    call :ask_yesno "!_RB_PROMPT!" "n" !_RB_VAR!
)
goto :eof

:: ---- resolve_int ----
:: Usage: call :resolve_int "PARAM_VAR_NAME" "prompt" "default" "min" "max" RESULT_VAR
:resolve_int
set "_RI_PARAM_NAME=%~1"
set "_RI_PROMPT=%~2"
set "_RI_DEFAULT=%~3"
set "_RI_MIN=%~4"
set "_RI_MAX=%~5"
set "_RI_VAR=%~6"
set "_RI_PARAM_VAL=!%_RI_PARAM_NAME%!"
if defined _RI_PARAM_VAL if not "!_RI_PARAM_VAL!"=="0" (
    set "!_RI_VAR!=!_RI_PARAM_VAL!"
    goto :eof
)
if defined NON_INTERACTIVE (
    set "!_RI_VAR!=!_RI_DEFAULT!"
    goto :eof
)
:resolve_int_loop
set "_RI_INPUT="
set /p "_RI_INPUT=!_RI_PROMPT! [!_RI_DEFAULT!]: "
if "!_RI_INPUT!"=="" (
    set "!_RI_VAR!=!_RI_DEFAULT!"
    goto :eof
)
:: Validate numeric
set /a "_RI_NUM=!_RI_INPUT!" 2>nul
if !_RI_NUM! geq !_RI_MIN! if !_RI_NUM! leq !_RI_MAX! (
    set "!_RI_VAR!=!_RI_NUM!"
    goto :eof
)
echo   Please enter a number between !_RI_MIN! and !_RI_MAX!.
goto resolve_int_loop

:: ---- resolve_string ----
:: Usage: call :resolve_string "PARAM_VAR_NAME" "prompt" "default" RESULT_VAR
:resolve_string
set "_RS_PARAM_NAME=%~1"
set "_RS_PROMPT=%~2"
set "_RS_DEFAULT=%~3"
set "_RS_VAR=%~4"
set "_RS_PARAM_VAL=!%_RS_PARAM_NAME%!"
if defined _RS_PARAM_VAL (
    set "!_RS_VAR!=!_RS_PARAM_VAL!"
    goto :eof
)
if defined NON_INTERACTIVE (
    set "!_RS_VAR!=!_RS_DEFAULT!"
    goto :eof
)
set "_RS_INPUT="
set /p "_RS_INPUT=!_RS_PROMPT! [!_RS_DEFAULT!]: "
if "!_RS_INPUT!"=="" (
    set "!_RS_VAR!=!_RS_DEFAULT!"
) else (
    set "!_RS_VAR!=!_RS_INPUT!"
)
goto :eof

:: ---- get_required_java ----
:: Usage: call :get_required_java "version" RESULT_VAR
:get_required_java
set "_GRJ_VER=%~1"
set "_GRJ_VAR=%~2"

:: Snapshot detection (e.g. 24w14a)
echo !_GRJ_VER! | findstr /r "^[0-9][0-9]w" >nul 2>&1
if !errorlevel! equ 0 (
    set "_SNAP_YEAR=!_GRJ_VER:~0,2!"
    if !_SNAP_YEAR! geq 24 ( set "!_GRJ_VAR!=21" & goto :eof )
    if !_SNAP_YEAR! geq 21 ( set "!_GRJ_VAR!=17" & goto :eof )
    set "!_GRJ_VAR!=8"
    goto :eof
)

:: Strip pre-release suffix and parse
for /f "tokens=1,2,3 delims=.-" %%a in ("!_GRJ_VER!") do (
    set "_GRJ_MAJOR=%%a"
    set "_GRJ_MINOR=%%b"
    set "_GRJ_PATCH=%%c"
)
if not defined _GRJ_MINOR set "_GRJ_MINOR=0"
if not defined _GRJ_PATCH set "_GRJ_PATCH=0"
:: Remove any non-numeric from patch
for /f "tokens=1 delims=abcdefghijklmnopqrstuvwxyz " %%x in ("!_GRJ_PATCH!") do set "_GRJ_PATCH=%%x"
if not defined _GRJ_PATCH set "_GRJ_PATCH=0"

if not "!_GRJ_MAJOR!"=="1" ( set "!_GRJ_VAR!=21" & goto :eof )
if !_GRJ_MINOR! geq 21 ( set "!_GRJ_VAR!=21" & goto :eof )
if !_GRJ_MINOR! equ 20 if !_GRJ_PATCH! geq 5 ( set "!_GRJ_VAR!=21" & goto :eof )
if !_GRJ_MINOR! geq 18 ( set "!_GRJ_VAR!=17" & goto :eof )
if !_GRJ_MINOR! equ 17 ( set "!_GRJ_VAR!=16" & goto :eof )
set "!_GRJ_VAR!=8"
goto :eof

:: ---- get_recommended_jdk ----
:: Usage: call :get_recommended_jdk MIN_JAVA RESULT_VAR
:get_recommended_jdk
set "_GRJDK_MIN=%~1"
set "_GRJDK_VAR=%~2"
if !_GRJDK_MIN! leq 8  ( set "!_GRJDK_VAR!=8"  & goto :eof )
if !_GRJDK_MIN! leq 17 ( set "!_GRJDK_VAR!=17" & goto :eof )
set "!_GRJDK_VAR!=21"
goto :eof

:: ---- install_java ----
:: Usage: call :install_java JDK_VERSION
:install_java
set "_IJ_VER=%~1"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" ( set "_IJ_ARCH=x64" ) else ( set "_IJ_ARCH=x86" )

echo.
echo   Downloading Eclipse Temurin JDK !_IJ_VER! (!_IJ_ARCH!^)...
echo   Source: adoptium.net (Eclipse Foundation^)

set "_IJ_API=https://api.adoptium.net/v3/assets/latest/!_IJ_VER!/hotspot?architecture=!_IJ_ARCH!^&image_type=jdk^&os=windows^&vendor=eclipse"
set "_IJ_JSON=%TEMP%\mc_java_assets.json"

!PS_CMD! "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('!_IJ_API!','!_IJ_JSON!')" >nul 2>&1

:: Extract MSI download URL
for /f "usebackq delims=" %%a in (`!PS_CMD! "$j=Get-Content '!_IJ_JSON!' | ConvertFrom-Json; ($j | Where-Object {$_.binary.installer.link -like '*.msi'} | Select-Object -First 1).binary.installer.link"`) do set "_IJ_MSI_URL=%%a"

if not defined _IJ_MSI_URL (
    echo   ERROR: Could not find JDK installer.
    goto :eof
)

set "_IJ_MSI_PATH=%TEMP%\temurin-jdk-!_IJ_VER!.msi"
echo   Downloading installer...
!PS_CMD! "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('!_IJ_MSI_URL!','!_IJ_MSI_PATH!')" >nul 2>&1

if not exist "!_IJ_MSI_PATH!" (
    echo   ERROR: Failed to download installer.
    goto :eof
)

echo   Running installer (you may see a UAC prompt^)...
msiexec /i "!_IJ_MSI_PATH!" ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome,FeatureOracleJavaSoft INSTALLDIR="C:\Program Files\Eclipse Adoptium\jdk-!_IJ_VER!" /qb /norestart

:: Refresh PATH
set "PATH=C:\Program Files\Eclipse Adoptium\jdk-!_IJ_VER!\bin;%PATH%"

:: Verify
where java >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%a in ('java -version 2^>^&1 ^| findstr /i "version"') do echo   Java installed: %%~a
) else (
    echo   Java installed but may need a terminal restart.
)

:: Clean up
if exist "!_IJ_MSI_PATH!" del /q "!_IJ_MSI_PATH!" >nul 2>&1
if exist "!_IJ_JSON!" del /q "!_IJ_JSON!" >nul 2>&1
goto :eof

:: ---- show_help ----
:show_help
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   --path PATH            Server directory
echo   --version VER          Minecraft version (e.g. 1.21.4^)
echo   --accept-eula          Accept the Minecraft EULA
echo   --auto-install-java    Auto-install Java if missing
echo   --name NAME            Server name / MOTD
echo   --port PORT            Server port
echo   --max-players N        Max players
echo   --online-mode BOOL     Online mode (true/false^)
echo   --pvp BOOL             PvP (true/false^)
echo   --hardcore BOOL        Hardcore (true/false^)
echo   --command-blocks BOOL  Command blocks (true/false^)
echo   --allow-flight BOOL    Allow flight (true/false^)
echo   --allow-nether BOOL    Allow nether (true/false^)
echo   --spawn-npcs BOOL      Spawn NPCs (true/false^)
echo   --spawn-animals BOOL   Spawn animals (true/false^)
echo   --spawn-monsters BOOL  Spawn monsters (true/false^)
echo   --difficulty DIFF      peaceful/easy/normal/hard
echo   --gamemode MODE        survival/creative/adventure/spectator
echo   --level-type TYPE      normal/flat/largebiomes/amplified
echo   --level-name NAME      World folder name
echo   --level-seed SEED      World seed
echo   --max-ram MB           Max RAM in MB
echo   --whitelist BOOL       Enable whitelist (true/false^)
echo   --help                 Show this help
exit /b 0
