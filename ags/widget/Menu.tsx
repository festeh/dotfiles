import { App, Astal, Gdk, Gtk } from "astal/gtk4"
import { Variable, bind } from "astal"
import { Widget } from "astal/gtk4"
import GLib from "gi://GLib"
import Hyprland from "gi://AstalHyprland"

const RECORDS_DIR = "/tmp/records"

function checkSwayidle(): boolean {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("pgrep swayidle")
    return stdout.length > 0
  } catch (error) {
    return false
  }
}

function checkRecording(): boolean {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("pgrep -f 'ffmpeg.*pulse.*records'")
    return stdout.length > 0
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
      const devices = JSON.parse(new TextDecoder().decode(stdout))
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

const isIdleRunning = Variable<boolean>(checkSwayidle()).poll(1000, () => checkSwayidle())
const keyboardLayout = Variable<string>(getCurrentKeyboardLayout())
const isRecording = Variable<boolean>(checkRecording()).poll(500, () => checkRecording())
const isProcessing = Variable<boolean>(false)
const recordingStartTime = Variable<number>(0)
const recordingDuration = Variable<string>("00:00").poll(1000, () => {
  if (!isRecording.get()) return "00:00"
  return formatDuration(getRecordingDuration())
})
const lastRecordedFile = Variable<string>("")
const menuVisible = Variable<boolean>(false)

function getLanguageCode(): string {
  const layout = keyboardLayout.get().toLowerCase()
  if (layout.includes("russian")) return "ru"
  if (layout.includes("english")) return "en"
  return "auto"
}

function startRecording() {
  if (isRecording.get() || isProcessing.get()) return

  GLib.spawn_command_line_sync(`mkdir -p ${RECORDS_DIR}`)
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const filename = `${RECORDS_DIR}/record_${timestamp}.wav`
  lastRecordedFile.set(filename)
  GLib.spawn_command_line_async(`ffmpeg -f pulse -i default -ac 1 -acodec pcm_s16le -ar 16000 ${filename}`)
  recordingStartTime.set(Date.now())
}

function stopRecording() {
  if (!isRecording.get() || isProcessing.get()) return

  GLib.spawn_command_line_async("pkill -f 'ffmpeg.*pulse.*records'")
  const filepath = lastRecordedFile.get()
  recordingStartTime.set(0)
  menuVisible.set(false)
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    if (filepath) {
      transcribeAudio(filepath)
    }
    return false
  })
}

function cancelRecording() {
  if (!isRecording.get() || isProcessing.get()) return

  GLib.spawn_command_line_async("pkill -f 'ffmpeg.*pulse.*records'")
  recordingStartTime.set(0)
  menuVisible.set(false)
}

async function transcribeAudio(filepath: string): Promise<void> {
  isProcessing.set(true)
  const langCode = getLanguageCode()
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync(
      `curl -s -X POST https://silence.dimalip.in/speak -F "audio=@${filepath}" -F "file_format=pcm_s16le_16" -F "language_code=${langCode}"`
    )
    if (success && stdout.length > 0) {
      const response = JSON.parse(new TextDecoder().decode(stdout))
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
      const errorMsg = new TextDecoder().decode(stderr)
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
  const win = (
    <window
      gdkmonitor={monitor}
      cssClasses={["Menu"]}
      visible={bind(menuVisible)}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      keymode={Astal.Keymode.EXCLUSIVE}
      application={App}>
      <box
        cssClasses={["menu-widget"]}
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <button
          focusable={false}
          css_classes={bind(isIdleRunning).as(running =>
            running ? ["idle-toggle-button"] : ["idle-toggle-button", "idle-toggle-button-inactive"]
          )}
          onClicked={() => {
            const running = isIdleRunning.get()
            if (running) {
              GLib.spawn_command_line_async("pkill swayidle")
            } else {
              GLib.spawn_command_line_async('bash -c "swayidle -w timeout 1500 \'systemctl hibernate\' &"')
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

  return win
}

export { isIdleRunning, keyboardLayout, isRecording, startRecording, stopRecording, cancelRecording, menuVisible }
