import { App, Widget, Gdk, Gtk } from "astal/gtk3";
import AstalTray from "gi://AstalTray?version=0.1";
import { GLib, Variable, bind } from "astal";


const createMenu = (menuModel, actionGroup): Gtk.Menu => {
    const menu = Gtk.Menu.new_from_model(menuModel);
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
      let menu: Gtk.Menu;

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

      return new Widget.Button({
        tooltipMarkup: bind(item, "tooltipMarkup"),
        onClick: (self, event) => {
          if (event.button === Gdk.BUTTON_PRIMARY) {
            console.log("click")
            item.activate(0, 0);
          }
          if (event.button === Gdk.BUTTON_SECONDARY) {
            menu?.popup_at_widget(self, Gdk.Gravity.NORTH, Gdk.Gravity.SOUTH, null);
          }
        },

      }, new Widget.Icon(
        {
          gicon: bind(item, "gicon"),
        }
      ))
    })
  })
  return new Widget.Box({
    spacing: 0
  }, children)
}
