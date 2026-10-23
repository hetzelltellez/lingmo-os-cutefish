/*
 * Copyright (C) 2021 LingmoOS Team.
 *
 * Author:     rekols <revenmartin@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "processprovider.h"
#include <QDBusInterface>
#include <QDBusPendingCall>
#include <QDBusPendingReply>
#include <QProcess>

ProcessProvider::ProcessProvider(QObject *parent)
    : QObject(parent)
{

}

bool ProcessProvider::startDetached(const QString &exec, QStringList args)
{
    // 1. Intentar via DBus com.lingmo.Session
    QDBusInterface ifaceLingmo("com.lingmo.Session",
                               "/Session",
                               "com.lingmo.Session", QDBusConnection::sessionBus());

    if (ifaceLingmo.isValid()) {
        QDBusPendingReply<> reply = ifaceLingmo.asyncCall("launch", exec, args);
        reply.waitForFinished();
        if (!reply.isError()) {
            return true;
        }
    }

    // 2. Intentar via DBus com.cutefish.Session
    QDBusInterface ifaceCute("com.cutefish.Session",
                             "/Session",
                             "com.cutefish.Session", QDBusConnection::sessionBus());

    if (ifaceCute.isValid()) {
        QDBusPendingReply<> reply = ifaceCute.asyncCall("launch", exec, args);
        reply.waitForFinished();
        if (!reply.isError()) {
            return true;
        }
    }

    // 3. Fallback infalible directo via QProcess
    if (!args.isEmpty()) {
        return QProcess::startDetached(exec, args);
    }
    return QProcess::startDetached(exec);
}
