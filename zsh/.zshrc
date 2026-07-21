# Repository-managed portable zsh configuration.
# Keep machine-specific paths, work aliases, and secrets in ~/.zshrc.local or ~/.zshenv.local.

if [[ -n "${__DOTFILES_ZSHRC_LOADED:-}" ]]; then
  return 0
fi
__DOTFILES_ZSHRC_LOADED=1

zsh_path_prepend() {
  local entry="$1"
  [[ -n "$entry" && -d "$entry" ]] || return 0
  case ":$PATH:" in
    *":$entry:"*) ;;
    *) export PATH="$entry:$PATH" ;;
  esac
}

zsh_source_if_readable() {
  local file="$1"
  [[ -r "$file" ]] && source "$file"
}

# Powerlevel10k instant prompt must stay near the top when available.
zsh_source_if_readable "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"
export LS_COLORS="${LS_COLORS:-di=38;5;67:ow=48;5;60:ex=38;5;132:ln=38;5;144:*.tar=38;5;180:*.zip=38;5;180:*.jpg=38;5;175:*.png=38;5;175:*.mp3=38;5;175:*.wav=38;5;175:*.txt=38;5;223:*.sh=38;5;132}"

zsh_path_prepend "$HOME/.local/bin"
zsh_path_prepend "$HOME/.opencode/bin"
zsh_path_prepend "$HOME/.cargo/bin"
zsh_path_prepend "$HOME/.volta/bin"
zsh_path_prepend "$HOME/.bun/bin"
zsh_path_prepend "$HOME/.nix-profile/bin"
zsh_path_prepend "/nix/var/nix/profiles/default/bin"
zsh_path_prepend "$HOME/.config"

if [[ -r "$HOME/.zshenv.local" ]]; then
  source "$HOME/.zshenv.local"
fi

if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v gls >/dev/null 2>&1; then
  alias ls='gls --color=auto'
elif [[ "$(uname -s)" == "Darwin" ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi

alias fzfbat='fzf --preview="bat --theme=gruvbox-dark --color=always {}"'
alias fzfnvim='nvim $(fzf --preview="bat --theme=gruvbox-dark --color=always {}")'
alias lla='ls -al'

export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --hidden --strip-cwd-prefix --exclude .git}"
export FZF_DEFAULT_T_COMMAND="${FZF_DEFAULT_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
export FZF_ALT_COMMAND="${FZF_ALT_COMMAND:-fd --type=d --hidden --strip-cwd-prefix --exclude .git}"

plugins=(
  command-not-found
  pj
)

if [[ -z "${ZSH_SKIP_OPTIONAL_INTEGRATIONS:-}" ]]; then
  brew_prefix="${HOMEBREW_PREFIX:-}"
  [[ -z "$brew_prefix" && -x "/opt/homebrew/bin/brew" ]] && brew_prefix="/opt/homebrew"
  [[ -z "$brew_prefix" && -x "/usr/local/bin/brew" ]] && brew_prefix="/usr/local"

  zsh_source_if_readable "$brew_prefix/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
  zsh_source_if_readable "$brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  zsh_source_if_readable "$brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  zsh_source_if_readable "$brew_prefix/share/powerlevel10k/powerlevel10k.zsh-theme"

  zsh_source_if_readable "$ZSH/oh-my-zsh.sh"

  export CARAPACE_BRIDGES="${CARAPACE_BRIDGES:-zsh,fish,bash,inshellisense}"
  zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
  command -v carapace >/dev/null 2>&1 && source <(carapace _carapace)
  command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"
  command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
  command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"

  if [[ -r "$HOME/.nvm/nvm.sh" ]]; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    source "$NVM_DIR/nvm.sh"
    zsh_source_if_readable "$NVM_DIR/bash_completion"
  fi

  if command -v terraform >/dev/null 2>&1; then
    autoload -U +X bashcompinit && bashcompinit
    if command -v brew >/dev/null 2>&1 && [[ -x "$(brew --prefix)/bin/terraform" ]]; then
      complete -o nospace -C "$(brew --prefix)/bin/terraform" terraform
    fi
  fi
fi

zsh_source_if_readable "$HOME/.p10k.zsh"

zsh_start_tmux_if_requested() {
  [[ "${ZSH_AUTO_START_TMUX:-0}" == "1" ]] || return 0
  [[ $- == *i* && -z "${TMUX:-}" && -t 1 ]] || return 0
  command -v tmux >/dev/null 2>&1 && exec tmux
}

zsh_source_if_readable "$HOME/.zshrc.local"
zsh_start_tmux_if_requested
