import { Widget } from "astal/gtk3"
import { Gio, Variable, bind } from "astal"
import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"


const focusingState = Variable("Initializing")
const changedState = Variable(new Date())
const durationState = Variable(0)
const connectionState = Variable("disconnected")
const numFocusesState = Variable(0)

// Connection management variables
let connection: Soup.WebsocketConnection | null = null
let reconnectAttempts = 0
const MAX_RECONNECT_ATTEMPTS = 10
const BASE_RECONNECT_DELAY = 1000 // 1 second
let heartbeatSource: number | null = null
const HEARTBEAT_INTERVAL = 60000 // 30 seconds

function setFocusingState(focusing: boolean, duration: number, numFocuses: number) {
  durationState.set(duration)
  numFocusesState.set(numFocuses)
  const durationMinutes = Math.floor(duration / 60)
  let durationString = ""
  if (durationMinutes == 1) {
    durationString = "for 1 minute"
  } else if (durationMinutes > 1) {
    durationString = `for ${durationMinutes} minutes`
  }
  let focusingString = "Focusing"
  if (!focusing) {
    focusingString = "Not focusing"
  }
  focusingState.set(`${focusingString} ${durationString} [${numFocuses}]`)
  changedState.set(new Date())
}

function updateFocusingState() {
  const now = new Date()
  const delta = Math.floor((now.getTime() - changedState.get().getTime()) / 1000)
  const duration = durationState.get() + delta
  let focusing = true
  if (focusingState.get().includes("Not focusing")) {
    focusing = false
  }
  const numFocuses = numFocusesState.get()
  setFocusingState(focusing, duration, numFocuses)
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
      sendWebSocketMessage(connection, { type: "health" })
    } else {
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
    reconnectAttempts = 0 // Reset reconnect attempts on successful connection

    connection.connect("message", handleWebSocketMessage)

    connection.connect("closed", () => {
      console.log("WebSocket connection closed")
      connectionState.set("disconnected")
      connection = null

      reconnect()
    })

    setupHeartbeat()

    sendWebSocketMessage(connection, { type: "health" })
  } catch (error) {
    console.error("WebSocket connection error:", error)
    connectionState.set("disconnected")
    connection = null

    reconnect()
  }
}

function handleWebSocketMessage(_: any, type: Soup.WebsocketDataType, message: any) {
  if (type !== Soup.WebsocketDataType.TEXT) return

  const data = new TextDecoder().decode(message.get_data())
  console.log("Received message:", data)

  try {
    const parsed = JSON.parse(data)

    if (parsed.focusing !== null) {
      setFocusingState(parsed.focusing, parsed.since_last_change, parsed.num_focuses)
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

  const button = new Widget.Button({
    // className: "focusing-button",
    onClicked: toggleFocus,
    child: new Widget.Label({
      // className: "focusing-label",
      label: bind(focusingState),
    })
  });
  return new Widget.Box({
    className: bind(connectionState).as(state =>
      `focusing-widget ${state !== "connected" ? "disconnected" : ""}`
    ),
    children: [button]
  })
}
