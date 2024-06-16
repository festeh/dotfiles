
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

  const myLabel = Widget.Icon({
    icon: icon.bind(),
  })

  setInterval(async () => {
    try {
      const res = Utils.exec("motivator")
      icon.setValue(isOk(res) ? goodIcon : badIcon)
      myLabel.toggleClassName("blink", !isOk(res))
    } catch (e) {
      icon.setValue(badIcon)
      myLabel.toggleClassName("blink", true)
    }
  }, 3000)

  return myLabel
}
