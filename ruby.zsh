#!/usr/bin/env zsh
# Mode: ruby — stateful IRB-like REPL via persistent Ruby process

typeset -g _ZSH_MODE_RUBY_PID=""
typeset -g _ZSH_MODE_RUBY_IN=""
typeset -g _ZSH_MODE_RUBY_OUT=""
typeset -g _ZSH_MODE_RUBY_DIR=""
typeset -g _ZSH_MODE_RUBY_BACKEND="${0:A:h}/ruby_backend.rb"

_zsh_mode_ruby_init() {
  _ZSH_MODE_RUBY_DIR="$(mktemp -d)"
  _ZSH_MODE_RUBY_IN="${_ZSH_MODE_RUBY_DIR}/in.fifo"
  _ZSH_MODE_RUBY_OUT="${_ZSH_MODE_RUBY_DIR}/out.fifo"

  mkfifo "$_ZSH_MODE_RUBY_IN"
  mkfifo "$_ZSH_MODE_RUBY_OUT"

  ruby "$_ZSH_MODE_RUBY_BACKEND" "$_ZSH_MODE_RUBY_IN" "$_ZSH_MODE_RUBY_OUT" &
  _ZSH_MODE_RUBY_PID=$!
}

_zsh_mode_ruby_teardown() {
  if [[ -n "$_ZSH_MODE_RUBY_PID" ]]; then
    echo "__EXIT__" > "$_ZSH_MODE_RUBY_IN" 2>/dev/null
    kill "$_ZSH_MODE_RUBY_PID" 2>/dev/null
    wait "$_ZSH_MODE_RUBY_PID" 2>/dev/null
    _ZSH_MODE_RUBY_PID=""
  fi
  [[ -d "$_ZSH_MODE_RUBY_DIR" ]] && rm -rf "$_ZSH_MODE_RUBY_DIR"
}

_zsh_mode_ruby_exec() {
  local input="${1}"

  if [[ -z "$_ZSH_MODE_RUBY_PID" ]] || ! kill -0 "$_ZSH_MODE_RUBY_PID" 2>/dev/null; then
    echo "Ruby backend died. Restarting..."
    _zsh_mode_ruby_init
  fi

  echo "$input" > "$_ZSH_MODE_RUBY_IN"
  local raw
  raw="$(cat "$_ZSH_MODE_RUBY_OUT")"

  local status value
  status="$(echo "$raw" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["status"]' 2>/dev/null)"
  value="$(echo "$raw"  | ruby -rjson -e 'puts JSON.parse(STDIN.read)["value"]' 2>/dev/null)"

  if [[ "$status" == "ok" ]]; then
    echo "=> $value"
  else
    print -P "%F{red}${value}%f"
  fi
}

zsh-mode-register \
  "ruby" \
  "_zsh_mode_ruby_exec" \
  "%F{red}rb%f %F{240}›%f " \
  "Stateful Ruby REPL (IRB-like)" \
  "_zsh_mode_ruby_init" \
  "_zsh_mode_ruby_teardown"
