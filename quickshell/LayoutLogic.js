.pragma library

function clean(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function physical(name) {
    return !!clean(name) && !/virtual|wtype|ydotool|uinput/i.test(name);
}

function primary(devices) {
    if (!devices || !Array.isArray(devices.keyboards)) return null;
    const keyboards = devices.keyboards.filter(keyboard => keyboard && physical(keyboard.name));
    return keyboards.find(keyboard => keyboard.main === true)
        || (keyboards.length === 1 ? keyboards[0] : null);
}

function describe(keyboard) {
    const device = keyboard ? clean(keyboard.name) : "";
    const name = keyboard ? clean(keyboard.active_keymap) : "";
    const layouts = keyboard ? clean(keyboard.layout).split(",").map(value => value.trim()).filter(Boolean) : [];
    const index = keyboard ? keyboard.active_layout_index : undefined;
    const code = Number.isInteger(index) && index >= 0 ? layouts[index] || "" : "";
    const canCycle = !!(device && name && layouts.length > 1 && /^[A-Za-z0-9_.:-]+$/.test(device));
    return {
        device: device,
        name: name,
        ready: !!(device && name),
        russian: code === "ru" || /^Russian(?:$|[\s,(])/i.test(name),
        canCycle: canCycle,
        tooltip: name ? name + (canCycle ? " · Click to switch layout" : "") : "Keyboard layout unavailable"
    };
}

function cycleCommand(keyboard) {
    const status = describe(keyboard);
    return status.canCycle ? ["hyprctl", "switchxkblayout", status.device, "next"] : [];
}

function withLayout(keyboard, name) {
    // The event carries a display name, not its index. Do not retain a stale
    // snapshot index after changing from Russian back to another layout.
    return Object.assign({}, keyboard, {active_keymap: clean(name), active_layout_index: undefined});
}
