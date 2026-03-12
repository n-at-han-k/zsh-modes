#!/usr/bin/env zsh
# Mode: kubectl — prepend 'kubectl' to every command

_zsh_mode_kubectl_exec() {
  local input="${1}"
  eval "kubectl ${input}"
}

zsh-mode-register \
  "kubectl" \
  "_zsh_mode_kubectl_exec" \
  "%F{blue}k8s%f %F{240}›%f " \
  "Prepend kubectl to all commands" \
  "" \
  ""
