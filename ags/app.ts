import { App } from "astal/gtk3"
import style from "inline:./style.css"
import Bar from "./widget/Bar"
import Calendar from "./widget/Calendar"
import Notifications from "./widget/Notifications"
import { Variable } from "astal"

const calendarVisible = Variable(false)
const currentDate = Variable(new Date())
const focusing = Variable("Not focusing")
const pomodoro = Variable("No pomodoro")

App.start({
  css: style,
  main() {
    Bar(calendarVisible, currentDate, focusing, pomodoro)
    Calendar(calendarVisible, currentDate)
    Notifications()
  },
  requestHandler(request: string, res: (response: any) => void) {
    try {
      const data = JSON.parse(request)
      if (data.focusing) {
        focusing.set(data.focusing)
      }
      if (data.pomodoro) {
        pomodoro.set(data.pomodoro)
      }

    } catch (error) {
      res("fail to parse: " + request)
    }
    res("ok")
  },
})
