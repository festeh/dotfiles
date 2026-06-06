import Astal from "gi://Astal?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import Gtk from "gi://Gtk?version=4.0"

type WidgetCtor<T> = (props?: Record<string, any>, ...children: any[]) => T

export { Astal, Gdk, Gtk }

export const App: any

export namespace Widget {
    export const Box: WidgetCtor<Gtk.Box>
    export const Button: WidgetCtor<Gtk.Button>
    export const CenterBox: WidgetCtor<Gtk.CenterBox>
    export const Entry: WidgetCtor<Gtk.Entry>
    export const Image: WidgetCtor<Gtk.Image>
    export const Label: WidgetCtor<Gtk.Label>
    export const LevelBar: WidgetCtor<Gtk.LevelBar>
    export const Overlay: WidgetCtor<Gtk.Overlay>
    export const Revealer: WidgetCtor<Gtk.Revealer>
    export const Slider: WidgetCtor<Gtk.Scale>
    export const Stack: WidgetCtor<Gtk.Stack>
    export const Switch: WidgetCtor<Gtk.Switch>
    export const Window: WidgetCtor<Astal.Window>
    export const MenuButton: WidgetCtor<Gtk.MenuButton>
    export const Popover: WidgetCtor<Gtk.Popover>
}
