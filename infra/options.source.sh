#!/usr/bin/env bash
# options.source.sh
# Strict option parser for internal modules.

# shellcheck disable=SC1091

# Prevent multiple sourcing
[[ -n "${__OPTIONS_SOURCED+x}" ]] && return 0
__OPTIONS_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$INFRA_DIR/log.source.sh"

# __parse_opts <spec> <args...>
# spec format:
#   --opt:var1,var2
# - each option must bind at least one variable
# - argument count inferred from variable count
# - unknown options are rejected
# - missing arguments are rejected
#
# example
# local a
# local b
# local c
# 
# __parse_opts '--a:a --x:b,c' "$@" || return 1
# 
__parse_opts() {
  local spec="$1"
  shift

  local scope="${FUNCNAME[0]}"

  declare -A opt_map=()
  local entry opt vars

  # --- Parse spec ---
  while read -r entry; do
    [[ -z "$entry" ]] && continue

    [[ "$entry" == --*:* ]] || {
      loge "$scope" "Invalid spec entry: $entry"
      return 2
    }

    opt="${entry%%:*}"
    vars="${entry#*:}"

    [[ -n "$vars" ]] || {
      loge "$scope" "Option requires variable binding: $opt"
      return 2
    }

    IFS=',' read -r -a var_list <<< "$vars"

    for var in "${var_list[@]}"; do
      [[ -n "$var" ]] || {
        loge "$scope" "Invalid variable in spec: $entry"
        return 2
      }
    done

    [[ -v opt_map["$opt"] ]] && {
      loge "$scope" "Duplicate option in spec: $opt"
      return 2
    }

    opt_map["$opt"]="$vars"
  done < <(printf '%s\n' $spec) # 不要加双引号，Bash 会按 IFS（空格、换行、tab）分词 转成换行

  # --- Parse arguments ---
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --)
        shift
        break
        ;;
      --*)
        opt="$1"
        shift

        [[ -v opt_map["$opt"] ]] || {
          loge "$scope" "Unknown option: $opt"
          return 2
        }

        vars="${opt_map[$opt]}"
        IFS=',' read -r -a var_list <<< "$vars"
        
        local expected
        expected=${#var_list[@]}

        (( $# >= expected )) || {
          loge "$scope" "Missing argument(s) for $opt"
          return 2
        }

        for var in "${var_list[@]}"; do
          declare -p "$var" >/dev/null 2>&1 || {
            loge "$scope" "Undefined variable: $var"
            return 2
          }

          local -n ref="$var"
          # shellcheck disable=SC2034
          ref="$1"
          shift
        done
        ;;
      *)
        loge "$scope" "Unexpected argument: $1"
        return 2
        ;;
    esac
  done

  return 0
}
