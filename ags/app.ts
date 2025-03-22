import { App } from "astal/gtk3"
import style from "inline:./style.css"
import Bar from "./widget/Bar"
import Calendar from "./widget/Calendar"
import Notifications from "./widget/Notifications"
import Coach from "./widget/Coach"
import { Variable } from "astal"

const calendarVisible = Variable(false)
const currentDate = Variable(new Date())
export const focusingState = Variable("Not focusing")
const pomodoro = Variable("No pomodoro")

App.start({
  css: style,
  main() {
    Bar(calendarVisible, currentDate, focusingState, pomodoro)
    Calendar(calendarVisible, currentDate)
    Notifications()
    Coach(focusingState)
  },
  requestHandler(request: string, res: (response: any) => void) {
    try {
      const data = JSON.parse(request)
      if (data.focusing !== undefined) {
        if (data.focusing === false && data.since_last_change) {
          const minutesNotFocusing = Math.floor(data.since_last_change / 60)
          focusingState.set(`Not focusing for ${minutesNotFocusing} minutes`)
        } else if (data.focusing) {
          focusingState.set(data.focusing)
        }
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
