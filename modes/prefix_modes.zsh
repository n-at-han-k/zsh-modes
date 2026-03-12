#!/usr/bin/env zsh
# Utility: define-prefix-mode — create simple prefix-prepend modes in one call
#
# Usage in a mode file:
#   define-prefix-mode "docker" "docker" "%F{cyan}docker%f %F{240}›%f " "Prepend docker to all commands"
#   define-prefix-mode "git"    "git"    "%F{yellow}git%f %F{240}›%f "  "Prepend git to all commands"

define-prefix-mode() {
  local name="$1" prefix="$2" prompt="$3" description="$4"

  # dynamically create the handler function
  eval "_zsh_mode_prefix_${name}_exec() { local input=\"\${1}\"; eval \"${prefix} \${input}\"; }"

  zsh-mode-register "$name" "_zsh_mode_prefix_${name}_exec" "$prompt" "$description"
}

# -- Built-in prefix modes (add your own here) --

define-prefix-mode "docker"  "docker"  "%F{cyan}docker%f %F{240}›%f "  "Prepend docker to all commands"
define-prefix-mode "git"     "git"     "%F{yellow}git%f %F{240}›%f "   "Prepend git to all commands"
define-prefix-mode "nix"     "nix"     "%F{105}nix%f %F{240}›%f "      "Prepend nix to all commands"
