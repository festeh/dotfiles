import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"
import Gio from "gi://Gio"

async function loadCoachUrl() {
  const coachUrl = GLib.getenv("COACH_URL")
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
    const webSocket = Soup.Session.websocket_connect_async(
      session,
      message,
      null, // origin
      ["coach"], // protocols
      null, // cancellable
      (self, result) => {
        try {
          const connection = Soup.Session.websocket_connect_finish(session, result)
          console.log("WebSocket connected to", coachUrl)
          
          // Handle incoming messages
          connection.connect("message", (_, type, message) => {
            if (type === Soup.WebsocketDataType.TEXT) {
              const data = new TextDecoder().decode(message.get_data())
              console.log("Received message:", data)
              // Process the message here
            }
          })
          
          // Handle connection close
          connection.connect("closed", () => {
            console.log("WebSocket connection closed")
          })
          
          // Example: Send a message
          const data = JSON.stringify({ type: "hello" })
          connection.send_message(
            Soup.WebsocketDataType.TEXT,
            new GLib.Bytes(new TextEncoder().encode(data))
          )
        } catch (error) {
          console.error("WebSocket connection error:", error)
        }
      }
    )
  } catch (error) {
    console.error("Error setting up WebSocket:", error)
  }
}

export default function Coach() {
  // Start the async loading process
  loadCoachUrl();
  
  return new Widget.Label({
    className: "focusing-widget",
    label: "SOSAT"
  })
}
