import { Widget } from "astal/gtk4"
import { Gio, Variable, bind } from "astal"
import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"


const focusingState = Variable("Initializing")
const changedState = Variable(new Date())
const durationState = Variable(0)
const timeLeftState = Variable(0)
const connectionState = Variable("disconnected")
const numFocusesState = Variable(0)
const isFocusing = Variable(true) // Track if currently focusing

// Connection management variables
let connection: Soup.WebsocketConnection | null = null
let reconnectAttempts = 0
const MAX_RECONNECT_ATTEMPTS = 10
const BASE_RECONNECT_DELAY = 1000 // 1 second
let heartbeatSource: number | null = null
const HEARTBEAT_INTERVAL = 60000 // 60 seconds
let awaitingHeartbeatResponse = false

function formatDuration(seconds: number): string {
  if (seconds >= 60) {
    const totalMinutes = Math.floor(seconds / 60)
    const days = Math.floor(totalMinutes / 1440)
    const hours = Math.floor((totalMinutes % 1440) / 60)
    const minutes = totalMinutes % 60
    const parts: string[] = []
    if (days > 0) parts.push(`${days}d`)
    if (hours > 0) parts.push(`${hours}h`)
    if (minutes > 0) parts.push(`${minutes}m`)
    return parts.join(" ")
  } else if (seconds > 0) {
    return `${seconds}s`
  }
  return ""
}

function setFocusingState(state: FocusState) {
  const wasFocusing = isFocusing.get()
  if (wasFocusing !== state.focusing) {
    console.log(`Focus state changed: ${wasFocusing} -> ${state.focusing}`)
  }
  durationState.set(state.since_last_change)
  timeLeftState.set(state.focus_time_left)
  numFocusesState.set(state.num_focuses)
  isFocusing.set(state.focusing)

  let timeString = ""
  if (state.focusing && state.focus_time_left > 0) {
    timeString = `[${formatDuration(state.focus_time_left)} left]`
  } else {
    const formatted = formatDuration(state.since_last_change)
    if (formatted) timeString = `[${formatted}]`
  }

  const focusingString = state.focusing ? "Focusing" : "Not focusing"
  focusingState.set(`${focusingString} ${timeString} [${state.num_focuses}]`)
  changedState.set(new Date())
}

function updateFocusingState() {
  const now = new Date()
  const delta = Math.floor((now.getTime() - changedState.get().getTime()) / 1000)
  setFocusingState({
    focusing: !focusingState.get().includes("Not focusing"),
    since_last_change: durationState.get() + delta,
    focus_time_left: Math.max(0, timeLeftState.get() - delta),
    num_focuses: numFocusesState.get(),
  })
}

function setupHeartbeat() {
  if (heartbeatSource !== null) {
    GLib.source_remove(heartbeatSource)
    heartbeatSource = null
  }

  // Set up a new heartbeat
  heartbeatSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, HEARTBEAT_INTERVAL, () => {
    updateFocusingState()
    if (connection && connectionState.get() === "connected") {
      if (awaitingHeartbeatResponse) {
        console.log("Previous heartbeat not answered, reconnecting")
        reconnect()
        return GLib.SOURCE_CONTINUE
      }
      console.log("Sending heartbeat get_focusing request")
      awaitingHeartbeatResponse = true
      sendWebSocketMessage(connection, { type: "get_focusing" })
    } else {
      console.log("Connection lost, attempting reconnect")
      reconnect()
    }
    return GLib.SOURCE_CONTINUE
  })
}

function reconnect() {
  if (connectionState.get() === "connecting") {
    return
  }

  if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
    console.error("Maximum reconnection attempts reached")
    focusingState.set("Connection failed")
    return
  }

  // Exponential backoff for reconnection attempts
  const delay = BASE_RECONNECT_DELAY * Math.pow(1.5, reconnectAttempts)
  reconnectAttempts++

  console.log(`Attempting to reconnect in ${delay / 1000} seconds (attempt ${reconnectAttempts})`)
  connectionState.set("connecting")

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, () => {
    console.log("Reconnecting...")
    init()
    return GLib.SOURCE_REMOVE // One-time timeout
  })
}

function handleWebSocketConnection(session: Soup.Session, result: Gio.AsyncResult) {
  try {
    connection = session.websocket_connect_finish(result)
    connectionState.set("connected")
    reconnectAttempts = 0
    awaitingHeartbeatResponse = false

    connection.connect("message", handleWebSocketMessage)

    connection.connect("closed", () => {
      console.log("WebSocket connection closed")
      connectionState.set("disconnected")
      connection = null

      reconnect()
    })

    setupHeartbeat()

    // sendWebSocketMessage(connection, { type: "health" })
  } catch (error) {
    console.error("WebSocket connection error:", error)
    connectionState.set("disconnected")
    connection = null

    reconnect()
  }
}

interface FocusState {
  focusing: boolean
  since_last_change: number
  focus_time_left: number
  num_focuses: number
}

interface FocusInfo extends FocusState {
  type: "focusing"
}

function isFocusInfo(obj: unknown): obj is FocusInfo {
  return typeof obj === "object" && obj !== null && (obj as FocusInfo).type === "focusing"
}

function handleWebSocketMessage(_: any, type: Soup.WebsocketDataType, message: any) {
  if (type !== Soup.WebsocketDataType.TEXT) return

  const data = new TextDecoder().decode(message.get_data())
  console.log("Received message:", data)

  try {
    const parsed = JSON.parse(data)

    if (isFocusInfo(parsed)) {
      awaitingHeartbeatResponse = false
      setFocusingState(parsed)
    } else {
      console.error("Unknown message type:", parsed.type ?? "missing type", data)
    }

  } catch (error) {
    console.error("Error parsing message:", error)
  }
}

// Send a message through WebSocket
function sendWebSocketMessage(connection: Soup.WebsocketConnection, messageObj: object) {
  if (!connection || connectionState.get() !== "connected") {
    console.warn("Cannot send message: WebSocket not connected")
    return
  }

  try {
    const data = JSON.stringify(messageObj)
    connection.send_message(
      Soup.WebsocketDataType.TEXT,
      new GLib.Bytes(new TextEncoder().encode(data))
    )
  } catch (error) {
    console.error("Error sending WebSocket message:", error)
    connectionState.set("disconnected")
    reconnect()
  }
}

async function init() {
  const coachUrl = GLib.getenv("COACH_URL") + "/connect"
  console.log("COACH_URL:", coachUrl)

  if (!coachUrl) {
    console.log("COACH_URL environment variable not set")
    focusingState.set("COACH_URL not set")
    return
  }

  try {
    connectionState.set("connecting")
    const session = new Soup.Session()
    const message = new Soup.Message({
      method: "GET",
      uri: GLib.Uri.parse(coachUrl, GLib.UriFlags.NONE)
    })

    session.websocket_connect_async(
      message,
      null, // origin
      null,
      1,
      null, // cancellable
      (_, result) => handleWebSocketConnection(session, result)
    )
  } catch (error) {
    console.error("Error setting up WebSocket:", error)
    connectionState.set("disconnected")
    focusingState.set("Connection error")
    reconnect()
  }
}

function toggleFocus() {
  if (connection && connectionState.get() === "connected") {
    sendWebSocketMessage(connection, { type: "focus" });
    console.log("Sent focus toggle message");
  } else {
    console.warn("Cannot toggle focus: WebSocket not connected");
  }
}

export default function Coach() {
  init();

  const button = Widget.Button({
    // className: "focusing-button",
    onClicked: toggleFocus,
    child: Widget.Label({
      // className: "focusing-label",
      label: bind(focusingState),
    })
  });
  return Widget.Box({
    css_classes: bind(isFocusing).as(focusing =>
      focusing ? ["focusing-widget"] : ["focusing-widget", "not-focusing"]
    ),
    children: [button]
  })
}
