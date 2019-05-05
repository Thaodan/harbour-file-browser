import QtQuick 2.2
import Sailfish.Silica 1.0
import harbour.file.browser.FileModel 1.0
import "functions.js" as Functions
import "../components"

Page {
    id: page
    allowedOrientations: Orientation.All

    SilicaListView {
        id: shortcutsView

        width: parent.width
        height: parent.height

        VerticalScrollDecorator { }

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Search")
                onClicked: pageStack.push(Qt.resolvedUrl("SearchPage.qml"),
                                          { dir: StandardPaths.home });
            }
        }

        model: listModel

        header: PageHeader {
            title: qsTr("File Browser")+" "+Functions.unicodeBlackDownPointingTriangle()
            MouseArea {
                anchors.fill: parent
                onClicked: dirPopup.show();
            }
        }

        delegate: Component {
            id: listItem

            BackgroundItem {
                id: iconButton
                width: shortcutsView.width
                height: Screen.height / 14

                onClicked: {
                    Functions.goToFolder(model.location)
                }

                Image {
                    id: image
                    width: height
                    source: "image://theme/" + model.thumbnail + "?" + (
                                iconButton.pressed ? Theme.highlightColor : Theme.primaryColor)
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: Theme.paddingMedium
                    }
                }

                Label {
                    id: shortcutLabel
                    width: parent.width - image.width - Theme.horizontalPageMargin
                    font.pixelSize: Theme.fontSizeMedium
                    color: iconButton.pressed ? Theme.highlightColor : Theme.primaryColor
                    text: model.name
                    elide: Text.ElideRight
                    anchors {
                        left: image.right
                        leftMargin: Theme.paddingMedium
                        top: parent.top
                        topMargin: model.location === model.name ? (parent.height / 2) - (height / 2) : 5
                    }
                }

                Text {
                    id: shortcutPath
                    width: parent.width - image.width - Theme.horizontalPageMargin
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: iconButton.pressed ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    text: Functions.unicodeArrow() + " " + model.location
                    visible: model.location === model.name ? false : true
                    elide: Text.ElideRight
                    anchors {
                        left: image.right
                        leftMargin: Theme.paddingSmall
                        top: shortcutLabel.bottom
                        topMargin: 2
                    }
                }

                IconButton {
                    id: deleteBookmarkBtn
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    visible: model.bookmark ? true : false
                    icon.source: "image://theme/icon-m-close"
                    anchors {
                        top: parent.top
                        right: parent.right
                        rightMargin: Theme.paddingLarge
                    }

                    onClicked: {
                        if (!model.bookmark) return
                        //settings.removeBookmarkPath(model.location) TODO
                        updateModel()
                    }
                }
            }
        }

        section {
            property: 'section'
            delegate: SectionHeader {
                text: section
                height: Theme.itemSizeExtraSmall
            }
        }

        ListModel {
            id: listModel
        }

        Component.onCompleted: updateModel()

        function updateModel() {
            listModel.clear()
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Last location"),
                               "thumbnail": "icon-m-back",
                               "location": main.lastPath })
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Home"),
                               "thumbnail": "icon-m-home",
                               "location": StandardPaths.home })
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Documents"),
                               "thumbnail": "icon-m-file-document-light",
                               "location": StandardPaths.documents })
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Downloads"),
                               "thumbnail": "icon-m-cloud-download",
                               "location": StandardPaths.download })
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Music"),
                               "thumbnail": "icon-m-file-audio",
                               "location": StandardPaths.music })
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Pictures"),
                               "thumbnail": "icon-m-file-image",
                               "location": StandardPaths.pictures })
            listModel.append({ "section": qsTr("Locations"),
                               "name": qsTr("Videos"),
                               "thumbnail": "icon-m-file-video",
                               "location": StandardPaths.videos })
            listModel.append({ "section": qsTr("Android locations"),
                               "name": qsTr("Android storage"),
                               "thumbnail": "icon-m-file-apk",
                               "location": StandardPaths.home + "/android_storage" })
            if (engine.sdcardPath() !== "") {
                listModel.append({ "section": qsTr("Storage devices"),
                                   "name": qsTr("SD card"),
                                   "thumbnail": "icon-m-sd-card",
                                   "location": engine.sdcardPath() })
            }

            // TODO support external drives via USB OTG

            // Add bookmarks if there are any
            // TODO support bookmarks
    //        var bookmarks = None//settings.getBookmarks()

    //        for (var key in bookmarks)
    //        {
    //            var entry = bookmarks[key];

    //            listModel.append({ "section": qsTr("Bookmarks"),
    //                               "name": entry,
    //                               "thumbnail": "icon-m-favorite",
    //                               "location": key,
    //                               "bookmark": true })
    //        }
        }
    }

    DirPopup {
        id: dirPopup
        anchors.fill: parent
        menuTop: Theme.itemSizeMedium
    }
}
