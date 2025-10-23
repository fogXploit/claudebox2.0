#!/usr/bin/env bash
# Shared helpers that every module can safely source.

# -------- colours -------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# -------- utility functions ---------------------------------------------------
cecho() { printf "${2:-$NC}%s${NC}\n" "$1"; }
error() { cecho "$1" "$RED" >&2; exit "${2:-1}"; }
warn() { cecho "$1" "$YELLOW"; }
info() { cecho "$1" "$BLUE"; }
success() { cecho "$1" "$GREEN"; }

# Enhanced error for Docker build failures with actionable guidance
docker_build_error() {
    cecho "Docker build failed" "$RED" >&2
    echo >&2
    cecho "Common causes and solutions:" "$YELLOW" >&2
    echo >&2
    printf "%s\n" "  ${CYAN}1. Out of disk space${NC}" >&2
    printf "%s\n" "     Try: ${WHITE}docker system prune -a${NC} (removes unused images)" >&2
    printf "%s\n" "     Or:  ${WHITE}df -h${NC} (check available space)" >&2
    echo >&2
    printf "%s\n" "  ${CYAN}2. Network issues${NC}" >&2
    printf "%s\n" "     Try: ${WHITE}ping -c 3 8.8.8.8${NC} (test connectivity)" >&2
    printf "%s\n" "     Or:  Wait a moment and retry" >&2
    echo >&2
    printf "%s\n" "  ${CYAN}3. BuildKit cache corruption${NC}" >&2
    printf "%s\n" "     Try: ${WHITE}claudebox clean --cache${NC}" >&2
    printf "%s\n" "     Then: ${WHITE}claudebox rebuild${NC}" >&2
    echo >&2
    printf "%s\n" "  ${CYAN}4. Docker daemon issues${NC}" >&2
    printf "%s\n" "     Try: ${WHITE}docker info${NC} (check Docker status)" >&2
    printf "%s\n" "     Or:  Restart Docker Desktop" >&2
    echo >&2
    exit 1
}

# Enhanced error for missing Docker image
no_image_error() {
    local project_dir="${1:-unknown}"
    cecho "No Docker image found for this project" "$RED" >&2
    echo >&2
    cecho "To build the image:" "$YELLOW" >&2
    echo >&2
    printf "%s\n" "  ${WHITE}cd $project_dir${NC}" >&2
    printf "%s\n" "  ${WHITE}claudebox${NC}" >&2
    echo >&2
    cecho "Or if you're already in the project directory:" "$YELLOW" >&2
    printf "%s\n" "  ${WHITE}claudebox${NC}" >&2
    echo >&2
    printf "%s\n" "${DIM}The first build may take a few minutes to download packages.${NC}" >&2
    echo >&2
    exit 1
}

# Enhanced error for slot not found
slot_not_found_error() {
    local slot_num="$1"
    cecho "Slot $slot_num does not exist" "$RED" >&2
    echo >&2
    cecho "To see available slots:" "$YELLOW" >&2
    printf "%s\n" "  ${WHITE}claudebox slots${NC}" >&2
    echo >&2
    cecho "To create a new slot:" "$YELLOW" >&2
    printf "%s\n" "  ${WHITE}claudebox create${NC}" >&2
    echo >&2
    exit 1
}

# -------- logo functions ------------------------------------------------------
logo() {
    local cb='
 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝

██████╗  ██████╗ ██╗  ██╗ ██████╗       ██████╗
██╔══██╗██╔═══██╗╚██╗██╔╝ ╚════██╗     ██╔═████╗
██████╔╝██║   ██║ ╚███╔╝   █████╔╝     ██║██╔██║
██╔══██╗██║   ██║ ██╔██╗  ██╔═══╝      ████╔╝██║
██████╔╝╚██████╔╝██╔╝ ██╗ ███████╗ ██╗ ╚██████╔╝
╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚══════╝ ╚═╝  ╚═════╝
       ┌───────────────────────────────────┐
       │    The Ultimate Claude Code       │
       │       Docker Dev Environment      │
       └───────────────────────────────────┘
'
    while IFS= read -r l; do
        o="" c=""
        for ((i=0;i<${#l};i++)); do
            ch="${l:$i:1}"
            if [ "$ch" = " " ]; then
                o+="$ch"
                continue
            fi
            cc=$(printf '%d' "'$ch" 2>/dev/null||echo 0)
            if [ $cc -ge 32 ] && [ $cc -le 126 ]; then n='\033[33m'      # Yellow for regular text
            elif [ $cc -ge 9552 ] && [ $cc -le 9580 ]; then n='\033[34m'  # Blue for box drawing
            elif [ $cc -eq 9608 ]; then n='\033[31m'                      # Red for block chars
            else n='\033[37m'; fi                                          # White for others
            if [ "$n" != "$c" ]; then
                o+="$n"
                c="$n"
            fi
            o+="$ch"
        done
        printf "${o}\033[0m\n"
    done <<< "$cb"
}

logo_header() {
    local cb='
╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║  █▀▀ █   ▄▀█ █ █ █▀▄ █▀▀ █▄▄ █▀█ ▀▄▀   Docker Environment for Claude Code  ║
║  █▄▄ █▄▄ █▀█ █▄█ █▄▀ ██▄ █▄█ █▄█ █ █    Isolated  •  Secure  •  Powerful   ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
'
    while IFS= read -r l; do
        o="" c=""
        for ((i=0;i<${#l};i++)); do
            ch="${l:$i:1}"
            if [ "$ch" = " " ]; then
                o+="$ch"
                continue
            fi
            cc=$(printf '%d' "'$ch" 2>/dev/null||echo 0)
            if [ $cc -ge 32 ] && [ $cc -le 126 ] && [ "$ch" != "•" ]; then n='\033[33m'      # Yellow for regular text
            elif [ $cc -ge 9552 ] && [ $cc -le 9580 ]; then n='\033[34m'  # Blue for box drawing
            elif [ $cc -eq 9608 ] || [ $cc -ge 9600 ] && [ $cc -le 9631 ]; then n='\033[31m'  # Red for block chars (CLAUDEBOX)
            elif [ "$ch" = "•" ]; then n='\033[32m'                       # Green for bullets
            else n='\033[33m'; fi                                          # Yellow for others
            if [ "$n" != "$c" ]; then
                o+="$n"
                c="$n"
            fi
            o+="$ch"
        done
        printf "${o}\033[0m\n"
    done <<< "$cb"
}

logo_small() {
    local cb='
█▀▀ █   ▄▀█ █ █ █▀▄ █▀▀ █▄▄ █▀█ ▀▄▀
█▄▄ █▄▄ █▀█ █▄█ █▄▀ ██▄ █▄█ █▄█ █ █
'
    printf "${RED}%s${NC}" "$cb"
}


# -------- fillbar progress indicator ------------------------------------------
FILLBAR_PID=""

fillbar() {
    case "${1:-}" in
        stop)
            if [ ! -z "$FILLBAR_PID" ]; then
                kill $FILLBAR_PID 2>/dev/null
            fi
            printf "\r\033[K"
            tput cnorm
            FILLBAR_PID=""
            ;;
        *)
            (
                p=0
                tput civis
                while true; do
                    printf "\r"
                    full=$((p / 8))
                    part=$((p % 8))
                    i=0
                    while [ $i -lt $full ]; do
                        printf "█"
                        i=$((i + 1))
                    done
                    if [ $part -gt 0 ]; then
                        pb=$(printf %x $((0x258F - part + 1)))
                        printf "\\u$pb"
                    fi
                    p=$((p + 1))
                    sleep 0.01
                done
            ) &
            FILLBAR_PID=$!
            ;;
    esac
}

export -f cecho error warn info success logo logo_header logo_small fillbar
