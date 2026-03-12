#!/usr/bin/env zsh
# zsh-modes - switchable REPL modes for zsh
# Usage: mode <name> | mode off | mode list

typeset -g ZSH_MODES_DIR="${0:A:h}/modes"
typeset -g ZSH_MODES_CURRENT=""
typeset -g ZSH_MODES_ORIGINAL_PROMPT=""

# Registry of loaded mode handlers
typeset -gA ZSH_MODES_HANDLERS
typeset -gA ZSH_MODES_PROMPTS
typeset -gA ZSH_MODES_DESCRIPTIONS
typeset -gA ZSH_MODES_INIT_HOOKS
typeset -gA ZSH_MODES_TEARDOWN_HOOKS

# --------------------------------------------------------------------------
# Mode registration API (called by individual mode files)
# --------------------------------------------------------------------------

zsh-mode-register() {
  local name="$1" handler="$2" prompt="$3" description="$4"
  local init_hook="${5:-}" teardown_hook="${6:-}"

  ZSH_MODES_HANDLERS[$name]="$handler"
  ZSH_MODES_PROMPTS[$name]="$prompt"
  ZSH_MODES_DESCRIPTIONS[$name]="$description"
  [[ -n "$init_hook" ]]     && ZSH_MODES_INIT_HOOKS[$name]="$init_hook"
  [[ -n "$teardown_hook" ]] && ZSH_MODES_TEARDOWN_HOOKS[$name]="$teardown_hook"
}

# --------------------------------------------------------------------------
# accept-line override — the core dispatch
# --------------------------------------------------------------------------

zsh-modes--accept-line() {
  if [[ -n "$ZSH_MODES_CURRENT" ]]; then
    local input="$BUFFER"

    # Escape hatch: leading backslash bypasses mode, runs raw shell
    if [[ "$input" == \\* ]]; then
      BUFFER="${input#\\}"
      zle .accept-line
      return
    fi

    # "mode off" always works inside a mode
    if [[ "$input" == "mode off" || "$input" == "mode list" || "$input" == mode\ * ]]; then
      zle .accept-line
      return
    fi

    local handler="${ZSH_MODES_HANDLERS[$ZSH_MODES_CURRENT]}"
    if [[ -n "$handler" ]]; then
      BUFFER="$handler ${(qq)input}"
    fi
  fi

  zle .accept-line
}

zle -N accept-line zsh-modes--accept-line

# --------------------------------------------------------------------------
# mode command
# --------------------------------------------------------------------------

mode() {
  case "${1:-}" in
    off)
      if [[ -n "$ZSH_MODES_CURRENT" ]]; then
        local teardown="${ZSH_MODES_TEARDOWN_HOOKS[$ZSH_MODES_CURRENT]}"
        [[ -n "$teardown" ]] && eval "$teardown"
        echo "Exited ${ZSH_MODES_CURRENT} mode."
        ZSH_MODES_CURRENT=""
        PROMPT="$ZSH_MODES_ORIGINAL_PROMPT"
      else
        echo "No active mode."
      fi
      ;;

    list)
      echo "Available modes:"
      for name in ${(k)ZSH_MODES_HANDLERS}; do
        local marker=" "
        [[ "$name" == "$ZSH_MODES_CURRENT" ]] && marker="*"
        printf "  %s %-12s %s\n" "$marker" "$name" "${ZSH_MODES_DESCRIPTIONS[$name]}"
      done
      ;;

    "")
      if [[ -n "$ZSH_MODES_CURRENT" ]]; then
        echo "Current mode: $ZSH_MODES_CURRENT"
      else
        echo "No active mode. Use 'mode list' to see available modes."
      fi
      ;;

    *)
      local name="$1"
      if [[ -z "${ZSH_MODES_HANDLERS[$name]}" ]]; then
        echo "Unknown mode: $name"
        echo "Use 'mode list' to see available modes."
        return 1
      fi

      # Teardown current mode first
      if [[ -n "$ZSH_MODES_CURRENT" ]]; then
        local teardown="${ZSH_MODES_TEARDOWN_HOOKS[$ZSH_MODES_CURRENT]}"
        [[ -n "$teardown" ]] && eval "$teardown"
      fi

      # Save original prompt once
      [[ -z "$ZSH_MODES_ORIGINAL_PROMPT" ]] && ZSH_MODES_ORIGINAL_PROMPT="$PROMPT"

      ZSH_MODES_CURRENT="$name"
      PROMPT="${ZSH_MODES_PROMPTS[$name]}"

      local init="${ZSH_MODES_INIT_HOOKS[$name]}"
      [[ -n "$init" ]] && eval "$init"

      echo "Entered ${name} mode. Type 'mode off' to exit, prefix with \\ for raw shell."
      ;;
  esac
}

# --------------------------------------------------------------------------
# Load all mode definitions
# --------------------------------------------------------------------------

for mode_file in "$ZSH_MODES_DIR"/*.zsh(N); do
  source "$mode_file"
done

# --------------------------------------------------------------------------
# Build ordered mode list for tab cycling (sorted, "off" anchors the cycle)
# --------------------------------------------------------------------------

typeset -ga ZSH_MODES_ORDER=("off" ${(o)${(k)ZSH_MODES_HANDLERS}})

# --------------------------------------------------------------------------
# Tab cycling — empty buffer cycles modes, text in buffer does completion
# --------------------------------------------------------------------------

zsh-modes--tab-cycle() {
  # Text in the buffer → normal tab completion
  if [[ -n "$BUFFER" ]]; then
    zle expand-or-complete
    return
  fi

  # Find current position in the cycle
  local current="${ZSH_MODES_CURRENT:-off}"
  local idx=1
  for i in {1..${#ZSH_MODES_ORDER}}; do
    [[ "${ZSH_MODES_ORDER[$i]}" == "$current" ]] && idx=$i
  done

  # Advance to next (wrap around)
  local next_idx=$(( (idx % ${#ZSH_MODES_ORDER}) + 1 ))
  local next="${ZSH_MODES_ORDER[$next_idx]}"

  # Teardown current mode
  if [[ -n "$ZSH_MODES_CURRENT" ]]; then
    local teardown="${ZSH_MODES_TEARDOWN_HOOKS[$ZSH_MODES_CURRENT]}"
    [[ -n "$teardown" ]] && eval "$teardown"
  fi

  if [[ "$next" == "off" ]]; then
    ZSH_MODES_CURRENT=""
    [[ -n "$ZSH_MODES_ORIGINAL_PROMPT" ]] && PROMPT="$ZSH_MODES_ORIGINAL_PROMPT"
    zle -M "mode: off (shell)"
  else
    [[ -z "$ZSH_MODES_ORIGINAL_PROMPT" ]] && ZSH_MODES_ORIGINAL_PROMPT="$PROMPT"
    ZSH_MODES_CURRENT="$next"
    PROMPT="${ZSH_MODES_PROMPTS[$next]}"

    local init="${ZSH_MODES_INIT_HOOKS[$next]}"
    [[ -n "$init" ]] && eval "$init"

    zle -M "mode: ${next} — ${ZSH_MODES_DESCRIPTIONS[$next]}"
  fi

  zle reset-prompt
}

zle -N zsh-modes--tab-cycle
bindkey '^I' zsh-modes--tab-cycle
