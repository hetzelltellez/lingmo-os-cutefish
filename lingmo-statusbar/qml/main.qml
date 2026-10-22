/*
 * Copyright (C) 2024 LingmoOS Team.
 *
 * Author:     Reion Wong <aj@lingmo.org>
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

import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12

import Lingmo.System 1.0 as System
import Lingmo.StatusBar 1.0
import Lingmo.NetworkManagement 1.0 as NM
import LingmoUI 1.0 as LingmoUI

Item {
    id: rootItem

    property int iconSize: 16

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // 0: Auto (follows system theme), 1: Light (force white), 2: Dark (force dark gray), 3: Original (Cutefish adaptive)
    property int barStyle: (typeof StatusBar !== "undefined" && typeof StatusBar.barStyle !== "undefined") ? StatusBar.barStyle : 0

    property bool effectiveDarkMode: {
        if (barStyle === 1) return false;
        if (barStyle === 2) return true;
        if (barStyle === 3) return bgHelper.isDarkWallpaper;
        return LingmoUI.Theme.darkMode;
    }

    property bool darkMode: effectiveDarkMode
    property color textColor: effectiveDarkMode ? "#FFFFFF" : "#000000"
    property var fontSize: rootItem.height ? rootItem.height / 3 : 1

    property var timeFormat: StatusBar.twentyFourTime ? "HH:mm" : "h:mm ap"

    onTimeFormatChanged: {
        timeTimer.restart()
    }

    System.Wallpaper {
        id: sysWallpaper

        function reload() {
            if (sysWallpaper.type === 0)
                bgHelper.setBackgound(sysWallpaper.path)
            else
                bgHelper.setColor(sysWallpaper.color)
        }

        Component.onCompleted: sysWallpaper.reload()

        onTypeChanged: sysWallpaper.reload()
        onColorChanged: sysWallpaper.reload()
        onPathChanged: sysWallpaper.reload()
    }

    BackgroundHelper {
        id: bgHelper
        property bool isDarkWallpaper: false

        onNewColor: {
            bgHelper.isDarkWallpaper = darkMode
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: rootItem.darkMode ? Qt.rgba(0.12, 0.13, 0.15, 0.82)
                                         : Qt.rgba(1.0, 1.0, 1.0, 0.82)
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            GradientStop {
                position: 1.0
                color: rootItem.darkMode ? Qt.rgba(0.09, 0.10, 0.12, 0.78)
                                         : Qt.rgba(0.96, 0.97, 0.98, 0.78)
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        // Subtle bottom border
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: rootItem.darkMode ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : "#CBD5E1"
            opacity: rootItem.darkMode ? 1.0 : 0.7
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }
    LingmoUI.WindowHelper {
        id: windowHelper
    }

    LingmoUI.WindowBlur {
        view: StatusBar
        geometry: Qt.rect(rootItem.x, rootItem.y, rootItem.width, rootItem.height)
        windowRadius: 0
        enabled: true
    }

    LingmoUI.PopupTips {
        id: popupTips
    }

    LingmoUI.DesktopMenu {
        id: acticityMenu

        MenuItem {
            text: qsTr("Close")
            onTriggered: acticity.close()
        }
    }

    // Main layout
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        spacing: LingmoUI.Units.smallSpacing / 2

        // App name and icon
        StandardItem {
            id: acticityItem
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: Math.min(rootItem.width / 3,
                                            acticityLayout.implicitWidth + LingmoUI.Units.largeSpacing)
            // 当窗口标题为 lingmo-desktop 时不显示
            visible: acticity.title !== "lingmo-desktop"
            onClicked: {
                if (mouse.button === Qt.RightButton)
                    acticityMenu.open()
            }

            RowLayout {
                id: acticityLayout
                anchors.fill: parent
                anchors.leftMargin: LingmoUI.Units.smallSpacing
                anchors.rightMargin: LingmoUI.Units.smallSpacing
                spacing: LingmoUI.Units.smallSpacing

                Image {
                    id: acticityIcon
                    width: rootItem.iconSize
                    height: rootItem.iconSize
                    sourceSize: Qt.size(rootItem.iconSize, rootItem.iconSize)
                    source: acticity.icon ? "image://icontheme/" + acticity.icon : ""
                    visible: status === Image.Ready
                    antialiasing: true
                    smooth: false
                }

                Label {
                    id: acticityLabel
                    text: acticity.title
                    Layout.fillWidth: true
                    elide: Qt.ElideRight
                    color: rootItem.textColor
                    visible: text
                    Layout.alignment: Qt.AlignVCenter
                    font.pointSize: rootItem.fontSize
                }
            }
        }

        // App menu
        Item {
            id: appMenuItem
            Layout.fillHeight: true
            Layout.fillWidth: true

            ListView {
                id: appMenuView
                anchors.fill: parent
                orientation: Qt.Horizontal
                spacing: LingmoUI.Units.smallSpacing
                visible: appMenuModel.visible
                interactive: false
                clip: true

                model: appMenuModel

                // Initialize the current index
                onVisibleChanged: {
                    if (!visible)
                        appMenuView.currentIndex = -1
                }

                delegate: StandardItem {
                    id: _menuItem
                    width: _actionText.width + LingmoUI.Units.largeSpacing
                    height: ListView.view.height
                    checked: appMenuApplet.currentIndex === index

                    onClicked: {
                        appMenuApplet.trigger(_menuItem, index)

                        checked = Qt.binding(function() {
                            return appMenuApplet.currentIndex === index
                        })
                    }

                    Text {
                        id: _actionText
                        anchors.centerIn: parent
                        color: rootItem.textColor
                        font.pointSize: rootItem.fontSize
                        text: {
                            var text = activeMenu
                            text = text.replace(/([^&]*)&(.)([^&]*)/g, function (match, p1, p2, p3) {
                                return p1.concat(p2, p3)
                            })
                            return text
                        }
                    }

                    // QMenu opens on press, so we'll replicate that here
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: appMenuApplet.currentIndex !== -1
                        onPressed: parent.clicked(null)
                        onEntered: parent.clicked(null)
                    }
                }

                AppMenuModel {
                    id: appMenuModel
                    onRequestActivateIndex: appMenuApplet.requestActivateIndex(appMenuView.currentIndex)
                    Component.onCompleted: {
                        appMenuView.model = appMenuModel
                    }
                }

                AppMenuApplet {
                    id: appMenuApplet
                    model: appMenuModel
                }

                Component.onCompleted: {
                    appMenuApplet.buttonGrid = appMenuView

                    // Handle left and right shortcut keys.
                    appMenuApplet.requestActivateIndex.connect(function (index) {
                        var idx = Math.max(0, Math.min(appMenuView.count - 1, index))
                        var button = appMenuView.itemAtIndex(index)
                        if (button) {
                            button.clicked(null)
                        }
                    });

                    // Handle mouse movement.
                    appMenuApplet.mousePosChanged.connect(function (x, y) {
                        var item = itemAt(x, y)
                        if (item)
                            item.clicked(null)
                    });
                }
            }
        }
        StandardItem {
            id: lyricsItem
            visible: lyricsHelper.lyricsVisible
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: _lyricsLayout.implicitWidth + LingmoUI.Units.smallSpacing

            RowLayout {
                id: _lyricsLayout
                anchors.fill: parent

                Label {
                    id: lyricsLabel
                    Layout.alignment: Qt.AlignCenter
                    font.pointSize: rootItem.fontSize
                    color: rootItem.textColor
                    text: lyricsHelper.lyrics
                    }
                }
         }
        // System tray(Right)
        SystemTray {}

        StandardItem {
            id: permissionSurveillanceItem
            visible: permissionSurveillance.permissionSurveillanceVisible
            backcolor: "#ee7959"
            backColorEnabled: true
            checked: true
            popupText: permissionSurveillance.cameraUser + " " + qsTr("is using the camera")
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: volumeIcon.implicitWidth + LingmoUI.Units.smallSpacing + 4
            Image {
                id: permissionSurveillanceIcon
                anchors.centerIn: parent
                width: rootItem.iconSize
                height: width
                sourceSize: Qt.size(width, height)
                source: "qrc:/images/dark/camera.svg"
                asynchronous: true
                antialiasing: true
                smooth: false
            }
        }

        StandardItem {
            id: controler

            checked: controlCenter.item ? controlCenter.item.visible : false
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: _controlerLayout.implicitWidth + LingmoUI.Units.largeSpacing

            onClicked: {
                toggleDialog()
            }

            function toggleDialog() {
                if (controlCenter.item) {
                    if (controlCenter.item.visible)
                        controlCenter.item.close()
                    else {
                        controlCenter.item.position = Qt.point(0, 0)
                        controlCenter.item.position = mapToGlobal(0, 0)
                        controlCenter.item.open()
                    }
                }
            }

            RowLayout {
                id: _controlerLayout
                anchors.fill: parent
                anchors.leftMargin: LingmoUI.Units.smallSpacing
                anchors.rightMargin: LingmoUI.Units.smallSpacing

                spacing: LingmoUI.Units.largeSpacing

                Image {
                    id: volumeIcon
                    visible: true
                    source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + ((controlCenter.item && controlCenter.item.volumeIconName) ? controlCenter.item.volumeIconName : "audio-volume-high-symbolic") + ".svg"
                    width: rootItem.iconSize
                    height: width
                    sourceSize: Qt.size(width, height)
                    asynchronous: true
                    Layout.alignment: Qt.AlignCenter
                    antialiasing: true
                    smooth: false
                }

                Image {
                    id: wirelessIcon
                    width: rootItem.iconSize
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + (activeConnection.wirelessIcon ? activeConnection.wirelessIcon : "network-wireless-connected-100") + ".svg"
                    asynchronous: true
                    Layout.alignment: Qt.AlignCenter
                    visible: true
                    antialiasing: true
                    smooth: false
                }

                Image {
                    id: controlCenterIcon
                    width: rootItem.iconSize
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + "control.svg"
                    asynchronous: true
                    Layout.alignment: Qt.AlignCenter
                    visible: true
                    antialiasing: true
                    smooth: false
                }

                // Battery Item
                RowLayout {
                    visible: battery.available

                    Image {
                        id: batteryIcon
                        height: rootItem.iconSize
                        width: height + 6
                        sourceSize: Qt.size(width, height)
                        source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + battery.iconSource
                        Layout.alignment: Qt.AlignCenter
                        antialiasing: true
                        smooth: false
                    }

                    Label {
                        text: battery.chargePercent + "%"
                        font.pointSize: rootItem.fontSize
                        color: rootItem.textColor
                        visible: battery.showPercentage
                    }
                }
            }
        }

        StandardItem {
            id: shutdownItem

            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: shutdownIcon.implicitWidth + LingmoUI.Units.largeSpacing
            checked: shutdownDialog.item ? shutdownDialog.item.visible : false

            onClicked: {
                if (shutdownDialog.item) {
                    shutdownDialog.item.position = Qt.point(0, 0)
                    shutdownDialog.item.position = mapToGlobal(0, 0)
                    shutdownDialog.item.open()
                }
            }

            Image {
                id: shutdownIcon
                anchors.centerIn: parent
                width: rootItem.iconSize
                height: width
                sourceSize: Qt.size(width, height)
                source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + "system-shutdown-symbolic.svg"
                asynchronous: true
                antialiasing: true
                smooth: false
            }
        }
        // Pop-up notification center and calendar
        StandardItem {
            id: datetimeItem

            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: _dateTimeLayout.implicitWidth + LingmoUI.Units.smallSpacing

            onClicked: {
                process.startDetached("lingmo-notificationd", ["-s"])
            }

            RowLayout {
                id: _dateTimeLayout
                anchors.fill: parent

               Image {
                   width: rootItem.iconSize
                   height: width
                   sourceSize: Qt.size(width, height)
                   source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + "notification-symbolic.svg"
                   asynchronous: true
                   Layout.alignment: Qt.AlignCenter
                   antialiasing: true
                   smooth: false
               }

                Label {
                    id: timeLabel
                    Layout.alignment: Qt.AlignCenter
                    font.pointSize: rootItem.fontSize
                    color: rootItem.textColor

                    Timer {
                        id: timeTimer
                        interval: 1000
                        repeat: true
                        running: true
                        triggeredOnStart: true
                        onTriggered: {
                            timeLabel.text = new Date().toLocaleTimeString(Qt.locale(), StatusBar.twentyFourTime ? rootItem.timeFormat
                                                                                                                 : Locale.ShortFormat)
                        }
                    }
                }
            }
        }

    }

    LingmoUI.DesktopMenu {
        id: statusbarContextMenu

        MenuItem {
            text: qsTr("Bar Style: Auto (follow system theme)")
            checkable: true
            checked: rootItem.barStyle === 0
            onTriggered: StatusBar.setBarStyle(0)
        }

        MenuItem {
            text: qsTr("Bar Style: Light (White frosted)")
            checkable: true
            checked: rootItem.barStyle === 1
            onTriggered: StatusBar.setBarStyle(1)
        }

        MenuItem {
            text: qsTr("Bar Style: Dark (Dark gray frosted)")
            checkable: true
            checked: rootItem.barStyle === 2
            onTriggered: StatusBar.setBarStyle(2)
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("Restore original Cutefish appearance")
            onTriggered: StatusBar.restoreOriginal()
        }

        MenuItem {
            text: qsTr("Appearance Settings...")
            onTriggered: process.startDetached("lingmo-settings", ["appearance"])
        }
    }

    MouseArea {
        id: _sliding
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property int startY: -1
        property bool activated: false

        onActivatedChanged: {
            // TODO
            // if (activated)
            //     acticity.move()
        }

        onPressed: {
            if (mouse.button === Qt.RightButton) {
                statusbarContextMenu.open()
                return
            }
            startY = mouse.y
        }

        onReleased: {
            startY = -1
        }

        onDoubleClicked: {
            acticity.toggleMaximize()
        }

        onMouseYChanged: {
            if (startY === parseInt(mouse.y)) {
                activated = false
                return
            }

            // Up
            if (startY > parseInt(mouse.y)) {
                activated = false
                return
            }

            if (mouse.y > rootItem.height)
                activated = true
            else
                activated = false
        }
    }

    // Components
    Loader {
        id: controlCenter
        sourceComponent: ControlCenter {}
        asynchronous: true
    }

    Loader {
        id: shutdownDialog
        sourceComponent: ShutdownDialog {}
        asynchronous: true
    }

    NM.ActiveConnection {
        id: activeConnection
    }

    NM.EnabledConnections {
        id: enabledConnections
    }

    NM.Handler {
        id: nmHandler
    }
}
