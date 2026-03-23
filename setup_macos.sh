#!/bin/bash
# =============================================================================
# MOEX Terminal — Установка окружения разработки на macOS
# =============================================================================
# Скрипт устанавливает всё необходимое ПО для разработки торгового терминала.
# Запуск: chmod +x setup_macos.sh && ./setup_macos.sh
#
# Поддерживаемые системы: macOS 12+ (Intel и Apple Silicon)
# =============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}[→]${NC} $1 — уже установлен, пропускаю"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Определяем архитектуру
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
    echo -e "${GREEN}Обнаружен Apple Silicon (arm64)${NC}"
else
    BREW_PREFIX="/usr/local"
    echo -e "${GREEN}Обнаружен Intel (x86_64)${NC}"
fi

# =============================================================================
print_header "1. Xcode Command Line Tools"
# =============================================================================

if xcode-select -p &>/dev/null; then
    print_skip "Xcode CLI Tools"
else
    echo "Установка Xcode Command Line Tools..."
    echo "Откроется системный диалог — нажмите «Установить»."
    xcode-select --install
    echo ""
    echo "Дождитесь завершения установки, затем запустите этот скрипт повторно."
    exit 0
fi

# =============================================================================
print_header "2. Homebrew"
# =============================================================================

if command -v brew &>/dev/null; then
    print_skip "Homebrew"
    brew update
else
    echo "Установка Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Добавляем Homebrew в PATH для Apple Silicon
    if [ "$ARCH" = "arm64" ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    print_step "Homebrew установлен"
fi

# =============================================================================
print_header "3. Python 3.11+"
# =============================================================================

# Проверяем наличие Python 3.11+
PYTHON_OK=false
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 11 ]; then
        PYTHON_OK=true
        print_skip "Python $PY_VERSION"
    fi
fi

if [ "$PYTHON_OK" = false ]; then
    echo "Установка Python 3.11..."
    brew install python@3.11
    print_step "Python 3.11 установлен"
fi

# =============================================================================
print_header "4. Node.js 20+"
# =============================================================================

NODE_OK=false
if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -ge 20 ]; then
        NODE_OK=true
        print_skip "Node.js $(node -v)"
    fi
fi

if [ "$NODE_OK" = false ]; then
    echo "Установка Node.js 20..."
    brew install node@20
    # Линкуем, если не в PATH
    brew link --overwrite node@20 2>/dev/null || true
    print_step "Node.js 20 установлен"
fi

# =============================================================================
print_header "5. pnpm (менеджер пакетов frontend)"
# =============================================================================

if command -v pnpm &>/dev/null; then
    print_skip "pnpm $(pnpm -v)"
else
    echo "Установка pnpm..."
    npm install -g pnpm@9
    print_step "pnpm установлен"
fi

# =============================================================================
print_header "6. TA-Lib (C-библиотека для технических индикаторов)"
# =============================================================================

if brew list ta-lib &>/dev/null; then
    print_skip "TA-Lib"
else
    echo "Установка TA-Lib..."
    brew install ta-lib
    print_step "TA-Lib установлен"
fi

# =============================================================================
print_header "7. SQLite (свежая версия)"
# =============================================================================

if brew list sqlite &>/dev/null; then
    print_skip "SQLite"
else
    echo "Установка SQLite..."
    brew install sqlite
    print_step "SQLite установлен"
fi

# =============================================================================
print_header "8. Зависимости для WeasyPrint (генерация PDF)"
# =============================================================================

WEASY_DEPS=("cairo" "pango" "gdk-pixbuf" "libffi")
for dep in "${WEASY_DEPS[@]}"; do
    if brew list "$dep" &>/dev/null; then
        print_skip "$dep"
    else
        echo "Установка $dep..."
        brew install "$dep"
        print_step "$dep установлен"
    fi
done

# =============================================================================
print_header "9. Git (обновление)"
# =============================================================================

if brew list git &>/dev/null; then
    print_skip "Git (Homebrew)"
else
    echo "Установка Git через Homebrew..."
    brew install git
    print_step "Git установлен"
fi

# =============================================================================
print_header "10. Проверка установки"
# =============================================================================

echo ""
echo "Версии установленного ПО:"
echo "─────────────────────────────────────────"

check_version() {
    local name=$1
    local cmd=$2
    local result
    if result=$(eval "$cmd" 2>/dev/null); then
        echo -e "  ${GREEN}✓${NC} $name: $result"
    else
        echo -e "  ${RED}✗${NC} $name: не найден"
    fi
}

check_version "Python"    "python3 --version"
check_version "pip"       "python3 -m pip --version | head -c 40"
check_version "Node.js"   "node --version"
check_version "npm"       "npm --version"
check_version "pnpm"      "pnpm --version"
check_version "Git"       "git --version"
check_version "SQLite"    "sqlite3 --version | cut -d' ' -f1"
check_version "TA-Lib"    "brew info ta-lib --json | python3 -c 'import sys,json; print(json.load(sys.stdin)[0][\"versions\"][\"stable\"])'"
check_version "Cairo"     "brew info cairo --json | python3 -c 'import sys,json; print(json.load(sys.stdin)[0][\"versions\"][\"stable\"])'"

echo ""
echo "─────────────────────────────────────────"

# =============================================================================
print_header "Установка завершена"
# =============================================================================

echo ""
echo "Все системные зависимости установлены."
echo ""
echo "Следующие шаги:"
echo ""
echo -e "  ${BLUE}1.${NC} Клонировать репозиторий проекта:"
echo "     git clone <URL> moex-terminal && cd moex-terminal"
echo ""
echo -e "  ${BLUE}2.${NC} Запустить установку зависимостей проекта:"
echo "     ./scripts/install.sh"
echo ""
echo -e "  ${BLUE}3.${NC} Настроить .env:"
echo "     cp .env.example .env"
echo "     # Заполнить JWT_SECRET_KEY и ENCRYPTION_KEY"
echo ""
echo -e "  ${BLUE}4.${NC} Запустить приложение:"
echo "     ./scripts/start.sh"
echo ""
echo -e "  ${BLUE}5.${NC} Настроить AI-провайдера через UI:"
echo "     Открыть http://localhost:3000 → Настройки → AI-провайдеры"
echo "     Добавить ключ Claude API или OpenAI API"
echo "     Нажать «Проверить ключ» для верификации"
echo ""
echo -e "${YELLOW}Примечание:${NC} API-ключи AI-провайдеров можно настроить"
echo "непосредственно в интерфейсе приложения (Настройки → AI-провайдеры)."
echo "Ключи хранятся в зашифрованном виде в базе данных."
echo "Поддерживаются: Claude (Anthropic), OpenAI, а также"
echo "локальные LLM через OpenAI-совместимый API (Ollama, LM Studio)."
echo ""
