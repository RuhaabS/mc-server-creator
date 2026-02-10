<div align="center">

<img src="assets/logo.svg" alt="Minecraft Server Creator" width="150">

<br>

# ⛏️ Minecraft Server Creator

**One command to set up a fully configured Minecraft Java Edition server.**

Automatic Java detection & install · Version picker · Paper + Plugins · Interactive or scripted · Windows & Linux

[![Windows](https://img.shields.io/badge/Windows-0078D4?logo=windows&logoColor=white)](#method-1--powershell-%EF%B8%8F)
[![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](#method-2--bash-)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Donate-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/ruhaabs)

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎮 **Version Picker** | Choose any release, snapshot, or specific version from Mojang's manifest |
| 📦 **Server Type** | Vanilla (Mojang) or Paper (high-performance with plugin support) |
| 🔌 **Plugin Installer** | Curated list of 13 popular plugins with one-command install (Paper only) |
| ☕ **Auto Java Install** | Detects installed Java, checks MC version compatibility, offers to install the right JDK |
| 📋 **Full Server Config** | Interactive prompts for MOTD, gamemode, difficulty, world type, PvP, hardcore, and more |
| 📝 **Smart server.properties** | Generates Minecraft defaults first, then only replaces what you changed |
| 🚀 **Start Scripts** | Auto-generates ready-to-run start scripts with your RAM settings |
| 🤖 **Non-Interactive Mode** | Pass all options as flags for fully automated / CI / Docker setups |
| 🔗 **Pipe-Friendly** | Run directly from a URL without downloading |

---

## 🚀 How to Create a Minecraft Server

### Method 1 — PowerShell

> Best for **Windows 10 / 11**

1. Open **PowerShell** (Start Menu → type `PowerShell`)
2. Copy-paste and press **Enter**:

```powershell
irm https://raw.githubusercontent.com/RuhaabS/mc-server-creator/main/Create-MCServer.ps1 | iex
```

3. Follow the interactive wizard!

**Or download and run directly:**

```powershell
.\Create-MCServer.ps1
```

---

### Method 2 — Bash

> Best for **Ubuntu / Debian / Fedora / Arch / any Linux**

1. Open a **Terminal**
2. Copy-paste and press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/RuhaabS/mc-server-creator/main/create-mcserver.sh | bash
```

3. Follow the interactive wizard!

**Or download and run directly:**

```bash
chmod +x create-mcserver.sh
./create-mcserver.sh
```

## 🤖 Non-Interactive Mode

Pass `--version` (or `-Version`) and `--path` (or `-ServerPath`) to skip all prompts.  
All other settings fall back to sensible defaults unless you override them.

<details>
<summary><b>PowerShell Example</b></summary>

```powershell
.\Create-MCServer.ps1 `
    -ServerPath "C:\mc-server" `
    -Version "1.21.4" `    -ServerType paper `    -AcceptEula `
    -AutoInstallJava `
    -Hardcore true `
    -MaxRam 4096 `
    -Difficulty hard `
    -Gamemode survival
```

</details>

<details>
<summary><b>Bash Example</b></summary>

```bash
./create-mcserver.sh \
    --path ~/mc-server \
    --version 1.21.4 \
    --server-type paper \
    --accept-eula \
    --auto-install-java \
    --hardcore true \
    --max-ram 4096 \
    --difficulty hard \
    --gamemode survival
```

</details>

---

## 📋 Parameters Reference

### Core

| Parameter | PS1 | Bash | Default | Description |
|---|---|---|---|---|
| Server Path | `-ServerPath` | `--path` | *(prompted)* | Directory where server files are created |
| Version | `-Version` | `--version` | *(prompted)* | Minecraft version (e.g. `1.21.4`, `1.20.1`) |
| Server Type | `-ServerType` | `--server-type` | *(prompted)* | `vanilla` or `paper` |
| Accept EULA | `-AcceptEula` | `--accept-eula` | *(prompted)* | Accept the [Minecraft EULA](https://aka.ms/MinecraftEULA) |
| Auto Install Java | `-AutoInstallJava` | `--auto-install-java` | `false` | Automatically install Java if missing/outdated |

### Server Settings

| Parameter | PS1 | Bash | Default | Description |
|---|---|---|---|---|
| Server Name | `-ServerName` | `--name` | `A Minecraft Server` | MOTD shown in server list |
| Port | `-ServerPort` | `--port` | `25565` | Server port |
| Max Players | `-MaxPlayers` | `--max-players` | `20` | Maximum player count |
| Online Mode | `-OnlineMode` | `--online-mode` | `true` | Authenticate players with Mojang |
| PvP | `-Pvp` | `--pvp` | `true` | Player vs Player combat |
| Whitelist | `-Whitelist` | `--whitelist` | `false` | Enable whitelist |

### Gameplay

| Parameter | PS1 | Bash | Default | Description |
|---|---|---|---|---|
| Hardcore | `-Hardcore` | `--hardcore` | `false` | One life — death = ban |
| Command Blocks | `-CommandBlocks` | `--command-blocks` | `true` | Enable command blocks |
| Allow Flight | `-AllowFlight` | `--allow-flight` | `true` | Allow flying (required for some mods) |
| Allow Nether | `-AllowNether` | `--allow-nether` | `true` | Enable the Nether dimension |
| Spawn NPCs | `-SpawnNpcs` | `--spawn-npcs` | `true` | Spawn villagers |
| Spawn Animals | `-SpawnAnimals` | `--spawn-animals` | `true` | Spawn passive mobs |
| Spawn Monsters | `-SpawnMonsters` | `--spawn-monsters` | `true` | Spawn hostile mobs |

### World

| Parameter | PS1 | Bash | Default | Description |
|---|---|---|---|---|
| Difficulty | `-Difficulty` | `--difficulty` | `normal` | `peaceful` · `easy` · `normal` · `hard` |
| Gamemode | `-Gamemode` | `--gamemode` | `survival` | `survival` · `creative` · `adventure` · `spectator` |
| Level Type | `-LevelType` | `--level-type` | `normal` | `normal` · `flat` · `largebiomes` · `amplified` |
| Level Name | `-LevelName` | `--level-name` | `world` | World folder name |
| Level Seed | `-LevelSeed` | `--level-seed` | *(random)* | World generation seed |

### Performance

| Parameter | PS1 | Bash | Default | Description |
|---|---|---|---|---|
| Max RAM | `-MaxRam` | `--max-ram` | `2048` | Max server RAM in MB (512–32768) |

---

## 🔌 Plugin Support (Paper Only)

When you choose **Paper** as the server type, you'll be offered a curated selection of popular plugins to install automatically:

| # | Plugin | Description | Source |
|---|---|---|---|
| 1 | **EssentialsX** | Essential commands (home, tp, spawn, kits) | GitHub |
| 2 | **LuckPerms** | Advanced permissions management | Jenkins CI |
| 3 | **ViaVersion** | Allow newer clients on older servers | Hangar |
| 4 | **ViaBackwards** | Allow older clients on newer servers | Hangar |
| 5 | **Geyser** | Allow Bedrock Edition players to join | Direct URL |
| 6 | **Floodgate** | Bedrock auth (companion to Geyser) | Direct URL |
| 7 | **Chunky** | Pre-generate world chunks | Hangar |
| 8 | **spark** | Performance profiler and monitoring | Jenkins CI |
| 9 | **BlueMap** | 3D web-based live map of your world | Hangar |
| 10 | **squaremap** | Minimalistic & lightweight web map | Hangar |
| 11 | **Timber** | Chop entire trees by breaking one log | Modrinth |
| 12 | **AuraSkills** | RPG skills & leveling (mcMMO alternative) | Hangar |
| 13 | **AuraMobs** | Mob levels add-on for AuraSkills | Modrinth |

You can install individual plugins by number (`1,2,5`), type `all` to install everything, or `search` to find more plugins on Hangar.

---

## ☕ Java Auto-Detection

The script automatically maps Minecraft versions to their required Java version:

| Minecraft Version | Required Java | Installed JDK |
|---|---|---|
| **1.21+** / **1.20.5+** | Java 21+ | Temurin JDK 21 (LTS) |
| **1.18** — **1.20.4** | Java 17+ | Temurin JDK 17 (LTS) |
| **1.17** — **1.17.1** | Java 16+ | Temurin JDK 17 (LTS) |
| **≤ 1.16.5** | Java 8+ | Temurin JDK 8 (LTS) |

If Java is missing or outdated, you'll be offered an automatic install:
- **Windows:** Downloads and runs the Adoptium MSI installer
- **Linux:** Uses your package manager (`apt`, `dnf`, `pacman`, `zypper`) or falls back to a tar.gz download

---

## 📁 What Gets Created

```
your-server-folder/
├── server.jar            ← Downloaded from Mojang / Paper
├── eula.txt              ← Auto-accepted
├── server.properties     ← Your custom settings
├── plugins/              ← Installed plugins (Paper only)
│   ├── EssentialsX.jar
│   ├── LuckPerms-Bukkit.jar
│   └── ...
├── start.sh              ← Linux start script (bash only)
├── start.bat             ← Windows start script
└── start.ps1             ← PowerShell start script
```

**To start your server**, just run the appropriate start script:

```bash
# Linux
./start.sh

# Windows (PowerShell)
.\start.ps1
```

---

## 🛠️ Requirements

| Platform | Requirements |
|---|---|
| **Windows (PS1)** | PowerShell 5.1+ (pre-installed on Windows 10/11) |
| **Linux (Bash)** | `bash` 4+, `curl` or `wget`, `jq` (auto-installed if missing) |
| **All** | Internet connection for first-time setup |

---

<div align="center">

**Happy Crafting! ⛏️**

Made with ❤️

<a href="https://ko-fi.com/ruhaabs">
  <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support on Ko-fi">
</a>

</div>
