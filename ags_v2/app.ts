import { App } from "astal/gtk3"
import style from "inline:./style.css"
import Bar from "./widget/Bar"
import Calendar from "./widget/Calendar"


App.start({
  css: style,
  main() {
    Bar()
    Calendar()
  },
})
