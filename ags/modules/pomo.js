let pomoStatus = Variable("waiting")
globalThis.pomoStatus = pomoStatus

pomoStatus.connect('changed', ({ value }) => {
  print('status changed to ' + `${value}`)
  pomoStatus.value = value
})

export function Pomo() {

  const label = Widget.Label({
    label: "lu",
    setup: self => self.hook(pomoStatus, () => {
      print("HOOKED")
      self.label = pomoStatus.value.toString();
    }, 'changed')
  })

  print("Pomo() called")

  return label
}
