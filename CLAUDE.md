# Dotfiles Management with Installer

This dotfiles repository uses a custom Go-based configuration manager called **Installer** located at `~/Installer`.

## Overview

The Installer is a tool that manages dotfiles through:
- **Symlinks**: Creates symbolic links from dotfiles to their destination locations
- **Templates**: Renders Go templates with host-specific data and symlinks the generated files

## Basic Usage

From the `~/Installer` directory:

```bash
# Generate configs and create symlinks for current host (auto-detected)
./installer -c config

# Specify a hostname explicitly
./installer -c config -h 360

# Install packages (if implemented)
./installer -c install -h 360
```

## Configuration Structure

Each host has its configuration in `dotfiles/hosts/<hostname>/config.toml`.

### Example config.toml structure:

```toml
# Symlinks: Direct file/directory links
[symlinks.kitty]
target = "kitty"                    # Path relative to dotfiles root
name = "~/.config/kitty"            # Destination path (~ is expanded)

# Templates: Rendered configs with variables
[templates.hyprland]
target = "hyprland/hyprland_template.conf"  # Template source
name = "~/.config/hypr/hyprland.conf"       # Final symlink destination
SCALING = "1"                                # Template variables
USER = "dima"
GTK_THEME = "catppuccin-mocha-mauve-standard+default"
```

## How Templates Work

1. **Template Source**: Template files use Go template syntax (e.g., `{{.SCALING}}`)
   - Located at paths like `dotfiles/hyprland/hyprland_template.conf`
   - Can use Go template functions like `{{or .GAPS_OUT 10}}` for defaults

2. **Rendering Process**:
   - Installer reads the template file
   - Renders it with data from config.toml
   - Writes output to `dotfiles/hosts/<hostname>/generated/<filename>`

3. **Symlinking**:
   - Creates a symlink from the `name` path to the generated file
   - For example: `~/.config/hypr/hyprland.conf` → `dotfiles/hosts/360/generated/hyprland_template.conf`

## Generated Files

Generated config files are stored in:
```
dotfiles/hosts/<hostname>/generated/
```

These files are:
- Auto-generated (don't edit directly!)
- Created from templates
- Symlinked to their final destinations
- Regenerated when you run the installer

## Important Notes

- **Always edit the template source files**, not the generated files
- After editing templates or config.toml, run `./installer -c config` to regenerate
- Generated files are host-specific and should not be committed to git
- The installer checks modification times and only updates when templates are newer

## Example Workflow

1. Edit a template: `vim ~/dotfiles/hyprland/hyprland_template.conf`
2. Regenerate configs: `cd ~/Installer && ./installer -c config`
3. The generated file appears in `~/dotfiles/hosts/360/generated/`
4. The symlink at `~/.config/hypr/hyprland.conf` points to the generated file

## Troubleshooting

### Config errors after updates
If you get config errors (like "option does not exist"), the template likely contains obsolete options:
1. Edit the template source file to remove the obsolete option
2. Run `./installer -c config` to regenerate
3. Restart the application to use the updated config

### Symlink conflicts
If symlinks fail to create, ensure:
- The destination directory exists
- No file already exists at the symlink destination
- You have write permissions to the destination

## AGS (Astal) Management

AGS is managed as a systemd user service. **NEVER run `ags` command directly.**

### Starting/Stopping AGS

```bash
# Restart AGS
systemctl --user restart ags

# Stop AGS
systemctl --user stop ags

# Start AGS
systemctl --user start ags

# Check AGS status
systemctl --user status ags
```

### Viewing AGS Logs

Use `journalctl` to view AGS logs:

```bash
# View recent logs
journalctl --user -u ags -n 50

# Follow logs in real-time
journalctl --user -u ags -f

# View logs since last restart
journalctl --user -u ags -b
```

### Workflow for AGS Changes

1. Make changes to AGS config files in `~/dotfiles/ags/`
2. Restart AGS: `systemctl --user restart ags`
3. Check logs for errors: `journalctl --user -u ags -n 50`
