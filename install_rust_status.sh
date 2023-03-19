#!/usr/bin/bash

(
set -e
cd /tmp
git clone https://github.com/greshake/i3status-rust
cd i3status-rust
git checkout 227bc31409aef6de90aa37e929da0c6c90134e3c
cargo install --path .
./install.sh
)
