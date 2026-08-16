// Windows-style ALT+TAB window list with App & WebApp Icons.
//
// This is the display half only. All key handling and all state live in
// altswitch.lua next to this file, loaded from the Hyprland config. It owns the
// frozen window list and the cursor, and drives this panel over IPC:
//
//   omarchy-shell altswitch show '{"windows":[...],"index":1}'
//   omarchy-shell altswitch select 2
//   omarchy-shell altswitch hide

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property var windows: []
  property int selectedIndex: 0

  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  readonly property int rowHeight: Style.space(46)
  readonly property int cardWidth: Math.min(Style.space(640), panel.width - Style.gapsOut * 2)
  readonly property int maxCardHeight: panel.height - Style.gapsOut * 2

  // Known brand names for clean display
  readonly property var brandMap: ({
    "chatgpt": "ChatGPT",
    "whatsapp": "WhatsApp",
    "youtube": "YouTube",
    "github": "GitHub",
    "figma": "Figma",
    "discord": "Discord",
    "slack": "Slack",
    "spotify": "Spotify",
    "notion": "Notion",
    "linear": "Linear",
    "reddit": "Reddit",
    "twitter": "X (Twitter)",
    "x": "X",
    "gmail": "Gmail",
    "sheets": "Google Sheets",
    "docs": "Google Docs",
    "leetcode": "LeetCode",
    "neetcode": "NeetCode",
    "outlook": "Outlook",
    "excalidraw": "Excalidraw",
    "claude": "Claude",
    "telegram": "Telegram"
  })

  function parseWebapp(appClass) {
    var raw = String(appClass || "").trim()
    var match = raw.match(/^(?:brave|chrome|chromium|google-chrome|edge|msedge|firefoxpwa|firefox-pwa)-(.+?)(?:__.*|-Default.*)?$/i)
    if (!match || !match[1]) return null

    var domain = match[1].replace(/_+/g, ".").replace(/\.$/, "")
    var parts = domain.split(".")
    var brand = parts[0]
    if (parts.length > 1) {
      var sub = parts[0].toLowerCase()
      if (["web", "app", "m", "beta", "mail", "music", "auth", "my", "account"].indexOf(sub) !== -1) {
        brand = parts[1]
      } else {
        brand = parts[0]
      }
    }
    return {
      domain: domain.toLowerCase(),
      brand: brand.toLowerCase(),
      browser: raw.split("-")[0].toLowerCase()
    }
  }

  function indexIconLine(path) {
    var value = String(path || "").trim()
    if (value.length === 0) return
    var slash = value.lastIndexOf("/")
    var file = slash >= 0 ? value.slice(slash + 1) : value
    var dot = file.lastIndexOf(".")
    var name = dot > 0 ? file.slice(0, dot) : file
    if (name.length > 0) {
      var lower = name.toLowerCase()
      if (root.pendingIconIndex[lower] === undefined) {
        root.pendingIconIndex[lower] = value
      }
      if (root.pendingIconIndex[name] === undefined) {
        root.pendingIconIndex[name] = value
      }
    }
  }

  Process {
    id: iconScan
    command: [
      "bash", "-c",
      'for ext in svg png; do ' +
      '  find "$HOME/.icons" "$HOME/.local/share/icons" "$HOME/.local/share/applications/icons" /usr/share/pixmaps /usr/share/icons -name "*.$ext" 2>/dev/null; ' +
      'done'
    ]
    stdout: SplitParser {
      onRead: function(line) { root.indexIconLine(line) }
    }
    onStarted: root.pendingIconIndex = ({})
    onExited: root.iconIndex = root.pendingIconIndex
  }

  function resolveIcon(appClass) {
    if (!appClass || appClass.length === 0) {
      return Quickshell.iconPath("application-x-executable", true) || ""
    }
    var raw = String(appClass).trim()
    var lower = raw.toLowerCase()

    // 1. Check for webapps (e.g. brave-chatgpt.com__-Default, brave-web.whatsapp.com__-Default)
    var webapp = root.parseWebapp(raw)
    if (webapp) {
      var candidates = [
        webapp.brand,
        webapp.domain,
        webapp.brand + "-desktop",
        "webapp-" + webapp.brand,
        root.brandMap[webapp.brand] || ""
      ]
      for (var i = 0; i < candidates.length; i++) {
        var c = candidates[i]
        if (!c) continue
        if (root.iconIndex[c.toLowerCase()]) return Util.fileUrl(root.iconIndex[c.toLowerCase()])
        if (root.iconIndex[c]) return Util.fileUrl(root.iconIndex[c])
        var wp = Quickshell.iconPath(c, true)
        if (wp && wp.length > 0) return wp
      }
      // Fallback to the browser icon if webapp icon not found
      if (root.iconIndex[webapp.browser]) return Util.fileUrl(root.iconIndex[webapp.browser])
      var bp = Quickshell.iconPath(webapp.browser, true)
      if (bp && bp.length > 0) return bp
    }

    // 2. Direct icon index match from disk scan
    if (root.iconIndex[lower]) return Util.fileUrl(root.iconIndex[lower])
    if (root.iconIndex[raw]) return Util.fileUrl(root.iconIndex[raw])

    // 3. Direct themed lookup via Quickshell
    var icon = Quickshell.iconPath(lower, true) || Quickshell.iconPath(raw, true)
    if (icon && icon.length > 0) return icon

    // 4. Known class alias mapping
    var aliases = {
      "code": "vscode",
      "code-oss": "vscode",
      "code - oss": "vscode",
      "google-chrome": "google-chrome",
      "chromium": "chromium",
      "firefox": "firefox",
      "firefox-esr": "firefox",
      "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
      "kitty": "kitty",
      "alacritty": "alacritty",
      "foot": "foot",
      "ghostty": "ghostty",
      "thunar": "system-file-manager",
      "nautilus": "org.gnome.Nautilus",
      "dolphin": "system-file-manager",
      "spotify": "spotify",
      "discord": "discord",
      "vesktop": "vesktop",
      "webcord": "discord",
      "telegramdesktop": "telegram",
      "org.telegram.desktop": "telegram",
      "steam": "steam",
      "obs": "com.obsproject.Studio"
    }
    if (aliases[lower]) {
      var aliasTarget = aliases[lower]
      if (root.iconIndex[aliasTarget]) return Util.fileUrl(root.iconIndex[aliasTarget])
      icon = Quickshell.iconPath(aliasTarget, true)
      if (icon && icon.length > 0) return icon
    }

    // 5. Reverse DNS / dot-separated IDs (e.g. io.github.xyz -> xyz, com.obsproject.Studio -> obs)
    var parts = lower.split(".")
    if (parts.length > 1) {
      var suffix = parts[parts.length - 1]
      if (root.iconIndex[suffix]) return Util.fileUrl(root.iconIndex[suffix])
      icon = Quickshell.iconPath(suffix, true)
      if (icon && icon.length > 0) return icon
    }

    // 6. Generic fallback
    return Quickshell.iconPath("application-x-executable", true) || Quickshell.iconPath("preferences-system-windows", true) || ""
  }

  function formatAppName(appClass) {
    if (!appClass) return "App"
    var raw = String(appClass).trim()

    var webapp = root.parseWebapp(raw)
    if (webapp) {
      if (root.brandMap[webapp.brand]) return root.brandMap[webapp.brand]
      return webapp.brand.charAt(0).toUpperCase() + webapp.brand.slice(1)
    }

    var parts = raw.split(".")
    var name = parts.length > 1 ? parts[parts.length - 1] : raw
    if (name.length > 0 && name === name.toLowerCase()) {
      return name.charAt(0).toUpperCase() + name.slice(1)
    }
    return name
  }

  function show(payloadJson) {
    watchdog.restart()

    if (Object.keys(root.iconIndex).length === 0 && !iconScan.running) {
      iconScan.running = true
    }

    let payload
    try {
      payload = JSON.parse(payloadJson)
    } catch (error) {
      console.warn("altswitch: unreadable payload:", error)
      root.hide()
      return
    }

    root.windows = payload.windows || []
    root.selectedIndex = payload.index || 0
    root.opened = root.windows.length > 0
  }

  function select(index) {
    root.selectedIndex = index
    watchdog.restart()
  }

  function hide() {
    watchdog.stop()
    root.opened = false
  }

  Timer {
    id: watchdog
    interval: 10000
    onTriggered: {
      root.hide()
      Quickshell.execDetached(["hyprctl", "eval", "__altswitch_cancel()"])
    }
  }

  IpcHandler {
    target: "altswitch"

    function show(payloadJson: string): string {
      root.show(payloadJson)
      return "ok"
    }

    function select(index: int): string {
      root.select(index)
      return "ok"
    }

    function hide(): string {
      root.hide()
      return "ok"
    }

    function state(): string {
      return root.opened ? "open" : "closed"
    }
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-altswitch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    BorderSurface {
      id: card

      width: root.cardWidth
      height: Math.min(
        root.maxCardHeight,
        root.windows.length * root.rowHeight + card.contentTopInset + card.contentBottomInset
      )
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        clip: true
        interactive: false
        model: root.windows
        currentIndex: root.selectedIndex
        highlightMoveDuration: 0
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: ListView.ApplyRange

        delegate: Rectangle {
          required property int index
          required property var modelData

          width: list.width
          height: root.rowHeight
          radius: Style.cornerRadius
          color: index === root.selectedIndex ? Color.menu.selectedBackground : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.rightMargin: Style.spacing.controlPaddingX
            spacing: Style.spacing.md

            // Application / WebApp Icon
            Image {
              Layout.preferredWidth: Style.space(26)
              Layout.preferredHeight: Style.space(26)
              Layout.alignment: Qt.AlignVCenter
              source: root.resolveIcon(modelData.appClass)
              sourceSize.width: Style.space(26) * Screen.devicePixelRatio
              sourceSize.height: Style.space(26) * Screen.devicePixelRatio
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
            }

            // Application / WebApp Name
            Text {
              Layout.preferredWidth: Style.space(110)
              Layout.maximumWidth: Style.space(110)
              Layout.alignment: Qt.AlignVCenter
              elide: Text.ElideRight
              text: root.formatAppName(modelData.appClass)
              color: index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text
              opacity: index === root.selectedIndex ? 1.0 : 0.85
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.weight: Font.DemiBold
            }

            // Window Title
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              elide: Text.ElideRight
              text: modelData.title || ""
              color: index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text
              opacity: index === root.selectedIndex ? 0.95 : 0.6
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }

            // Workspace Badge Pill
            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              implicitWidth: Math.max(Style.space(24), wsText.implicitWidth + Style.space(10))
              implicitHeight: Style.space(20)
              radius: Style.space(4)
              color: index === root.selectedIndex ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06)
              visible: (modelData.workspace || "").length > 0

              Text {
                id: wsText
                anchors.centerIn: parent
                text: modelData.workspace || ""
                color: index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text
                opacity: 0.8
                font.family: Style.font.menuFamily
                font.pixelSize: Math.max(10, Style.font.body - 2)
              }
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    iconScan.running = true
  }
}
