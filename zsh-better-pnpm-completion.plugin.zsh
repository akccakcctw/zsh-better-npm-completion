_zbpc_pnpm_command() {
  echo "${words[2]}"
}

_zbpc_pnpm_command_arg() {
  echo "${words[3]}"
}

_zbpc_no_of_pnpm_args() {
  echo "$#words"
}

_zbpc_list_cached_modules() {
  ls $(pnpm store path) 2>/dev/null
}

_zbpc_recursively_look_for() {
  local filename="$1"
  local dir=$PWD
  while [ ! -e "$dir/$filename" ]; do
    dir=${dir%/*}
    [[ "$dir" = "" ]] && break
  done
  [[ ! "$dir" = "" ]] && echo "$dir/$filename"
}

_zbpc_get_package_json_property_object() {
  local package_json="$1"
  local property="$2"
  cat "$package_json" |
    sed -nE "/^  \"$property\": \{$/,/^  \},?$/p" | # Grab scripts object
    sed '1d;$d' |                                   # Remove first/last lines
    sed -E 's/    "([^"]+)": "(.+)",?/\1=>\2/'      # Parse into key=>value
}

_zbpc_get_package_json_property_object_keys() {
  local package_json="$1"
  local property="$2"
  _zbpc_get_package_json_property_object "$package_json" "$property" | cut -f 1 -d "="
}

_zbpc_parse_package_json_for_script_suggestions() {
  local package_json="$1"
  _zbpc_get_package_json_property_object "$package_json" scripts |
    sed -E 's/(.+)=>(.+)/\1:$ \2/' |  # Parse commands into suggestions
    sed 's/\(:\)[^$]/\\&/g' |         # Escape ":" in commands
    sed 's/\(:\)$[^ ]/\\&/g'          # Escape ":$" without a space in commands
}

_zbpc_parse_package_json_for_deps() {
  local package_json="$1"
  _zbpc_get_package_json_property_object_keys "$package_json" dependencies
  _zbpc_get_package_json_property_object_keys "$package_json" devDependencies
}

_zbpc_pnpm_install_completion() {

  # Only run on `pnpm install ?`
  [[ ! "$(_zbpc_no_of_pnpm_args)" = "3" ]] && return

  # Return if we don't have any cached modules
  [[ "$(_zbpc_list_cached_modules)" = "" ]] && return

  # If we do, recommend them
  _values $(_zbpc_list_cached_modules)

  # Make sure we don't run default completion
  custom_completion=true
}

_zbpc_pnpm_uninstall_completion() {

  # Use default pnpm completion to recommend global modules
  [[ "$(_zbpc_pnpm_command_arg)" = "-g" ]] || [[ "$(_zbpc_pnpm_command_arg)" = "--global" ]] && return

  # Look for a package.json file
  local package_json="$(_zbpc_recursively_look_for package.json)"

  # Return if we can't find package.json
  [[ "$package_json" = "" ]] && return

  _values $(_zbpc_parse_package_json_for_deps "$package_json")

  # Make sure we don't run default completion
  custom_completion=true
}

_zbpc_pnpm_run_completion() {

  # Only run on `pnpm run ?`
  [[ ! "$(_zbpc_no_of_pnpm_args)" = "3" ]] && return

  # Look for a package.json file
  local package_json="$(_zbpc_recursively_look_for package.json)"

  # Return if we can't find package.json
  [[ "$package_json" = "" ]] && return

  # Parse scripts in package.json
  local -a options
  options=(${(f)"$(_zbpc_parse_package_json_for_script_suggestions $package_json)"})

  # Return if we can't parse it
  [[ "$#options" = 0 ]] && return

  # Load the completions
  _describe 'values' options

  # Make sure we don't run default completion
  custom_completion=true
}

_zbpc_default_pnpm_completion() {
  compadd -- $(COMP_CWORD=$((CURRENT-1)) \
              COMP_LINE=$BUFFER \
              COMP_POINT=0 \
              pnpm completion -- "${words[@]}" \
              2>/dev/null)
}

_zbpc_zsh_better_pnpm_completion() {

  # Store custom completion status
  local custom_completion=false

  # Load custom completion commands
  case "$(_zbpc_pnpm_command)" in
    i|install)
      _zbpc_pnpm_install_completion
      ;;
    remove|uninstall)
      _zbpc_pnpm_uninstall_completion
      ;;
    run)
      _zbpc_pnpm_run_completion
      ;;
  esac

  # Fall back to default completion if we haven't done a custom one
  [[ $custom_completion = false ]] && _zbpc_default_pnpm_completion
}

compdef _zbpc_zsh_better_pnpm_completion pnpm
