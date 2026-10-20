pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire
import "VolumeLogic.js" as VolumeLogic

QtObject {
    id: root
    property Item popupOwner: null
    readonly property var node: Pipewire.defaultAudioSink
    readonly property bool ready: Pipewire.ready
    readonly property var status: VolumeLogic.describe(node, ready)
    readonly property var outputs: Pipewire.nodes.values
        .filter(output => output.audio && output.isSink && !output.isStream)
        .sort((a, b) => VolumeLogic.name(a).localeCompare(VolumeLogic.name(b)) || a.id - b.id)
    property var balances: ({})

    // All outputs share one native connection. Only the current output needs
    // detailed volume/mute subscriptions; names of other outputs are unbound metadata.
    readonly property PwObjectTracker tracker: PwObjectTracker { objects: [root.node] }

    function key(output): string {
        return output.name + ":" + output.id;
    }

    onStatusChanged: {
        if (balances && status.known && status.level > 0)
            balances[key(node)] = VolumeLogic.ratios(node.audio.volumes);
    }
    onOutputsChanged: {
        if (!balances) return;
        const remaining = outputs.map(output => key(output));
        for (let saved of Object.keys(balances))
            if (!remaining.includes(saved)) delete balances[saved];
    }

    function setVolume(target: real, expectedNode: var): bool {
        if (!status.known || (expectedNode !== undefined && expectedNode !== node))
            return false;
        const values = VolumeLogic.scaled(node.audio.volumes, target, balances[key(node)], false);
        if (!values)
            return false;
        node.audio.volumes = values;
        return true;
    }

    function adjustVolume(delta: real): void {
        if (!status.known)
            return;
        const target = VolumeLogic.adjusted(status.level, delta);
        const values = VolumeLogic.scaled(node.audio.volumes, target, balances[key(node)], true);
        if (values)
            node.audio.volumes = values;
    }

    function toggleMute(): void {
        if (status.known)
            node.audio.muted = !node.audio.muted;
    }

    function selectOutput(output): bool {
        if (!ready || !output || !outputs.includes(output))
            return false;
        Pipewire.preferredDefaultAudioSink = output;
        return true;
    }
}
