/*
 * This file is part of File Browser.
 *
 * SPDX-FileCopyrightText: 2021 Mirian Margiani
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * File Browser is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * File Browser is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/>.
 */

#include <QSettings>
#include "filemodelworker.h"
#include "statfileinfo.h"
#include "settingshandler.h"

FileModelWorker::FileModelWorker(QObject *parent) : QThread(parent) {
    connect(this, &FileModelWorker::error, this, &FileModelWorker::logError);
    connect(this, &FileModelWorker::alreadyRunning, this,
            [&](){ logError("operation already running"); });
}

FileModelWorker::~FileModelWorker()
{
    quit();
    requestInterruption();
    wait();
}

void FileModelWorker::cancel()
{
    m_cancelled.storeRelease(Cancelled);
}

void FileModelWorker::startReadFull(QString dir, QString nameFilter, Settings* settings)
{
    doStartThread(FullMode, {}, dir, nameFilter, settings);
}

void FileModelWorker::startReadChanged(QList<StatFileInfo> oldEntries,
                                       QString dir, QString nameFilter, Settings *settings)
{
    doStartThread(DiffMode, oldEntries, dir, nameFilter, settings);
}

void FileModelWorker::run()
{
    if (m_mode == FullMode) {
        doReadFull();
    } else if (m_mode == DiffMode) {
        doReadDiff();
    }
}

#include <QDebug>
void FileModelWorker::logError(QString message)
{
    qDebug() << "[FileModelWorker] error:" << message;
    qDebug() << "[FileModelWorker] state:" << m_dir << m_mode;
}

void FileModelWorker::doStartThread(FileModelWorker::Mode mode, QList<StatFileInfo> oldEntries,
                                    QString dir, QString nameFilter, Settings* settings)
{
    if (isRunning()) {
        emit alreadyRunning(); // we hope everything works out
        return;
    }

    m_settings = settings;
    m_mode = mode;
    m_finalEntries = {};
    m_oldEntries = oldEntries;
    m_dir = dir;
    m_nameFilter = nameFilter;
    m_cancelled.storeRelease(KeepRunning);
    start();
}

void FileModelWorker::doReadFull()
{
    if (!verifyOrAbort()) return;

    QDir dir(m_dir);
    if (!applySettings(dir)) return; // cancelled

    QStringList fileList = dir.entryList();
    for (auto filename : fileList) {
        QString fullpath = dir.absoluteFilePath(filename);
        StatFileInfo info(fullpath);
        m_finalEntries.append(info);
        if (cancelIfCancelled()) return;
    }

    emit done(m_mode, m_finalEntries);
}

void FileModelWorker::doReadDiff()
{
    if (!verifyOrAbort()) return;

    QDir dir(m_dir);
    if (!applySettings(dir)) return; // cancelled

    // read all files
    QList<StatFileInfo> newFiles;

    QStringList fileList = dir.entryList();
    for (auto filename : fileList) {
        QString fullpath = dir.absoluteFilePath(filename);
        StatFileInfo info(fullpath);
        newFiles.append(info);
        if (cancelIfCancelled()) return;
    }

    m_finalEntries = m_oldEntries;

    // compare old and new files and do removes if needed
    for (int i = m_oldEntries.count()-1; i >= 0; --i) {
        StatFileInfo data = m_oldEntries.at(i);
        if (!filesContains(newFiles, data)) {
            emit entryRemoved(i, data);
            m_finalEntries.removeAt(i);
            if (cancelIfCancelled()) return;
        }
    }

    // compare old and new files and do inserts if needed
    for (int i = 0; i < newFiles.count(); ++i) {
        StatFileInfo data = newFiles.at(i);
        if (!filesContains(m_oldEntries, data)) {
            emit entryAdded(i, data);
            m_finalEntries.insert(i, data);
            if (cancelIfCancelled()) return;
        }
    }

    if (cancelIfCancelled()) return;
    emit done(m_mode, m_finalEntries);
}

bool FileModelWorker::verifyOrAbort()
{
    if (m_dir.isEmpty()) {
        // not translated
        emit error("Internal worker error: empty directory name");
        return false;
    }

    QDir dir(m_dir);
    if (!dir.exists()) {
        emit error(tr("Folder does not exist"));
        return false;
    }

    if (!dir.isReadable()) {
        emit error(tr("No permission to read the folder"));
        return false;
    }

    return true;
}

// see SETTINGS for details
bool FileModelWorker::applySettings(QDir& dir) {
    if (cancelIfCancelled()) return false;

    // there are no settings to apply
    if (!m_settings) return true;

    QString localPath = dir.absoluteFilePath(".directory");
    bool useLocal = m_settings->readVariant("View/UseLocalSettings", true).toBool();

    // filters
    bool hidden = m_settings->readVariant("View/HiddenFilesShown", false).toBool();
    if (useLocal) hidden = m_settings->readVariant("Settings/HiddenFilesShown", hidden, localPath).toBool();
    QDir::Filter hiddenFilter = hidden ? QDir::Hidden : static_cast<QDir::Filter>(0);

    dir.setFilter(QDir::AllDirs | QDir::Files | QDir::NoDotAndDotDot | QDir::System | hiddenFilter);

    if (!m_nameFilter.isEmpty()) {
        // TODO implement with support for filtering directories
        // dir.setNameFilters({m_nameFilter});
    }

    if (cancelIfCancelled()) return false;

    // sorting
    bool dirsFirst = m_settings->readVariant("View/ShowDirectoriesFirst", true).toBool();
    if (useLocal) dirsFirst = m_settings->readVariant("Sailfish/ShowDirectoriesFirst", dirsFirst, localPath).toBool();
    QDir::SortFlag dirsFirstFlag = dirsFirst ? QDir::DirsFirst : static_cast<QDir::SortFlag>(0);

    QString sortSetting = m_settings->readVariant("View/SortRole", "name").toString();
    if (useLocal) sortSetting = m_settings->readVariant("Dolphin/SortRole", sortSetting, localPath).toString();
    QDir::SortFlag sortBy = QDir::Name;

    if (sortSetting == "name") {
        sortBy = QDir::Name;
    } else if (sortSetting == "size") {
        sortBy = QDir::Size;
    } else if (sortSetting == "modificationtime") {
        sortBy = QDir::Time;
    } else if (sortSetting == "type") {
        sortBy = QDir::Type;
    } else {
        sortBy = QDir::Name;
    }

    bool orderDefault = m_settings->readVariant("View/SortOrder", "default").toString() == "default";
    if (useLocal) orderDefault = m_settings->readVariant("Dolphin/SortOrder", 0, localPath) == 0 ? true : false;
    QDir::SortFlag orderFlag = orderDefault ? static_cast<QDir::SortFlag>(0) : QDir::Reversed;

    bool caseSensitive = m_settings->readVariant("View/SortCaseSensitively", false).toBool();
    if (useLocal) caseSensitive = m_settings->readVariant("Sailfish/SortCaseSensitively", caseSensitive, localPath).toBool();
    QDir::SortFlag caseSensitiveFlag = caseSensitive ? static_cast<QDir::SortFlag>(0) : QDir::IgnoreCase;

    dir.setSorting(sortBy | dirsFirstFlag | orderFlag | caseSensitiveFlag);

    if (cancelIfCancelled()) return false;
    return true;
}

bool FileModelWorker::filesContains(const QList<StatFileInfo> &files, const StatFileInfo &fileData) const
{
    // check if list contains fileData with relevant info
    for (const auto& f : files) {
        if (f.fileName() == fileData.fileName() &&
                f.size() == fileData.size() &&
                f.permissions() == fileData.permissions() &&
                f.lastModified() == fileData.lastModified() &&
                f.isSymLink() == fileData.isSymLink() &&
                f.isDirAtEnd() == fileData.isDirAtEnd()) {
            return true;
        }
    }
    return false;
}

bool FileModelWorker::cancelIfCancelled()
{
    if (m_cancelled.loadAcquire() == Cancelled) {
        emit error(tr("Directory listing cancelled"));
        return true;
    }
    return false;
}
