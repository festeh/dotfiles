package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const sessionTemplate = `new_tab
layout fat
enabled_layouts fat,grid,horizontal,splits,stack,tall,vertical
set_layout_state {"main_bias": [0.5, 0.5], "biased_map": {}, "opts": {"full_size": 1, "bias": 50, "mirrored": "n"}, "class": "Fat", "all_windows": {"active_group_idx": 0, "active_group_history": [1], "window_groups": [{"id": 1, "window_ids": [1]}]}}
cd %s

launch 'kitty-unserialize-data={"id": 1, "cmd_at_shell_startup": "nvim"}'
focus

new_tab
layout fat
enabled_layouts fat,grid,horizontal,splits,stack,tall,vertical
set_layout_state {"main_bias": [0.5, 0.5], "biased_map": {}, "opts": {"full_size": 1, "bias": 50, "mirrored": "n"}, "class": "Fat", "all_windows": {"active_group_idx": 0, "active_group_history": [2], "window_groups": [{"id": 2, "window_ids": [2]}]}}
cd %s

launch 'kitty-unserialize-data={"id": 2, "cmd_at_shell_startup": "claude"}'
focus

new_tab
layout fat
enabled_layouts fat,grid,horizontal,splits,stack,tall,vertical
set_layout_state {"main_bias": [0.5, 0.5], "biased_map": {}, "opts": {"full_size": 1, "bias": 50, "mirrored": "n"}, "class": "Fat", "all_windows": {"active_group_idx": 0, "active_group_history": [3], "window_groups": [{"id": 3, "window_ids": [3]}]}}
cd %s

launch 'kitty-unserialize-data={"id": 3}'
focus

focus_tab 2
`

func expandPath(p string) (string, error) {
	if strings.HasPrefix(p, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(home, p[2:]), nil
	}
	return filepath.Abs(p)
}

func validateDirectory(p string) (string, error) {
	expanded, err := expandPath(p)
	if err != nil {
		return "", fmt.Errorf("cannot expand path: %w", err)
	}

	info, err := os.Stat(expanded)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("directory does not exist: %s", p)
		}
		return "", fmt.Errorf("cannot access directory: %w", err)
	}

	if !info.IsDir() {
		return "", fmt.Errorf("path exists but is not a directory: %s", p)
	}

	return expanded, nil
}

func generateSession(projectPath string) string {
	return fmt.Sprintf(sessionTemplate, projectPath, projectPath, projectPath)
}

func prompt(message string) string {
	fmt.Print(message)
	reader := bufio.NewReader(os.Stdin)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

func main() {
	spawnFlag := flag.Bool("spawn", false, "Spawn kitty with the session after creation")
	localFlag := flag.Bool("local", false, "Write directly to ~/.config/kitty/ instead of dotfiles")
	flag.Parse()

	args := flag.Args()
	var projectPath string

	if len(args) > 0 {
		projectPath = args[0]
	} else {
		fmt.Println("Kitty Session Generator\n")
		projectPath = prompt("Enter project path (e.g., ~/projects/myproject): ")
	}

	if projectPath == "" {
		fmt.Fprintln(os.Stderr, "Error: Project path cannot be empty")
		os.Exit(1)
	}

	expanded, err := validateDirectory(projectPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "\nError: %v\n", err)
		os.Exit(1)
	}

	dirName := filepath.Base(expanded)
	sessionContent := generateSession(expanded)

	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: cannot get home directory: %v\n", err)
		os.Exit(1)
	}

	configKittyDir := filepath.Join(home, ".config", "kitty")
	sessionPath := filepath.Join(configKittyDir, dirName)

	if *localFlag {
		if err := os.WriteFile(sessionPath, []byte(sessionContent), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("\n✓ Session file created: %s\n", sessionPath)
	} else {
		// Get the directory where the executable is located
		execPath, err := os.Executable()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: cannot get executable path: %v\n", err)
			os.Exit(1)
		}
		execDir := filepath.Dir(execPath)

		// Sessions dir is kitty/sessions (parent of executable dir)
		sessionsDir := filepath.Join(filepath.Dir(execDir), "sessions")
		if err := os.MkdirAll(sessionsDir, 0755); err != nil {
			fmt.Fprintf(os.Stderr, "Error: cannot create sessions directory: %v\n", err)
			os.Exit(1)
		}

		outputPath := filepath.Join(sessionsDir, dirName)
		if err := os.WriteFile(outputPath, []byte(sessionContent), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		// Remove existing symlink/file if it exists
		if _, err := os.Lstat(sessionPath); err == nil {
			if err := os.Remove(sessionPath); err != nil {
				fmt.Fprintf(os.Stderr, "Error: cannot remove existing file: %v\n", err)
				os.Exit(1)
			}
		}

		if err := os.Symlink(outputPath, sessionPath); err != nil {
			fmt.Fprintf(os.Stderr, "Error: cannot create symlink: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("\n✓ Session file created in dotfiles: %s\n", outputPath)
		fmt.Printf("✓ Symlink created: %s -> %s\n", sessionPath, outputPath)
	}

	fmt.Printf("  Session name: %s\n", dirName)
	fmt.Printf("  Project path: %s\n", expanded)

	if *spawnFlag {
		fmt.Println("\nSpawning kitty with session...")
		cmd := exec.Command("kitty", "--session", sessionPath)
		cmd.Stdout = nil
		cmd.Stderr = nil
		cmd.Stdin = nil
		if err := cmd.Start(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: cannot spawn kitty: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Printf("\nYou can now load this session with:\n")
		fmt.Printf("  kitty --session ~/.config/kitty/%s\n", dirName)
	}
}
