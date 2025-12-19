# My dotfiles

* `hosts/` - contains configs for my machines

## Quick Setup

Bootstrap a new machine with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/festeh/dotfiles/master/bootstrap.sh | bash -s <hostname>
```

Or clone and run locally:

```bash
git clone https://github.com/festeh/dotfiles.git ~/dotfiles
./bootstrap.sh <hostname>
```

The bootstrap script will:
1. Clone dotfiles to `~/dotfiles`
2. Download the [Installer](https://github.com/festeh/Installer) binary to `~/Installer`
3. Install packages defined in `hosts/<hostname>/install.toml`
4. Create symlinks and generate configs for the specified host
