import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import { focusingState } from "../app"
import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"
import Gio from "gi://Gio"

// Handle WebSocket connection result
function handleWebSocketConnection(session, result, coachUrl) {
  try {
    const connection = session.websocket_connect_finish(result)
    console.log("WebSocket connected to", coachUrl)

    // Handle incoming messages
    connection.connect("message", handleWebSocketMessage)

    // Handle connection close
    connection.connect("closed", () => {
      console.log("WebSocket connection closed")
    })

    // Send initial hello message
    sendWebSocketMessage(connection, { type: "hello" })
  } catch (error) {
    console.error("WebSocket connection error:", error)
  }
}

// Handle not focusing state
function handleNotFocused(message) {
  if (!message.since_last_change) return
  
  // Calculate minutes not focusing
  const minutesNotFocusing = Math.floor(message.since_last_change / 60)
  
  // Update the focusing label
  const focusingLabel = `Not focusing for ${minutesNotFocusing} minutes`
  console.log(focusingLabel)
  
  // Update the focusing state variable to update the UI
  if (typeof focusingState !== 'undefined' && focusingState.set) {
    focusingState.set(focusingLabel)
  }
}

// Handle incoming WebSocket messages
function handleWebSocketMessage(_, type, message) {
  if (type !== Soup.WebsocketDataType.TEXT) return

  const data = new TextDecoder().decode(message.get_data())
  console.log("Received message:", data)
  
  try {
    const parsedMessage = JSON.parse(data)
    
    // Check if the message contains focusing status
    if (parsedMessage.focusing === false) {
      handleNotFocused(parsedMessage)
    }
  } catch (error) {
    console.error("Error parsing message:", error)
  }
}

// Send a message through WebSocket
function sendWebSocketMessage(connection, messageObj) {
  const data = JSON.stringify(messageObj)
  connection.send_message(
    Soup.WebsocketDataType.TEXT,
    new GLib.Bytes(new TextEncoder().encode(data))
  )
}

async function init() {
  const coachUrl = GLib.getenv("COACH_URL") + "/connect"
  console.log("COACH_URL:", coachUrl)

  if (!coachUrl) {
    console.log("COACH_URL environment variable not set")
    return
  }

  try {
    // Create a WebSocket connection
    const session = new Soup.Session()
    const message = new Soup.Message({
      method: "GET",
      uri: GLib.Uri.parse(coachUrl, GLib.UriFlags.NONE)
    })

    // Setup WebSocket connection
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
  }
}

export default function Coach(focusing) {
  init();

  return new Widget.Label({
    className: "focusing-widget",
    label: bind(focusing)
  })
}
