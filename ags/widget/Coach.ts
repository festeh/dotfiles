import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"

const focusingState = Variable("Initializing")
const changedState = Variable(new Date())
const connectionState = Variable("disconnected")

// Connection management variables
let connection = null
let reconnectAttempts = 0
const MAX_RECONNECT_ATTEMPTS = 10
const BASE_RECONNECT_DELAY = 1000 // 1 second
let heartbeatSource = null
const HEARTBEAT_INTERVAL = 60000 // 30 seconds

function setFocusingState(focusing: bool, duration: int) {
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
  focusingState.set(`${focusingString} ${durationString}`)
  changedState.set(new Date())
}

function updateFocusingState() {
  const now = new Date()
  const duration = Math.floor((now.getTime() - changedState.get().getTime()) / 1000)
  let focusing = true
  if (focusingState.get().includes("Not focusing")) {
    focusing = false
  }
  setFocusingState(focusing, duration)
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

function handleWebSocketConnection(session, result, coachUrl) {
  try {
    connection = session.websocket_connect_finish(result)
    console.log("WebSocket connected to", coachUrl)
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

    // Try to reconnect on connection error
    reconnect()
  }
}

function handleNotFocused(message: object) {
  setFocusingState(false, message.since_last_change)
}

function handleFocused(message) {
  setFocusingState(true, message.since_last_change)
}

function handleWebSocketMessage(_, type: Soup.WebsocketDataType, message: object) {
  if (type !== Soup.WebsocketDataType.TEXT) return

  const data = new TextDecoder().decode(message.get_data())
  console.log("Received message:", data)

  try {
    const parsedMessage = JSON.parse(data)

    // Handle ping-pong for heartbeat
    if (parsedMessage.type === "pong") {
      console.log("Received pong from server")
      return
    }

    if (parsedMessage.focusing === false) {
      handleNotFocused(parsedMessage)
    }

    if (parsedMessage.focusing === true) {
      handleFocused(parsedMessage)
    }

  } catch (error) {
    console.error("Error parsing message:", error)
  }
}

// Send a message through WebSocket
function sendWebSocketMessage(connection, messageObj) {
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
      (self, result) => handleWebSocketConnection(session, result, coachUrl)
    )
  } catch (error) {
    console.error("Error setting up WebSocket:", error)
    connectionState.set("disconnected")
    focusingState.set("Connection error")
    reconnect()
  }
}

export default function Coach() {
  // Initialize the connection when the widget is created
  init();

  // Return a widget that shows both the focusing state and connection state
  return new Widget.Box({
    className: bind(connectionState).as(state =>
      `focusing-widget ${state !== "connected" ? "disconnected" : ""}`
    ),
    children: [
      new Widget.Label({
        label: bind(focusingState)
      })
    ]
  })
}
