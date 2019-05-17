import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.file.browser.FileModel 1.0
import "functions.js" as Functions
import "../components"

Page {
    id: page
    allowedOrientations: Orientation.All
    property string dir: "/"
    property bool initial: false // this is set to true if the page is initial page
    property bool remorsePopupActive: false // set to true when remorsePopup is active
    property bool remorseItemActive: false // set to true when remorseItem is active (item level)
    property bool thumbnailsShown: updateThumbnailsState()
    property alias progressPanel: progressPanel

    FileModel {
        id: fileModel
        dir: page.dir
        // page.status does not exactly work - root folder seems to be active always??
        active: page.status === PageStatus.Active
    }

    RemorsePopup {
        id: remorsePopup
        onCanceled: remorsePopupActive = false
        onTriggered: remorsePopupActive = false
    }

    SilicaListView {
        id: fileList
        anchors.fill: parent
        anchors.bottomMargin: selectionPanel.visible ? selectionPanel.visibleSize : 0
        clip: true

        model: fileModel

        VerticalScrollDecorator { flickable: fileList }

        PullDownMenu {
            MenuItem {
                text: qsTr("Sort")
                onClicked: pageStack.push(Qt.resolvedUrl("SortingPage.qml"), { dir: dir })
            }
            MenuItem {
                text: qsTr("Create Folder")
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("CreateFolderDialog.qml"),
                                          { path: page.dir })
                    dialog.accepted.connect(function() {
                        if (dialog.errorMessage !== "")
                            notificationPanel.showText(dialog.errorMessage, "")
                    })
                }
            }
            MenuItem {
                visible: engine.clipboardCount > 0
                text: qsTr("Paste") +
                      (engine.clipboardCount > 0 ? " ("+engine.clipboardCount+")" : "")
                onClicked: {
                    if (remorsePopupActive) return;
                    var existingFiles = engine.listExistingFiles(page.dir);
                    if (existingFiles.length > 0) {
                        // show overwrite dialog
                        var dialog = pageStack.push(Qt.resolvedUrl("OverwriteDialog.qml"),
                                                    { "files": existingFiles })
                        dialog.accepted.connect(function() {
                            progressPanel.showText(engine.clipboardContainsCopy ?
                                                       qsTr("Copying") : qsTr("Moving"))
                            clearSelectedFiles();
                            engine.pasteFiles(page.dir);
                        })
                    } else {
                        // no overwrite dialog
                        progressPanel.showText(engine.clipboardContainsCopy ?
                                                   qsTr("Copying") : qsTr("Moving"))
                        clearSelectedFiles();
                        engine.pasteFiles(page.dir);
                    }
                }
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Search")
                onClicked: pageStack.push(Qt.resolvedUrl("SearchPage.qml"),
                                          { dir: page.dir });
            }
            MenuItem {
                id: bookmarkEntry
                property bool hasBookmark: Functions.hasBookmark(dir)
                text: hasBookmark ? qsTr("Remove bookmark") : qsTr("Add to bookmarks")
                onClicked: {
                    clearSelectedFiles();
                    if (hasBookmark) {
                        removeBookmark(dir);
                        hasBookmark = false;
                    } else {
                        addBookmark(dir);
                        hasBookmark = true;
                    }
                }
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
        }

        header: PageHeader {
            title: Functions.formatPathForTitle(page.dir)
            _titleItem.elide: Text.ElideMiddle

            MouseArea {
                anchors.fill: parent
                onClicked: pageStack.push(Qt.resolvedUrl("SortingPage.qml"), { dir: dir });
            }
        }

        footer: Spacer { }

        delegate: ListItem {
            id: fileItem

            property int itemSize: page.thumbnailsShown ? Theme.itemSizeExtraLarge : Theme.itemSizeSmall

            Component.onCompleted: {
                page.thumbnailsShownChanged.connect(function (){
                    itemSize = page.thumbnailsShown ? Theme.itemSizeExtraLarge : Theme.itemSizeSmall
                });
            }

            menu: contextMenu
            width: ListView.view.width
            contentHeight: itemSize

            // background shown when item is selected
            Rectangle {
                visible: isSelected
                anchors.fill: parent
                color: fileItem.highlightedColor
            }

            // HighlightImage replaced with a Loader so that HighlightImage or Image
            // can be loaded depending on Sailfish version (lightPrimaryColor is defined on SF3)
            Loader {
                id: listIcon
                anchors.verticalCenter: thumbnailsShown ? parent.verticalCenter : listLabel.verticalCenter
                x: Theme.paddingLarge
                width: itemSize === Theme.itemSizeSmall ? Theme.iconSizeSmall : itemSize
                height: width
                Component.onCompleted: {
                    var qml = Theme.lightPrimaryColor ? "../components/HighlightImageSF3.qml"
                                                      : "../components/HighlightImageSF2.qml";
                    setSource(qml, {
                        imgsrc: "../images/"+(thumbnailsShown ? "large" : "small")+"-"+fileIcon+".png",
                        imgw: width,
                        imgh: height
                    })
                }

                property bool highlighted: fileItem.highlighted || isSelected
                onHighlightedChanged: item.highlighted = highlighted
            }

            // circle shown when item is selected
            Rectangle {
                visible: isSelected
                anchors.verticalCenter: listLabel.verticalCenter
                x: Theme.paddingLarge - 2*Theme.pixelRatio
                width: Theme.iconSizeSmall + 4*Theme.pixelRatio
                height: width
                color: "transparent"
                border.color: Theme.highlightColor
                border.width: 2.25 * Theme.pixelRatio
                radius: width * 0.5
            }

            Label {
                id: listLabel
                anchors.left: listIcon.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingLarge
                y: Theme.paddingSmall
                text: filename
                elide: Text.ElideRight
                color: fileItem.highlighted || isSelected ? Theme.highlightColor : Theme.primaryColor
            }
            Label {
                id: listSize
                anchors.left: listIcon.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.top: listLabel.bottom
                text: !(isLink && isDir) ? size : Functions.unicodeArrow()+" "+symLinkTarget
                color: fileItem.highlighted || isSelected ? Theme.secondaryHighlightColor : Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Label {
                visible: !(isLink && isDir)
                anchors.top: listLabel.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: filekind+permissions
                color: fileItem.highlighted || isSelected ? Theme.secondaryHighlightColor : Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Label {
                visible: !(isLink && isDir)
                anchors.top: listLabel.bottom
                anchors.right: listLabel.right
                text: modified
                color: fileItem.highlighted || isSelected ? Theme.secondaryHighlightColor : Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            onClicked: {
                if (model.isDir) {
                    pageStack.push(Qt.resolvedUrl("DirectoryPage.qml"),
                                   { dir: fileModel.appendPath(listLabel.text) });
                } else {
                    pageStack.push(Qt.resolvedUrl("FilePage.qml"),
                                   { file: fileModel.appendPath(listLabel.text) });
                }
            }

            MouseArea {
                width: itemSize
                height: parent.height
                onClicked: {
                    fileModel.toggleSelectedFile(index);
                    selectionPanel.open = (fileModel.selectedFileCount > 0);
                    selectionPanel.overrideText = "";
                }
            }

            RemorseItem {
                id: remorseItem
                onTriggered: remorseItemActive = false
                onCanceled: remorseItemActive = false
            }

            // delete file after remorse time
            function deleteFile(deleteFilename) {
                remorseItemActive = true;
                remorseItem.execute(fileItem, qsTr("Deleting"), function() {
                    progressPanel.showText(qsTr("Deleting"));
                    engine.deleteFiles([ deleteFilename ]);
                });
            }

            // enable animated list item removals
            ListView.onRemove: animateRemoval(fileItem)

            // context menu is activated with long press
            Component {
                 id: contextMenu
                 ContextMenu {
                     // cancel delete if context menu is opened
                     onActiveChanged: { remorsePopup.cancel(); clearSelectedFiles(); }
                     MenuItem {
                         text: qsTr("Cut")
                         onClicked: engine.cutFiles([ fileModel.fileNameAt(index) ]);
                     }
                     MenuItem {
                         text: qsTr("Copy")
                         onClicked: engine.copyFiles([ fileModel.fileNameAt(index) ]);
                     }
                     MenuItem {
                         visible: main.sharingEnabled && !isLink && !isDir
                         text: qsTr("Share")
                         onClicked: {
                            pageStack.animatorPush("Sailfish.TransferEngine.SharePage", {
                                source: Qt.resolvedUrl(fileModel.fileNameAt(index)),
                                mimeType: fileModel.mimeTypeAt(index),
                                serviceFilter: ["sharing", "e-mail"]
                            })
                        }
                     }

                     MenuItem {
                         text: qsTr("Delete")
                         onClicked:  {
                             deleteFile(fileModel.fileNameAt(index));
                         }
                     }
                     MenuItem {
                         visible: model.isDir
                         text: qsTr("Properties")
                         onClicked:  {
                             pageStack.push(Qt.resolvedUrl("FilePage.qml"),
                                            { file: fileModel.fileNameAt(index) });
                         }
                     }
                 }
             }
        }

        // text if no files or error message
        ViewPlaceholder {
            enabled: fileModel.fileCount === 0 || fileModel.errorMessage !== ""
            text: fileModel.errorMessage !== "" ? fileModel.errorMessage : qsTr("No files")
        }
    }

    function clearSelectedFiles() {
        fileModel.clearSelectedFiles();
        selectionPanel.open = false;
        selectionPanel.overrideText = "";
    }
    function selectAllFiles() {
        fileModel.selectAllFiles();
        selectionPanel.open = true;
        selectionPanel.overrideText = "";
    }

    SelectionPanel {
        id: selectionPanel
        selectedCount: fileModel.selectedFileCount
        enabled: !page.remorsePopupActive && !page.remorseItemActive
        displayClose: fileModel.selectedFileCount == fileModel.fileCount
        selectedFiles: function() { return fileModel.selectedFiles(); }

        Connections {
            target: selectionPanel.actions
            onCloseTriggered: clearSelectedFiles();
            onSelectAllTriggered: selectAllFiles();
            onDeleteTriggered: {
                var files = fileModel.selectedFiles();
                remorsePopupActive = true;
                remorsePopup.execute(qsTr("Deleting"), function() {
                    clearSelectedFiles();
                    progressPanel.showText(qsTr("Deleting"));
                    engine.deleteFiles(files);
                });
            }
        }
    }

    NotificationPanel {
        id: notificationPanel
        page: page
    }

    ProgressPanel {
        id: progressPanel
        page: page
        onCancelled: engine.cancel()
    }

    // connect signals from engine to panels
    Connections {
        target: engine
        onProgressChanged: progressPanel.text = engine.progressFilename
        onWorkerDone: progressPanel.hide()
        onWorkerErrorOccurred: {
            // the error signal goes to all pages in pagestack, show it only in the active one
            if (progressPanel.open) {
                progressPanel.hide();
                if (message === "Unknown error")
                    filename = qsTr("Trying to move between phone and SD Card? It does not work, try copying.");
                else if (message === "Failure to write block")
                    filename = qsTr("Perhaps the storage is full?");

                notificationPanel.showText(message, filename);
            }
        }
        onSettingsChanged: {
            updateThumbnailsState();
        }
    }

    // require page to be x milliseconds active before
    // pushing the attached page, so the page is not pushed
    // while navigating (= while building the back-tree)
    Timer {
        id:  preparationTimer
        interval: 15
        running: false
        repeat: false
        onTriggered: {
            if (status === PageStatus.Active) {
                if (!canNavigateForward) {
                    pageStack.pushAttached(Qt.resolvedUrl("ShortcutsPage.qml"));
                }
                coverText = Functions.lastPartOfPath(page.dir)+"/"; // update cover
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Deactivating) {
            // clear file selections when the directory is changed
            clearSelectedFiles();
        }

        if (status === PageStatus.Active) {
            preparationTimer.start();
        }

        if (status === PageStatus.Activating && page.initial) {
            page.initial = false;
            Functions.goToFolder(StandardPaths.home);
        }
    }

    function updateThumbnailsState() {
        var showThumbs = engine.readSetting("show-thumbnails");
        if (engine.readSetting("use-local-view-settings", "false") === "true") {
            thumbnailsShown = engine.readSetting("Dolphin/PreviewsShown", showThumbs, dir+"/.directory") === "true";
        } else {
            thumbnailsShown = showThumbs === "true";
        }
    }

    Connections {
        target: main
        onBookmarkAdded: if (path === dir) bookmarkEntry.hasBookmark = true;
        onBookmarkRemoved: if (path === dir) bookmarkEntry.hasBookmark = false;
    }

    signal addBookmark(var path)
    signal removeBookmark(var path)
    onAddBookmark: Functions.addBookmark(path)
    onRemoveBookmark: Functions.removeBookmark(path)
}
