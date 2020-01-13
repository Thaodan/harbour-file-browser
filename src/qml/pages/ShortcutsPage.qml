import QtQuick 2.2
import Sailfish.Silica 1.0
import harbour.file.browser.FileModel 1.0
import "functions.js" as Functions
import "../components"

Page {
    id: page
    allowedOrientations: Orientation.All
    property string currentPath: ""

    NotificationPanel {
        id: notificationPanel
        page: page
    }

    ShortcutsList {
        id: shortcutsView
        anchors.fill: parent
        onItemClicked: Functions.goToFolder(path)

        header: PageHeader { title: qsTr("Places") }
        footer: Spacer { id: footerSpacer }
        VerticalScrollDecorator { flickable: shortcutsView; }

        PullDownMenu {
            MenuItem {
                property bool hasPrevious: pageStack.previousPage() ? true : false
                property var hasBookmark: hasPrevious ? pageStack.previousPage().hasBookmark : undefined
                visible: currentPath !== "" && hasPrevious
                text: (hasBookmark !== undefined) ?
                          (hasBookmark ?
                               qsTr("Remove bookmark for “%1”").arg(Functions.lastPartOfPath(currentPath)) :
                               qsTr("Add “%1” to bookmarks").arg(currentPath === "/" ? "/" : Functions.lastPartOfPath(currentPath))) : ""
                onClicked: {
                    if (hasBookmark !== undefined) {
                        pageStack.previousPage().toggleBookmark();
                    }
                }
            }
            MenuItem {
                text: qsTr("Open new window")
                onClicked: {
                    engine.openNewWindow(currentPath);
                    notificationPanel.showTextWithTimer(qsTr("New window opened"),
                        qsTr("Sometimes the application stays in the background"));
                }
            }
            MenuItem {
                text: qsTr("Search")
                onClicked: pageStack.push(Qt.resolvedUrl("SearchPage.qml"),
                                          { dir: currentPath === "" ? StandardPaths.home : currentPath });
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: shortcutsView.updateModel();
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            main.coverText = Functions.lastPartOfPath(currentPath)+"/"; // update cover
            if (!forwardNavigation) pageStack.pushAttached(Qt.resolvedUrl("SettingsPage.qml"));
        }
        if (status === PageStatus.Activating || status === PageStatus.Deactivating) {
            shortcutsView._isEditing = false;
        }
    }
}
