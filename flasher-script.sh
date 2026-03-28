#!/bin/bash
# ============================================================
#  compile.sh — Script de compilação para Raspberry Pi Pico
# ============================================================

set -e  # Para se der algum erro

# --- Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
NC='\033[0m'

# --- Configurações ---
BUILD_DIR="build"
PROJECT_NAME=$(basename "$PWD")
CORES=$(nproc)
PICO_BOARD="adafruit_feather_rp2040"  # padrão para clone paralelo
BOOT_LABEL="RPI-RP2"                   # label do clone no modo BOOTSEL

# --- Placas suportadas ---
SUPPORTED_BOARDS=(
    "pico"
    "pico_w"
    "pico2"
    "adafruit_feather_rp2040"
    "adafruit_itsybitsy_rp2040"
    "adafruit_qtpy_rp2040"
    "adafruit_trinkey_qt2040"
    "adafruit_macropad_rp2040"
    "sparkfun_micromod_rp2040"
    "sparkfun_promicro_rp2040"
    "arduino_nano_rp2040_connect"
    "pimoroni_tiny2040"
    "waveshare_rp2040_zero"
)

# --- Funções ---
info()    { echo -e "${CYAN}${BOLD}[INFO]${NC} ${CYAN}$1${NC}"; }
success() { echo -e "${GREEN}${BOLD}[OK]${NC} ${GREEN}$1${NC}"; }
warning() { echo -e "${YELLOW}${BOLD}[AVISO]${NC} ${YELLOW}$1${NC}"; }
error()   { echo -e "${RED}${BOLD}[ERRO]${NC} ${RED}$1${NC}"; exit 1; }

print_header() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           Script de compilação — Raspberry Pi Pico       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

goodbye_footer() {
    echo ""
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                   Encerrando Sript                       ║"
    echo "║                🐱 Obrigado por usar 🐱                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# --- Verifica dependências ---
check_deps() {
    info "Verificando dependências..."
    for cmd in cmake make arm-none-eabi-gcc; do
        if ! command -v "$cmd" &> /dev/null; then
            error "'$cmd' não encontrado. Instale com: sudo pacman -S $( [[ "$cmd" == "arm-none-eabi-gcc" ]] && echo "arm-none-eabi-gcc" || echo "$cmd" )"
        fi
    done
    success "Dependências OK"
}

# --- Limpa build ---
clean_build() {
    if [ -d "$BUILD_DIR" ]; then
        warning "Limpando diretório de build..."
        rm -rf "$BUILD_DIR"
        success "Build limpo"
    else
        info "Nada para limpar"
    fi
}

run_cmake() {
    info "Executando CMake..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    CMAKE_ARGS=".."
    if [ -n "$PICO_BOARD" ]; then
        info "Placa selecionada: ${BOLD}$PICO_BOARD${NC}"
        cmake -DPICO_BOARD="$PICO_BOARD" .. 2>&1 | tail -5 || error "Erro no CMake"
    else
        cmake .. 2>&1 | tail -5 || error "Erro no CMake"
    fi

    cd ..
    success "Configuração concluída"
}

# --- Compila ---
run_make() {
    info "Compilando com $CORES núcleos..."
    cd "$BUILD_DIR"
    make -j"$CORES" 2>&1 || error "Erro durante a compilação"
    cd ..
    success "Compilação concluída"
}

# --- Reinicia o Pico em modo BOOTSEL via picotool ---
reboot_pico() {
    if ! command -v picotool &> /dev/null; then
        error "picotool não encontrado. Instale com: paru -S picotool"
    fi

    info "Tentando reiniciar o Pico em modo BOOTSEL..."

    if picotool reboot -f -u 2>/dev/null; then
        success "Pico reiniciado em modo BOOTSEL!"
        info "Aguardando montar..."
        sleep 2
    else
        warning "Não foi possível reiniciar automaticamente."
        warning "O firmware atual pode não ter stdio USB ativo."
        warning "Certifique-se que seu main.c chama stdio_init_all()"
        warning "e grave uma vez manualmente segurando BOOTSEL."
        exit 1
    fi
}

# --- Grava no Pico ---
flash_pico() {
    info "Iniciando gravação no Pico..."

    UF2="./${PROJECT_NAME}.uf2"

    if [ ! -f "$UF2" ]; then
        error "Arquivo .uf2 não encontrado: $UF2"
    fi

    # Tenta com picotool
    PICOTOOL="$BUILD_DIR/_deps/picotool-build/picotool"
    if [ -f "$PICOTOOL" ]; then
        info "Gravando com picotool..."
        "$PICOTOOL" load "$UF2" -f && success "Gravado com sucesso!" && return
    fi

    # Aguarda o dispositivo montar (timeout 15s)
    info "Aguardando $BOOT_LABEL montar..."
    TIMEOUT=15
    ELAPSED=0
    MOUNT_POINT=""

    while [ $ELAPSED -lt $TIMEOUT ]; do
        MOUNT_POINT=$(findmnt -n -o TARGET --source LABEL="$BOOT_LABEL" 2>/dev/null)
        [ -z "$MOUNT_POINT" ] && MOUNT_POINT=$(ls /run/media/"$USER"/ 2>/dev/null | grep -i "$BOOT_LABEL" | head -1)
        [ -z "$MOUNT_POINT" ] && MOUNT_POINT=$(ls /media/ 2>/dev/null | grep -i "$BOOT_LABEL" | head -1)

        if [ -n "$MOUNT_POINT" ]; then
            break
        fi

        sleep 1
        ELAPSED=$((ELAPSED + 1))
        echo -ne "${DIM}  esperando... ${ELAPSED}s/${TIMEOUT}s\r${NC}"
    done
    echo ""

    if [ -n "$MOUNT_POINT" ]; then
        # Garante o caminho completo
        [[ "$MOUNT_POINT" != /* ]] && MOUNT_POINT="/run/media/$USER/$MOUNT_POINT"
        info "Copiando para $MOUNT_POINT ..."
        cp "$UF2" "$MOUNT_POINT/"
        sync
        success "Gravado com sucesso!"
    else
        warning "Dispositivo não montou após ${TIMEOUT}s"
        warning "Segure BOOTSEL, conecte o USB e rode: $0 --flash"
        warning "Ou copie manualmente: cp $UF2 /run/media/\$USER/$BOOT_LABEL/"
    fi
}

rename() {
    found=false

    for ext in uf2 bin elf
    do
        count=1

        for file in "$BUILD_DIR"/*."$ext"
        do
            [ -e "$file" ] || continue

            if [ $count -eq 1 ]; then
                cp "$file" "./${PROJECT_NAME}.${ext}"
                success "Arquivo gerado: ./${PROJECT_NAME}.${ext}"
            else
                cp "$file" "./${PROJECT_NAME}.${count}.${ext}"
                success "Arquivo gerado: ./${PROJECT_NAME}.${count}.${ext}"
            fi

            count=$((count + 1))
            found=true
        done
    done

    if ! $found; then
        error "Nenhum arquivo (.uf2, .bin, .elf) encontrado em $BUILD_DIR"
    fi
}

clean_files() {
    found=false

    for ext in uf2 bin elf
    do
        for file in ./*."$ext"
        do
            [ -e "$file" ] || continue
            rm "$file"
            found=true
        done
    done

    if $found; then
        success "Arquivos (.uf2, .bin, .elf) removidos"
    else
        info "Nenhum arquivo (.uf2, .bin, .elf) para remover"
    fi
}

list_boards() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                  Placas suportadas                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    for board in "${SUPPORTED_BOARDS[@]}"; do
        echo -e "  ${CYAN}•${NC} $board"
    done
    echo ""
    echo -e "  ${DIM}Qualquer outra placa do SDK pode ser usada com ${NC}${GREEN}--board <nome>${NC}"
    echo -e "  ${DIM}Lista completa em:${NC} ${UNDERLINE}\$PICO_SDK_PATH/src/boards/include/boards/${NC}"
    echo ""
}

show_help() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                        AJUDA                             ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${YELLOW}${BOLD}USO:${NC}"
    echo -e "  ${CYAN}./compile.sh [opções]${NC}"
    echo ""

    echo -e "${YELLOW}${BOLD}OPÇÕES:${NC}"
    echo -e "  ${GREEN}${BOLD}(sem opção)${NC}"
    echo -e "      ${DIM}Compila o projeto${NC}"
    echo -e "      ${DIM}Executa CMake se necessário e depois make${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--full${NC}, ${GREEN}-f${NC}"
    echo -e "      ${DIM}Recompila do zero${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--flash${NC}"
    echo -e "      ${DIM}Compila e grava no Raspberry Pi Pico${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--board${NC}, ${GREEN}-B${NC} <nome>"
    echo -e "      ${DIM}Define a placa alvo para compilação${NC}"
    echo -e "      ${DIM}Exemplo: --board adafruit_feather_rp2040${NC}"
    echo -e "      ${DIM}Use --list-boards para ver as placas disponíveis${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--list-boards${NC}, ${GREEN}-lb${NC}"
    echo -e "      ${DIM}Lista as placas suportadas${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--clean-build${NC}, ${GREEN}-cb${NC}"
    echo -e "      ${DIM}Remove o diretório de build${NC}"
    echo -e "      ${YELLOW}${DIM}Obs: só remove se o diretório for '${BUILD_DIR}'${NC}"
    echo -e "      ${YELLOW}${DIM}Diretórios personalizados podem não ser encontrados${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--clean-files${NC}, ${GREEN}-cf${NC}"
    echo -e "      ${DIM}Remove todos os arquivos .uf2, .elf, .bin${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--clean${NC}, ${GREEN}-c${NC}"
    echo -e "      ${DIM}Remove o diretório de build${NC}"
    echo -e "      ${DIM}Remove todos os arquivos .uf2, .elf, .bin${NC}"
    echo -e "      ${YELLOW}${DIM}Obs: o build só será removido se for '${BUILD_DIR}'${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--check${NC}, ${GREEN}-e${NC}"
    echo -e "      ${DIM}Verifica dependências${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--name${NC}, ${GREEN}-n${NC} <nome>"
    echo -e "      ${DIM}Define o nome do arquivo${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--build-dir${NC}, ${GREEN}-b${NC} <dir>"
    echo -e "      ${DIM}Define o diretório de build${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--help${NC}, ${GREEN}-h${NC}"
    echo -e "      ${DIM}Exibe esta ajuda${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}--license${NC}, ${GREEN}-l${NC}"
    echo -e "      ${DIM}Exibe o texto completo da licença GPLv3${NC}"
    echo -e "      ${DIM}Utiliza o arquivo baixado da internet${NC}"
    echo ""

    echo -e "${YELLOW}${BOLD}EXEMPLOS:${NC}"
    echo -e "  ${CYAN}./compile.sh${NC}"
    echo -e "  ${CYAN}./compile.sh --full${NC}"
    echo -e "  ${CYAN}./compile.sh --flash${NC}"
    echo -e "  ${CYAN}./compile.sh --board adafruit_feather_rp2040${NC}"
    echo -e "  ${CYAN}./compile.sh --board adafruit_feather_rp2040 --flash${NC}"
    echo -e "  ${CYAN}./compile.sh --full --board pico_w --flash${NC}"
    echo -e "  ${CYAN}./compile.sh --name blink${NC}"
    echo ""

    echo -e "${YELLOW}${BOLD}ARQUIVOS GERADOS:${NC}"
    echo -e "  ${BLUE}${BUILD_DIR}/${PROJECT_NAME}.uf2${NC}"
    echo -e "  ${BLUE}${BUILD_DIR}/${PROJECT_NAME}.elf${NC}"
    echo -e "  ${BLUE}${BUILD_DIR}/${PROJECT_NAME}.bin${NC}"
    echo ""

    echo -e "${YELLOW}${BOLD}DEPENDÊNCIAS:${NC}"
    echo -e "  ${DIM}cmake, make, arm-none-eabi-gcc${NC}"
    echo ""
}

show_license() {
    info "Exibindo licença GPLv2..."

    LICENSE_FILE="LICENSE"

    if [ ! -f "$LICENSE_FILE" ]; then
        info "Arquivo LICENSE não encontrado, baixando..."
        curl -s https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt -o "$LICENSE_FILE" \
            || error "Falha ao baixar a licença"
        success "LICENSE criado"
    fi

    if command -v less &> /dev/null; then
        less "$LICENSE_FILE"
    else
        cat "$LICENSE_FILE"
    fi

    echo ""
    echo -e "${MAGENTA}${DIM}══════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}${DIM}${NC} ${BOLD}Script de compilação Raspberry Pi Pico${NC}"
    echo -e "${MAGENTA}${DIM}${NC} ${DIM}Autor:${NC} ${CYAN}Jpmasr3r${NC}"
    echo -e "${MAGENTA}${DIM}${NC} ${DIM}Licença:${NC} ${CYAN}GNU GPL v2${NC}"
    echo -e "${MAGENTA}${DIM}${NC} ${DIM}Ano:${NC} ${CYAN}$(date +%Y)${NC}"
    echo -e "${MAGENTA}${DIM}══════════════════════════════════════════════════════════${NC}"
}

# --- Main ---
print_header
info "Placa padrão : ${BOLD}$PICO_BOARD${NC}"
info "Label BOOTSEL: ${BOLD}$BOOT_LABEL${NC}"
echo ""

use_full=false
use_flash=false
new_args=()

for arg in "$@"
do
    if [ "$arg" = "--full" ] || [ "$arg" = "-f" ]
    then
        use_full=true
        for arg in "$@"
        do
            if [ "$arg" != "--full" ] && [ "$arg" != "-f" ]
            then
                new_args+=("$arg")
            fi
        done
        set -- "${new_args[@]}"
        break
    fi
done

while [ $# -gt 0 ]
do
    case "$1" in
        --clean-build|-cb)
            clean_build
            exit 0
            ;;
        --clean-files|-cf)
            clean_files
            exit 0
            ;;
        --clean|-c)
            clean_build
            clean_files
            exit 0
            ;;
        --check|-e)
            check_deps
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --list-boards|-lb)
            list_boards
            exit 0
            ;;
        --board|-B)
            [ -z "$2" ] && error "--board requer um nome de placa. Use --list-boards para ver as opções."
            PICO_BOARD="$2"
            shift 2
            ;;
        --name|-n)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --build-dir|-b)
            BUILD_DIR=$2
            shift 2
            ;;
        --flash)
            use_flash=true
            shift 1
            ;;
        --reboot|-r)
            reboot_pico
            exit 0
            ;;
        --license|-l)
            show_license
            exit 0
            ;;
        *)
            error "Opção inválida: $1"
            ;;
    esac
done

check_deps

if $use_full;
then
    clean_build
    run_cmake
else
    [ ! -f "$BUILD_DIR/Makefile" ] && run_cmake
fi

run_make

rename

if $use_flash;
then
    flash_pico
fi

echo ""
echo -e "${GREEN}${BOLD}[OK]${NC} ${GREEN}Pronto!${NC} ${DIM}Arquivos gerados:${NC}"
echo -e "${BLUE}${UNDERLINE}./${PROJECT_NAME}.uf2${NC}"
echo -e "${BLUE}${UNDERLINE}./${PROJECT_NAME}.elf${NC}"
echo -e "${BLUE}${UNDERLINE}./${PROJECT_NAME}.bin${NC}"

goodbye_footer
