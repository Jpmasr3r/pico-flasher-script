# pico-flasher-script

Script de compilação para projetos com **Raspberry Pi Pico / RP2040** usando o [Pico SDK](https://github.com/raspberrypi/pico-sdk).

Automatiza o processo de configuração, compilação e gravação do firmware, com suporte a múltiplas placas e reboot via `picotool`.

---

## Requisitos

- `cmake`
- `make`
- `arm-none-eabi-gcc`
- `picotool` *(opcional, necessário para `--reboot`)*

Instale no Arch Linux:

```bash
sudo pacman -S cmake make arm-none-eabi-gcc
paru -S picotool
```

Variável de ambiente necessária:

```bash
export PICO_SDK_PATH=/caminho/para/pico-sdk
```

---

## Instalação

```bash
git clone https://github.com/jpmasr3r/pico-flasher-script
cp pico-flasher-scritpt/compile.sh seu-projeto/
chmod +x seu-projeto/compile.sh
```

---

## Uso

```bash
./compile.sh [opções]
```

| Opção | Atalho | Descrição |
|---|---|---|
| *(sem opção)* | | Compila o projeto |
| `--full` | `-f` | Limpa e recompila do zero |
| `--flash` | | Compila e grava no Pico |
| `--reboot` | `-r` | Reinicia o Pico em modo BOOTSEL via picotool |
| `--board <nome>` | `-B` | Define a placa alvo |
| `--list-boards` | `-lb` | Lista as placas suportadas |
| `--clean-build` | `-cb` | Remove o diretório de build |
| `--clean-files` | `-cf` | Remove arquivos `.uf2`, `.elf`, `.bin` |
| `--clean` | `-c` | Remove build e arquivos gerados |
| `--check` | `-e` | Verifica dependências |
| `--name <nome>` | `-n` | Define o nome do arquivo de saída |
| `--build-dir <dir>` | `-b` | Define o diretório de build |
| `--help` | `-h` | Exibe a ajuda |
| `--license` | `-l` | Exibe a licença GPLv2 |

---

## Exemplos

```bash
# Compilar normalmente
./compile.sh

# Recompilar do zero e gravar
./compile.sh --full --flash

# Usar placa específica
./compile.sh --board pico_w --flash

# Reiniciar o Pico em modo BOOTSEL sem apertar o botão
./compile.sh --reboot

# Reiniciar e gravar em seguida
./compile.sh --reboot && ./compile.sh --flash
```

---

## Placas suportadas

| Placa | `--board` |
|---|---|
| Raspberry Pi Pico | `pico` |
| Raspberry Pi Pico W | `pico_w` |
| Raspberry Pi Pico 2 | `pico2` |
| Adafruit Feather RP2040 | `adafruit_feather_rp2040` |
| Adafruit ItsyBitsy RP2040 | `adafruit_itsybitsy_rp2040` |
| Adafruit QT Py RP2040 | `adafruit_qtpy_rp2040` |
| Pimoroni Tiny 2040 | `pimoroni_tiny2040` |
| Waveshare RP2040 Zero | `waveshare_rp2040_zero` |

Qualquer outra placa do SDK pode ser usada passando o nome diretamente. Lista completa em `$PICO_SDK_PATH/src/boards/include/boards/`.

> O script usa `adafruit_feather_rp2040` como padrão por compatibilidade com clones paralelos do Pico.

---

## Gravação sem apertar BOOTSEL

Para usar `--reboot` e `--flash` sem sudo, configure as regras udev:

```bash
sudo nano /etc/udev/rules.d/99-pico.rules
```

```
SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0005", MODE="0660", GROUP="uucp", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0003", MODE="0660", GROUP="uucp", TAG+="uaccess"
```

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG uucp $USER
```

Seu firmware precisa ter `stdio_init_all()` e um loop infinito no `main` para manter o USB ativo.

---

## Licença

Este projeto é distribuído sob a licença [GNU GPL v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).
