import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: root
    property int phase: 0
    property var events: null
    function require(value, message): void { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { const value=find(child,name); if(value) return value; }
        return null;
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 300
        implicitHeight: 80
        GoogleWorkWidget { id: mail; kind: "gmail"; x: 10; y: 10 }
        GoogleWorkWidget { id: calendar; kind: "calendar"; x: 120; y: 10 }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            try {
                if(GoogleWorkState.gmail.status === "loading") return;
                if(root.phase === 0) {
                    root.events=Qt.createQmlObject('import QtTest; TestEvent {}',mail,'work-events');
                    root.require(mail.labelText === "2", "Unread count missing");
                    events.mouseClick(mail,mail.width/2,mail.height/2,Qt.RightButton,Qt.NoModifier,0);
                    root.require(!mail.popupOpen,"Right click opened mail popup");
                    events.mouseClick(mail,mail.width/2,mail.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.phase=1;
                } else if(root.phase === 1 && mail.popupItem) {
                    root.require(mail.popupOpen,"Left click did not open mail popup");
                    const button=root.find(mail.popupItem.contentItem,"work-read-0");
                    root.require(button && button.enabled,"Mark as read unavailable");
                    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.phase=2;
                } else if(root.phase === 2 && GoogleWorkState.gmail.unread === 1) {
                    root.require(mail.popupOpen,"Read action closed popup");
                    root.require(mail.labelText === "1","Read action did not update count");
                    const button=root.find(mail.popupItem.contentItem,"work-read-0");
                    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.phase=3;
                } else if(root.phase === 3 && GoogleWorkState.gmail.status === "stale") {
                    root.require(mail.labelText === "1" && mail.popupOpen,"Failed write hid mail or changed count");
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0);
                    root.require(!mail.popupOpen,"Escape did not close from read button");
                    const next=JSON.parse(JSON.stringify(GoogleWorkState.snapshot));
                    next.gmail.unread=0; next.gmail.rows=[];
                    GoogleWorkState.receive(JSON.stringify(next));
                    root.require(mail.labelText === "","Zero count should be hidden");
                    events.mouseClick(calendar,calendar.width/2,calendar.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.phase=4;
                } else if(root.phase === 4 && calendar.popupItem) {
                    root.require(calendar.popupOpen,"Left click did not open meetings");
                    const entry=root.find(calendar.popupItem.contentItem,"work-entry-0");
                    events.mouseClick(entry,entry.width/2,entry.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    root.require(!calendar.popupOpen,"Opening event did not dismiss meetings");
                    root.phase=5;
                } else if(root.phase === 5) {
                    events.mouseClick(calendar,calendar.width/2,calendar.height/2,Qt.RightButton,Qt.NoModifier,0);
                    root.require(!calendar.popupOpen,"Right click opened meetings popup");
                    const next=JSON.parse(JSON.stringify(GoogleWorkState.snapshot));
                    next.calendar.rows=[{id:"away",title:"Away",start:Date.now()-1000,end:Date.now()+3600000,kind:"outOfOffice",allDay:true}];
                    GoogleWorkState.receive(JSON.stringify(next));
                    root.require(calendar.iconName === "palm" && calendar.labelText === "","Out of office should use palm");
                    root.phase=6;
                } else if(root.phase === 6) {
                    console.log("GOOGLE_WORK_UI_PASSED");
                    Qt.quit();
                }
            } catch(error) { console.error("GOOGLE_WORK_UI_FAILED",String(error)); Qt.quit(); }
        }
    }
    Timer { interval: 9000; running: true; onTriggered: { console.error("GOOGLE_WORK_UI_FAILED timeout",root.phase); Qt.quit(); } }
}
