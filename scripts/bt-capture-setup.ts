#!/usr/bin/env -S npx tsx

import { execSync, spawn } from "child_process";
import { readSync, openSync, closeSync } from "fs";

const SINK_NAME = "combined_bt";
const SINK_DESC = "Combined_BT_Capture";

function log(msg: string): void {
  console.log(`[bt-capture] ${msg}`);
}

function logError(msg: string): void {
  console.error(`[bt-capture] ERROR: ${msg}`);
}

function run(cmd: string): string {
  log(`exec: ${cmd}`);
  const result = execSync(cmd, { encoding: "utf-8" }).trim();
  if (result) log(`output: ${result}`);
  return result;
}

function tryRun(cmd: string): string | null {
  try {
    return run(cmd);
  } catch (e) {
    logError(`command failed: ${cmd} — ${e instanceof Error ? e.message : e}`);
    return null;
  }
}

function promptChoice(addrs: string[]): string {
  console.log("\nMultiple BT devices found:");
  for (let i = 0; i < addrs.length; i++) {
    console.log(`  ${i + 1}) ${addrs[i]}`);
  }
  process.stdout.write("\nSelect device [1-9]: ");

  const buf = Buffer.alloc(1);
  const fd = openSync("/dev/tty", "r");
  readSync(fd, buf, 0, 1, null);
  closeSync(fd);

  const ch = buf.toString("utf-8").trim();
  const idx = parseInt(ch, 10) - 1;
  if (isNaN(idx) || idx < 0 || idx >= addrs.length) {
    logError(`Invalid selection: "${ch}"`);
    process.exit(1);
  }

  log(`Selected device ${idx + 1}: ${addrs[idx]}`);
  return addrs[idx];
}

function findBluezDevice(): { input: string; output: string } | null {
  log("Searching for Bluetooth audio devices...");
  const lines = run("pw-cli list-objects");
  const btAddresses = new Set<string>();

  for (const match of lines.matchAll(/node\.name = "bluez_input\.([\w:]+)"/g)) {
    btAddresses.add(match[1]);
  }

  log(`Found ${btAddresses.size} BT address(es): ${[...btAddresses].join(", ") || "none"}`);

  if (btAddresses.size === 0) {
    return null;
  }

  const addrs = [...btAddresses];
  const addr = addrs.length === 1 ? addrs[0] : promptChoice(addrs);

  return {
    input: `bluez_input.${addr}`,
    output: `bluez_output.${addr}`,
  };
}

function sinkExists(): boolean {
  log("Checking if sink already exists...");
  const out = tryRun("pactl list sinks short");
  const exists = out?.includes(SINK_NAME) ?? false;
  log(`Sink "${SINK_NAME}" exists: ${exists}`);
  return exists;
}

function createSink(): void {
  if (sinkExists()) {
    log(`Sink "${SINK_NAME}" already exists, reusing.`);
    return;
  }
  log(`Creating null sink "${SINK_NAME}"...`);
  run(
    `pactl load-module module-null-sink sink_name=${SINK_NAME} sink_properties=device.description=${SINK_DESC}`
  );
  log(`Created null sink "${SINK_NAME}".`);
}

function link(src: string, dst: string): void {
  log(`Linking: ${src} -> ${dst}`);
  const result = tryRun(`pw-link "${src}" "${dst}"`);
  if (result === null) {
    log(`Link may already exist (pw-link returned non-zero), continuing.`);
  }
}

function getOutputPorts(nodeName: string): string[] {
  log(`Getting output ports for "${nodeName}"...`);
  const lines = run("pw-link -o");
  const ports = lines.split("\n").filter((l) => l.startsWith(`${nodeName}:`));
  log(`Found ${ports.length} port(s) for "${nodeName}": ${ports.join(", ") || "none"}`);
  return ports;
}

function setupLinks(device: { input: string; output: string }): void {
  log("Setting up PipeWire links...");
  const inputPorts = getOutputPorts(device.input);
  const allOutputPorts = getOutputPorts(device.output);
  const monitorPorts = allOutputPorts.filter((p) => p.includes("monitor_"));

  log(`Input ports (mic): ${inputPorts.length}`);
  log(`Output ports (headphone): ${allOutputPorts.length} total, ${monitorPorts.length} monitor`);

  if (inputPorts.length === 0) {
    logError("No input (mic) ports found — mic capture won't work.");
  }
  if (monitorPorts.length === 0) {
    logError("No monitor ports found — headphone capture won't work.");
  }

  // Link mic -> combined sink (mono mic goes to both channels)
  for (const port of inputPorts) {
    link(port, `${SINK_NAME}:playback_FL`);
    link(port, `${SINK_NAME}:playback_FR`);
    log(`Linked mic ${port} -> ${SINK_NAME}:playback_FL/FR`);
  }

  // Link headphone monitor -> combined sink
  for (const port of monitorPorts) {
    const ch = port.includes("_FL") ? "playback_FL" : "playback_FR";
    link(port, `${SINK_NAME}:${ch}`);
    log(`Linked monitor ${port} -> ${SINK_NAME}:${ch}`);
  }

  log("Link setup complete.");
}

function startRecording(outFile: string): void {
  log(`Starting recording to ${outFile}...`);
  log(`Target: ${SINK_NAME}.monitor`);
  console.log("Press Ctrl+C to stop.\n");

  const proc = spawn(
    "pw-record",
    ["--target", `${SINK_NAME}.monitor`, outFile],
    { stdio: "inherit" }
  );

  proc.on("error", (err) => {
    logError(`Failed to start pw-record: ${err.message}`);
  });

  process.on("SIGINT", () => {
    log("Received SIGINT, stopping recording...");
    proc.kill("SIGINT");
  });

  proc.on("exit", (code, signal) => {
    log(`pw-record exited with code=${code}, signal=${signal}`);
    console.log(`\nRecording saved to ${outFile}`);
    process.exit(code ?? 0);
  });
}

// --- CLI ---

type Command =
  | { kind: "help" }
  | { kind: "teardown" }
  | { kind: "status" }
  | { kind: "setup"; record?: string };

const USAGE = `Usage: bt-capture-setup.ts [command] [options]

Sets up a PipeWire virtual sink that captures both a Bluetooth
microphone and headphone output (what you hear) into a single device.

Commands:
  setup             Set up the virtual sink (default)
  teardown          Remove the virtual sink
  status            Show current state of sink, BT device, and links

Options:
  --record <file>   Start recording to a WAV file after setup
  -h, --help        Show this help`;

function parseArgs(argv: string[]): Command {
  if (argv.includes("-h") || argv.includes("--help")) {
    return { kind: "help" };
  }

  if (argv.includes("teardown") || argv.includes("--teardown")) {
    return { kind: "teardown" };
  }

  if (argv.includes("status") || argv.includes("--status")) {
    return { kind: "status" };
  }

  const cmd: Command = { kind: "setup" };
  const recordIdx = argv.indexOf("--record");
  if (recordIdx !== -1) {
    const outFile = argv[recordIdx + 1];
    if (!outFile || outFile.startsWith("-")) {
      logError("--record requires an output file path");
      process.exit(1);
    }
    cmd.record = outFile;
  }

  return cmd;
}

function getLinks(): { src: string; dst: string }[] {
  const out = tryRun("pw-link -l") ?? "";
  const links: { src: string; dst: string }[] = [];
  let currentSrc = "";
  for (const line of out.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    if (line.startsWith(" ") || line.startsWith("\t")) {
      if (trimmed.startsWith("|->")) {
        links.push({ src: currentSrc, dst: trimmed.replace("|-> ", "") });
      }
    } else {
      currentSrc = trimmed;
    }
  }
  return links;
}

function status(): void {
  log("Checking status...");

  // Sink
  const hasSink = sinkExists();
  console.log(`\nSink "${SINK_NAME}": ${hasSink ? "ACTIVE" : "NOT FOUND"}`);

  // BT device
  const device = findBluezDevice();
  if (device) {
    console.log(`BT device input:  ${device.input}`);
    console.log(`BT device output: ${device.output}`);
  } else {
    console.log("BT device: NOT FOUND");
  }

  // Links involving our sink
  const allLinks = getLinks();
  const sinkLinks = allLinks.filter(
    (l) => l.src.includes(SINK_NAME) || l.dst.includes(SINK_NAME)
  );

  if (sinkLinks.length > 0) {
    console.log(`\nActive links (${sinkLinks.length}):`);
    for (const l of sinkLinks) {
      console.log(`  ${l.src} -> ${l.dst}`);
    }
  } else {
    console.log("\nNo active links to sink.");
  }
}

function teardown(): void {
  log("Teardown requested...");
  const out = tryRun("pactl list modules short");
  const line = out?.split("\n").find((l) => l.includes(SINK_NAME));
  if (line) {
    const moduleId = line.split("\t")[0];
    log(`Found module ${moduleId}, unloading...`);
    run(`pactl unload-module ${moduleId}`);
    log(`Removed sink "${SINK_NAME}".`);
  } else {
    log(`Sink "${SINK_NAME}" not found, nothing to remove.`);
  }
}

function setup(record?: string): void {
  log("Starting BT capture setup...");

  const device = findBluezDevice();
  if (!device) {
    logError("No Bluetooth audio device found. Is it connected?");
    process.exit(1);
  }

  log(`Found BT device — input: ${device.input}, output: ${device.output}`);

  createSink();

  log("Waiting 500ms for PipeWire to register ports...");
  execSync("sleep 0.5");

  setupLinks(device);

  log("Setup complete.");
  console.log(`\nDone. Select "${SINK_DESC}" monitor as recording source in Audacity.`);
  console.log(`Or record from CLI: parecord -d ${SINK_NAME}.monitor --file-format=wav output.wav`);

  if (record) {
    startRecording(record);
  }
}

function main(): void {
  const cmd = parseArgs(process.argv.slice(2));
  log(`Command: ${cmd.kind}`);

  switch (cmd.kind) {
    case "help":
      console.log(USAGE);
      break;
    case "teardown":
      teardown();
      break;
    case "status":
      status();
      break;
    case "setup":
      setup(cmd.record);
      break;
  }
}

main();
