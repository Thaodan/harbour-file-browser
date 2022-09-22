/*
 * This file is part of File Browser.
 *
 * SPDX-FileCopyrightText: 2022 Mirian Margiani
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

#include <QDebug>
#include <QCoreApplication>

#include "fileoperations.h"

void FileOperationsEnums::registerTypes(const char *qmlUrl, int major, int minor) {
#define REGISTER_ENUM_CONTAINER(NAME) \
    qRegisterMetaType<FileOp##NAME::NAME>("FileOp" #NAME "::" #NAME); \
    FileOp##NAME::registerToQml(qmlUrl, major, minor);

    REGISTER_ENUM_CONTAINER(Mode)
    REGISTER_ENUM_CONTAINER(ErrorType)
    REGISTER_ENUM_CONTAINER(ErrorAction)
    REGISTER_ENUM_CONTAINER(Status)

#undef REGISTER_ENUM_CONTAINER
}

FileWorker2::~FileWorker2() {
    if (m_status.load() != FileOpStatus::Finished) emit finished(false);
}

void FileWorker2::cancel()
{
    if (m_status.loadAcquire() == FileOpStatus::Finished) return;

    qDebug() << "File operation cancelled in thread" << QThread::currentThreadId();
    m_status.storeRelease(FileOpStatus::Cancelled);
    emit statusChanged(FileOpStatus::Cancelled);
}

void FileWorker2::pause() {
    if (m_status.loadAcquire() == FileOpStatus::Finished) return;

    qDebug() << "File operation paused in thread" << QThread::currentThreadId();
    m_status.storeRelease(FileOpStatus::Paused);
    emit statusChanged(FileOpStatus::Paused);
}

void FileWorker2::carryOn(FileOpErrorAction::ErrorAction feedback) {
    int status = m_status.loadAcquire();

    if (status != FileOpStatus::WaitingForFeedback && status != FileOpStatus::Paused) {
        qDebug() << "Cannot continue file operation: neither paused nor waiting for feedback in thread" << QThread::currentThreadId();
        return;
    }

    if (status == FileOpStatus::WaitingForFeedback) {
        m_errorAction.storeRelease(feedback);
    }

    qDebug() << "Continuing file operation in thread" << QThread::currentThreadId() << "with feedback" << feedback;
    m_status.storeRelease(FileOpStatus::Running);
    emit statusChanged(FileOpStatus::Running);
}

void FileWorker2::process() {
    // TODO Implement.

    if (m_status.loadAcquire() == FileOpStatus::Finished) {
        qDebug() << "Bug: finished file operation asked to run again - request ignored";
        return;
    }

    m_status.storeRelease(FileOpStatus::Running);
    emit statusChanged(FileOpStatus::Running);

    emit progressChanged(0, 0, {}, 0, 0);
    emit progressChanged(0, m_files.size(), {}, 0, 0);

    qDebug() << "Processing file operation in thread" << QThread::currentThreadId();

    for (int i = 0; i < m_files.size(); i++) {
        QThread::sleep(1);
        qDebug() << "DEBUG TURN:" << i << "in" << QThread::currentThreadId() << "status:" << m_status << m_files[i];

        emit progressChanged(i, m_files.size(), {}, 0, 0);
        QCoreApplication::processEvents();

        if (!checkContinue()) break;
    }

    if (m_status.loadAcquire() == FileOpStatus::Cancelled) {
        emit finished(false);
    } else {
        m_status.storeRelease(FileOpStatus::Finished);
        emit statusChanged(FileOpStatus::Finished);
        emit finished(true);
    }
}

bool FileWorker2::checkContinue() {
    FileOpStatus::Status status = static_cast<FileOpStatus::Status>(m_status.loadAcquire());

    switch (status) {
    case FileOpStatus::Running:
        return true;

    case FileOpStatus::Enqueued:
    case FileOpStatus::WaitingForFeedback:
    case FileOpStatus::Paused:
        while (true) {
            qDebug() << "DEBUG Waiting to continue file operation in thread" << QThread::currentThreadId();
            QThread::msleep(500);
            QCoreApplication::processEvents();
            status = static_cast<FileOpStatus::Status>(m_status.loadAcquire());

            switch (status) {
            case FileOpStatus::Running:
                return true;

            case FileOpStatus::Finished:
            case FileOpStatus::Cancelled:
                return false;

            default:
                continue;
            }
        }
    case FileOpStatus::Finished:
    case FileOpStatus::Cancelled:
        return false;
    }

    return true; // should not be reachable
}

FileWorker2::FileWorker2(FileOpMode::Mode mode, QStringList files, QStringList targets) :
    m_mode(mode), m_files(files), m_targets(targets) {}

FileOperationsHandler::FileOperationsHandler(QObject *parent) : QObject(parent)
{
    m_tasks.reserve(100);
}

FileOperationsHandler::~FileOperationsHandler()
{
    //
}

FileOperationsHandler::Task &FileOperationsHandler::makeTask(FileOpMode::Mode mode, QStringList files, QStringList targets, bool autoDelete) {
    QSharedPointer<QThread> thread(new QThread());
    QSharedPointer<FileWorker2> worker(new FileWorker2(mode, files, targets));
    worker->moveToThread(thread.data());

    qDebug() << "Adding new file operation in thread" << QThread::currentThreadId();

    connect(thread.data(), &QThread::started, worker.data(), &FileWorker2::process);
    connect(worker.data(), &FileWorker2::finished, thread.data(), &QThread::quit);

    if (autoDelete) {
        // Is this even safe or would it lead to double-free?
        // connect(worker.data(), &FileWorker2::finished, worker.data(), &FileWorker2::deleteLater);
        // connect(thread.data(), &QThread::finished, thread.data(), &QThread::deleteLater);
    }

    int handle = m_count.fetchAndAddAcquire(1);
    m_handles.append(handle);
    m_tasks.insert(handle, Task(handle, thread, worker, mode, files, targets));
    Task& task = m_tasks[handle];

    connect(worker.data(), &FileWorker2::progressChanged,
            [&](int current, int of, QString file, int fileCurrent, int fileOf) {
        task.progressCurrent = current;
        task.progressOf = of;
        task.progressFilename = file;
        task.progressFileCurrent = fileCurrent;
        task.progressFileOf = fileOf;
    });

    return task;
}

void FileOperationsHandler::forgetTask(int handle)
{
    if (m_tasks.contains(handle)) {
        m_tasks.remove(handle);
        m_handles.removeAll(handle);
    }
}

const QList<int> &FileOperationsHandler::getTasks() const
{
    return m_handles;
}

bool FileOperationsHandler::haveTask(int handle)
{
    if (m_tasks.contains(handle)) return true;
    return false;
}

FileOperationsHandler::Task &FileOperationsHandler::getTask(int handle)
{
    return m_tasks[handle];
}

enum {
    HandleRole =          Qt::UserRole +  1,
    ModeRole =            Qt::UserRole +  2,
    FilesRole =           Qt::UserRole +  3,
    TargetsRole =         Qt::UserRole +  4,
    StatusRole =          Qt::UserRole +  5,
    ProgressCurrentRole = Qt::UserRole +  6,
    ProgressOfRole =      Qt::UserRole +  7,
    ProgressFilenameRole =    Qt::UserRole + 11,
    ProgressFileCurrentRole = Qt::UserRole + 12,
    ProgressFileOfRole =  Qt::UserRole + 13,
    ErrorTypeRole =       Qt::UserRole +  8,
    ErrorMessageRole =    Qt::UserRole +  9,
    ErrorFileRole =       Qt::UserRole + 10,
};

FileOperationsModel::FileOperationsModel(QObject *parent) :
    QAbstractListModel(parent), m_handler(new FileOperationsHandler(this))
{
    //
}

FileOperationsModel::~FileOperationsModel()
{
    const auto tasks = m_handler->getTasks();
    for (const auto& i : tasks) {
        m_handler->getTask(i).get()->cancel();
    }
}

int FileOperationsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_handler->getTasks().count();
}

QVariant FileOperationsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount()) {
        return QVariant();
    }

    const auto& task = m_handler->getTask(m_handler->getTasks()[index.row()]);

    switch (role) {
    case Qt::DisplayRole:
    case HandleRole:
        return task.handle();

    case ModeRole:
        return task.mode();

    case FilesRole:
        return task.files();

    case TargetsRole:
        return task.targets();

    case StatusRole:
        return task.status();

    case ProgressCurrentRole:
        return task.progressCurrent;

    case ProgressOfRole:
        return task.progressOf;

    case ProgressFilenameRole:
        return task.progressFilename;

    case ProgressFileCurrentRole:
        return task.progressFileCurrent;

    case ProgressFileOfRole:
        return task.progressFileOf;

    case ErrorTypeRole:
        return task.errorType;

    case ErrorMessageRole:
        return task.errorMessage;

    case ErrorFileRole:
        return task.errorFile;

    default:
        return QVariant();
    }
}

QHash<int, QByteArray> FileOperationsModel::roleNames() const
{
    QHash<int, QByteArray> roles = QAbstractListModel::roleNames();
    roles.insert(HandleRole, QByteArray("handle"));
    roles.insert(ModeRole, QByteArray("mode"));
    roles.insert(FilesRole, QByteArray("files"));
    roles.insert(TargetsRole, QByteArray("targets"));
    roles.insert(StatusRole, QByteArray("status"));
    roles.insert(ProgressCurrentRole, QByteArray("progressCurrent"));
    roles.insert(ProgressOfRole, QByteArray("progressOf"));
    roles.insert(ProgressFilenameRole, QByteArray("progressFilename"));
    roles.insert(ProgressFileCurrentRole, QByteArray("progressFileCurrent"));
    roles.insert(ProgressFileOfRole, QByteArray("progressFileOf"));
    roles.insert(ErrorTypeRole, QByteArray("errorType"));
    roles.insert(ErrorMessageRole, QByteArray("errorMessage"));
    roles.insert(ErrorFileRole, QByteArray("errorFile"));
    return roles;
}

int FileOperationsModel::deleteFiles(QStringList files)
{
    return addTask(FileOpMode::Delete, files, {});
}

int FileOperationsModel::copyFiles(QStringList files, QStringList targetDirs)
{
    return addTask(FileOpMode::Copy, files, targetDirs);
}

int FileOperationsModel::moveFiles(QStringList files, QString targetDir)
{
    return addTask(FileOpMode::Move, files, {targetDir});
}

int FileOperationsModel::symlinkFiles(QStringList files, QStringList targetDirs)
{
    return addTask(FileOpMode::Symlink, files, targetDirs);
}

int FileOperationsModel::compressFiles(QStringList files, QString targetFile)
{
    return addTask(FileOpMode::Compress, files, {targetFile});
}

void FileOperationsModel::cancelTask(int handle)
{
    if (!m_handler->haveTask(handle)) return;
    m_handler->getTask(handle).get()->cancel();
}

void FileOperationsModel::pauseTask(int handle)
{
    if (!m_handler->haveTask(handle)) return;
    m_handler->getTask(handle).get()->pause();
}

void FileOperationsModel::continueTask(int handle, FileOpErrorAction::ErrorAction errorAction)
{
    if (!m_handler->haveTask(handle)) return;
    m_handler->getTask(handle).get()->carryOn(errorAction);
}

void FileOperationsModel::dismissTask(int handle)
{
    if (!m_handler->haveTask(handle)) return;
    if (m_handler->getTask(handle).status() != FileOpStatus::Finished &&
            m_handler->getTask(handle).status() != FileOpStatus::Cancelled) {
        return;
    }

    int index = m_handler->getTasks().indexOf(handle);

    beginRemoveRows(QModelIndex(), index, index);
    m_handler->forgetTask(handle);
    endRemoveRows();
    emit countChanged();
}

int FileOperationsModel::addTask(FileOpMode::Mode mode, QStringList files, QStringList targets)
{
    int lastRow = rowCount();
    beginInsertRows(QModelIndex(), lastRow, lastRow);

    auto& task = m_handler->makeTask(mode, files, targets, false);

    task.get()->connect(task.get(), &FileWorker2::statusChanged, this, [=](FileOpStatus::Status status){
        qDebug() << "File operation status changed:" << status << lastRow;
        QModelIndex topLeft = index(lastRow, 0);
        QModelIndex bottomRight = index(lastRow, 0);
        emit dataChanged(topLeft, bottomRight, {StatusRole});
    });
    connect(task.get(), &FileWorker2::progressChanged, this,
            [=](int current, int of, QString file, int fileCurrent, int fileOf) {
        auto& t = m_handler->getTask(task.handle());
        t.progressCurrent = current;
        t.progressOf = of;

        qDebug() << "File operation progress changed:" << file << current
                 << of << lastRow << t.handle() << fileCurrent << fileOf;
        QModelIndex topLeft = index(lastRow, 0);
        QModelIndex bottomRight = index(lastRow, 0);
        emit dataChanged(topLeft, bottomRight, {
            ProgressCurrentRole, ProgressOfRole,
            ProgressFilenameRole, ProgressFileCurrentRole, ProgressFileOfRole
        });
    });
    connect(task.get(), &FileWorker2::errorOccurred, this, [=](FileOpErrorType::ErrorType type, QString message, QString file){
        auto& t = m_handler->getTask(task.handle());
        t.errorType = type;
        t.errorMessage = message;
        t.errorFile = file;

        qDebug() << "Error occurred in file operation:" << type << message << file << lastRow << t.handle();
        QModelIndex topLeft = index(lastRow, 0);
        QModelIndex bottomRight = index(lastRow, 0);
        emit dataChanged(topLeft, bottomRight, {ErrorTypeRole, ErrorMessageRole, ErrorFileRole});
    });

    endInsertRows();
    emit countChanged();

    task.run();
    return task.handle();
}
