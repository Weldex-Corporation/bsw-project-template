#!/usr/bin/env bash
# BSW Project Template - environment setup
# Usage:   source _shared/env-setup.sh
# Exports: PATH for cmake/ninja/ARM GCC, BSW_ENV, ARM_GCC_PATH
# Prints:  one-line banner showing detected environment + tool versions

_bsw_script="${BASH_SOURCE[0]:-$0}"
_bsw_repo="$(cd "$(dirname "$_bsw_script")/.." && pwd)"

_bsw_workspace_shared=/srv/workspaces/_shared/tools
_bsw_repo_shared="$_bsw_repo/_shared/tools"

# --- environment detection -------------------------------------------------
# ELM server is identified by the shared workspace mount. ELM_API_TOKEN is
# additionally checked because the mount alone can exist on developer VMs.
if [ -d /srv/workspaces/_shared ] && [ -n "${ELM_API_TOKEN:-}" ]; then
  export BSW_ENV=elm-server
  _bsw_tools="$_bsw_workspace_shared"
elif [ -d /srv/workspaces/_shared ]; then
  export BSW_ENV=elm-server
  _bsw_tools="$_bsw_workspace_shared"
else
  export BSW_ENV=local
  _bsw_tools="$_bsw_repo_shared"
fi

# --- PATH: cmake / ninja ---------------------------------------------------
if [ -d "$_bsw_tools/bin" ]; then
  case ":$PATH:" in
    *":$_bsw_tools/bin:"*) ;;
    *) export PATH="$_bsw_tools/bin:$PATH" ;;
  esac
fi

# --- PATH: ARM GCC ---------------------------------------------------------
_bsw_arm_ver=13.3.rel1
_bsw_arm_root="$_bsw_tools/compilers/gnu-arm/$_bsw_arm_ver"
if [ -d "$_bsw_arm_root/bin" ]; then
  export ARM_GCC_PATH="$_bsw_arm_root"
  case ":$PATH:" in
    *":$_bsw_arm_root/bin:"*) ;;
    *) export PATH="$_bsw_arm_root/bin:$PATH" ;;
  esac
fi

# --- banner ----------------------------------------------------------------
printf '[bsw env] mode=%s  tools=%s\n' "$BSW_ENV" "$_bsw_tools"
if [ "$BSW_ENV" = "elm-server" ]; then
  printf '[bsw env] ELM server detected (shared toolchain under /srv/workspaces/_shared)\n'
fi
_v() { "$@" 2>/dev/null | head -1; }
printf '[bsw env] cmake : %s\n'             "$(_v cmake --version             || echo NOT_FOUND)"
printf '[bsw env] ninja : %s\n'             "$(_v ninja --version             || echo NOT_FOUND)"
printf '[bsw env] host-gcc: %s\n'           "$(_v gcc --version               || echo NOT_FOUND)"
printf '[bsw env] arm-gcc: %s\n'            "$(_v arm-none-eabi-gcc --version || echo NOT_FOUND)"
unset _v _bsw_script _bsw_repo _bsw_workspace_shared _bsw_repo_shared _bsw_tools _bsw_arm_ver _bsw_arm_root
