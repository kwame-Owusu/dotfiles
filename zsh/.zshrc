# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# Set personal aliases
alias reload-zsh='source ~/.zshrc'

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# aliases for eza
alias ls="eza --icons"
alias l='eza -lh --icons'
alias la='eza -a'

alias cat="bat"

# configs for homebrew (path differs by OS)
if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# fzf key bindings and completion
if command -v brew >/dev/null 2>&1 && brew --prefix fzf >/dev/null 2>&1; then
    source "$(brew --prefix fzf)/shell/key-bindings.zsh"
    source "$(brew --prefix fzf)/shell/completion.zsh"
fi

# config for calling lazygit in current directory
alias lg='lazygit -p "$(pwd)"'

# aliases for go development
alias Grm='go run main.go'
alias Gv='go vet ./...'
alias Gt='go test ./...'
alias Gtd='go test .'
alias Gmt='go mod tidy'
alias Gmi='go mod init'
alias Gi='go install'
alias Gg='go get'
alias Gcheck='go fmt ./... && go vet ./... && go test ./...'

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
alias oc='opencode'

if [[ "$(uname)" == "Linux" ]]; then
    export PATH="/home/linuxbrew/.linuxbrew/opt/clang-format/bin:$PATH"
fi

# tmux alias (scripts live in ~/.local/bin, symlinked by GNU Stow)
alias tmux-dev='tmux-dev-session.sh'