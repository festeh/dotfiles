source "$XDG_CONFIG_HOME/zsh/aliases"

unsetopt CASE_GLOB
#If a command is issued that can’t be executed as a normal command, and the command is the name of a directory, perform the cd command to that directory
setopt AUTO_CD


autoload -U compinit; compinit
# Autocomplete hidden files
_comp_options+=(globdots)
source ~/dotfiles/zsh/external/completion.zsh

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/autojump/autojump.zsh
#source ~/dotfiles/antigen.zsh
#antigen bundle zsh-users/zsh-autosuggestions
#antigen bundle autojump
#antigen apply

bindkey -v '^?' backward-delete-char
bindkey -v '^[l' forward-word
bindkey -v "^[[1;3C" forward-word

setopt hist_ignore_dups
unsetopt hist_ignore_space

PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{255}%1~%f%b %# '
