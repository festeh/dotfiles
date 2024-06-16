let pomoStatus = Variable("waiting")
globalThis.pomoStatus = pomoStatus

export function Pomo() {

  const label = Widget.Label({
    label: "",
    setup: self => self.hook(pomoStatus, () => {
      self.label = pomoStatus.value.toString();
    }, 'changed')
  })

  return label
}
