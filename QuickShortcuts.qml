import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Shortcuts are managed from Settings > Desktop Widgets; the widget itself only shows and launches them.
DesktopPluginComponent {
    id: root

    minWidth: 96
    minHeight: 96
    widgetWidth: 380
    widgetHeight: 140

    readonly property int iconSize: pluginData.iconSize ?? 52
    readonly property real backgroundOpacity: (pluginData.backgroundOpacity ?? 72) / 100
    readonly property bool showLabels: pluginData.showLabels ?? true
    readonly property var shortcuts: Array.isArray(pluginData.shortcuts) ? pluginData.shortcuts : []

    // Re-evaluates icon and launch lookups once the desktop entry database (re)loads.
    readonly property var desktopApps: DesktopEntries.applications.values

    readonly property real padding: Theme.spacingS
    readonly property real labelHeight: Math.ceil(Theme.fontSizeSmall * 1.5)
    readonly property real minCellWidth: showLabels ? Math.max(iconSize + Theme.spacingXL + Theme.spacingXS, Theme.fontSizeSmall * 7.5) : iconSize + Theme.spacingL + Theme.spacingXS
    readonly property real cellHeight: iconSize + Theme.spacingL + Theme.spacingXS + (showLabels ? labelHeight + Theme.spacingXS : 0)
    readonly property real availableWidth: width - padding * 2
    readonly property int columns: Math.max(1, Math.min(shortcuts.length, Math.floor(availableWidth / minCellWidth)))
    // Spare width goes to the cells (longer labels fit) up to a limit, then the grid stays centred.
    readonly property real cellWidth: Math.max(minCellWidth, Math.floor(Math.min(availableWidth / columns, minCellWidth * 1.4)))

    function desktopEntryFor(shortcut) {
        if (!shortcut || !shortcut.desktopId || desktopApps.length === 0)
            return null;
        return DesktopEntries.byId(shortcut.desktopId) || DesktopEntries.heuristicLookup(shortcut.desktopId);
    }

    function shortcutIcon(shortcut) {
        if (shortcut.iconOverride)
            return Paths.resolveIconUrl(shortcut.iconOverride);
        const entry = desktopEntryFor(shortcut);
        if (entry && entry.icon)
            return Paths.resolveIconUrl(String(entry.icon));
        return Paths.resolveIconUrl(shortcut.icon || "application-x-executable");
    }

    function launchShortcut(shortcut) {
        const entry = desktopEntryFor(shortcut);
        if (entry) {
            AppUsageHistoryData.addAppUsage({
                "id": entry.id,
                "name": entry.name || shortcut.name,
                "icon": entry.icon ? String(entry.icon) : "",
                "exec": entry.exec || "",
                "comment": entry.comment || ""
            });
            SessionService.launchDesktopEntry(entry);
            return;
        }
        // The .desktop file is gone (uninstalled or renamed); fall back to the command saved when it was added.
        if (Array.isArray(shortcut.command) && shortcut.command.length > 0) {
            Quickshell.execDetached({
                command: shortcut.command,
                workingDirectory: Quickshell.env("HOME")
            });
            return;
        }
        ToastService.showError(I18n.trFor("quickShortcuts", "Could not open %1").arg(shortcut.name), I18n.trFor("quickShortcuts", "Its desktop entry was not found."));
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, root.backgroundOpacity)
        border.width: root.backgroundOpacity > 0 ? 1 : 0
        border.color: Theme.withAlpha(Theme.outline, 0.18 * Math.min(1, root.backgroundOpacity * 2))
    }

    DankGridView {
        id: shortcutGrid
        visible: root.shortcuts.length > 0
        anchors.centerIn: parent
        width: root.columns * root.cellWidth
        height: Math.min(contentHeight, root.height - root.padding * 2)
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        interactive: contentHeight > height
        clip: true
        model: root.shortcuts

        delegate: Item {
            id: cell

            required property var modelData

            width: shortcutGrid.cellWidth
            height: shortcutGrid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.spacingXXS
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.primary, shortcutMouse.pressed ? 0.20 : 0.12)
                opacity: shortcutMouse.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                scale: shortcutMouse.pressed ? 0.92 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Image {
                    width: root.iconSize
                    height: root.iconSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: root.shortcutIcon(cell.modelData)
                    sourceSize.width: root.iconSize * 2
                    sourceSize.height: root.iconSize * 2
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    onStatusChanged: {
                        if (status === Image.Error)
                            source = "image://icon/application-x-executable";
                    }
                }

                StyledText {
                    visible: root.showLabels
                    width: shortcutGrid.cellWidth - Theme.spacingM
                    height: root.labelHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cell.modelData.name
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MouseArea {
                id: shortcutMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: root.launchShortcut(cell.modelData)
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.shortcuts.length === 0

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "apps"
                size: Theme.iconSize
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.trFor("quickShortcuts", "Click to add apps")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: PopoutService.openSettingsWithTab("desktop_widgets")
        }
    }
}
