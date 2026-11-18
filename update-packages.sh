#!/usr/bin/env bash
# ==============================================================================
# Script de actualización automática para harvy-arch-packages / harvy-pacman-repo
# Totalmente genérico y seguro para repositorios públicos: no contiene secretos,
# tokens ni rutas absolutas locales.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_REPO_DIR="${PACMAN_REPO_DIR:-$(cd "$SCRIPT_DIR/../harvy-pacman-repo" 2>/dev/null && pwd || true)}"
GH_REPO="${GH_REPO:-HarCar/harvy-pacman-repo}"
GPG_KEY="${GPG_KEY:-86FCFF26FD3A55690A5DB1DE617FF4F6B559D151}"

# Colores para salida de consola
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}${BOLD}==>${NC} ${BOLD}$*${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}==>${NC} ${GREEN}$*${NC}"; }
log_warn() { echo -e "${YELLOW}${BOLD}==> ADVERTENCIA:${NC} ${YELLOW}$*${NC}"; }
log_error() { echo -e "${RED}${BOLD}==> ERROR:${NC} ${RED}$*${NC}" >&2; }

# Validar dependencias requeridas
for cmd in makepkg updpkgsums gpg gh curl jq gzip; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "El comando '$cmd' es requerido pero no está instalado."
        exit 1
    fi
done

if [[ -z "$PACMAN_REPO_DIR" || ! -d "$PACMAN_REPO_DIR" ]]; then
    log_error "No se encontró el directorio de harvy-pacman-repo."
    log_error "Asegurate de que esté en ../harvy-pacman-repo o definí la variable PACMAN_REPO_DIR."
    exit 1
fi

# ------------------------------------------------------------------------------
# Funciones para obtener versiones
# ------------------------------------------------------------------------------

get_current_pkgver() {
    local pkg="$1"
    grep '^pkgver=' "$SCRIPT_DIR/$pkg/PKGBUILD" | head -n1 | cut -d'=' -f2
}

get_current_buildid() {
    local pkg="$1"
    grep '^_buildid=' "$SCRIPT_DIR/$pkg/PKGBUILD" | head -n1 | cut -d'=' -f2 || true
}

fetch_latest_antigravity() {
    # Retorna: version:execution_id
    curl -s --connect-timeout 8 "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases" | \
        jq -r '.[0] | "\(.version):\(.execution_id)"' 2>/dev/null || true
}

fetch_latest_chrome() {
    curl -s --connect-timeout 8 "https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages.gz" | \
        gzip -dc 2>/dev/null | grep -A10 '^Package: google-chrome-stable$' | grep '^Version:' | head -n1 | cut -d' ' -f2 | cut -d'-' -f1 || true
}

fetch_latest_vscode() {
    curl -s --connect-timeout 8 "https://update.code.visualstudio.com/api/update/linux-deb-x64/stable/latest" | \
        jq -r '.name' 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Parámetros y banderas
# ------------------------------------------------------------------------------

CHECK_ONLY=false
AUTO_CONFIRM=false
DRY_RUN=false
TARGET_PACKAGES=()

MANUAL_ANTIGRAVITY=""
MANUAL_CHROME=""
MANUAL_VSCODE=""

usage() {
    cat <<EOF
Uso: $(basename "$0") [OPCIONES] [PAQUETE...]

Opciones:
  -c, --check            Solo comprobar si hay versiones nuevas y salir.
  -y, --yes              Actualizar automáticamente sin pedir confirmación.
  -n, --dry-run          Simular las acciones sin compilar ni publicar.
  --antigravity VER:ID   Especificar versión y buildid para antigravity (ej: 2.33.0:4731201358004224).
  --chrome VER           Especificar versión para google-chrome (ej: 158.0.8127.36).
  --vscode VER           Especificar versión para visual-studio-code-bin (ej: 1.147.0).
  -h, --help             Mostrar esta ayuda.

Paquetes soportados:
  antigravity, google-chrome, visual-studio-code-bin
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--check) CHECK_ONLY=true; shift ;;
        -y|--yes) AUTO_CONFIRM=true; shift ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        --antigravity) MANUAL_ANTIGRAVITY="$2"; shift 2 ;;
        --chrome) MANUAL_CHROME="$2"; shift 2 ;;
        --vscode) MANUAL_VSCODE="$2"; shift 2 ;;
        -h|--help) usage ;;
        antigravity|google-chrome|visual-studio-code-bin)
            TARGET_PACKAGES+=("$1"); shift ;;
        *)
            log_error "Argumento desconocido: $1"
            usage ;;
    esac
done

# Si no se indicaron paquetes específicos, comprobar todos
if [[ ${#TARGET_PACKAGES[@]} -eq 0 ]]; then
    TARGET_PACKAGES=("antigravity" "google-chrome" "visual-studio-code-bin")
fi

# ------------------------------------------------------------------------------
# Comprobación de versiones
# ------------------------------------------------------------------------------

log_info "Comprobando versiones actuales y upstream..."

declare -A CURRENT_VERSIONS
declare -A CURRENT_BUILDIDS
declare -A NEW_VERSIONS
declare -A NEW_BUILDIDS
PACKAGES_TO_UPDATE=()

for pkg in "${TARGET_PACKAGES[@]}"; do
    CURRENT_VERSIONS["$pkg"]="$(get_current_pkgver "$pkg")"
    if [[ "$pkg" == "antigravity" ]]; then
        CURRENT_BUILDIDS["$pkg"]="$(get_current_buildid "$pkg")"
    fi

    case "$pkg" in
        antigravity)
            if [[ -n "$MANUAL_ANTIGRAVITY" ]]; then
                NEW_VERSIONS["$pkg"]="${MANUAL_ANTIGRAVITY%%:*}"
                NEW_BUILDIDS["$pkg"]="${MANUAL_ANTIGRAVITY##*:}"
            else
                info="$(fetch_latest_antigravity)"
                if [[ -n "$info" && "$info" == *:* ]]; then
                    NEW_VERSIONS["$pkg"]="${info%%:*}"
                    NEW_BUILDIDS["$pkg"]="${info##*:}"
                else
                    log_warn "No se pudo consultar la versión remota de antigravity."
                    NEW_VERSIONS["$pkg"]="${CURRENT_VERSIONS["$pkg"]}"
                fi
            fi
            ;;
        google-chrome)
            if [[ -n "$MANUAL_CHROME" ]]; then
                NEW_VERSIONS["$pkg"]="$MANUAL_CHROME"
            else
                ver="$(fetch_latest_chrome)"
                NEW_VERSIONS["$pkg"]="${ver:-${CURRENT_VERSIONS["$pkg"]}}"
            fi
            ;;
        visual-studio-code-bin)
            if [[ -n "$MANUAL_VSCODE" ]]; then
                NEW_VERSIONS["$pkg"]="$MANUAL_VSCODE"
            else
                ver="$(fetch_latest_vscode)"
                NEW_VERSIONS["$pkg"]="${ver:-${CURRENT_VERSIONS["$pkg"]}}"
            fi
            ;;
    esac

    # Comparar si hay cambio de versión
    has_update=false
    if [[ "${NEW_VERSIONS["$pkg"]}" != "${CURRENT_VERSIONS["$pkg"]}" ]]; then
        has_update=true
    elif [[ "$pkg" == "antigravity" && -n "${NEW_BUILDIDS["$pkg"]:-}" && "${NEW_BUILDIDS["$pkg"]}" != "${CURRENT_BUILDIDS["$pkg"]}" ]]; then
        has_update=true
    fi

    if $has_update; then
        PACKAGES_TO_UPDATE+=("$pkg")
        echo -e "  * ${BOLD}$pkg${NC}: ${RED}${CURRENT_VERSIONS["$pkg"]}${NC} -> ${GREEN}${NEW_VERSIONS["$pkg"]}${NC}"
    else
        echo -e "  * ${BOLD}$pkg${NC}: ${CURRENT_VERSIONS["$pkg"]} (al día)"
    fi
done

if [[ ${#PACKAGES_TO_UPDATE[@]} -eq 0 ]]; then
    log_success "Todos los paquetes seleccionados ya están en su última versión."
    exit 0
fi

if $CHECK_ONLY; then
    exit 0
fi

# Confirmación
if ! $AUTO_CONFIRM; then
    echo
    read -rp "¿Deseas proceder a compilar y publicar estos paquetes? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[sSyY]$ ]]; then
        log_info "Operación cancelada por el usuario."
        exit 0
    fi
fi

if $DRY_RUN; then
    log_info "Modo simulación (dry-run) finalizado sin realizar cambios."
    exit 0
fi

# ------------------------------------------------------------------------------
# Compilación y firma de cada paquete
# ------------------------------------------------------------------------------

NEW_PKG_ARCHIVES=()

for pkg in "${PACKAGES_TO_UPDATE[@]}"; do
    pkg_dir="$SCRIPT_DIR/$pkg"
    pkgver="${NEW_VERSIONS["$pkg"]}"
    
    log_info "Actualizando receta PKGBUILD para $pkg ($pkgver)..."
    
    # 1. Modificar PKGBUILD
    sed -i "s/^pkgver=.*/pkgver=$pkgver/" "$pkg_dir/PKGBUILD"
    sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkg_dir/PKGBUILD"
    if [[ "$pkg" == "antigravity" && -n "${NEW_BUILDIDS["$pkg"]:-}" ]]; then
        sed -i "s/^_buildid=.*/_buildid=${NEW_BUILDIDS["$pkg"]}/" "$pkg_dir/PKGBUILD"
    fi

    # 2. Refrescar sumas de verificación
    log_info "Descargando fuentes y refrescando checksums (updpkgsums)..."
    (cd "$pkg_dir" && updpkgsums)

    # 3. Regenerar .SRCINFO
    log_info "Regenerando .SRCINFO..."
    (cd "$pkg_dir" && makepkg --printsrcinfo > .SRCINFO)

    # 4. Compilar paquete
    log_info "Compilando paquete con makepkg..."
    (cd "$pkg_dir" && makepkg -f)

    # Buscar el paquete generado
    pkg_file="$(find "$pkg_dir" -maxdepth 1 -name "${pkg}-${pkgver}-1-x86_64.pkg.tar.zst" -print -quit)"
    if [[ -z "$pkg_file" || ! -f "$pkg_file" ]]; then
        log_error "No se encontró el archivo compilado para $pkg en $pkg_dir"
        exit 1
    fi

    # 5. Firmar paquete con GPG
    log_info "Firmando paquete con GPG..."
    gpg --detach-sign --use-agent --yes --default-key "$GPG_KEY" "$pkg_file"

    sig_file="${pkg_file}.sig"
    if [[ ! -f "$sig_file" ]]; then
        log_error "Fallo al generar la firma GPG: $sig_file"
        exit 1
    fi

    # 6. Copiar a harvy-pacman-repo
    log_info "Copiando $pkg compilado a harvy-pacman-repo..."
    cp -f "$pkg_file" "$sig_file" "$PACMAN_REPO_DIR/"

    NEW_PKG_ARCHIVES+=("$(basename "$pkg_file")")
    log_success "Paquete $pkg ($pkgver) compilado y firmado."
done

# ------------------------------------------------------------------------------
# Regenerar base de datos del repositorio Pacman
# ------------------------------------------------------------------------------

log_info "Actualizando base de datos pacman en harvy-pacman-repo..."
cd "$PACMAN_REPO_DIR"

# repo-add actualiza y firma tanto harvy.db como harvy.files en un solo paso
repo-add --sign --key "$GPG_KEY" harvy.db.tar.gz "${NEW_PKG_ARCHIVES[@]}"

# ------------------------------------------------------------------------------
# Publicar en GitHub Releases
# ------------------------------------------------------------------------------

log_info "Subiendo assets a GitHub Releases (tag: current)..."

UPLOAD_FILES=()
for archive in "${NEW_PKG_ARCHIVES[@]}"; do
    UPLOAD_FILES+=("$archive" "${archive}.sig")
done
UPLOAD_FILES+=("harvy.db" "harvy.db.sig" "harvy.files" "harvy.files.sig")

# Asegurar que no haya entradas huérfanas en estado 'starter' previas
for archive in "${NEW_PKG_ARCHIVES[@]}"; do
    broken_id="$(gh api "$(gh api repos/"$GH_REPO"/releases/tags/current --jq .assets_url)?per_page=100" \
        --jq ".[] | select(.name == \"$archive\" and .state == \"starter\") | .id" 2>/dev/null || true)"
    if [[ -n "$broken_id" ]]; then
        log_warn "Eliminando asset incompleto previo ($archive, id: $broken_id)..."
        gh api -X DELETE "repos/$GH_REPO/releases/assets/$broken_id" || true
    fi
done

gh release upload current "${UPLOAD_FILES[@]}" --clobber -R "$GH_REPO"

log_info "Verificando disponibilidad de assets en GitHub..."
sleep 2

# Esperar a que GitHub finalice la carga de los blobs
for archive in "${NEW_PKG_ARCHIVES[@]}"; do
    for i in {1..20}; do
        state="$(gh api "$(gh api repos/"$GH_REPO"/releases/tags/current --jq .assets_url)?per_page=100" \
            --jq ".[] | select(.name == \"$archive\") | .state" 2>/dev/null || true)"
        if [[ "$state" == "uploaded" ]]; then
            log_success "Asset verificado en GitHub: $archive"
            break
        fi
        log_info "Esperando procesamiento en GitHub para $archive... ($i/20)"
        sleep 3
    done
done

# ------------------------------------------------------------------------------
# Git Commit & Push en harvy-arch-packages
# ------------------------------------------------------------------------------

log_info "Haciendo commit y push en harvy-arch-packages..."
cd "$SCRIPT_DIR"

commit_msg="update $(IFS=', '; echo "${PACKAGES_TO_UPDATE[*]}")"
git add .
git commit -m "$commit_msg"
git push origin main
log_success "Cambios enviados a GitHub en harvy-arch-packages."

# ------------------------------------------------------------------------------
# Limpieza de archivos temporales
# ------------------------------------------------------------------------------

log_info "Limpiando archivos temporales de compilación..."
git clean -dfx
log_success "Repositorio limpio y libre de archivos temporales."

echo
log_success "¡Actualización completada exitosamente!"
echo -e "Para actualizar tu sistema local, ejecutá:\n  ${BOLD}sudo pacman -Syu${NC}"
