.pragma library

function clean(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function key(value) { return clean(value).replace(/\.desktop$/i, "").toLowerCase(); }

function address(value) {
    value = clean(value).replace(/^0x/i, "");
    return /^[0-9a-f]+$/i.test(value) && !/^0+$/.test(value) ? value.toLowerCase() : "";
}

function normal(workspace) {
    return workspace && workspace.name !== "special" && !workspace.name.startsWith("special:");
}

function compare(a, b) {
    const aNumber = a.id > 0, bNumber = b.id > 0;
    if (aNumber && bNumber) return a.id - b.id;
    if (aNumber !== bNumber) return aNumber ? -1 : 1;
    return clean(a.name).localeCompare(clean(b.name), undefined, {numeric: true})
        || String(a.address).localeCompare(String(b.address));
}

function label(workspace) {
    return workspace ? workspace.id > 0 ? String(workspace.id) : clean(workspace.name) || "Workspace" : "";
}

function workspaceKey(workspace) {
    if (!workspace) return "";
    if (workspace.address !== undefined && workspace.address !== "") return String(workspace.address);
    return Number.isInteger(workspace.id) ? String(workspace.id) : "";
}

function luaString(value) {
    return '"' + value.replace(/[\\"\x00-\x1f\x7f]/g,
        char => "\\" + char.charCodeAt(0).toString().padStart(3, "0")) + '"';
}

function workspaceRequest(workspace, lua) {
    if (!normal(workspace)) return "";
    // Positive numbered workspaces can have identical user-visible names.
    const selector = workspace.id > 0 ? workspace.id : "name:" + workspace.name;
    return lua ? "hl.dsp.focus({ workspace = " + (typeof selector === "number" ? selector : luaString(selector)) + " })"
        : "workspace " + selector;
}

function index(entries) {
    const result = {ids: {}, classes: {}, executables: {}};
    for (const entry of entries) {
        const id = key(entry.id), startup = key(entry.startupClass);
        // Reading these fields also makes QML rebuild the index when metadata changes.
        const info = {entry: entry, icon: entry.icon, name: entry.name};
        if (id) result.ids[id] = info;
        if (startup) result.classes[startup] = result.classes[startup] === undefined ? info : null;
        const executable = commandExecutable(entry.command || []);
        if (executable) result.executables[executable] = result.executables[executable] === undefined ? info : null;
    }
    return result;
}

function resolve(candidates, catalog) {
    for (const candidate of candidates) {
        const match = catalog.ids[key(candidate)];
        if (match) return match.entry;
    }
    for (const candidate of candidates) {
        const match = catalog.classes[key(candidate)];
        if (match) return match.entry;
    }
    return null;
}

function commandExecutable(command) {
    let position = 0;
    if (command.length && command[0].split("/").pop() === "env") {
        position++;
        while (position < command.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(command[position])) position++;
        if (command[position] === "--") position++;
    }
    const value = command[position] || "";
    return value.startsWith("-") ? "" : key(value.split("/").pop());
}

function resolveProgram(candidates, catalog) {
    const direct = resolve(candidates, catalog);
    if (direct) return direct;
    for (const candidate of candidates) {
        const match = catalog.executables[key(candidate)];
        if (match) return match.entry;
    }
    return null;
}

function trayItem(candidates, items) {
    const ids = new Set(candidates.map(key).filter(value => value));
    let match = null;
    for (const item of items) {
        if (!ids.has(key(item.id))) continue;
        // Multiple matching registrations do not identify one app icon safely.
        if (match) return null;
        match = item;
    }
    return match;
}

function themeIconNames(candidates, desktopId, icon) {
    const names = [];
    function add(value) {
        if (typeof value !== "string") return;
        value = value.trim();
        if (!value || /[\/\\:]/.test(value) || names.includes(value)) return;
        names.push(value);
    }
    // Preserve case and explicit icon names. Absolute launcher-image paths
    // are tried separately, after the app's themed identity.
    add(icon);
    add(desktopId);
    for (const candidate of candidates) {
        add(candidate);
        if (typeof candidate === "string") add(candidate.replace(/\.desktop$/i, ""));
    }
    return names;
}

function focusRequest(value, lua) {
    const id = address(value);
    if (!id) return "";
    return lua ? 'hl.dsp.focus({ window = "address:0x' + id + '" })' : "focuswindow address:0x" + id;
}
