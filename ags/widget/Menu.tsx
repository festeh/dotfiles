import { App, Astal, Gdk, Gtk } from "astal/gtk4"
import { Variable, bind } from "astal"
import { Widget } from "astal/gtk4"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import Graphene from "gi://Graphene"
import Hyprland from "gi://AstalHyprland"

const RECORDS_DIR = "/tmp/records"
const SIGTERM = 15

function decodeBytes(bytes: Uint8Array | null): string {
  return bytes === null ? "" : new TextDecoder().decode(bytes)
}

function checkSwayidle(): boolean {
  try {
    const [, stdout] = GLib.spawn_command_line_sync("pgrep swayidle")
    return (stdout?.length ?? 0) > 0
  } catch (error) {
    return false
  }
}

function getRecordingDuration(): number {
  if (!isRecording.get()) return 0
  const startTime = recordingStartTime.get()
  if (startTime === 0) return 0
  return Math.floor((Date.now() - startTime) / 1000)
}

function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
}

function getCurrentKeyboardLayout(): string {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("hyprctl devices -j")
    if (success) {
      const devices = JSON.parse(decodeBytes(stdout))
      // Filter out virtual keyboards (like wtype) and find the main physical keyboard
      const realKeyboard = devices.keyboards.find((kb: any) =>
        kb.main && !kb.name.includes("virtual")
      ) || devices.keyboards.find((kb: any) =>
        kb.name === "at-translated-set-2-keyboard"
      )
      if (realKeyboard) {
        return realKeyboard.active_keymap || "Unknown"
      }
    }
  } catch (error) {
    console.error("Failed to get keyboard layout:", error)
  }
  return "Unknown"
}

let swayidleProcess: Gio.Subprocess | null = null
let recordingProcess: Gio.Subprocess | null = null
let expectedRecordingExit: Gio.Subprocess | null = null
let pendingTranscriptionPath: string | null = null
let recordingDurationTimer = 0

const isIdleRunning = Variable<boolean>(checkSwayidle())
const keyboardLayout = Variable<string>(getCurrentKeyboardLayout())
const isRecording = Variable<boolean>(false)
const isProcessing = Variable<boolean>(false)
const recordingStartTime = Variable<number>(0)
const recordingDuration = Variable<string>("00:00")
const lastRecordedFile = Variable<string>("")
const menuVisible = Variable<boolean>(false)

function startRecordingDurationTimer() {
  if (recordingDurationTimer !== 0) return

  recordingDuration.set(formatDuration(getRecordingDuration()))
  recordingDurationTimer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
    if (!isRecording.get()) {
      recordingDurationTimer = 0
      return GLib.SOURCE_REMOVE
    }

    recordingDuration.set(formatDuration(getRecordingDuration()))
    return GLib.SOURCE_CONTINUE
  })
}

function stopRecordingDurationTimer() {
  if (recordingDurationTimer !== 0) {
    GLib.source_remove(recordingDurationTimer)
    recordingDurationTimer = 0
  }
  recordingDuration.set("00:00")
}

function resetRecordingState() {
  isRecording.set(false)
  recordingStartTime.set(0)
  stopRecordingDurationTimer()
}

function watchRecordingProcess(process: Gio.Subprocess, filepath: string) {
  process.wait_async(null, (proc, result) => {
    try {
      process.wait_finish(result)
    } catch (error) {
      if (recordingProcess === process && expectedRecordingExit !== process) {
        console.error("Recording process exited with an error:", error)
      }
    }

    const shouldTranscribe = pendingTranscriptionPath === filepath
    if (expectedRecordingExit === process) {
      expectedRecordingExit = null
    }
    if (recordingProcess === process) {
      recordingProcess = null
      resetRecordingState()
    }
    if (pendingTranscriptionPath === filepath) {
      pendingTranscriptionPath = null
    }
    if (shouldTranscribe) {
      transcribeAudio(filepath)
    }
  })
}

function startSwayidle() {
  if (swayidleProcess !== null) return

  const process = Gio.Subprocess.new(
    ["swayidle", "-w", "timeout", "1500", "systemctl", "hibernate"],
    Gio.SubprocessFlags.NONE,
  )
  swayidleProcess = process
  isIdleRunning.set(true)
  process.wait_async(null, (_proc, result) => {
    try {
      process.wait_finish(result)
    } catch {
      // A SIGTERM from the toggle is an expected stop path.
    }
    if (swayidleProcess === process) {
      swayidleProcess = null
      isIdleRunning.set(false)
    }
  })
}

function stopSwayidle() {
  if (swayidleProcess !== null) {
    swayidleProcess.send_signal(SIGTERM)
    swayidleProcess = null
  } else {
    GLib.spawn_command_line_async("pkill swayidle")
  }
  isIdleRunning.set(false)
}

function getLanguageCode(): string {
  const layout = keyboardLayout.get().toLowerCase()
  if (layout.includes("russian")) return "ru"
  if (layout.includes("english")) return "en"
  return "auto"
}

function startRecording() {
  if (recordingProcess !== null || isRecording.get() || isProcessing.get()) return

  GLib.mkdir_with_parents(RECORDS_DIR, 0o755)
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const filename = `${RECORDS_DIR}/record_${timestamp}.wav`
  lastRecordedFile.set(filename)
  recordingProcess = Gio.Subprocess.new(
    ["ffmpeg", "-f", "pulse", "-i", "default", "-ac", "1", "-acodec", "pcm_s16le", "-ar", "16000", filename],
    Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE,
  )
  recordingStartTime.set(Date.now())
  isRecording.set(true)
  startRecordingDurationTimer()
  watchRecordingProcess(recordingProcess, filename)
}

function stopRecording() {
  if (recordingProcess === null || !isRecording.get() || isProcessing.get()) return

  const filepath = lastRecordedFile.get()
  pendingTranscriptionPath = filepath
  expectedRecordingExit = recordingProcess
  recordingProcess.send_signal(SIGTERM)
  resetRecordingState()
  menuVisible.set(false)
}

function cancelRecording() {
  if (recordingProcess === null || !isRecording.get() || isProcessing.get()) return

  pendingTranscriptionPath = null
  expectedRecordingExit = recordingProcess
  recordingProcess.send_signal(SIGTERM)
  resetRecordingState()
  menuVisible.set(false)
}

async function transcribeAudio(filepath: string): Promise<void> {
  isProcessing.set(true)
  const langCode = getLanguageCode()
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync(
      `curl -s -X POST https://silence.dimalip.in/speak -F "audio=@${filepath}" -F "file_format=pcm_s16le_16" -F "language_code=${langCode}"`
    )
    if (success && (stdout?.length ?? 0) > 0) {
      const response = JSON.parse(decodeBytes(stdout))
      if (response.text) {
        // Copy to clipboard
        const escapedText = response.text.replace(/'/g, "'\\''")
        GLib.spawn_command_line_async(`bash -c 'echo -n "${escapedText}" | wl-copy'`)
        // Simulate keyboard input
        GLib.spawn_command_line_async(`wtype "${response.text.replace(/"/g, '\\"')}"`)
        GLib.spawn_command_line_async(
          `notify-send -a "Audio Transcription" "ASR Result (typed)" "${response.text.replace(/"/g, '\\"')}"`
        )
      } else if (response.error) {
        GLib.spawn_command_line_async(
          `notify-send -a "Audio Transcription" -u critical "ASR Error" "${response.error}"`
        )
      }
    } else {
      const errorMsg = decodeBytes(stderr)
      GLib.spawn_command_line_async(
        `notify-send -a "Audio Transcription" -u critical "ASR Error" "Failed to transcribe audio"`
      )
      console.error("Transcription failed:", errorMsg)
    }
  } catch (error) {
    console.error("Transcription error:", error)
    GLib.spawn_command_line_async(
      `notify-send -a "Audio Transcription" -u critical "ASR Error" "Failed to transcribe audio"`
    )
  } finally {
    isProcessing.set(false)
  }
}

// Update keyboard layout when it changes
const hyprland = Hyprland.get_default()
hyprland.connect("keyboard-layout", () => {
  keyboardLayout.set(getCurrentKeyboardLayout())
})

export default function Menu(monitor: Gdk.Monitor) {
  let contentBox: Gtk.Box
  const win = (
    <window
      gdkmonitor={monitor}
      cssClasses={["Menu"]}
      visible={bind(menuVisible)}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      application={App}>
      <box
        setup={(self: Gtk.Box) => { contentBox = self }}
        cssClasses={["menu-widget"]}
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
        halign={Gtk.Align.END}
        valign={Gtk.Align.START}
      >
        <button
          focusable={false}
          css_classes={bind(isIdleRunning).as(running =>
            running ? ["idle-toggle-button"] : ["idle-toggle-button", "idle-toggle-button-inactive"]
          )}
          onClicked={() => {
            const running = isIdleRunning.get()
            if (running) {
              stopSwayidle()
            } else {
              startSwayidle()
            }
          }}
        >
          <box spacing={10}>
            <image
              iconName={bind(isIdleRunning).as(running =>
                running ? "face-plain-symbolic" : "face-surprise-symbolic"
              )}
              css="font-size: 18px"
            />
            <label
              label={bind(isIdleRunning).as(running =>
                running ? "Idle Monitor Active" : "Idle Monitor Inactive"
              )}
            />
          </box>
        </button>

        <button
          focusable={false}
          css_classes={["keyboard-layout-button"]}
          onClicked={() => {
            GLib.spawn_command_line_async("hyprctl switchxkblayout at-translated-set-2-keyboard next")
          }}
        >
          <box spacing={10}>
            <label
              label="🌐"
              css="font-size: 18px"
            />
            <label
              label={bind(keyboardLayout)}
            />
          </box>
        </button>

        {/* Start recording button (shown when idle) */}
        <button
          focusable={false}
          css_classes={["record-button"]}
          visible={Variable.derive(
            [isRecording, isProcessing],
            (recording, processing) => !recording && !processing
          )()}
          onClicked={() => startRecording()}
        >
          <box spacing={10}>
            <image iconName="media-record-symbolic" css="font-size: 18px" />
            <label label="Record Audio" />
          </box>
        </button>

        {/* Recording status + controls (shown when recording) */}
        <box
          css_classes={["record-button", "record-button-active"]}
          visible={bind(isRecording)}
          spacing={10}
        >
          <image iconName="media-record-symbolic" css="font-size: 18px; color: @red;" />
          <label label={bind(recordingDuration)} css_classes={["record-duration"]} />
          <box hexpand={true} />
          <button
            focusable={false}
            css_classes={["record-action-button", "record-finish-button"]}
            onClicked={() => stopRecording()}
          >
            <image iconName="checkmark-symbolic" css="font-size: 14px" />
          </button>
          <button
            focusable={false}
            css_classes={["record-action-button", "record-cancel-button"]}
            onClicked={() => cancelRecording()}
          >
            <image iconName="process-stop-symbolic" css="font-size: 14px" />
          </button>
        </box>

        {/* Processing indicator */}
        <box
          css_classes={["record-button", "record-button-processing"]}
          visible={bind(isProcessing)}
          spacing={10}
        >
          <image
            iconName="emblem-synchronizing-symbolic"
            css_classes={["record-icon-spinning"]}
            css="font-size: 18px"
          />
          <label label="Transcribing..." />
        </box>
      </box>
    </window>
  ) as Astal.Window

  const keyController = new Gtk.EventControllerKey()
  keyController.connect("key-pressed", (_self: any, keyval: number) => {
    if (keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter) {
      if (isRecording.get()) stopRecording()
      return true
    }
    if (keyval === Gdk.KEY_Escape) {
      if (isRecording.get()) cancelRecording()
      else menuVisible.set(false)
      return true
    }
    return false
  })
  win.add_controller(keyController)

  const clickController = new Gtk.GestureClick({ button: 0 })
  clickController.connect("pressed", (_self: any, _n: number, x: number, y: number) => {
    if (!contentBox) return
    const [, rect] = contentBox.compute_bounds(win)
    const point = new Graphene.Point({ x, y })
    if (!rect.contains_point(point)) {
      menuVisible.set(false)
    }
  })
  win.add_controller(clickController)

  return win
}

export { isIdleRunning, keyboardLayout, isRecording, startRecording, stopRecording, cancelRecording, menuVisible }
