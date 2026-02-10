#!/usr/bin/env bash
# ============================================================
#  Minecraft Server Creator Script (Linux)
#  Creates a Minecraft Java Edition server with custom settings
#
#  Run directly:  ./create-mcserver.sh
# ============================================================

set -euo pipefail

# ---- Color codes ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ---- Defaults (overridden by CLI flags) ----
SERVER_PATH=""
MC_VERSION=""
ACCEPT_EULA=false
AUTO_INSTALL_JAVA=false
OPT_SERVER_NAME=""
OPT_SERVER_PORT=""
OPT_MAX_PLAYERS=""
OPT_ONLINE_MODE=""
OPT_PVP=""
OPT_HARDCORE=""
OPT_COMMAND_BLOCKS=""
OPT_ALLOW_FLIGHT=""
OPT_ALLOW_NETHER=""
OPT_SPAWN_NPCS=""
OPT_SPAWN_ANIMALS=""
OPT_SPAWN_MONSTERS=""
OPT_DIFFICULTY=""
OPT_GAMEMODE=""
OPT_LEVEL_TYPE=""
OPT_LEVEL_NAME=""
OPT_LEVEL_SEED=""
OPT_MAX_RAM=""
OPT_WHITELIST=""
OPT_SERVER_TYPE=""

# ---- Parse CLI arguments ----
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --path PATH            Server directory"
    echo "  --version VER          Minecraft version (e.g. 1.21.4)"
    echo "  --server-type TYPE     Server type (vanilla/paper)"
    echo "  --accept-eula          Accept the Minecraft EULA"
    echo "  --auto-install-java    Auto-install Java if missing"
    echo "  --name NAME            Server name / MOTD"
    echo "  --port PORT            Server port"
    echo "  --max-players N        Max players"
    echo "  --online-mode BOOL     Online mode (true/false)"
    echo "  --pvp BOOL             PvP (true/false)"
    echo "  --hardcore BOOL        Hardcore (true/false)"
    echo "  --command-blocks BOOL  Command blocks (true/false)"
    echo "  --allow-flight BOOL    Allow flight (true/false)"
    echo "  --allow-nether BOOL    Allow nether (true/false)"
    echo "  --spawn-npcs BOOL      Spawn NPCs (true/false)"
    echo "  --spawn-animals BOOL   Spawn animals (true/false)"
    echo "  --spawn-monsters BOOL  Spawn monsters (true/false)"
    echo "  --difficulty DIFF      peaceful/easy/normal/hard"
    echo "  --gamemode MODE        survival/creative/adventure/spectator"
    echo "  --level-type TYPE      normal/flat/largebiomes/amplified"
    echo "  --level-name NAME      World folder name"
    echo "  --level-seed SEED      World seed"
    echo "  --max-ram MB           Max RAM in MB"
    echo "  --whitelist BOOL       Enable whitelist (true/false)"
    echo "  --help                 Show this help"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)            SERVER_PATH="$2"; shift 2 ;;
        --version)         MC_VERSION="$2"; shift 2 ;;
        --accept-eula)     ACCEPT_EULA=true; shift ;;
        --auto-install-java) AUTO_INSTALL_JAVA=true; shift ;;
        --name)            OPT_SERVER_NAME="$2"; shift 2 ;;
        --port)            OPT_SERVER_PORT="$2"; shift 2 ;;
        --max-players)     OPT_MAX_PLAYERS="$2"; shift 2 ;;
        --online-mode)     OPT_ONLINE_MODE="$2"; shift 2 ;;
        --pvp)             OPT_PVP="$2"; shift 2 ;;
        --hardcore)        OPT_HARDCORE="$2"; shift 2 ;;
        --command-blocks)  OPT_COMMAND_BLOCKS="$2"; shift 2 ;;
        --allow-flight)    OPT_ALLOW_FLIGHT="$2"; shift 2 ;;
        --allow-nether)    OPT_ALLOW_NETHER="$2"; shift 2 ;;
        --spawn-npcs)      OPT_SPAWN_NPCS="$2"; shift 2 ;;
        --spawn-animals)   OPT_SPAWN_ANIMALS="$2"; shift 2 ;;
        --spawn-monsters)  OPT_SPAWN_MONSTERS="$2"; shift 2 ;;
        --difficulty)      OPT_DIFFICULTY="$2"; shift 2 ;;
        --gamemode)        OPT_GAMEMODE="$2"; shift 2 ;;
        --level-type)      OPT_LEVEL_TYPE="$2"; shift 2 ;;
        --level-name)      OPT_LEVEL_NAME="$2"; shift 2 ;;
        --level-seed)      OPT_LEVEL_SEED="$2"; shift 2 ;;
        --max-ram)         OPT_MAX_RAM="$2"; shift 2 ;;
        --whitelist)       OPT_WHITELIST="$2"; shift 2 ;;
        --server-type)     OPT_SERVER_TYPE="$2"; shift 2 ;;
        --help)            print_usage; exit 0 ;;
        *) echo "Unknown option: $1"; print_usage; exit 1 ;;
    esac
done

# Non-interactive if both path and version are given
NON_INTERACTIVE=false
if [[ -n "$SERVER_PATH" && -n "$MC_VERSION" ]]; then
    NON_INTERACTIVE=true
fi

# ---- Helper functions ----

parse_bool() {
    local val="${1,,}"  # lowercase
    case "$val" in
        true|yes|1|y)  echo "true" ;;
        false|no|0|n)  echo "false" ;;
        *)             echo "" ;;
    esac
}

bool_str() {
    if [[ "$1" == "true" ]]; then echo "true"; else echo "false"; fi
}

ask_yesno() {
    local prompt="$1"
    local default="${2:-false}"
    local default_text
    if [[ "$default" == "true" ]]; then default_text="Y/n"; else default_text="y/N"; fi

    while true; do
        read -rp "$(echo -e "${WHITE}${prompt} [${default_text}]:${NC} ")" answer < /dev/tty
        if [[ -z "$answer" ]]; then
            echo "$default"; return
        fi
        case "${answer,,}" in
            y|yes) echo "true"; return ;;
            n|no)  echo "false"; return ;;
            *)     echo -e "  ${YELLOW}Please enter y or n.${NC}" >&2 ;;
        esac
    done
}

ask_choice() {
    local prompt="$1"
    shift
    local default="$1"
    shift
    local options=("$@")
    local count=${#options[@]}

    echo "" >&2
    echo -e "  ${WHITE}${prompt}${NC}" >&2
    for i in "${!options[@]}"; do
        local num=$((i + 1))
        local marker=""
        if [[ $i -eq $default ]]; then marker=" (default)"; fi
        echo -e "    ${GRAY}[${num}] ${options[$i]}${marker}${NC}" >&2
    done

    while true; do
        read -rp "  Choice [1-${count}]: " input < /dev/tty
        if [[ -z "$input" ]]; then echo "$default"; return; fi
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= count )); then
            echo $((input - 1)); return
        fi
        echo -e "  ${YELLOW}Invalid choice. Try again.${NC}" >&2
    done
}

ask_string() {
    local prompt="$1"
    local default="$2"
    read -rp "$(echo -e "${WHITE}${prompt} [${default}]:${NC} ")" answer
    if [[ -z "$answer" ]]; then echo "$default"; else echo "$answer"; fi
}

ask_int() {
    local prompt="$1"
    local default="$2"
    local min="$3"
    local max="$4"

    while true; do
        read -rp "$(echo -e "${WHITE}${prompt} [${default}]:${NC} ")" answer < /dev/tty
        if [[ -z "$answer" ]]; then echo "$default"; return; fi
        if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= min && answer <= max )); then
            echo "$answer"; return
        fi
        echo -e "  ${YELLOW}Please enter a number between ${min} and ${max}.${NC}" >&2
    done
}

resolve_bool() {
    local param_val="$1"
    local prompt="$2"
    local default="$3"
    if [[ -n "$param_val" ]]; then
        local parsed
        parsed=$(parse_bool "$param_val")
        if [[ -n "$parsed" ]]; then echo "$parsed"; return; fi
    fi
    if [[ "$NON_INTERACTIVE" == "true" ]]; then echo "$default"; return; fi
    ask_yesno "$prompt" "$default"
}

resolve_int() {
    local param_val="$1"
    local prompt="$2"
    local default="$3"
    local min="$4"
    local max="$5"
    if [[ -n "$param_val" && "$param_val" != "0" ]]; then echo "$param_val"; return; fi
    if [[ "$NON_INTERACTIVE" == "true" ]]; then echo "$default"; return; fi
    ask_int "$prompt" "$default" "$min" "$max"
}

resolve_string() {
    local param_val="$1"
    local prompt="$2"
    local default="$3"
    if [[ -n "$param_val" ]]; then echo "$param_val"; return; fi
    if [[ "$NON_INTERACTIVE" == "true" ]]; then echo "$default"; return; fi
    ask_string "$prompt" "$default"
}

# ---- Java version mapping ----

get_required_java() {
    local mc_ver="$1"

    # Snapshot detection (e.g. 24w14a)
    if [[ "$mc_ver" =~ ^([0-9]{2})w ]]; then
        local snap_year="${BASH_REMATCH[1]}"
        if (( snap_year >= 24 )); then echo 21; return; fi
        if (( snap_year >= 21 )); then echo 17; return; fi
        echo 8; return
    fi

    # Strip pre-release suffix (e.g. 1.21-pre1 -> 1.21)
    local cleaned
    cleaned=$(echo "$mc_ver" | grep -oP '^\d+\.\d+(\.\d+)?' || echo "$mc_ver")

    local major minor patch
    IFS='.' read -r major minor patch <<< "$cleaned"
    major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}

    if (( major != 1 )); then echo 21; return; fi
    if (( minor >= 21 )); then echo 21; return; fi
    if (( minor == 20 && patch >= 5 )); then echo 21; return; fi
    if (( minor >= 18 )); then echo 17; return; fi
    if (( minor == 17 )); then echo 16; return; fi
    echo 8
}

get_recommended_jdk() {
    local min_java="$1"
    if (( min_java <= 8 ));  then echo 8;  return; fi
    if (( min_java <= 17 )); then echo 17; return; fi
    echo 21
}

# --- Paper Server & Plugin Support ---

get_paper_build_info() {
    # Gets latest Paper build for a Minecraft version.
    # Sets: PAPER_BUILD, PAPER_FILENAME, PAPER_DOWNLOAD_URL
    local mc_version="$1"
    PAPER_BUILD="" ; PAPER_FILENAME="" ; PAPER_DOWNLOAD_URL=""

    local project_json
    project_json=$(download_string "https://api.papermc.io/v2/projects/paper" 2>/dev/null) || return 1

    if ! echo "$project_json" | jq -e --arg v "$mc_version" '.versions | index($v)' &>/dev/null; then
        return 1
    fi

    local builds_json
    builds_json=$(download_string "https://api.papermc.io/v2/projects/paper/versions/${mc_version}" 2>/dev/null) || return 1
    local latest_build
    latest_build=$(echo "$builds_json" | jq -r '.builds[-1]')

    local build_json
    build_json=$(download_string "https://api.papermc.io/v2/projects/paper/versions/${mc_version}/builds/${latest_build}" 2>/dev/null) || return 1
    local dl_name
    dl_name=$(echo "$build_json" | jq -r '.downloads.application.name')

    PAPER_BUILD="$latest_build"
    PAPER_FILENAME="$dl_name"
    PAPER_DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/${mc_version}/builds/${latest_build}/downloads/${dl_name}"
    return 0
}

get_hangar_plugin() {
    # Gets latest Hangar plugin version with direct download.
    # Sets: PLUGIN_FILENAME, PLUGIN_URL, PLUGIN_VERSION
    local slug="$1"
    PLUGIN_FILENAME="" ; PLUGIN_URL="" ; PLUGIN_VERSION=""

    local json
    json=$(download_string "https://hangar.papermc.io/api/v1/projects/${slug}/versions?limit=1&platform=PAPER" 2>/dev/null) || return 1

    local count
    count=$(echo "$json" | jq '.result | length')
    if [[ "$count" == "0" ]]; then return 1; fi

    PLUGIN_VERSION=$(echo "$json" | jq -r '.result[0].name')
    local has_file
    has_file=$(echo "$json" | jq -r '.result[0].downloads.PAPER.fileInfo.name // empty')

    if [[ -n "$has_file" ]]; then
        PLUGIN_FILENAME="$has_file"
        PLUGIN_URL="https://hangar.papermc.io/api/v1/projects/${slug}/versions/${PLUGIN_VERSION}/PAPER/download"
        return 0
    fi
    return 1
}

get_jenkins_artifact() {
    # Downloads latest artifact from Jenkins CI.
    # Args: base_url job_name artifact_regex
    # Sets: PLUGIN_FILENAME, PLUGIN_URL, PLUGIN_VERSION
    local base_url="$1" job_name="$2" artifact_match="$3"
    PLUGIN_FILENAME="" ; PLUGIN_URL="" ; PLUGIN_VERSION=""

    local json
    json=$(download_string "${base_url}/job/${job_name}/lastSuccessfulBuild/api/json" 2>/dev/null) || return 1

    PLUGIN_VERSION=$(echo "$json" | jq -r '.number')
    local artifact
    artifact=$(echo "$json" | jq -r --arg pat "$artifact_match" \
        '[.artifacts[] | select(.fileName | test($pat))] | first // empty')

    if [[ -z "$artifact" || "$artifact" == "null" ]]; then return 1; fi

    PLUGIN_FILENAME=$(echo "$artifact" | jq -r '.fileName')
    local rel_path
    rel_path=$(echo "$artifact" | jq -r '.relativePath')
    PLUGIN_URL="${base_url}/job/${job_name}/lastSuccessfulBuild/artifact/${rel_path}"
    return 0
}

get_github_release_asset() {
    # Gets latest GitHub release asset matching a regex.
    # Args: repo asset_regex
    # Sets: PLUGIN_FILENAME, PLUGIN_URL, PLUGIN_VERSION
    local repo="$1" asset_match="$2"
    PLUGIN_FILENAME="" ; PLUGIN_URL="" ; PLUGIN_VERSION=""

    local json
    json=$(download_string "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null) || return 1

    PLUGIN_VERSION=$(echo "$json" | jq -r '.tag_name')
    local asset
    asset=$(echo "$json" | jq -r --arg pat "$asset_match" \
        '[.assets[] | select(.name | test($pat))] | first // empty')

    if [[ -z "$asset" || "$asset" == "null" ]]; then return 1; fi

    PLUGIN_FILENAME=$(echo "$asset" | jq -r '.name')
    PLUGIN_URL=$(echo "$asset" | jq -r '.browser_download_url')
    return 0
}

get_modrinth_plugin() {
    # Gets latest Paper-compatible version of a Modrinth plugin.
    # Args: project_slug
    # Sets: PLUGIN_FILENAME, PLUGIN_URL, PLUGIN_VERSION
    local slug="$1"
    PLUGIN_FILENAME="" ; PLUGIN_URL="" ; PLUGIN_VERSION=""

    local encoded_loaders
    encoded_loaders=$(python3 -c "import urllib.parse; print(urllib.parse.quote('[\"paper\",\"bukkit\",\"spigot\"]'))" 2>/dev/null || echo '%5B%22paper%22%2C%22bukkit%22%2C%22spigot%22%5D')
    local json
    json=$(download_string "https://api.modrinth.com/v2/project/${slug}/version?loaders=${encoded_loaders}&limit=1" 2>/dev/null) || return 1

    local count
    count=$(echo "$json" | jq 'length')
    if [[ "$count" == "0" ]]; then return 1; fi

    PLUGIN_VERSION=$(echo "$json" | jq -r '.[0].version_number')
    PLUGIN_FILENAME=$(echo "$json" | jq -r '.[0].files[] | select(.primary == true) | .filename' | head -1)
    if [[ -z "$PLUGIN_FILENAME" ]]; then
        PLUGIN_FILENAME=$(echo "$json" | jq -r '.[0].files[0].filename')
    fi
    PLUGIN_URL=$(echo "$json" | jq -r '.[0].files[] | select(.primary == true) | .url' | head -1)
    if [[ -z "$PLUGIN_URL" ]]; then
        PLUGIN_URL=$(echo "$json" | jq -r '.[0].files[0].url')
    fi
    [[ -n "$PLUGIN_URL" && "$PLUGIN_URL" != "null" ]]
}

search_hangar_plugins() {
    # Searches Hangar for Paper plugins. Returns JSON array.
    local query="$1" limit="${2:-10}"
    local encoded_query
    encoded_query=$(printf '%s' "$query" | jq -sRr @uri 2>/dev/null || echo "$query")
    download_string "https://hangar.papermc.io/api/v1/projects?q=${encoded_query}&sort=-downloads&platform=PAPER&limit=${limit}" 2>/dev/null
}

# Plugin definitions: index|name|description|source|extra_args...
# Source types: hangar, jenkins, github, url, modrinth
PLUGIN_DEFS=(
    "Essentials|EssentialsX|Essential commands (home, tp, spawn, kits)|github|EssentialsX/Essentials|^EssentialsX-[0-9.]+\\.jar$"
    "LuckPerms|LuckPerms|Advanced permissions management|jenkins|https://ci.lucko.me|LuckPerms|^LuckPerms-Bukkit-[0-9]"
    "ViaVersion|ViaVersion|Allow newer clients on older servers|hangar|ViaVersion"
    "ViaBackwards|ViaBackwards|Allow older clients on newer servers|hangar|ViaBackwards"
    "Geyser|Geyser|Allow Bedrock Edition players to join|url|https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot|Geyser-Spigot.jar"
    "Floodgate|Floodgate|Bedrock auth (companion to Geyser)|url|https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot|Floodgate-Spigot.jar"
    "Chunky|Chunky|Pre-generate world chunks|hangar|Chunky"
    "spark|spark|Performance profiler and monitoring|jenkins|https://ci.lucko.me|spark|spark-[0-9.]+-paper\\.jar"
    "BlueMap|BlueMap|3D web-based live map of your world|hangar|BlueMap"
    "Squaremap|squaremap|Minimalistic & lightweight web map|hangar|Squaremap"
    "TreeTimber|Timber|Chop entire trees by breaking one log|modrinth|treetimber"
    "AuraSkills|AuraSkills|RPG skills & leveling (mcMMO alternative)|hangar|AuraSkills"
    "AuraMobs|AuraMobs|Mob levels add-on for AuraSkills|modrinth|auramobs"
)

resolve_plugin_download() {
    # Resolves download info for a plugin definition string.
    # Sets: PLUGIN_FILENAME, PLUGIN_URL, PLUGIN_VERSION
    local def="$1"
    IFS='|' read -r _slug name desc source arg1 arg2 arg3 <<< "$def"

    case "$source" in
        hangar)   get_hangar_plugin "$arg1" ;;
        jenkins)  get_jenkins_artifact "$arg1" "$arg2" "$arg3" ;;
        github)   get_github_release_asset "$arg1" "$arg2" ;;
        modrinth) get_modrinth_plugin "$arg1" ;;
        url)
            PLUGIN_URL="$arg1"
            PLUGIN_FILENAME="$arg2"
            PLUGIN_VERSION="latest"
            return 0
            ;;
        *) return 1 ;;
    esac
}

install_paper_plugins() {
    # Interactive Paper plugin selection and installation.
    local plugins_dir="$1"
    mkdir -p "$plugins_dir"

    local plugin_count=${#PLUGIN_DEFS[@]}

    echo ""
    echo -e "  ${CYAN}+================================================+${NC}"
    echo -e "  ${CYAN}|         Plugin Installation                     |${NC}"
    echo -e "  ${CYAN}+================================================+${NC}"
    echo ""
    echo -e "  ${WHITE}Popular plugins for Paper servers:${NC}"
    echo ""

    for i in "${!PLUGIN_DEFS[@]}"; do
        IFS='|' read -r _slug name desc _rest <<< "${PLUGIN_DEFS[$i]}"
        printf "    ${GRAY}[%2d] %-16s - %s${NC}\n" "$((i + 1))" "$name" "$desc"
    done

    echo ""
    echo -e "  ${WHITE}Enter plugin numbers separated by commas (e.g. 1,2,3)${NC}"
    echo -e "  ${GRAY}Or type 'all' to install all, 'none' to skip, 'search' to search Hangar${NC}"

    local -a selected_indices=()

    while true; do
        read -rp "  Selection: " answer < /dev/tty
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]' | xargs)

        if [[ -z "$answer" || "$answer" == "none" ]]; then
            echo -e "  ${YELLOW}Skipping plugin installation.${NC}"
            return
        fi

        if [[ "$answer" == "all" ]]; then
            for i in "${!PLUGIN_DEFS[@]}"; do
                selected_indices+=("$i")
            done
            break
        fi

        if [[ "$answer" == "search" ]]; then
            read -rp "  Search Hangar for: " search_query < /dev/tty
            if [[ -n "$search_query" ]]; then
                echo -e "  ${GRAY}Searching Hangar for '${search_query}'...${NC}"
                local search_json
                search_json=$(search_hangar_plugins "$search_query" 10)
                local sr_count
                sr_count=$(echo "$search_json" | jq '.result | length' 2>/dev/null || echo 0)

                if [[ "$sr_count" == "0" ]]; then
                    echo -e "  ${YELLOW}No plugins found for '${search_query}'.${NC}"
                else
                    echo ""
                    echo -e "  ${WHITE}Search results:${NC}"
                    for si in $(seq 0 $((sr_count - 1))); do
                        local sr_name sr_desc sr_downloads
                        sr_name=$(echo "$search_json" | jq -r ".result[$si].name")
                        sr_desc=$(echo "$search_json" | jq -r ".result[$si].description" | cut -c1-50)
                        sr_downloads=$(echo "$search_json" | jq -r ".result[$si].stats.downloads")
                        local dl_display
                        if (( sr_downloads >= 1000000 )); then
                            dl_display="$(echo "scale=1; $sr_downloads/1000000" | bc)M"
                        elif (( sr_downloads >= 1000 )); then
                            dl_display="$(echo "scale=1; $sr_downloads/1000" | bc)K"
                        else
                            dl_display="$sr_downloads"
                        fi
                        printf "    ${GRAY}[%2d] %-24s %6s dl  - %s${NC}\n" "$((si + 1))" "$sr_name" "$dl_display" "$sr_desc"
                    done
                    echo ""
                    read -rp "  Enter numbers to install (e.g. 1,2) or press Enter to go back: " sr_answer < /dev/tty
                    if [[ -n "$sr_answer" ]]; then
                        IFS=',' read -ra sr_nums <<< "$sr_answer"
                        for sn in "${sr_nums[@]}"; do
                            sn=$(echo "$sn" | xargs)
                            if [[ "$sn" =~ ^[0-9]+$ ]] && (( sn >= 1 && sn <= sr_count )); then
                                local sr_slug
                                sr_slug=$(echo "$search_json" | jq -r ".result[$((sn - 1))].namespace.slug")
                                local sr_n
                                sr_n=$(echo "$search_json" | jq -r ".result[$((sn - 1))].name")
                                # Add as a dynamic hangar entry at the end
                                PLUGIN_DEFS+=("${sr_slug}|${sr_n}|Hangar search result|hangar|${sr_slug}")
                                selected_indices+=($((${#PLUGIN_DEFS[@]} - 1)))
                            fi
                        done
                    fi
                fi
                echo ""
                echo -e "  ${GRAY}Enter numbers from the popular list, 'search' again, or 'done' to proceed${NC}"
            fi
            continue
        fi

        if [[ "$answer" == "done" ]]; then
            break
        fi

        # Parse comma-separated numbers
        IFS=',' read -ra nums <<< "$answer"
        local valid=true
        local parsed_nums=()
        for n in "${nums[@]}"; do
            n=$(echo "$n" | xargs)
            if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= plugin_count )); then
                parsed_nums+=($((n - 1)))
            else
                echo -e "  ${YELLOW}Invalid number: $n. Please enter 1-${plugin_count}.${NC}"
                valid=false
                break
            fi
        done
        if [[ "$valid" == "true" && ${#parsed_nums[@]} -gt 0 ]]; then
            selected_indices=("${parsed_nums[@]}")
            break
        fi
        if [[ ${#parsed_nums[@]} -eq 0 ]]; then
            echo -e "  ${YELLOW}Please enter valid numbers, 'all', 'none', or 'search'.${NC}"
        fi
    done

    if [[ ${#selected_indices[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}No plugins selected.${NC}"
        return
    fi

    # Remove duplicates
    local -A seen=()
    local -a final_indices=()
    for idx in "${selected_indices[@]}"; do
        IFS='|' read -r slug _rest <<< "${PLUGIN_DEFS[$idx]}"
        if [[ -z "${seen[$slug]+x}" ]]; then
            seen["$slug"]=1
            final_indices+=("$idx")
        fi
    done

    echo ""
    echo -e "  ${CYAN}Installing ${#final_indices[@]} plugin(s)...${NC}"

    local installed_count=0
    local failed_count=0

    for idx in "${final_indices[@]}"; do
        IFS='|' read -r _slug name _rest <<< "${PLUGIN_DEFS[$idx]}"
        echo -ne "    Downloading ${name}..."

        if resolve_plugin_download "${PLUGIN_DEFS[$idx]}"; then
            local plugin_path="${plugins_dir}/${PLUGIN_FILENAME}"
            if download_file "$PLUGIN_URL" "$plugin_path" 2>/dev/null; then
                local size_mb
                size_mb=$(du -m "$plugin_path" 2>/dev/null | cut -f1)
                echo -e " ${GREEN}done (v${PLUGIN_VERSION}, ${size_mb} MB)${NC}"
                installed_count=$((installed_count + 1))
            else
                echo -e " ${RED}download failed${NC}"
                failed_count=$((failed_count + 1))
            fi
        else
            echo -e " ${YELLOW}not available${NC}"
            failed_count=$((failed_count + 1))
        fi
    done

    echo ""
    echo -e "  ${GREEN}Plugins installed: ${installed_count}${NC}"
    if (( failed_count > 0 )); then
        echo -e "  ${YELLOW}Plugins failed:    ${failed_count}${NC}"
    fi
}

# ---- Downloader (uses curl or wget) ----

download_file() {
    local url="$1"
    local output="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$output" "$url"
    elif command -v wget &>/dev/null; then
        wget -q -O "$output" "$url"
    else
        echo -e "  ${RED}ERROR: Neither curl nor wget found. Cannot download files.${NC}"
        exit 1
    fi
}

download_string() {
    local url="$1"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url"
    elif command -v wget &>/dev/null; then
        wget -q -O- "$url"
    else
        echo -e "  ${RED}ERROR: Neither curl nor wget found.${NC}" >&2
        exit 1
    fi
}

# ---- Java installer (Linux) ----

install_java() {
    local jdk_version="${1:-21}"
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x64" ;;
        aarch64) arch="aarch64" ;;
        armv7l)  arch="arm" ;;
        *)       echo -e "  ${RED}Unsupported architecture: $arch${NC}"; return 1 ;;
    esac

    echo ""
    echo -e "  ${CYAN}Installing Eclipse Temurin JDK ${jdk_version} (${arch})...${NC}"
    echo -e "  ${GRAY}Source: adoptium.net (Eclipse Foundation)${NC}"

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        echo -e "  ${WHITE}Using apt (Debian/Ubuntu)...${NC}"
        # Add Adoptium repo
        sudo mkdir -p /etc/apt/keyrings
        download_file "https://packages.adoptium.net/artifactory/api/gpg/key/public" "/tmp/adoptium.gpg.key"
        cat /tmp/adoptium.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/adoptium.gpg >/dev/null 2>&1
        echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y "temurin-${jdk_version}-jdk" && return 0

    elif command -v dnf &>/dev/null; then
        echo -e "  ${WHITE}Using dnf (Fedora/RHEL)...${NC}"
        sudo dnf install -y "java-${jdk_version}-openjdk" && return 0

    elif command -v yum &>/dev/null; then
        echo -e "  ${WHITE}Using yum (CentOS/RHEL)...${NC}"
        sudo yum install -y "java-${jdk_version}-openjdk" && return 0

    elif command -v pacman &>/dev/null; then
        echo -e "  ${WHITE}Using pacman (Arch)...${NC}"
        if (( jdk_version == 21 )); then
            sudo pacman -Sy --noconfirm jdk21-openjdk && return 0
        elif (( jdk_version == 17 )); then
            sudo pacman -Sy --noconfirm jdk17-openjdk && return 0
        else
            sudo pacman -Sy --noconfirm jdk8-openjdk && return 0
        fi

    elif command -v zypper &>/dev/null; then
        echo -e "  ${WHITE}Using zypper (openSUSE)...${NC}"
        sudo zypper install -y "java-${jdk_version}-openjdk" && return 0

    else
        # Fallback: download tar.gz from Adoptium API
        echo -e "  ${WHITE}No supported package manager found. Downloading tar.gz...${NC}"
        local api_url="https://api.adoptium.net/v3/binary/latest/${jdk_version}/ga/linux/${arch}/jdk/hotspot/normal/eclipse"
        local install_dir="/opt/java/temurin-${jdk_version}"
        local tmp_tar="/tmp/temurin-${jdk_version}.tar.gz"

        download_file "$api_url" "$tmp_tar"
        sudo mkdir -p "$install_dir"
        sudo tar -xzf "$tmp_tar" -C "$install_dir" --strip-components=1
        rm -f "$tmp_tar"

        # Add to PATH for this session
        export PATH="${install_dir}/bin:${PATH}"
        export JAVA_HOME="${install_dir}"

        # Persist in profile
        echo "export JAVA_HOME=${install_dir}" | sudo tee /etc/profile.d/temurin.sh >/dev/null
        echo 'export PATH="${JAVA_HOME}/bin:${PATH}"' | sudo tee -a /etc/profile.d/temurin.sh >/dev/null
    fi

    # Verify
    if command -v java &>/dev/null; then
        local ver
        ver=$(java -version 2>&1 | head -1)
        echo -e "  ${GREEN}Java installed: $ver${NC}"
        return 0
    else
        echo -e "  ${YELLOW}Java installed but not on PATH yet. Restart your shell.${NC}"
        return 1
    fi
}

# ============================================================
#  MAIN SCRIPT
# ============================================================

# Banner
echo ""
echo -e "  ${CYAN}+================================================+${NC}"
echo -e "  ${CYAN}|       Minecraft Server Creator  v1.0 (Linux)    |${NC}"
echo -e "  ${CYAN}+================================================+${NC}"
echo ""

# ---- Detect Java ----
echo -e "  ${GRAY}Detecting Java...${NC}"
current_java_major=0
if command -v java &>/dev/null; then
    java_version_str=$(java -version 2>&1 | head -1)
    echo -e "  ${GREEN}Found: ${java_version_str}${NC}"
    current_java_major=$(echo "$java_version_str" | grep -oP '\d+' | head -1)
    current_java_major=${current_java_major:-0}
else
    echo -e "  ${YELLOW}Java not found on PATH.${NC}"
fi

# ---- Detect jq (needed for JSON parsing) ----
if ! command -v jq &>/dev/null; then
    echo -e "  ${YELLOW}jq not found. Installing jq (needed for JSON parsing)...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y -qq jq
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y -q jq
    elif command -v yum &>/dev/null; then
        sudo yum install -y -q jq
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm jq
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y jq
    elif command -v brew &>/dev/null; then
        brew install jq
    else
        echo -e "  ${RED}ERROR: Cannot install jq automatically. Please install it manually.${NC}"
        exit 1
    fi
fi

# ---- Choose server directory ----
echo ""
echo -e "  ${CYAN}+================================================+${NC}"
echo -e "  ${CYAN}|         Server Location                         |${NC}"
echo -e "  ${CYAN}+================================================+${NC}"

if [[ -z "$SERVER_PATH" ]]; then
    current_path="$(pwd)/minecraft-server"
    home_path="${HOME}/minecraft-server"

    path_choice=$(ask_choice "Where would you like to set up the server?" 0 \
        "Current directory  (${current_path})" \
        "Home directory     (${home_path})" \
        "Enter a custom path")

    case "$path_choice" in
        0) SERVER_PATH="$current_path" ;;
        1) SERVER_PATH="$home_path" ;;
        2) SERVER_PATH=$(ask_string "  Enter full path for the server" "$current_path") ;;
    esac

    folder_name=$(basename "$SERVER_PATH")
    new_folder=$(ask_string "  Server folder name" "$folder_name")
    if [[ "$new_folder" != "$folder_name" ]]; then
        SERVER_PATH="$(dirname "$SERVER_PATH")/${new_folder}"
    fi
fi

# Resolve to absolute path
SERVER_PATH=$(cd "$(dirname "$SERVER_PATH")" 2>/dev/null && echo "$(pwd)/$(basename "$SERVER_PATH")" || echo "$SERVER_PATH")

echo ""
echo -e "  ${WHITE}Server will be set up at:${NC}"
echo -e "  ${CYAN}${SERVER_PATH}${NC}"

if [[ -f "${SERVER_PATH}/server.jar" ]]; then
    echo ""
    echo -e "  ${YELLOW}A server.jar already exists at this location.${NC}"
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        overwrite=$(ask_yesno "  Overwrite existing server files?" "false")
        if [[ "$overwrite" != "true" ]]; then
            echo -e "  ${GRAY}Exiting.${NC}"
            exit 0
        fi
    else
        echo -e "  ${YELLOW}Overwriting (non-interactive mode).${NC}"
    fi
fi

mkdir -p "$SERVER_PATH"
echo -e "  ${GREEN}Directory ready.${NC}"

# ---- Select server type ----
echo ""
echo -e "  ${CYAN}+================================================+${NC}"
echo -e "  ${CYAN}|         Server Type                             |${NC}"
echo -e "  ${CYAN}+================================================+${NC}"

selected_server_type="vanilla"
if [[ -n "$OPT_SERVER_TYPE" ]]; then
    case "${OPT_SERVER_TYPE,,}" in
        vanilla|paper) selected_server_type="${OPT_SERVER_TYPE,,}" ;;
        *) echo -e "  ${YELLOW}Unknown server type '${OPT_SERVER_TYPE}', defaulting to vanilla.${NC}" ;;
    esac
elif [[ "$NON_INTERACTIVE" != "true" ]]; then
    type_choice=$(ask_choice "Select server type:" 0 \
        "Vanilla  — Official Mojang server" \
        "Paper    — High-performance server with plugin support")
    case "$type_choice" in
        0) selected_server_type="vanilla" ;;
        1) selected_server_type="paper" ;;
    esac
fi

server_type_display="${selected_server_type^}"
echo -e "  ${CYAN}Server type: ${server_type_display}${NC}"

# ---- Select Minecraft version ----
echo ""
echo -e "  ${GRAY}Fetching available Minecraft versions...${NC}"
manifest_json=$(download_string "https://launchermeta.mojang.com/mc/game/version_manifest.json")
if [[ -z "$manifest_json" ]]; then
    echo -e "  ${RED}ERROR: Could not fetch version manifest from Mojang.${NC}"
    exit 1
fi

latest_release=$(echo "$manifest_json" | jq -r '.latest.release')
latest_snapshot=$(echo "$manifest_json" | jq -r '.latest.snapshot')

echo ""
echo -e "  ${GREEN}Latest release:  ${latest_release}${NC}"
echo -e "  ${YELLOW}Latest snapshot: ${latest_snapshot}${NC}"

if [[ -n "$MC_VERSION" ]]; then
    selected_version="$MC_VERSION"
else
    ver_choice=$(ask_choice "Select version type:" 0 \
        "Latest release (${latest_release})" \
        "Latest snapshot (${latest_snapshot})" \
        "Enter a specific version")

    case "$ver_choice" in
        0) selected_version="$latest_release" ;;
        1) selected_version="$latest_snapshot" ;;
        2) selected_version=$(ask_string "  Enter version (e.g. 1.20.4)" "$latest_release") ;;
    esac
fi

echo ""
echo -e "  ${CYAN}Selected version: ${selected_version}${NC}"

# Find version URL in manifest
version_url=$(echo "$manifest_json" | jq -r --arg v "$selected_version" '.versions[] | select(.id == $v) | .url')
if [[ -z "$version_url" || "$version_url" == "null" ]]; then
    echo -e "  ${RED}ERROR: Version '${selected_version}' not found in Mojang's manifest.${NC}"
    exit 1
fi

# ---- Check Java compatibility ----
required_java=$(get_required_java "$selected_version")
recommended_jdk=$(get_recommended_jdk "$required_java")

echo ""
echo -e "  ${WHITE}Minecraft ${selected_version} requires Java ${required_java}+${NC}"

needs_java=false
java_reason=""

if (( current_java_major == 0 )); then
    needs_java=true
    java_reason="missing"
    echo ""
    echo -e "  ${RED}+------------------------------------------------------+${NC}"
    echo -e "  ${RED}|  Java was NOT found on your system!                   |${NC}"
    echo -e "  ${RED}|  Minecraft ${selected_version} requires Java ${required_java}+ to run.${NC}"
    echo -e "  ${RED}+------------------------------------------------------+${NC}"
elif (( current_java_major < required_java )); then
    needs_java=true
    java_reason="outdated"
    echo ""
    echo -e "  ${YELLOW}+------------------------------------------------------+${NC}"
    echo -e "  ${YELLOW}|  Java ${current_java_major} is installed, but MC ${selected_version} needs ${required_java}+${NC}"
    echo -e "  ${YELLOW}+------------------------------------------------------+${NC}"
else
    echo -e "  ${GREEN}Java ${current_java_major} is compatible.${NC}"
fi

if [[ "$needs_java" == "true" ]]; then
    echo ""
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        if [[ "$AUTO_INSTALL_JAVA" == "true" ]]; then
            echo -e "  ${CYAN}Auto-installing Java ${recommended_jdk} (non-interactive mode)...${NC}"
            install_java "$recommended_jdk" || echo -e "  ${YELLOW}Java install had issues. Continuing.${NC}"
        else
            echo -e "  ${YELLOW}Skipping Java install (use --auto-install-java to auto-install).${NC}"
        fi
    else
        want_install=$(ask_yesno "  Would you like to install Java?" "false")

        if [[ "$want_install" == "true" ]]; then
            # Let user pick JDK version
            jdk_opt_0="JDK 21  -- Best for MC 1.20.5+ / 1.21+  (latest LTS)"
            jdk_opt_1="JDK 17  -- Best for MC 1.18 - 1.20.4"
            jdk_opt_2="JDK 8   -- Best for MC 1.16.5 and older"

            case "$recommended_jdk" in
                21) default_jdk=0 ;;
                17) default_jdk=1 ;;
                8)  default_jdk=2 ;;
                *)  default_jdk=0 ;;
            esac

            # Tag recommended
            case "$default_jdk" in
                0) jdk_opt_0="${jdk_opt_0}  <-- recommended for MC ${selected_version}" ;;
                1) jdk_opt_1="${jdk_opt_1}  <-- recommended for MC ${selected_version}" ;;
                2) jdk_opt_2="${jdk_opt_2}  <-- recommended for MC ${selected_version}" ;;
            esac

            jdk_choice=$(ask_choice "Which Java version would you like to install?" "$default_jdk" \
                "$jdk_opt_0" "$jdk_opt_1" "$jdk_opt_2")

            case "$jdk_choice" in
                0) chosen_jdk=21 ;;
                1) chosen_jdk=17 ;;
                2) chosen_jdk=8  ;;
            esac

            if (( chosen_jdk < required_java )); then
                echo ""
                echo -e "  ${YELLOW}WARNING: JDK ${chosen_jdk} may not work with MC ${selected_version} (needs Java ${required_java}+).${NC}"
                confirm=$(ask_yesno "  Install JDK ${chosen_jdk} anyway?" "false")
                if [[ "$confirm" != "true" ]]; then
                    echo -e "  ${CYAN}Falling back to recommended JDK ${recommended_jdk}.${NC}"
                    chosen_jdk=$recommended_jdk
                fi
            fi

            echo ""
            install_java "$chosen_jdk" || {
                echo ""
                echo -e "  ${YELLOW}Java installation had issues.${NC}"
                cont=$(ask_yesno "  Continue creating the server anyway?" "false")
                if [[ "$cont" != "true" ]]; then
                    echo -e "  ${GRAY}Exiting.${NC}"
                    exit 1
                fi
            }
        else
            echo ""
            echo -e "  ${YELLOW}Skipping Java install.${NC}"
            if [[ "$java_reason" == "missing" ]]; then
                echo -e "  ${YELLOW}You'll need Java ${required_java}+ before starting the server.${NC}"
            else
                echo -e "  ${YELLOW}Your Java ${current_java_major} may not work -- MC ${selected_version} needs Java ${required_java}+.${NC}"
            fi
            echo -e "  ${CYAN}Download from: https://adoptium.net/${NC}"
            cont=$(ask_yesno "  Continue creating the server?" "false")
            if [[ "$cont" != "true" ]]; then
                echo -e "  ${GRAY}Exiting.${NC}"
                exit 1
            fi
        fi
    fi
fi

# ---- Download server JAR ----
if [[ "$selected_server_type" == "paper" ]]; then
    echo ""
    echo -e "  ${GRAY}Checking Paper availability for MC ${selected_version}...${NC}"

    if get_paper_build_info "$selected_version"; then
        echo -e "  ${CYAN}Paper build #${PAPER_BUILD} available${NC}"
        jar_path="${SERVER_PATH}/server.jar"
        echo -e "  ${WHITE}Downloading Paper server JAR...${NC}"
        if download_file "$PAPER_DOWNLOAD_URL" "$jar_path" 2>/dev/null; then
            size_mb=$(du -m "$jar_path" | cut -f1)
            echo -e "  ${GREEN}Downloaded Paper server.jar (${size_mb} MB)${NC}"
        else
            echo -e "  ${RED}ERROR: Failed to download Paper server JAR.${NC}"
            if [[ "$NON_INTERACTIVE" != "true" ]]; then
                fallback=$(ask_yesno "  Fall back to Vanilla server?" "true")
                if [[ "$fallback" == "true" ]]; then
                    selected_server_type="vanilla"
                    server_type_display="Vanilla"
                else
                    echo -e "  ${GRAY}Exiting.${NC}"
                    exit 1
                fi
            else
                echo -e "  ${YELLOW}Falling back to Vanilla server.${NC}"
                selected_server_type="vanilla"
                server_type_display="Vanilla"
            fi
        fi
    else
        echo -e "  ${YELLOW}Paper is not available for MC ${selected_version}.${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            fallback=$(ask_yesno "  Fall back to Vanilla server?" "true")
            if [[ "$fallback" == "true" ]]; then
                selected_server_type="vanilla"
                server_type_display="Vanilla"
            else
                echo -e "  ${GRAY}Exiting.${NC}"
                exit 1
            fi
        else
            echo -e "  ${YELLOW}Falling back to Vanilla server.${NC}"
            selected_server_type="vanilla"
            server_type_display="Vanilla"
        fi
    fi
fi

if [[ "$selected_server_type" == "vanilla" ]]; then
    echo -e "  ${GRAY}Fetching download URL for ${selected_version}...${NC}"
    version_json=$(download_string "$version_url")
    jar_url=$(echo "$version_json" | jq -r '.downloads.server.url // empty')

    if [[ -z "$jar_url" ]]; then
        echo -e "  ${RED}ERROR: No server JAR available for version ${selected_version}.${NC}"
        exit 1
    fi

    jar_path="${SERVER_PATH}/server.jar"
    echo -e "  ${WHITE}Downloading server.jar...${NC}"
    download_file "$jar_url" "$jar_path"
    size_mb=$(du -m "$jar_path" | cut -f1)
    echo -e "  ${GREEN}Downloaded server.jar (${size_mb} MB)${NC}"
fi

# ---- Accept EULA ----
echo ""
if [[ "$ACCEPT_EULA" == "true" ]]; then
    echo -e "  ${GREEN}EULA accepted via --accept-eula flag.${NC}"
elif [[ "$NON_INTERACTIVE" == "true" ]]; then
    echo -e "  ${RED}ERROR: You must pass --accept-eula in non-interactive mode.${NC}"
    echo -e "  ${YELLOW}EULA: https://aka.ms/MinecraftEULA${NC}"
    exit 1
else
    echo -e "  ${YELLOW}+----------------------------------------------+${NC}"
    echo -e "  ${YELLOW}|  Minecraft EULA                               |${NC}"
    echo -e "  ${YELLOW}|  https://aka.ms/MinecraftEULA                 |${NC}"
    echo -e "  ${YELLOW}|  You must agree to the EULA to run a server.  |${NC}"
    echo -e "  ${YELLOW}+----------------------------------------------+${NC}"

    eula_answer=$(ask_yesno "  Do you accept the Minecraft EULA?" "false")
    if [[ "$eula_answer" != "true" ]]; then
        echo -e "  ${RED}You must accept the EULA to create a server. Exiting.${NC}"
        exit 1
    fi
fi

# (eula.txt will be written after server.properties is generated)
echo -e "  ${GREEN}EULA accepted.${NC}"

# ---- Plugin Installation ----
if [[ "$selected_server_type" == "paper" && "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    want_plugins=$(ask_yesno "  Would you like to install plugins?" "true")
    if [[ "$want_plugins" == "true" ]]; then
        install_paper_plugins "${SERVER_PATH}/plugins"
    fi
fi

# ---- Server Configuration ----
echo ""
echo -e "  ${MAGENTA}+================================================+${NC}"
echo -e "  ${MAGENTA}|         Server Configuration                    |${NC}"
echo -e "  ${MAGENTA}+================================================+${NC}"
echo ""

# General
server_name=$(resolve_string  "$OPT_SERVER_NAME"  "  Server name (MOTD)" "A Minecraft Server")
server_port=$(resolve_int     "$OPT_SERVER_PORT"   "  Server port" 25565 1 65535)
max_players=$(resolve_int     "$OPT_MAX_PLAYERS"   "  Max players" 20 1 1000)
online_mode=$(resolve_bool    "$OPT_ONLINE_MODE"   "  Online mode (authenticate with Mojang)?" "true")
pvp=$(resolve_bool            "$OPT_PVP"           "  Enable PvP?" "true")

if [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    echo -e "  ${MAGENTA}--- Gameplay ---${NC}"
fi

hardcore=$(resolve_bool       "$OPT_HARDCORE"       "  Hardcore mode?" "false")
command_blocks=$(resolve_bool "$OPT_COMMAND_BLOCKS"  "  Enable command blocks?" "true")
allow_flight=$(resolve_bool   "$OPT_ALLOW_FLIGHT"   "  Allow flight?" "true")
allow_nether=$(resolve_bool   "$OPT_ALLOW_NETHER"   "  Allow the Nether?" "true")
spawn_npcs=$(resolve_bool     "$OPT_SPAWN_NPCS"     "  Spawn NPCs (villagers)?" "true")
spawn_animals=$(resolve_bool  "$OPT_SPAWN_ANIMALS"  "  Spawn animals?" "true")
spawn_monsters=$(resolve_bool "$OPT_SPAWN_MONSTERS" "  Spawn monsters?" "true")

if [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    echo -e "  ${MAGENTA}--- World ---${NC}"
fi

# Difficulty
valid_difficulties="peaceful easy normal hard"
if [[ -n "$OPT_DIFFICULTY" ]] && echo "$valid_difficulties" | grep -qw "${OPT_DIFFICULTY,,}"; then
    difficulty="${OPT_DIFFICULTY,,}"
elif [[ "$NON_INTERACTIVE" == "true" ]]; then
    difficulty="normal"
else
    diff_choice=$(ask_choice "Select difficulty:" 2 "Peaceful" "Easy" "Normal" "Hard")
    difficulty=$(echo "$valid_difficulties" | tr ' ' '\n' | sed -n "$((diff_choice + 1))p")
fi

# Gamemode
valid_gamemodes="survival creative adventure spectator"
if [[ -n "$OPT_GAMEMODE" ]] && echo "$valid_gamemodes" | grep -qw "${OPT_GAMEMODE,,}"; then
    gamemode="${OPT_GAMEMODE,,}"
elif [[ "$NON_INTERACTIVE" == "true" ]]; then
    gamemode="survival"
else
    gm_choice=$(ask_choice "Select default gamemode:" 0 "Survival" "Creative" "Adventure" "Spectator")
    gamemode=$(echo "$valid_gamemodes" | tr ' ' '\n' | sed -n "$((gm_choice + 1))p")
fi

# World type
if [[ -n "$OPT_LEVEL_TYPE" ]]; then
    lt_key=$(echo "${OPT_LEVEL_TYPE,,}" | tr -d ' _-')
    case "$lt_key" in
        normal)      level_type="minecraft:normal" ;;
        flat)        level_type="minecraft:flat" ;;
        largebiomes) level_type="minecraft:large_biomes" ;;
        amplified)   level_type="minecraft:amplified" ;;
        minecraft:*) level_type="$OPT_LEVEL_TYPE" ;;
        *)           level_type="minecraft:normal" ;;
    esac
elif [[ "$NON_INTERACTIVE" == "true" ]]; then
    level_type="minecraft:normal"
else
    wt_choice=$(ask_choice "Select world type:" 0 "Normal" "Flat" "Large Biomes" "Amplified")
    level_types=("minecraft:normal" "minecraft:flat" "minecraft:large_biomes" "minecraft:amplified")
    level_type="${level_types[$wt_choice]}"
fi

level_name=$(resolve_string "$OPT_LEVEL_NAME" "  World/level name" "world")
level_seed=$(resolve_string "$OPT_LEVEL_SEED" "  World seed (leave blank for random)" "")

if [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    echo -e "  ${MAGENTA}--- Performance ---${NC}"
fi

max_ram=$(resolve_int "$OPT_MAX_RAM" "  Max RAM for server (MB)" 2048 512 32768)
whitelist=$(resolve_bool "$OPT_WHITELIST" "  Enable whitelist?" "false")

# ---- Build server.properties ----
echo ""
echo -e "  ${GRAY}Generating server.properties...${NC}"

props_path="${SERVER_PATH}/server.properties"

# Run server once to generate defaults if no server.properties exists
if [[ ! -f "$props_path" ]]; then
    # Ensure eula.txt does NOT exist so the server generates files and exits immediately
    rm -f "${SERVER_PATH}/eula.txt"
    echo -e "  ${GRAY}Running server once to generate defaults (will exit automatically)...${NC}"
    if command -v timeout &>/dev/null; then
        (cd "$SERVER_PATH" && timeout 30 java -Xmx256M -Xms256M -jar server.jar nogui >/dev/null 2>&1 || true)
    else
        (cd "$SERVER_PATH" && java -Xmx256M -Xms256M -jar server.jar nogui >/dev/null 2>&1 || true)
    fi
    if [[ ! -f "$props_path" ]]; then
        echo -e "  ${YELLOW}Could not auto-generate defaults, creating from scratch.${NC}"
        echo "#Minecraft server properties" > "$props_path"
    fi
fi

# Associative array of user settings
declare -A user_settings=(
    ["motd"]="$server_name"
    ["server-port"]="$server_port"
    ["max-players"]="$max_players"
    ["online-mode"]="$online_mode"
    ["pvp"]="$pvp"
    ["white-list"]="$whitelist"
    ["enforce-whitelist"]="$whitelist"
    ["hardcore"]="$hardcore"
    ["enable-command-block"]="$command_blocks"
    ["allow-flight"]="$allow_flight"
    ["allow-nether"]="$allow_nether"
    ["spawn-npcs"]="$spawn_npcs"
    ["spawn-animals"]="$spawn_animals"
    ["spawn-monsters"]="$spawn_monsters"
    ["difficulty"]="$difficulty"
    ["gamemode"]="$gamemode"
    ["level-name"]="$level_name"
    ["level-seed"]="$level_seed"
    ["level-type"]="$level_type"
)

# Read file, replace matching keys, track which were written
echo -e "  ${GRAY}Updating server.properties with your settings...${NC}"
declare -A keys_written=()
tmp_props=$(mktemp)

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*= ]]; then
        key="${BASH_REMATCH[1]}"
        if [[ -n "${user_settings[$key]+x}" ]]; then
            echo "${key}=${user_settings[$key]}" >> "$tmp_props"
            keys_written["$key"]=1
        else
            echo "$line" >> "$tmp_props"
        fi
    else
        echo "$line" >> "$tmp_props"
    fi
done < "$props_path"

# Append any settings whose keys weren't in the file
missing_count=0
first_missing=true
for key in "${!user_settings[@]}"; do
    if [[ -z "${keys_written[$key]+x}" ]]; then
        if [[ "$first_missing" == "true" ]]; then
            echo "" >> "$tmp_props"
            echo "# Added by create-mcserver.sh" >> "$tmp_props"
            first_missing=false
        fi
        echo "${key}=${user_settings[$key]}" >> "$tmp_props"
        missing_count=$((missing_count + 1))
    fi
done

mv "$tmp_props" "$props_path"

changed_count=${#keys_written[@]}
echo -e "  ${GREEN}server.properties saved (${changed_count} updated, ${missing_count} added).${NC}"

# ---- Write EULA ----
echo -e "# Minecraft EULA - accepted via create-mcserver.sh
eula=true" > "${SERVER_PATH}/eula.txt"
echo -e "  ${GREEN}eula.txt written.${NC}"

# ---- Create start script ----
echo -e "  ${GRAY}Generating start script...${NC}"

cat > "${SERVER_PATH}/start.sh" << STARTEOF
#!/usr/bin/env bash
# Start Minecraft Server
# Generated by create-mcserver.sh

cd "\$(dirname "\$0")"

echo "Starting Minecraft Server..."
echo "RAM: ${max_ram}MB | Port: ${server_port} | Version: ${selected_version}"
echo "Press Ctrl+C or type 'stop' to shut down."
echo ""

java -Xmx${max_ram}M -Xms${max_ram}M -jar server.jar nogui
STARTEOF

chmod +x "${SERVER_PATH}/start.sh"
echo -e "  ${GREEN}start.sh created.${NC}"

# ---- Summary ----
echo ""
echo -e "  ${GREEN}+================================================+${NC}"
echo -e "  ${GREEN}|         Server Created Successfully!             |${NC}"
echo -e "  ${GREEN}+================================================+${NC}"
echo ""
echo -e "  ${WHITE}Location:       ${SERVER_PATH}${NC}"
if [[ "$selected_server_type" == "paper" ]]; then
    echo -e "  ${CYAN}Server type:    ${server_type_display}${NC}"
else
    echo -e "  ${WHITE}Server type:    ${server_type_display}${NC}"
fi
echo -e "  ${WHITE}Version:        ${selected_version}${NC}"
echo -e "  ${WHITE}Port:           ${server_port}${NC}"
echo -e "  ${WHITE}Gamemode:       ${gamemode}${NC}"
echo -e "  ${WHITE}Difficulty:     ${difficulty}${NC}"
if [[ "$hardcore" == "true" ]]; then
    echo -e "  ${RED}Hardcore:       true${NC}"
else
    echo -e "  ${WHITE}Hardcore:       false${NC}"
fi
echo -e "  ${WHITE}Command Blocks: ${command_blocks}${NC}"
echo -e "  ${WHITE}Allow Flight:   ${allow_flight}${NC}"
echo -e "  ${WHITE}Max RAM:        ${max_ram}MB${NC}"
if [[ "$selected_server_type" == "paper" ]]; then
    local_plugins_dir="${SERVER_PATH}/plugins"
    if [[ -d "$local_plugins_dir" ]]; then
        plugin_jar_count=$(find "$local_plugins_dir" -maxdepth 1 -name '*.jar' 2>/dev/null | wc -l)
        if (( plugin_jar_count > 0 )); then
            echo -e "  ${CYAN}Plugins:        ${plugin_jar_count} installed${NC}"
        fi
    fi
fi
echo ""
echo -e "  ${YELLOW}To start your server:${NC}"
echo -e "  ${GRAY}  cd \"${SERVER_PATH}\"${NC}"
echo -e "  ${GRAY}  ./start.sh${NC}"
echo ""
echo -e "  ${GREEN}Happy crafting!${NC}"
echo ""
