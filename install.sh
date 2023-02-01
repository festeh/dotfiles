#!/bin/bash

rm -rf "$XDG_CONFIG_HOME/nvim"
ln -sf "$DOTFILES/nvim" "$XDG_CONFIG_HOME/nvim"

rm -rf "$XDG_CONFIG_HOME/X11"
ln -s "$DOTFILES/X11" "$XDG_CONFIG_HOME/X11"

rm -rf "$XDG_CONFIG_HOME/i3"
ln -s "$DOTFILES/i3" $XDG_CONFIG_HOME/i3
mkdir -p $XDG_CONFIG_HOME/i3status-rust/
ln -sf "$DOTFILES/i3/status_config.toml" $XDG_CONFIG_HOME/i3status-rust/config.toml
$DOTFILES/i3/install_i3_bar.sh


mkdir -p $XDG_CONFIG_HOME/zsh
ln -sf "$DOTFILES/zsh/.zshenv" "$HOME"
ln -sf "$DOTFILES/zsh/.zshrc" "$XDG_CONFIG_HOME/zsh"
ln -sf "$DOTFILES/zsh/aliases" "$XDG_CONFIG_HOME/zsh/aliases"

rm -rf "$XDG_CONFIG_HOME/zsh/external"
ln -sf "$DOTFILES/zsh/external" "$XDG_CONFIG_HOME/zsh"


# Install clipboard manager
[ ! -d "$XDG_CONFIG_HOME/zsh/plugins/zsh-system-clipboard" ] \
    && mkdir -p "$XDG_CONFIG_HOME/zsh/plugins" \
    && git clone https://github.com/kutsan/zsh-system-clipboard $XDG_CONFIG_HOME/zsh/plugins/zsh-system-clipboard

mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "$DOTFILES/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"

# tmux plugins
[ ! -d "$XDG_CONFIG_HOME/tmux/plugins" ] \
    && mkdir "$XDG_CONFIG_HOME/tmux/plugins" \
    && git clone https://github.com/tmux-plugins/tpm "$XDG_CONFIG_HOME/tmux/plugins/tpm" 

# starship prompt
if ! [ -x "$(command -v starship)" ]; then
  echo 'Installing Starship'
  curl -sS https://starship.rs/install.sh | sh
  STARSHIP_PATH="$XDG_CONFIG_HOME/starship.toml"
  rm -rf "$STARSHIP_PATH"
  ln -sf "$DOTFILES/starship/starship.toml" "$STARSHIP_PATH"
fi
