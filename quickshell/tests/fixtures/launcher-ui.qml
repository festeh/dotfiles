//@ pragma IconTheme Papirus-Dark

import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: root
    property int phase: 0
    property var events: null
    Launcher {
        id: launcher
        testMode: true
        helperCommand: ["python3", Quickshell.shellPath("mock.py")]
    }
    function require(value, message): void { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { const found=find(child,name); if(found) return found; }
        return null;
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if(!launcher.transportReady) return;
                const field=root.find(launcher.windowItem.contentItem,"launcher-search");
                if(root.phase===0) {
                    root.events=Qt.createQmlObject('import QtTest; TestEvent {}',field,'launcher-events');
                    launcher.open("apps"); root.phase=1;
                } else if(root.phase===1) {
                    root.require(root.find(launcher.windowItem.contentItem,"launcher-refresh-icon").status===Image.Ready,"Refresh icon did not load");
                    root.require(field.activeFocus,"Search not focused");
                    field.text="alpha";
                    root.require(launcher.results.length===2,"Search failed");
                    root.require(events.keyClick(Qt.Key_J,Qt.ControlModifier,0),"Ctrl+j not delivered");
                    root.require(launcher.currentIndex===1,"Ctrl+j did not select next result");
                    events.keyClick(Qt.Key_L,Qt.ControlModifier,0); root.phase=2;
                } else if(root.phase===2 && launcher.results.length===2) {
                    root.require(launcher.category==="books" && launcher.query==="alpha","Category switch lost query");
                    launcher.currentIndex=1;
                    launcher.receive(JSON.stringify({type:"cover",id:"book:alpha",source:""}));
                    root.require(launcher.currentIndex===1,"Cover update moved keyboard selection");
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0);
                    root.require(!launcher.opened,"Escape did not close");
                    launcher.open("apps");
                    root.require(launcher.query==="","Reopening retained query");
                    root.phase=3;
                } else if(root.phase===3) {
                    field.forceActiveFocus();
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0);
                    root.require(!launcher.opened,"Enter did not close app launcher"); root.phase=4;
                } else if(root.phase===4) {
                    launcher.open("clipboard"); root.phase=5;
                } else if(root.phase===5 && launcher.results.length===1) {
                    field.forceActiveFocus();
                    events.keyClick(Qt.Key_Return,Qt.ShiftModifier,0);
                    root.require(!launcher.opened,"Shift+Enter did not close clipboard"); root.phase=6;
                } else if(root.phase===6) {
                    launcher.open("widgets"); root.phase=7;
                } else if(root.phase===7 && launcher.results.length===3) {
                    field.text="awake";
                    launcher.currentIndex=launcher.results.findIndex(row=>row.id==="idle:awake");
                    launcher.focusInput();
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0);
                    root.require(launcher.opened,"Widget action closed launcher"); root.phase=8;
                } else if(root.phase===8 && launcher.results.find(row=>row.id==="idle:awake")?.selected) {
                    const awake=root.find(launcher.windowItem.contentItem,"launcher-sleep-awake");
                    events.mouseClick(awake,awake.width/2,awake.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    const automatic=root.find(launcher.windowItem.contentItem,"launcher-sleep-auto");
                    events.mouseClick(automatic,automatic.width/2,automatic.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.phase=9;
                } else if(root.phase===9 && launcher.results.find(row=>row.id==="idle:auto")?.selected) {
                    root.require(!launcher.results.find(row=>row.id==="idle:awake")?.selected,"Both sleep choices selected");
                    root.require(root.find(launcher.windowItem.contentItem,"launcher-sleep-external").visible,"Other app status hidden");
                    root.find(launcher.windowItem.contentItem,"launcher-sleep-auto").forceActiveFocus();
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0);
                    root.require(!launcher.opened,"Escape on widget card did not close");
                    launcher.open("widgets");
                    field.text="awake";
                    const button=root.find(launcher.windowItem.contentItem,"launcher-category-books");
                    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.require(launcher.category==="books","Sidebar mouse activation failed");
                    root.require(launcher.query==="awake","Sidebar lost query");
                    root.find(launcher.windowItem.contentItem,"launcher-refresh").forceActiveFocus();
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0);
                    root.require(!launcher.opened,"Escape on Refresh did not close");
                    launcher.receive(JSON.stringify({type:"error",message:"Late background error"}));
                    root.require(!launcher.opened,"Late error reopened dismissed launcher");
                    root.phase=10;
                } else if(root.phase===10) {
                    console.log("LAUNCHER_UI_PASSED"); Qt.quit();
                }
            } catch(error) { console.error("LAUNCHER_UI_FAILED",error.message); Qt.quit(); }
        }
    }
    Timer { interval:8000; running:true; onTriggered:{ console.error("LAUNCHER_UI_TIMEOUT",root.phase); Qt.quit(); } }
}
