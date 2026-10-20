import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

ShellRoot {
    id: root
    property var heldNode: null
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 112
        implicitHeight: 40
        VolumeWidget { id: widget }
        TestEvent { id: events }
    }
    VolumePopup { id: popup; anchorItem: widget }

    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) {
            const found = findItem(child, name);
            if (found) return found;
        }
        return null;
    }

    IpcHandler {
        target: "volume-test"
        function state(): string {
            const node = VolumeState.node;
            return JSON.stringify({status: VolumeState.status, ready: VolumeState.ready,
                channels: VolumeState.status.known ? Array.from(node.audio.volumes) : [],
                nodeName: node ? node.name : "",
                preferredName: Pipewire.preferredDefaultAudioSink ? Pipewire.preferredDefaultAudioSink.name : "",
                outputs: VolumeState.outputs.map(output => ({id: output.id, name: output.name})),
                foreground: widget.foreground.toString(), widgetWidth: widget.width,
                popupOpen: widget.popupOpen, windowReady: window.backingWindowVisible});
        }
        function clickControl(name: string): bool {
            const button = root.findItem(widget, "volume-" + name);
            if (!button || !button.enabled) return false;
            return events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
        }
        function wheel(delta: int): bool {
            return events.mouseWheel(widget, 86, 20, Qt.NoButton, Qt.NoModifier, 0, delta, 0);
        }
        function openContextMenu(): bool {
            return events.mouseClick(widget, 22, 20, Qt.RightButton, Qt.NoModifier, 0);
        }
        function closePopup(): void { VolumeState.popupOwner = null; }
        function setVolume(value: real): bool { return VolumeState.setVolume(value, VolumeState.node); }
        function moveSlider(value: real): void {
            const slider = root.findItem(popup.contentItem, "volume-slider");
            slider.value = value;
            slider.moved();
        }
        function adjust(delta: real): void { VolumeState.adjustVolume(delta); }
        function mute(): void { VolumeState.toggleMute(); }
        function hold(): void { root.heldNode = VolumeState.node; }
        function setHeld(value: real): bool { return VolumeState.setVolume(value, root.heldNode); }
        function select(name: string): bool {
            const node = VolumeState.outputs.find(output => output.name === name);
            return VolumeState.selectOutput(node);
        }
    }
}
