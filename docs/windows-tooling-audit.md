# Auditoria de herramientas para Windows

**Alcance**: documentación de decisión sobre qué herramientas del repositorio `dotfiles` pueden usarse en Windows y cómo. Este documento NO instala nada y NO modifica configuración.

## Resumen rapido

| Herramienta / modulo | Ubicacion en el repo | Estado en Windows | Camino recomendado | Referencia |
|----------------------|----------------------|-------------------|--------------------|------------|
| Neovim (config) | `nvim/` | Compatible | Nativo (instalar Neovim) + adaptar config | [neovim.io](https://neovim.io/) |
| Tmux | `Tmux/` | No compatible (nativo) | WSL2 + tmux | [tmux repo](https://github.com/tmux/tmux) |
| Ghostty | `ghostty/` | Parcialmente compatible | Binario nativo Windows + adaptar config | [ghostty.org](https://ghostty.org) |
| Zsh | `zsh/` | Parcialmente compatible | WSL2 + zsh, o Git Bash para scripts simples | [zsh.org](https://www.zsh.org/) |
| Iris Keyboard (VIA) | `keyboard/` | Compatible | VIA app nativa Windows | [usevia.app](https://www.usevia.app/) |
| Dotfiles Installer (Go) | `installer/` | No compatible (binarios solo darwin) | WSL2 + `go run`, o recompilar para Windows | [Go](https://go.dev/) |
| Setup scripts (bash/macOS) | `setup/` | No compatible (macOS-only) | WSL2, o revisión manual | [WSL](https://learn.microsoft.com/es-es/windows/wsl/) |
| GitHub Actions | `.github/workflows/` | Compatible (cloud) | Nativo (runner de GitHub) | [GitHub Actions](https://docs.github.com/es/actions) |
| `dist/` | `dist/` | Fuera de alcance | Generado (no se versiona contenido) | — |
| README raiz | `README.md` | Fuera de alcance | Documentación | — |

## Como leer los estados

- **Compatible**: existe una ruta de instalación nativa en Windows y la configuración del repo se puede adaptar sin barreras mayores.
- **Parcialmente compatible**: funciona solo con caveats, un subsistema (WSL2, Git Bash, MSYS2), adaptación manual, o funcionalidad reducida.
- **No compatible**: no es práctico o no está soportado en Windows para el contexto de este repositorio.
- **Fuera de alcance**: archivo o artefacto generado que no es una herramienta usable.

## Hallazgos por herramienta

### Neovim

- Estado en Windows: Compatible
- Ubicacion en el repo: `nvim/`
- Uso recomendado: Instalación nativa en Windows (winget, Scoop, o el instalador oficial) y adaptar la configuración que asume macOS.
- Enlaces:
  - [Neovim oficial](https://neovim.io/)
  - [Neovim download](https://github.com/neovim/neovim/releases)
  - [winget](https://learn.microsoft.com/es-es/windows/package-manager/winget/)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - `winget install Neovim.Neovim` o `scoop install neovim`
- Ventajas:
  - Neovim es multiplataforma y funciona nativamente en Windows sin WSL.
  - La mayoría de los plugins del repo (lualine, bufferline, snacks, treesitter) tienen soporte Windows.
- Desventajas:
  - Algunos language servers y formatters usan rutas o instaladores de Homebrew/npm en `nvim/dependencies.tsv` (`brew install ...`), lo que requiere adaptar el método de instalación en Windows.
  - Herramientas como `dprint`, `tsgo` o `ty` pueden necesitar rutas o variables de entorno distintas en Windows.
  - El validador `setup/validate-nvim-deps.sh` y el bootstrap `setup/bootstrap-nvim-deps.sh` son bash/macOS.
- Caveats del repo:
  - `nvim/dependencies.tsv` usa `install_hint` con Homebrew, Mason, npm, pnpm, go y curl; en Windows las fuentes Mason/npm/go siguen existiendo, pero las de Homebrew no.
  - `nvim/README.md` documenta rutas macOS como `~/.local/share/cfn-lsp/`; en Windows el equivalente es distinto.
  - El manejo de `vim.pack` y `nvim-pack-lock.json` es multiplataforma (Neovim lo resuelve por sí mismo).

### Tmux

- Estado en Windows: No compatible (nativo)
- Ubicacion en el repo: `Tmux/`
- Uso recomendado: No existe una build nativa oficial de tmux para Windows; usar WSL2 con tmux instalado en la distro Linux.
- Enlaces:
  - [tmux repo](https://github.com/tmux/tmux)
  - [WSL install](https://learn.microsoft.com/es-es/windows/wsl/install)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - Dentro de WSL2: `sudo apt install tmux` (o el gestor de paquetes de la distro).
- Ventajas:
  - En WSL2, tmux funciona completo, incluyendo TPM y plugins.
- Desventajas:
  - No hay instalación nativa de tmux en Windows; requiere un subsistema Linux completo.
  - `Tmux/tmux.conf` usa `pbcopy` en el modo copy para enviar al portapapeles (`copy-pipe-and-cancel "pbcopy"`); `pbcopy` no existe en Windows ni en WSL por defecto, y hay que reconfigurar el portapapeles (`clip.exe` o un script de WSL).
- Caveats del repo:
  - `Tmux/README.md` documenta TPM con `~/.tmux/plugins/tpm`; esa ruta funciona igual dentro de WSL2.
  - La instalación de TPM es manual (keypress `prefix + I`) y sigue siendo manual en WSL2.

### Ghostty

- Estado en Windows: Parcialmente compatible
- Ubicacion en el repo: `ghostty/`
- Uso recomendado: Ghostty tiene binarios para Windows; instalar el binario nativo y adaptar la ruta de configuración.
- Enlaces:
  - [Ghostty](https://ghostty.org)
  - [Ghostty download](https://ghostty.org/download)
  - [Ghostty install docs](https://ghostty.org/docs/install)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - Descargar el instalador o binario desde la página oficial; hay paquetes nativos para Windows.
- Ventajas:
  - Terminal moderno y rápido, soporta configuración similar a la del repo.
  - Puede mostrar imágenes en Neovim (una de las razones por las que el usuario lo usa).
- Desventajas:
  - El repo documenta la config activa de macOS en `$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty` y el script de linkeo `setup/link-ghostty-config.sh` es bash/macOS.
  - En Windows la ruta de configuración es distinta (por ejemplo `%APPDATA%\ghostty\config`); el archivo `config.ghostty` del repo puede necesitar ajustes de rutas de fuente y opciones específicas de macOS.
  - El validador `setup/validate-ghostty-config.sh` asume la CLI `ghostty` en PATH y la app en `/Applications/Ghostty.app`.
- Caveats del repo:
  - `ghostty/config.ghostty` usa `font-family = IosevkaTerm NF`; la fuente Nerd Font se instala igual en Windows (archivo `.ttf`/`.otf`).
  - `ghostty/local.example.ghostty` se copia a `$HOME/.config/ghostty/local.ghostty` en macOS; en Windows esa ruta cambia.

### Zsh

- Estado en Windows: Parcialmente compatible
- Ubicacion en el repo: `zsh/`
- Uso recomendado: WSL2 con zsh instalado; el archivo `zsh/.zshrc` es portable en su mayor parte dentro de WSL2.
- Enlaces:
  - [zsh](https://www.zsh.org/)
  - [WSL install](https://learn.microsoft.com/es-es/windows/wsl/install)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - En WSL2: `sudo apt install zsh`.
  - En Git Bash/MSYS2 también hay paquetes de zsh, pero con comportamiento reducido.
- Ventajas:
  - `zsh/.zshrc` es mayormente portable: usa `$HOME`, fuentes condicionales y `zsh_source_if_readable` para no fallar si falta una herramienta.
  - Todas las integraciones (Oh My Zsh, Powerlevel10k, fzf, zoxide, atuin, etc.) tienen versiones instalables en Linux/WSL2.
- Desventajas:
  - `zsh/.zshrc` detecta Homebrew en `/opt/homebrew` o `/usr/local`; Homebrew no existe en Windows nativo, solo dentro de WSL2 (Linuxbrew) o Git Bash.
  - Ciertas variables como `$HOME/.nix-profile/bin` y el prompt de Powerlevel10k (`~/.p10k.zsh`) dependen de que el entorno se configure igual.
  - El validador `setup/validate-zsh-config.sh` es bash.
- Caveats del repo:
  - `zsh/dependencies.tsv` lista `install_hint` con Homebrew; en WSL2 se usa el gestor de paquetes de la distro.
  - Los overrides locales (`~/.zshrc.local`, `~/.zshenv.local`) son rutas `$HOME`, equivalentes en WSL2.
  - Git Bash/MSYS2 pueden ejecutar scripts simples de zsh pero no la experiencia completa (plugins, autosugerencias, prompts complejos).

### Iris Keyboard (VIA)

- Estado en Windows: Compatible
- Ubicacion en el repo: `keyboard/`
- Uso recomendado: Aplicacion VIA nativa de Windows para importar `keyboard/iris_rev__5.json`.
- Enlaces:
  - [VIA](https://www.usevia.app/)
  - [Keeb.io docs VIA](https://docs.keeb.io/via)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - Descargar la aplicacion VIA para Windows desde usevia.app y abrir el JSON del repo.
- Ventajas:
  - VIA tiene soporte nativo de Windows.
  - El archivo `iris_rev__5.json` es un layout portable y se importa igual en cualquier OS.
- Desventajas:
  - La importacion y el flasheo de hardware siguen siendo manuales (el repo lo documenta como manual-only).
- Caveats del repo:
  - `keyboard/README.md` valida el JSON con Ruby (`ruby -rjson -e ...`); Windows nativo necesita Ruby instalado, pero es solo una validacion de desarrollo, no un requisito de uso.

### Dotfiles Installer (Go)

- Estado en Windows: No compatible (en el contexto actual)
- Ubicacion en el repo: `installer/`
- Uso recomendado: Los binarios publicados son solo darwin (`dotfiles-installer-darwin-arm64`, `dotfiles-installer-darwin-amd64`). En Windows se podria recompilar desde fuente con `GOOS=windows`, pero el instalador delega en scripts bash de `setup/` que son macOS-only.
- Enlaces:
  - [Go](https://go.dev/)
  - [Go cross compile docs](https://go.dev/doc/install/source#environment)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - `cd installer && GOOS=windows GOARCH=amd64 go build ./cmd/dotfiles-installer` para obtener un binario de prueba.
- Ventajas:
  - Go es multiplataforma; el modulo compila para Windows sin cambios de lenguaje.
- Desventajas:
  - El instalador ejecuta comandos de `setup/` (bash) y comandos de Homebrew; en Windows fallarian sin WSL2 o Git Bash.
  - Los release assets se publican solo para darwin (`.github/workflows/release-installer.yml`).
  - El bootstrap `setup/bootstrap-dotfiles-installer.sh` instala Xcode Command Line Tools y Homebrew, que no existen en Windows.
- Caveats del repo:
  - `installer/README.md` documenta binarios darwin-arm64/darwin-amd64 y el runner construye con `GOOS=darwin`.
  - En WSL2 se podria correr `go run ./cmd/dotfiles-installer` desde la distro, pero la utilidad real es para maquinas macOS.

### Setup scripts (bash/macOS)

- Estado en Windows: No compatible
- Ubicacion en el repo: `setup/`
- Uso recomendado: Solo dentro de WSL2 con un entorno que emule rutas macOS; el flujo real es macOS.
- Enlaces:
  - [WSL install](https://learn.microsoft.com/es-es/windows/wsl/install)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - Instalar WSL2 y adaptar cada script; no se recomienda como camino principal.
- Ventajas:
  - Ninguna especifica de Windows; son la referencia de comportamiento para el instalador Go.
- Desventajas:
  - Usan `xcode-select`, Homebrew (`/opt/homebrew`, `/usr/local`), `pbcopy`, rutas de Application Support y deteccion de macOS (`OSTYPE == "darwin"`).
  - `setup/macos.sh` configura GitHub SSH/cuenta, credenciales y apps de macOS.
- Caveats del repo:
  - `setup/bootstrap-dotfiles-installer.sh` comprueba Xcode Command Line Tools y Homebrew; ambos son macOS-only.
  - `setup/link-nvim-config.sh` y `setup/link-ghostty-config.sh` gestionan symlinks a rutas macOS (`~/.config/nvim`, `~/Library/Application Support/...`).

### GitHub Actions

- Estado en Windows: Compatible
- Ubicacion en el repo: `.github/workflows/`
- Uso recomendado: Se ejecuta en la nube de GitHub (runner `macos-latest`), no en la maquina local; no hay restriccion de SO para el usuario.
- Enlaces:
  - [GitHub Actions](https://docs.github.com/es/actions)
- Forma de instalar en Windows (guia manual futura, NO ejecutada por este feature):
  - No aplica: el workflow corre en GitHub, no en la maquina local.
- Ventajas:
  - Independiente del SO local; el usuario no necesita nada en Windows para que el release funcione.
- Desventajas:
  - El workflow publica solo binarios darwin; si se quisieran assets de Windows habria que ampliarlo (por ejemplo `GOOS=windows`).
- Caveats del repo:
  - `release-installer.yml` construye `dotfiles-installer-darwin-*` con `CGO_ENABLED=0`; agregar `GOOS=windows` es un cambio futuro opcional.

### `dist/`

- Estado en Windows: Fuera de alcance
- Ubicacion en el repo: `dist/`
- Uso recomendado: Directorio generado por el proceso de release; no contiene herramientas a instalar.
- Enlaces: —
- Forma de instalar en Windows: —
- Ventajas: —
- Desventajas: —
- Caveats del repo:
  - Esta ignorado en `.gitignore` (`dist/`); su contenido se genera localmente durante un release y no se versiona.

### `README.md` (raiz)

- Estado en Windows: Fuera de alcance
- Ubicacion en el repo: `README.md`
- Uso recomendado: Documentacion; no es una herramienta.
- Enlaces: —
- Forma de instalar en Windows: —
- Ventajas: —
- Desventajas: —
- Caveats del repo:
  - Documenta instalacion con Homebrew (`brew install nvim`, `brew install stylua`, etc.) que no aplica en Windows nativo.

## Fuera de alcance

- `dist/`: contenido generado por el release, ignorado por `.gitignore`.
- `README.md` raiz: documentacion, no una herramienta.
- Archivos locales de override (`.zshrc.local`, `.zshenv.local`, `ghostty/local.example.ghostty`) y estado generado (p. ej. `ghostty/.../auto/`): no se auditan como herramientas.
- Secretos, rutas privadas y estado local: fuera del documento por regla de seguridad del repositorio.
- El directorio `specs/` y los artefactos Spec Kit: no son herramientas de desarrollo y se excluyen.

## Recomendaciones finales

1. **Neovim** es la herramienta mas portatil del repo: se puede usar nativa en Windows con poca adaptacion (fuentes de instalacion de dependencias distintas a Homebrew).
2. **Tmux, Zsh y los setup scripts** requieren WSL2. El camino realista en Windows es: WSL2 + zsh + tmux, y no usar el instalador Go.
3. **Ghostty** tiene binario Windows, pero el modulo del repo esta pensado para macOS (rutas de config y scripts de linkeo); se puede adoptar el archivo de config con adaptaciones.
4. **Keyboard/VIA** funciona igual en Windows; no hay barrera.
5. **No instalar nada** desde este documento: toda la guia es manual y futura. Si se quiere soporte Windows real del instalador, eso requiere un feature futuro (build `GOOS=windows` y adaptacion de scripts), fuera del alcance de esta auditoria.
6. El repositorio es principalmente macOS; Windows solo es viable para Neovim, VIA y herramientas de la nube (GitHub Actions) sin cambios, y para el resto via WSL2.
