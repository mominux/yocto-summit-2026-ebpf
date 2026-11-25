# Source this script before using kas: source env.sh
if [ -n "${ZSH_VERSION:-}" ]; then
    _ld_here="${0:A:h}"
else
    _ld_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
fi
if ! command -v kas >/dev/null 2>&1 && [ -x "$HOME/.venvs/kas/bin/kas" ]; then
    export PATH="$HOME/.venvs/kas/bin:$PATH"
fi
export KAS_WORK_DIR="$_ld_here/yocto-build"
export KAS_FILE="$_ld_here/kas/lockdown.yml"
# A machine-local KAS cache overlay is optional. It is Git-ignored and must
# contain paths only; resource limits live in the tracked base KAS file.
if [ -f "$_ld_here/kas/local-cache.yml" ]; then
    export KAS_FILE="$KAS_FILE:$_ld_here/kas/local-cache.yml"
fi
# Preserve the original layer location for the local kas configuration.
mkdir -p "$KAS_WORK_DIR"
ln -sfn "$_ld_here/meta-lockdown" "$KAS_WORK_DIR/meta-lockdown"
unset _ld_here
