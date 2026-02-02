#!/usr/bin/env bash
# Source-only library: runtime context
# - purpose: define project directory layout and shared paths

# Prevent multiple sourcing
[[ -n "${__CdVxBZUh+x}" ]] && return 0
__CdVxBZUh=1

# Resolve project root (based on this file location)
__context_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$(cd "$__context_dir/.." >/dev/null && pwd)"

# Public directories
INFRA_DIR="$ROOT_DIR/infra"
LIB_DIR="$ROOT_DIR/lib"
ACTION_DIR="$ROOT_DIR/action"
BIN_DIR="$ROOT_DIR/bin"

export ROOT_DIR INFRA_DIR LIB_DIR ACTION_DIR BIN_DIR


# shellcheck source=/dev/null
source "$INFRA_DIR/log.source.sh"