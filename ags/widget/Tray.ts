import { App, Widget, Gdk, Gtk } from "astal/gtk4";
import AstalTray from "gi://AstalTray?version=0.1";
import { GLib, Variable, bind } from "astal";


const createMenu = (menuModel, actionGroup): Gtk.PopoverMenu => {
    const menu = Gtk.PopoverMenu.new_from_model(menuModel);
    menu.insert_action_group('dbusmenu', actionGroup);
    return menu;
};

export default function Tray() {
  const tray = AstalTray.get_default()
  const children = bind(tray, "items").as(items => {
    return items.map(item => {
      if (item.icon_theme_path !== null) {
        App.add_icons(item.icon_theme_path)
      }
      let menu: Gtk.PopoverMenu;

      const entryBinding = Variable.derive(
        [bind(item, 'menuModel'), bind(item, 'actionGroup')],
        (menuModel, actionGroup) => {
          if (!menuModel) {
            return console.error(`Menu Model not found for ${item.id}`);
          }
          if (!actionGroup) {
            return console.error(`Action Group not found for ${item.id}`);
          }

          menu = createMenu(menuModel, actionGroup);
        },
      );

      const button = Widget.Button({
        tooltipMarkup: bind(item, "tooltipMarkup"),
        onClicked: () => {
          console.log("click")
          item.activate(0, 0);
        },

      }, Widget.Image(
        {
          gicon: bind(item, "gicon"),
        }
      ))

      // Add right-click support for context menu
      const gesture = Gtk.GestureClick.new()
      gesture.set_button(3) // Right mouse button
      gesture.connect("pressed", () => {
        if (menu) {
          menu.set_parent(button)
          menu.popup()
        }
      })
      button.add_controller(gesture)

      return button;
    })
  })
  return Widget.Box({
    css_classes: ["tray-widget"],
    spacing: 0
  }, children)
}
