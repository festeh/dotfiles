
function isOk(data) {
  // try to deserialize the data to json
  try {
    const json = JSON.parse(data)
    const res = json.DmnOn
    if (res === undefined) {
      return false
    }
    return res
  } catch (e) {
    return false
  }
}

export function Motivator() {
  const goodIcon = "emblem-favorite-symbolic"
  const badIcon = "face-sad-symbolic"

  const icon = Variable(goodIcon)
  const className = Variable("")

  const myLabel = Widget.Icon({
    icon: icon.bind(),
    className: className.bind()
  })

  setInterval(async () => {
    try {
      const res = Utils.exec("motivator")
      icon.setValue(isOk(res) ? goodIcon : badIcon)
      if (isOk(res)) {
        className.setValue("")
      } else {
        className.setValue("blink")
      }
    } catch (e) {
      icon.setValue(badIcon)
      className.setValue("blink")
    }
  }, 3000)

  return myLabel
}
