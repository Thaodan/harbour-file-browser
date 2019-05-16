
function goToRoot(animated) {
    pageStack.clear();
    pageStack.push(Qt.resolvedUrl("DirectoryPage.qml"), { dir: "/" }, animated === true ? PageStackAction.Animated : PageStackAction.Immediate);
}

// trims a string from left and right
function trim(s) {
    return s.replace(/^\s+|\s+$/g, "");
}

function sharedStart(array) {
    var A=array.concat().sort(), a1=A[0].split("/"), a2=A[A.length-1].split("/"), L=a1.length, i=0;
    while(i<L && a1[i]===a2[i]) i++;
    return a1.slice(0, i).join("/");
}

function goToFolder(folder) {
    var pagePath = Qt.resolvedUrl("DirectoryPage.qml");
    var prevPage = pageStack.previousPage();
    var cur = "", shared = "", rest = "", basePath = "";

    if (prevPage !== null) {
        cur = prevPage.dir
        shared = sharedStart([folder, cur]);
    }

    if (shared === folder) {
        var existingTarget = pageStack.find(function(page) {
            if (page.dir === folder) return true;
            return false;
        })
        if (!existingTarget) {
            goToRoot(true);
        } else {
            pageStack.pop(existingTarget, PageStackAction.Animated);
        }

        return;
    } else if (shared === "/" || shared === "") {
        goToRoot(false);
        rest = folder
        basePath = ""
    } else if (shared !== "") {
        var existingBase = pageStack.find(function(page) {
            if (page.dir === shared) return true;
            return false;
        })
        pageStack.pop(existingBase, PageStackAction.Immediate);
        rest = folder.replace(shared+"/", "/");
        basePath = shared;
    }

    var dirs = rest.split("/");
    for (var j = 1; j < dirs.length-1; ++j) {
        basePath += "/"+dirs[j];
        pageStack.push(pagePath, { dir: basePath }, PageStackAction.Immediate);
    }
    pageStack.push(pagePath, { dir: folder }, PageStackAction.Animated);
}

// bookmark handling
function addBookmark(path) {
    var bookmarks = getBookmarks();
    bookmarks.push(path);
    engine.writeSetting("bookmarks/"+path, lastPartOfPath(path));
    engine.writeSetting("bookmark-entries", JSON.stringify(bookmarks));
    main.bookmarkAdded(path);
}

function removeBookmark(path) {
    var bookmarks = getBookmarks();
    var filteredBookmarks = bookmarks.filter(function(e) { return e !== path; });
    engine.writeSetting("bookmark-entries", JSON.stringify(filteredBookmarks));
    engine.removeSetting("bookmarks/"+path);
    main.bookmarkRemoved(path);
}

function hasBookmark(path) {
    if (engine.readSetting("bookmarks/"+path) !== "") return true;
    return false;
}

function getBookmarks() {
    try {
        var entries = JSON.parse(engine.readSetting("bookmark-entries"));
        return entries;
    } catch (SyntaxError) {
        engine.writeSetting("bookmark-entries", JSON.stringify([]));
        return [];
    }
}

// returns the text after the last / in a path
function lastPartOfPath(path) {
    if (path === "/") return "";
    var i = path.lastIndexOf("/");
    if (i < -1) return path;
    return path.substring(i+1);
}

function formatPathForTitle(path) {
    if (path === "/") return "File Browser: /";
    return lastPartOfPath(path)+"/";
}

function formatPathForSearch(path) {
    if (path === "/") return qsTr("root"); //: root directory (placeholder in search mask)
    return lastPartOfPath(path);
}

function unicodeArrow() {
    return "\u2192"; // unicode for right pointing arrow symbol (for links)
}
