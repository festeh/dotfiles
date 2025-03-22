import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"
import Gio from "gi://Gio"

const focusingState = Variable("Initializing")
const changedState = Variable(new Date())

function handleWebSocketConnection(session, result, coachUrl) {
  try {
    const connection = session.websocket_connect_finish(result)
    console.log("WebSocket connected to", coachUrl)

    connection.connect("message", handleWebSocketMessage)

    connection.connect("closed", () => {
      console.log("WebSocket connection closed")
    })

    sendWebSocketMessage(connection, { type: "health" })
  } catch (error) {
    console.error("WebSocket connection error:", error)
  }
}

function handleNotFocused(message: object) {
  const minutesNotFocusing = Math.floor(message.since_last_change / 60)

  const focusingLabel = `Not focusing for ${minutesNotFocusing} minutes`
  console.log(focusingLabel)

  focusingState.set(focusingLabel)
  changedState.set(new Date())
}

function handleFocused(message) {
  const focusingLabel = `Focusing`
  focusingState.set(focusingLabel)
  changedState.set(new Date())
}

function handleWebSocketMessage(_, type: Soup.WebsocketDataType, message: object) {
  if (type !== Soup.WebsocketDataType.TEXT) return

  const data = new TextDecoder().decode(message.get_data())
  console.log("Received message:", data)

  try {
    const parsedMessage = JSON.parse(data)

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
  }
}

export default function Coach() {
  init();

  return new Widget.Label({
    className: "focusing-widget",
    label: bind(focusingState)
  })
}
