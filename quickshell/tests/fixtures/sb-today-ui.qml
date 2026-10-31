import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: root
    property int phase: 0
    property var events: null
    property var popup: null
    function require(value, message): void { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { const value=find(child,name); if(value) return value; }
        return null;
    }
    function click(item): void {
        root.events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0);
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 200
        implicitHeight: 80
        SbTodayWidget { id: widget; x: 10; y: 10 }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            try {
                if(!SbTodayState.available) return;
                if(root.phase === 0) {
                    root.events=Qt.createQmlObject('import QtTest; TestEvent {}',widget,'sb-today-events');
                    root.require(widget.visible,"Widget hidden with open tasks");
                    root.require(widget.labelText === "3","Count should be 3, was "+widget.labelText);
                    root.require(widget.overdue,"Overdue tasks did not turn the count red");
                    events.mouseClick(widget,widget.width/2,widget.height/2,Qt.RightButton,Qt.NoModifier,0);
                    root.require(!widget.popupOpen,"Right click opened the popup");
                    root.click(widget);
                    root.phase=1;
                } else if(root.phase === 1 && widget.popupItem) {
                    root.popup=widget.popupItem.contentItem;
                    root.require(widget.popupOpen,"Left click did not open the popup");
                    const overdue=root.find(root.popup,"sb-today-overdue-count");
                    root.require(overdue && overdue.visible && overdue.text === "2 overdue","Header lacks the overdue count");
                    root.click(root.find(root.popup,"sb-today-done-0"));
                    root.require(SbTodayState.isBusy(SbTodayState.tasks[0].path),"Checked task is not marked busy");
                    root.phase=2;
                } else if(root.phase === 2 && SbTodayState.tasks.length === 2) {
                    root.require(widget.popupOpen,"Completing a task closed the popup");
                    root.require(widget.labelText === "2","Count did not follow the completion");
                    const field=root.find(root.popup,"sb-today-add");
                    field.text="Buy beans";
                    field.accepted();
                    root.phase=3;
                } else if(root.phase === 3 && SbTodayState.tasks.length === 3) {
                    root.require(SbTodayState.tasks[2].title === "Buy beans","Quick add did not add the task");
                    root.require(root.find(root.popup,"sb-today-add").text === "","Quick add kept its text");
                    root.click(root.find(root.popup,"sb-today-done-0"));
                    root.phase=4;
                } else if(root.phase === 4 && SbTodayState.error.length > 0) {
                    root.require(widget.popupOpen,"A failed completion closed the popup");
                    root.require(!SbTodayState.isBusy("tasks/home/Reply to the landlord.md"),"A failed completion stayed busy");
                    root.require(root.find(root.popup,"sb-today-error").visible,"The failure is not shown");
                    root.click(root.find(root.popup,"sb-today-row-1"));
                    root.require(!widget.popupOpen,"Opening a task did not close the popup");
                    root.phase=5;
                } else if(root.phase === 5) {
                    SbTodayState.receive(JSON.stringify({type:"snapshot",today:"2026-10-31",tasks:[]}));
                    root.require(!widget.visible,"Widget shown with nothing left");
                    console.log("SB_TODAY_UI_PASSED");
                    Qt.quit();
                }
            } catch(error) { console.error("SB_TODAY_UI_FAILED",String(error)); Qt.quit(); }
        }
    }
    Timer { interval: 9000; running: true; onTriggered: { console.error("SB_TODAY_UI_FAILED timeout",root.phase); Qt.quit(); } }
}
