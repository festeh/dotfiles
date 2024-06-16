let pomoStatus = Variable("waiting")
globalThis.pomoStatus = pomoStatus

export function Pomo() {

  const label = Widget.Label({
    label: "",
    css: "border: 1px solid #fff; padding: 4px; border-radius: 4px;",
    setup: self => self.hook(pomoStatus, () => {
      self.label = pomoStatus.value.toString();
    }, 'changed')
  })

  return label
}
