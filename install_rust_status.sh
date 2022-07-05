#!/usr/bin/bash

(
set -e
cd /tmp
git clone https://github.com/greshake/i3status-rust
cd i3status-rust
cargo install --path .
./install.sh
)
