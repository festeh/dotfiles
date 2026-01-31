#!/usr/bin/env -S npx tsx

import { execSync, spawn } from "child_process";

const SINK_NAME = "combined_bt";
const SINK_DESC = "Combined_BT_Capture";

function run(cmd: string): string {
  return execSync(cmd, { encoding: "utf-8" }).trim();
}

function tryRun(cmd: string): string | null {
  try {
    return run(cmd);
  } catch {
    return null;
  }
}

function findBluezDevice(): { input: string; output: string } | null {
  const lines = run("pw-cli list-objects");
  const btAddresses = new Set<string>();

  for (const match of lines.matchAll(/node\.name = "bluez_input\.([\w:]+)"/g)) {
    btAddresses.add(match[1]);
  }

  if (btAddresses.size === 0) {
    return null;
  }

  const addr = [...btAddresses][0];
  return {
    input: `bluez_input.${addr}`,
    output: `bluez_output.${addr}`,
  };
}

function sinkExists(): boolean {
  const out = tryRun("pactl list sinks short");
  return out?.includes(SINK_NAME) ?? false;
}

function createSink(): void {
  if (sinkExists()) {
    console.log(`Sink "${SINK_NAME}" already exists, reusing.`);
    return;
  }
  run(
    `pactl load-module module-null-sink sink_name=${SINK_NAME} sink_properties=device.description=${SINK_DESC}`
  );
  console.log(`Created null sink "${SINK_NAME}".`);
}

function link(src: string, dst: string): void {
  const result = tryRun(`pw-link "${src}" "${dst}"`);
  if (result === null) {
    // pw-link exits non-zero if link already exists, that's fine
  }
}

function getOutputPorts(nodeName: string): string[] {
  const lines = run("pw-link -o");
  return lines.split("\n").filter((l) => l.startsWith(`${nodeName}:`));
}

function setupLinks(device: { input: string; output: string }): void {
  const inputPorts = getOutputPorts(device.input);
  const monitorPorts = getOutputPorts(device.output).filter((p) =>
    p.includes("monitor_")
  );

  // Link mic -> combined sink (mono mic goes to both channels)
  for (const port of inputPorts) {
    link(port, `${SINK_NAME}:playback_FL`);
    link(port, `${SINK_NAME}:playback_FR`);
    console.log(`Linked ${port} -> ${SINK_NAME}:playback_FL/FR`);
  }

  // Link headphone monitor -> combined sink
  for (const port of monitorPorts) {
    const ch = port.includes("_FL") ? "playback_FL" : "playback_FR";
    link(port, `${SINK_NAME}:${ch}`);
    console.log(`Linked ${port} -> ${SINK_NAME}:${ch}`);
  }
}

function startRecording(outFile: string): void {
  console.log(`\nRecording to ${outFile} ...`);
  console.log("Press Ctrl+C to stop.\n");

  const proc = spawn(
    "pw-record",
    ["--target", `${SINK_NAME}.monitor`, outFile],
    { stdio: "inherit" }
  );

  process.on("SIGINT", () => {
    proc.kill("SIGINT");
  });

  proc.on("exit", (code) => {
    console.log(`\nRecording saved to ${outFile}`);
    process.exit(code ?? 0);
  });
}

// --- Main ---

const args = process.argv.slice(2);
const usage = `Usage: bt-capture-setup.ts [--record <output.wav>]

Sets up a PipeWire virtual sink that captures both a Bluetooth
microphone and headphone output (what you hear) into a single device.

Options:
  --record <file>   Start recording to a WAV file after setup
  --teardown        Remove the virtual sink
  -h, --help        Show this help`;

if (args.includes("-h") || args.includes("--help")) {
  console.log(usage);
  process.exit(0);
}

if (args.includes("--teardown")) {
  const out = tryRun("pactl list modules short");
  const line = out?.split("\n").find((l) => l.includes(SINK_NAME));
  if (line) {
    const moduleId = line.split("\t")[0];
    run(`pactl unload-module ${moduleId}`);
    console.log(`Removed sink "${SINK_NAME}".`);
  } else {
    console.log(`Sink "${SINK_NAME}" not found.`);
  }
  process.exit(0);
}

const device = findBluezDevice();
if (!device) {
  console.error("No Bluetooth audio device found. Is it connected?");
  process.exit(1);
}

console.log(`Found BT device: ${device.input}`);

createSink();

// Wait a moment for PipeWire to register ports
execSync("sleep 0.5");

setupLinks(device);

console.log(`\nDone. Select "${SINK_DESC}" monitor as recording source in Audacity.`);
console.log(`Or record from CLI: pw-record --target ${SINK_NAME}.monitor output.wav`);

const recordIdx = args.indexOf("--record");
if (recordIdx !== -1) {
  const outFile = args[recordIdx + 1];
  if (!outFile) {
    console.error("--record requires an output file path");
    process.exit(1);
  }
  startRecording(outFile);
}
