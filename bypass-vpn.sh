#!/bin/bash

set -e

# =========[ CONFIG DEFAULTS ]=========
CONFIG_FILE="$HOME/.bypass-vpn.conf"
TABLE_NAME="local_bypass"
TABLE_ID="100"
DEFAULT_PRIORITY=1000
DOCKER_NETWORK_DRIVER="bridge"
EXTRA_SUBNETS=()
LANGUAGE="en"  # Default, overridden by config or --lang

# =========[ FLAGS ]=========
VERBOSE=0
DRY_RUN=0
RESET=0
LIST_ONLY=0
CHECK_VPN=0
UPDATE_LANG=0

# =========[ COLOR CODES ]=========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# =========[ BILINGUAL MESSAGES ]=========
declare -A MESSAGES_EN MESSAGES_RU

MESSAGES_EN=(
    ["usage"]="Usage: $0 [--verbose] [--dry-run] [--reset] [--list] [--check-vpn] [--lang {en|ru}] [--help]\n\nOptions:\n  --verbose     Show detailed output\n  --dry-run     Show what would be done without executing\n  --reset       Remove all rules and routes for table '$TABLE_NAME'\n  --list        List current rules and routes\n  --check-vpn   Check if VPN is active\n  --lang        Set language (en or ru) and update config\n  --help        Show this help\n\nPurpose:\n  Bypasses VPN routing for localhost and Docker subnets.\n  Useful for development servers listening on 127.0.0.1."
    ["reset"]="Removing all rules and routes from table $TABLE_NAME"
    ["list_rules"]="IP rules with $TABLE_NAME"
    ["list_routes"]="Routes in table $TABLE_NAME"
    ["no_rules"]="(no rules)"
    ["no_table"]="(table is empty or does not exist)"
    ["table_added"]="Added routing table $TABLE_NAME ($TABLE_ID) to /etc/iproute2/rt_tables"
    ["localhost_rules"]="Adding rules for 127.0.0.0/8"
    ["docker_search"]="Searching for Docker networks (driver=$DOCKER_NETWORK_DRIVER)..."
    ["docker_processing"]="→ Processing network"
    ["docker_no_subnet"]="[WARN] Subnet not found for"
    ["docker_no_iface"]="[WARN] Interface not found for"
    ["docker_adding"]="→ Adding:"
    ["no_docker"]="[WARN] Docker not found"
    ["extra_subnet"]="→ EXTRA:"
    ["no_iface_subnet"]="[WARN] Interface not found for"
    ["completed"]="✅ Completed."
    ["no_root"]="Error: This script requires root privileges."
    ["vpn_check"]="Checking VPN status..."
    ["vpn_active"]="VPN is active on interface"
    ["vpn_inactive"]="No VPN detected."
    ["invalid_lang"]="Invalid language. Use 'en' or 'ru'."
    ["invalid_subnet"]="Invalid subnet format:"
    ["lang_set"]="Language set to"
    ["config_error"]="Warning: Config file $CONFIG_FILE is not readable."
    ["config_updated"]="Updated config file $CONFIG_FILE with LANGUAGE=$LANGUAGE"
)

MESSAGES_RU=(
    ["usage"]="Использование: $0 [--verbose] [--dry-run] [--reset] [--list] [--check-vpn] [--lang {en|ru}] [--help]\n\nОпции:\n  --verbose     Вывод подробной информации\n  --dry-run     Показать, что будет сделано, без выполнения\n  --reset       Удалить все правила и маршруты таблицы '$TABLE_NAME'\n  --list        Показать текущие правила и маршруты\n  --check-vpn   Проверить, активен ли VPN\n  --lang        Установить язык (en или ru) и обновить конфигурацию\n  --help        Показать эту справку\n\nНазначение:\n  Обходит VPN-маршрутизацию для localhost и docker-подсетей.\n  Полезно для серверов разработки, слушающих на 127.0.0.1."
    ["reset"]="[!] Удаляем все правила и маршруты из таблицы $TABLE_NAME"
    ["list_rules"]="== Правила IP с $TABLE_NAME =="
    ["list_routes"]="== Маршруты в таблице $TABLE_NAME =="
    ["no_rules"]="(нет правил)"
    ["no_table"]="(таблица пуста или не существует)"
    ["table_added"]="Добавлена таблица маршрутизации $TABLE_NAME ($TABLE_ID) в /etc/iproute2/rt_tables"
    ["localhost_rules"]="Добавляем правила для 127.0.0.0/8"
    ["docker_search"]="Ищем docker-сети (driver=$DOCKER_NETWORK_DRIVER)..."
    ["docker_processing"]="→ Обработка сети"
    ["docker_no_subnet"]="[WARN] subnet не найдена для"
    ["docker_no_iface"]="[WARN] iface не найден для"
    ["docker_adding"]="→ Добавляем:"
    ["no_docker"]="[WARN] Docker не найден"
    ["extra_subnet"]="→ EXTRA:"
    ["no_iface_subnet"]="[WARN] iface не найден для"
    ["completed"]="✅ Завершено."
    ["no_root"]="Ошибка: Этот скрипт требует права суперпользователя."
    ["vpn_check"]="Проверка статуса VPN..."
    ["vpn_active"]="VPN активен на интерфейсе"
    ["vpn_inactive"]="VPN не обнаружен."
    ["invalid_lang"]="Неверный язык. Используйте 'en' или 'ru'."
    ["invalid_subnet"]="Неверный формат подсети:"
    ["lang_set"]="Язык установлен на"
    ["config_error"]="Предупреждение: Файл конфигурации $CONFIG_FILE не читаем."
    ["config_updated"]="Обновлен файл конфигурации $CONFIG_FILE с LANGUAGE=$LANGUAGE"
)

# =========[ LOAD CONFIG ]=========
if [[ -f "$CONFIG_FILE" && -r "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    [[ -f "$CONFIG_FILE" ]] && echo -e "${YELLOW}$(msg config_error)${NC}"
fi

# =========[ MESSAGE FUNCTION ]=========
msg() {
    local key="$1"
    if [[ "$LANGUAGE" == "ru" ]]; then
        echo -e "${MESSAGES_RU[$key]}"
    else
        echo -e "${MESSAGES_EN[$key]}"
    fi
}

# =========[ LOGGING ]=========
log() {
    [[ "$VERBOSE" == "1" ]] && echo -e "${YELLOW}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

run() {
    [[ "$DRY_RUN" == "1" ]] && echo -e "${GREEN}[DRY]${NC} $*" || eval "$@"
}

# =========[ UPDATE CONFIG FILE ]=========
update_config() {
    if [[ "$DRY_RUN" == "1" ]]; then
        log "[DRY] Would update $CONFIG_FILE with LANGUAGE=$LANGUAGE"
        return
    fi
    {
        echo "# Configuration file for bypass-vpn.sh"
        echo "TABLE_NAME=\"$TABLE_NAME\""
        echo "TABLE_ID=\"$TABLE_ID\""
        echo "DEFAULT_PRIORITY=$DEFAULT_PRIORITY"
        echo "DOCKER_NETWORK_DRIVER=\"$DOCKER_NETWORK_DRIVER\""
        echo "EXTRA_SUBNETS=(${EXTRA_SUBNETS[*]})"
        echo "LANGUAGE=\"$LANGUAGE\""
    } > "$CONFIG_FILE"
    log "$(msg config_updated)"
}

# =========[ VALIDATE ROOT ]=========
if [[ $EUID -ne 0 ]]; then
    error "$(msg no_root)"
fi

# =========[ HELP ]=========
usage() {
    msg usage
    exit 0
}

# =========[ PARSE ARGS ]=========
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose) VERBOSE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --reset) RESET=1 ;;
        --list) LIST_ONLY=1 ;;
        --check-vpn) CHECK_VPN=1 ;;
        --lang)
            shift
            if [[ "$1" == "en" || "$1" == "ru" ]]; then
                LANGUAGE="$1"
                UPDATE_LANG=1
            else
                error "$(msg invalid_lang)"
            fi
            ;;
        --help|-h) usage ;;
        *) error "Unknown option: $1" ;;
    esac
    shift
done

# Update config file if language changed
[[ "$UPDATE_LANG" == "1" ]] && update_config

# Log language selection if verbose
log "$(msg lang_set) $LANGUAGE"

# =========[ CHECK VPN STATUS ]=========
check_vpn() {
    echo "$(msg vpn_check)"
    vpn_iface=$(ip link | grep -E 'tun[0-9]+|wg[0-9]+|ppp[0-9]+|outline-tun[0-9]+' | awk -F: '{print $2}' | tr -d ' ' | head -n1)
    if [[ -n "$vpn_iface" ]]; then
        echo "$(msg vpn_active) $vpn_iface"
        log "Detected VPN interface: $vpn_iface"
    else
        echo "$(msg vpn_inactive)"
        log "No VPN interfaces (tun*, wg*, ppp*, outline-tun*) found"
    fi
}

# =========[ RESET MODE ]=========
if [[ "$RESET" == "1" ]]; then
    echo "$(msg reset)"
    sudo ip rule show | grep "$TABLE_NAME" | while read -r line; do
        PRIORITY=$(echo "$line" | awk -F: '{print $1}')
        run sudo ip rule del priority "$PRIORITY"
    done
    run sudo ip route flush table "$TABLE_NAME"
    exit 0
fi

# =========[ LIST MODE ]=========
if [[ "$LIST_ONLY" == "1" ]]; then
    echo "$(msg list_rules)"
    ip rule show | grep "$TABLE_NAME" || echo "$(msg no_rules)"
    echo "$(msg list_routes)"
    ip route show table "$TABLE_NAME" 2>/dev/null || echo "$(msg no_table)"
    exit 0
fi

# =========[ CHECK VPN ]=========
if [[ "$CHECK_VPN" == "1" ]]; then
    check_vpn
    exit 0
fi

# =========[ VALIDATE SUBNETS ]=========
validate_subnet() {
    local subnet="$1"
    if [[ ! "$subnet" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        error "$(msg invalid_subnet) $subnet"
    fi
}

# =========[ 1. Ensure table exists in rt_tables ]=========
if ! grep -qE "^$TABLE_ID[[:space:]]+$TABLE_NAME" /etc/iproute2/rt_tables; then
    echo "$TABLE_ID $TABLE_NAME" | sudo tee -a /etc/iproute2/rt_tables > /dev/null
    log "$(msg table_added)"
fi

# =========[ 2. Add localhost rules safely ]=========
log "$(msg localhost_rules)"
run sudo ip route add local 127.0.0.0/8 dev lo table "$TABLE_NAME" 2>/dev/null || true
run sudo ip rule add from 127.0.0.0/8 lookup "$TABLE_NAME" priority "$DEFAULT_PRIORITY" 2>/dev/null || true
run sudo ip rule add to 127.0.0.0/8 lookup "$TABLE_NAME" priority "$DEFAULT_PRIORITY" 2>/dev/null || true

# =========[ 3. Docker subnet detection ]=========
if command -v docker >/dev/null 2>&1; then
    log "$(msg docker_search)"
    docker network ls --filter driver="$DOCKER_NETWORK_DRIVER" --format '{{.Name}}' | while read -r net_name; do
        log "$(msg docker_processing) $net_name"
        subnet=$(docker network inspect "$net_name" 2>/dev/null | grep Subnet | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' | head -n1)
        [[ -z "$subnet" ]] && log "$(msg docker_no_subnet) $net_name" && continue

        validate_subnet "$subnet"
        iface=$(ip route | grep "$subnet" | awk '{print $3}' | head -n1)
        [[ -z "$iface" ]] && log "$(msg docker_no_iface) $subnet" && continue

        log "$(msg docker_adding) $subnet через $iface"
        run sudo ip route add "$subnet" dev "$iface" table "$TABLE_NAME" 2>/dev/null || true
        run sudo ip rule add to "$subnet" lookup "$TABLE_NAME" priority $((DEFAULT_PRIORITY + 10)) 2>/dev/null || true
    done
else
    log "$(msg no_docker)"
fi

# =========[ 4. Extra manual subnets ]=========
for subnet in "${EXTRA_SUBNETS[@]}"; do
    validate_subnet "$subnet"
    iface=$(ip route | grep "$subnet" | awk '{print $3}' | head -n1)
    [[ -z "$iface" ]] && log "$(msg no_iface_subnet) $subnet" && continue

    log "$(msg extra_subnet) $subnet через $iface"
    run sudo ip route add "$subnet" dev "$iface" table "$TABLE_NAME" 2>/dev/null || true
    run sudo ip rule add to "$subnet" lookup "$TABLE_NAME" priority $((DEFAULT_PRIORITY + 20)) 2>/dev/null || true
done

log "$(msg completed)"