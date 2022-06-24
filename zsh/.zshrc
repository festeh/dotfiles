source "$XDG_CONFIG_HOME/zsh/aliases"

unsetopt CASE_GLOB
#If a command is issued that can’t be executed as a normal command, and the command is the name of a directory, perform the cd command to that directory
setopt AUTO_CD


autoload -U compinit; compinit
# Autocomplete hidden files
_comp_options+=(globdots)
source ~/dotfiles/zsh/external/completion.zsh
