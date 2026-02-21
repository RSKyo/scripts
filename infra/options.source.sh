#!/usr/bin/env bash
# -------------------------------------------------
# Strict option parser (internal use)
# -------------------------------------------------
#
# __parse_opts <spec> <args...>
#
# spec format:
#   "--opt:var"
#   "--opt:var1,var2"
#   "--flag"
#
# rules:
# - each option must be declared in spec
# - unknown options are rejected
# - missing arguments are rejected
# - argument count inferred from variable list
# - "--opt=value" allowed only when exactly one variable is bound
# - "--flag" sets variable to 1
# - "--flag=value" sets variable to value (may be empty)
#
# return:
#   0  success
#   2  parse error
#
# usage example:
#   local a b c flag
#   __parse_opts '--a:a --x:b,c --flag' "$@" || return 1

# shellcheck disable=SC2034

# Prevent multiple sourcing
[[ -n "${__OPTIONS_SOURCED+x}" ]] && return 0
__OPTIONS_SOURCED=1

__parse_opts() {
  local spec="$1"
  shift

  # Build option → variable binding map from spec
  declare -A opt_map=()
  local entry opt vars
  while read -r entry; do
    [[ -n "$entry" ]] || continue
    [[ "$entry" =~ ^--[a-zA-Z_][a-zA-Z0-9_]*(:[a-zA-Z_][a-zA-Z0-9_]*(,[a-zA-Z_][a-zA-Z0-9_]*)*)?$ ]] || return 2

    IFS=':' read -r opt vars <<< "$entry"
    opt_map["$opt"]="$vars"

    # 注意：$spec 不要加双引号。Bash 会按 IFS（空格、换行、tab）分词 转成换行
  done < <(printf '%s\n' $spec) 

  # Parse input arguments according to spec map
  local opt_key opt_value has_eq
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --)
        shift
        break
        ;;
      --*)
        opt="$1"
        shift

        # Detect explicit "=" form to preserve semantic distinction:
        #   --opt      (no value)
        #   --opt=     (explicit empty value)
        #   --opt=val  (explicit value)
        if [[ "$opt" == *=* ]]; then
          has_eq=1
          opt_key="${opt%%=*}"
          opt_value="${opt#*=}"
        else
          has_eq=0
          opt_key="$opt"
          opt_value=''
        fi
        
        [[ -v opt_map["$opt_key"] ]] || return 2
        vars="${opt_map[$opt_key]}"

        # Option binds one or more variables
        if [[ -n "$vars" ]]; then
          local -a var_list
          local expected var

          IFS=',' read -r -a var_list <<< "$vars"
          expected=${#var_list[@]}

          # Flag option (no bound variables)
          if (( has_eq )); then
            (( expected == 1 )) || return 2
            var="${var_list[0]}"
            declare -p "$var" >/dev/null 2>&1 || return 2
            local -n ref="$var"
            ref="$opt_value"
          else
            (( $# >= expected )) || return 2
            for var in "${var_list[@]}"; do
              declare -p "$var" >/dev/null 2>&1 || return 2
              local -n ref="$var"
              ref="$1"
              shift
            done
          fi
        else
          local var="${opt_key#--}"
          declare -p "$var" >/dev/null 2>&1 || return 2
          local -n ref="$var"
          if (( has_eq )); then
            ref="$opt_value"
          else
            ref=1
          fi
          
        fi
        ;;
      *)
        return 2
        ;;
    esac
  done

  return 0
}
