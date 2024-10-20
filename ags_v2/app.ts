import { App } from "astal/gtk3"
import style from "inline:./style.css"
import Bar from "./widget/Bar"
import Calendar from "./widget/Calendar"
import { Variable } from "astal"

const calendarVisible = Variable(true)

App.start({
  css: style,
  main() {
    Bar(calendarVisible)
    Calendar(calendarVisible)
  },
})
