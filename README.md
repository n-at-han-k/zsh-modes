# zsh-modes

Switchable REPL modes for zsh. Enter a mode and your shell transforms — every
line you type gets dispatched through that mode's handler.

## Install (Nix flake)

Add to your flake inputs:

```nix
{
  inputs.zsh-modes.url = "github:you/zsh-modes"; # or path, gitea, etc.
}
```

### Home Manager module

```nix
{ inputs, ... }:
{
  imports = [ inputs.zsh-modes.homeManagerModules.zsh-modes ];

  programs.zsh.zsh-modes = {
    enable = true;

    # Optional: restrict which modes are active (controls runtime deps).
    # Defaults to all built-in modes.
    # modes = [ "ruby" "kubectl" "docker" "git" "nix" ];

    # Optional: load additional custom mode files
    # extraModes = [ ./my-modes/helm.zsh ];
  };
}
```

### Manual / non-Nix

```zsh
# zinit
zinit light /path/to/zsh-modes

# manual
source /path/to/zsh-modes/zsh-modes.plugin.zsh

# oh-my-zsh (symlink into custom/plugins/)
ln -s /path/to/zsh-modes ~/.oh-my-zsh/custom/plugins/zsh-modes
```

## Usage

```
mode list          # show available modes
mode ruby          # enter ruby mode
mode kubectl       # enter kubectl mode
mode off           # exit current mode
mode               # show current mode
```

### Inside a mode

Everything you type goes through the mode handler. Two escape hatches:

- `\some command` — prefix with backslash to run a raw shell command
- `mode off` / `mode <other>` — always works, even inside a mode

### Ruby mode

Stateful IRB-like REPL. A persistent Ruby process keeps your bindings alive
between lines:

```
mode ruby
rb › x = 42
=> 42
rb › x * 2
=> 84
rb › [1,2,3].map { |n| n ** 2 }
=> [1, 4, 9]
```

### kubectl mode

Every line gets `kubectl` prepended:

```
mode kubectl
k8s › get pods -A
k8s › describe svc traefik -n kube-system
k8s › logs -f deploy/tradeportal -n production
```

### Prefix modes (docker, git, nix)

Same pattern — the command name is prepended automatically.

## Adding your own mode

### Prefix mode (one-liner)

Add to `modes/prefix_modes.zsh`:

```zsh
define-prefix-mode "helm" "helm" "%F{green}helm%f %F{240}›%f " "Prepend helm to all commands"
```

### Custom mode

Create `modes/mymode.zsh`:

```zsh
_zsh_mode_mymode_exec() {
  local input="${1}"
  # do whatever you want with input
}

zsh-mode-register \
  "mymode" \
  "_zsh_mode_mymode_exec" \
  "%F{magenta}my%f %F{240}›%f " \
  "Description here" \
  "_optional_init_function" \
  "_optional_teardown_function"
```

The registration API:

```
zsh-mode-register <name> <handler_fn> <prompt> <description> [init_fn] [teardown_fn]
```

- **handler_fn** — receives the raw input line as `$1`, runs it however you want
- **init_fn** — called when entering the mode (start background processes, etc.)
- **teardown_fn** — called when leaving the mode (cleanup)
