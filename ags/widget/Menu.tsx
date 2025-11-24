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
      const mainKeyboard = devices.keyboards.find((kb: any) => kb.main)
      if (mainKeyboard) {
        return mainKeyboard.active_keymap || "Unknown"
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
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    if (filepath) {
      transcribeAudio(filepath)
    }
    return false
  })
}

function toggleRecording() {
  if (isRecording.get()) {
    stopRecording()
  } else {
    startRecording()
  }
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

export default function Menu(monitor: Gdk.Monitor, visible: Variable<boolean>) {
  return (
    <window
      gdkmonitor={monitor}
      cssClasses={["Menu"]}
      visible={bind(visible)}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      application={App}>
      <box
        cssClasses={["menu-widget"]}
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <button
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

        <button
          css_classes={Variable.derive(
            [isRecording, isProcessing],
            (recording, processing) => {
              if (processing) return ["record-button", "record-button-processing"]
              if (recording) return ["record-button", "record-button-active"]
              return ["record-button"]
            }
          )()}
          sensitive={bind(isProcessing).as(p => !p)}
          onClicked={() => toggleRecording()}
        >
          <box spacing={10}>
            <image
              iconName={Variable.derive(
                [isRecording, isProcessing],
                (recording, processing) => {
                  if (processing) return "emblem-synchronizing-symbolic"
                  if (recording) return "media-playback-stop-symbolic"
                  return "media-record-symbolic"
                }
              )()}
              css_classes={bind(isProcessing).as(p => p ? ["record-icon-spinning"] : [])}
              css="font-size: 18px"
            />
            <label
              label={Variable.derive(
                [isRecording, isProcessing],
                (recording, processing) => {
                  if (processing) return "Transcribing..."
                  if (recording) return "Stop Recording"
                  return "Record Audio"
                }
              )()}
            />
            <label
              css_classes={["record-duration"]}
              visible={bind(isRecording)}
              label={bind(recordingDuration)}
            />
          </box>
        </button>
      </box>
    </window>
  )
}

export { isIdleRunning, keyboardLayout, isRecording, startRecording, toggleRecording }
