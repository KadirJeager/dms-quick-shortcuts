import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

PluginSettings {
    id: root
    pluginId: "quickShortcuts"

    // Set by the Desktop Widgets settings card for the widget instance being edited.
    property string instanceId: ""
    property var instanceData: null

    Column {
        id: shortcutManager

        property var items: []

        width: parent.width
        spacing: Theme.spacingS

        function loadValue() {
            const value = root.loadValue("shortcuts", []);
            items = Array.isArray(value) ? value : [];
        }

        function save(list) {
            items = list;
            root.saveValue("shortcuts", list);
        }

        function isAdded(app) {
            for (let i = 0; i < items.length; i++) {
                const item = items[i];
                if (app.id && item.desktopId === app.id)
                    return true;
                if (!item.desktopId && item.name === app.name)
                    return true;
            }
            return false;
        }

        function addApp(appId) {
            const apps = AppSearchService.getVisibleApplications() || [];
            const app = apps.find(a => (a.id || a.execString) === appId);
            if (!app || isAdded(app))
                return;
            const command = [];
            for (let i = 0; i < (app.command?.length ?? 0); i++)
                command.push(app.command[i]);
            save(items.concat([{
                    "name": app.name || app.id,
                    "desktopId": app.id || "",
                    "command": command,
                    "icon": app.icon ? String(app.icon) : "application-x-executable"
                }]));
        }

        function removeAt(index) {
            const list = items.slice();
            list.splice(index, 1);
            save(list);
        }

        function move(from, to) {
            if (from < 0 || to < 0 || from >= items.length || to >= items.length || from === to)
                return;
            const list = items.slice();
            const moved = list.splice(from, 1)[0];
            list.splice(to, 0, moved);
            save(list);
        }

        function openPicker() {
            appPicker.appsModel = (AppSearchService.getVisibleApplications() || []).filter(app => !isAdded(app));
            appPicker.show();
        }

        function iconFor(shortcut) {
            if (shortcut.iconOverride)
                return Paths.resolveIconUrl(shortcut.iconOverride);
            const entry = shortcut.desktopId ? DesktopEntries.byId(shortcut.desktopId) : null;
            if (entry && entry.icon)
                return Paths.resolveIconUrl(String(entry.icon));
            return Paths.resolveIconUrl(shortcut.icon || "application-x-executable");
        }

        Component.onCompleted: loadValue()

        AppBrowserPopup {
            id: appPicker
            parentModal: shortcutManager.QsWindow.window
            onAppSelected: appId => shortcutManager.addApp(appId)
        }

        StyledText {
            text: I18n.trFor("quickShortcuts", "Shortcuts")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: I18n.trFor("quickShortcuts", "Apps shown on the desktop. Use the arrows to change their order.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: shortcutManager.items

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                width: shortcutManager.width
                height: 48
                radius: Theme.cornerRadius
                color: Theme.floatingWindowFieldColor

                Image {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSize
                    height: Theme.iconSize
                    source: shortcutManager.iconFor(row.modelData)
                    sourceSize.width: Theme.iconSize * 2
                    sourceSize.height: Theme.iconSize * 2
                    fillMode: Image.PreserveAspectFit
                    onStatusChanged: {
                        if (status === Image.Error)
                            source = "image://icon/application-x-executable";
                    }
                }

                StyledText {
                    anchors.left: rowIcon.right
                    anchors.right: rowButtons.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Row {
                    id: rowButtons
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankActionButton {
                        iconName: "arrow_upward"
                        iconSize: Theme.iconSizeSmall
                        enabled: row.index > 0
                        opacity: enabled ? 1 : 0.35
                        tooltipText: I18n.trFor("quickShortcuts", "Move up")
                        onClicked: shortcutManager.move(row.index, row.index - 1)
                    }

                    DankActionButton {
                        iconName: "arrow_downward"
                        iconSize: Theme.iconSizeSmall
                        enabled: row.index < shortcutManager.items.length - 1
                        opacity: enabled ? 1 : 0.35
                        tooltipText: I18n.trFor("quickShortcuts", "Move down")
                        onClicked: shortcutManager.move(row.index, row.index + 1)
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSizeSmall
                        iconColor: Theme.error
                        tooltipText: I18n.trFor("quickShortcuts", "Remove")
                        onClicked: shortcutManager.removeAt(row.index)
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: shortcutManager.items.length === 0
            text: I18n.trFor("quickShortcuts", "No shortcuts yet")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            horizontalAlignment: Text.AlignHCenter
            topPadding: Theme.spacingS
            bottomPadding: Theme.spacingS
        }

        DankButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.trFor("quickShortcuts", "Add app")
            iconName: "add"
            onClicked: shortcutManager.openPicker()
        }
    }

    SliderSetting {
        settingKey: "iconSize"
        label: I18n.trFor("quickShortcuts", "Icon size")
        defaultValue: 52
        minimum: 36
        maximum: 80
        unit: " px"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.trFor("quickShortcuts", "Background opacity")
        description: I18n.trFor("quickShortcuts", "Set to 0 to show only the icons")
        defaultValue: 72
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "showLabels"
        label: I18n.trFor("quickShortcuts", "Show app names")
        defaultValue: true
    }
}
