# Bypass VPN

![GitHub](https://img.shields.io/github/license/ScarletVIS/vpn-fix-localhost)
![GitHub last commit](https://img.shields.io/github/last-commit/ScarletVIS/vpn-fix-localhost)
![GitHub issues](https://img.shields.io/github/issues/ScarletVIS/vpn-fix-localhost)

Bypass VPN routing for localhost and Docker subnets. Useful for development servers listening on `127.0.0.1` when a VPN is active.

**Русский**: Обходит VPN-маршрутизацию для localhost и Docker-подсетей. Полезно для серверов разработки, слушающих на `127.0.0.1`, при активном VPN.

## Features

- Automatically detects Docker networks
- Supports custom subnets via configuration
- Bilingual support (English and Russian)
- Color-coded logging
- VPN status checking
- Safe reset and dry-run modes

**Русский**:
- Автоматическое определение Docker-сетей
- Поддержка пользовательских подсетей через конфигурацию
- Двуязычная поддержка (английский и русский)
- Цветной вывод логов
- Проверка статуса VPN
- Безопасный сброс и режим сухого прогона

## Installation

```bash
git clone https://github.com/ScarletVIS/vpn-fix-localhost.git
cd bypass-vpn
chmod +x bypass-vpn.sh
```

## Usage

Run with sudo:

```bash
sudo ./bypass-vpn.sh
```

### Options

```bash
--verbose     Show detailed output
--dry-run     Show what would be done without executing
--reset       Remove all rules and routes
--list        List current rules and routes
--check-vpn   Check if VPN is active
--lang {en|ru} Set language (English or Russian)
--help        Show help
```

**Русский**:

```bash
--verbose     Вывод подробной информации
--dry-run     Показать, что будет сделано
--reset       Удалить все правила и маршруты
--list        Показать текущие правила и маршруты
--check-vpn   Проверить статус VPN
--lang {en|ru} Установить язык (английский или русский)
--help        Показать справку
```

## Configuration

Create a `$HOME/.bypass-vpn.conf` file to customize settings:

```bash
# Example configuration
TABLE_NAME="local_bypass"
TABLE_ID="100"
DEFAULT_PRIORITY=1000
DOCKER_NETWORK_DRIVER="bridge"
EXTRA_SUBNETS=("100.64.0.0/10" "192.168.0.0/16")
```

## Requirements

- `iproute2` for routing rules
- `docker` (optional) for Docker subnet detection
- Root privileges

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Feel free to open issues