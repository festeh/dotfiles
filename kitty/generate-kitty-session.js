#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { spawn } = require('child_process');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

function expandPath(filePath) {
  if (filePath.startsWith('~/')) {
    return path.join(os.homedir(), filePath.slice(2));
  }
  // Resolve relative paths (like . or ..) to absolute
  return path.resolve(filePath);
}

function validateDirectory(dirPath) {
  const expanded = expandPath(dirPath);
  try {
    const stats = fs.statSync(expanded);
    if (!stats.isDirectory()) {
      return { valid: false, error: `Path exists but is not a directory: ${dirPath}` };
    }
    return { valid: true, expanded };
  } catch (error) {
    if (error.code === 'ENOENT') {
      return { valid: false, error: `Directory does not exist: ${dirPath}` };
    }
    return { valid: false, error: `Cannot access directory: ${error.message}` };
  }
}

function generateSession(projectPath) {
  // Extract directory name for session name
  const dirName = path.basename(projectPath);

  // Generate the session content based on the silence template
  const sessionContent = `
new_tab
layout fat
enabled_layouts fat,grid,horizontal,splits,stack,tall,vertical
set_layout_state {"main_bias": [0.5, 0.5], "biased_map": {}, "opts": {"full_size": 1, "bias": 50, "mirrored": "n"}, "class": "Fat", "all_windows": {"active_group_idx": 0, "active_group_history": [1], "window_groups": [{"id": 1, "window_ids": [1]}]}}
cd ${projectPath}

launch 'kitty-unserialize-data={"id": 1, "cmd_at_shell_startup": "nvim"}'
focus

new_tab
layout fat
enabled_layouts fat,grid,horizontal,splits,stack,tall,vertical
set_layout_state {"main_bias": [0.5, 0.5], "biased_map": {}, "opts": {"full_size": 1, "bias": 50, "mirrored": "n"}, "class": "Fat", "all_windows": {"active_group_idx": 0, "active_group_history": [2], "window_groups": [{"id": 2, "window_ids": [2]}]}}
cd ${projectPath}

launch 'kitty-unserialize-data={"id": 2, "cmd_at_shell_startup": "claude"}'
focus

new_tab
layout fat
enabled_layouts fat,grid,horizontal,splits,stack,tall,vertical
set_layout_state {"main_bias": [0.5, 0.5], "biased_map": {}, "opts": {"full_size": 1, "bias": 50, "mirrored": "n"}, "class": "Fat", "all_windows": {"active_group_idx": 0, "active_group_history": [3], "window_groups": [{"id": 3, "window_ids": [3]}]}}
cd ${projectPath}

launch 'kitty-unserialize-data={"id": 3}'
focus

focus_tab 2
`;

  return { dirName, sessionContent: sessionContent.trim() + '\n' };
}

async function main() {
  // Parse command-line arguments
  const args = process.argv.slice(2);
  const spawnFlag = args.includes('--spawn');
  const localFlag = args.includes('--local');
  const pathArgs = args.filter(arg => !arg.startsWith('--'));
  let projectPath;

  if (pathArgs.length > 0) {
    projectPath = pathArgs[0];
  } else {
    console.log('Kitty Session Generator\n');
    projectPath = await question('Enter project path (e.g., ~/projects/myproject): ');
  }

  if (!projectPath.trim()) {
    console.error('Error: Project path cannot be empty');
    rl.close();
    process.exit(1);
  }

  // Validate that the directory exists
  const validation = validateDirectory(projectPath.trim());
  if (!validation.valid) {
    console.error(`\nError: ${validation.error}`);
    rl.close();
    process.exit(1);
  }

  // Use the expanded (absolute) path for session generation
  const { dirName, sessionContent } = generateSession(validation.expanded);

  const configKittyDir = path.join(os.homedir(), '.config', 'kitty');
  const sessionPath = path.join(configKittyDir, dirName);

  try {
    if (localFlag) {
      // Write directly to ~/.config/kitty/
      fs.writeFileSync(sessionPath, sessionContent);
      console.log(`\n✓ Session file created: ${sessionPath}`);
    } else {
      // Save to dotfiles/kitty/sessions/ and create symlink
      const sessionsDir = path.join(__dirname, 'sessions');
      if (!fs.existsSync(sessionsDir)) {
        fs.mkdirSync(sessionsDir, { recursive: true });
      }
      const outputPath = path.join(sessionsDir, dirName);
      fs.writeFileSync(outputPath, sessionContent);

      // Remove existing symlink if it exists
      if (fs.existsSync(sessionPath)) {
        fs.unlinkSync(sessionPath);
      }
      fs.symlinkSync(outputPath, sessionPath);

      console.log(`\n✓ Session file created in dotfiles: ${outputPath}`);
      console.log(`✓ Symlink created: ${sessionPath} -> ${outputPath}`);
    }

    console.log(`  Session name: ${dirName}`);
    console.log(`  Project path: ${validation.expanded}`);

    if (spawnFlag) {
      console.log(`\nSpawning kitty with session...`);
      const kitty = spawn('kitty', ['--session', sessionPath], {
        detached: true,
        stdio: 'ignore'
      });
      kitty.unref();
    } else {
      console.log(`\nYou can now load this session with:`);
      console.log(`  kitty --session ~/.config/kitty/${dirName}`);
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }

  rl.close();
}

main();
