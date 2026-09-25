import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

Item {
    id: root
    width: 680
    height: 180

    // User properties
    property string userName: typeof kscreenlocker_userName !== "undefined" ? kscreenlocker_userName : "pavver"
    property string userRealName: userName
    property string userImage: typeof kscreenlocker_userImage !== "undefined" ? kscreenlocker_userImage : ""

    readonly property string effectiveUserImage: {
        var path = "";
        if (root.userImage && root.userImage.length > 0) {
            path = root.userImage;
        } else if (root.userName && root.userName.length > 0) {
            path = "/var/lib/AccountsService/icons/" + root.userName;
        }
        if (path.length > 0 && path.indexOf("://") === -1) {
            return "file://" + path.split("/").map(encodeURIComponent).join("/");
        }
        return path;
    }

    // Context objects
    property var sessionManagement: null
    property var authenticator: null

    // Signals
    signal unlockRequested(string password)

    // Helper functions
    function focusPassword() {
        passwordInput.forceActiveFocus();
    }

    readonly property bool isTyping: passwordInput.text.length > 0

    // Caps Lock state detection
    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    property bool mockCapsLock: false
    readonly property bool isCapsLockOn: mockCapsLock || (typeof capsLockState !== "undefined" && capsLockState && capsLockState.locked)

    FontLoader {
        id: cascadiaFont
        source: Qt.resolvedUrl("../fonts/CascadiaCode.ttf")
    }

    readonly property string mainFontFamily: cascadiaFont.status === FontLoader.Ready ? cascadiaFont.name : "Cascadia Code"

    // Keyboard layouts handling
    readonly property var availableLayouts: {
        if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
            return keyboard.layouts;
        }
        return [
            { shortName: "us", longName: "English (US)" },
            { shortName: "ua", longName: "Українська" }
        ];
    }

    property int mockLayoutIndex: 0
    readonly property int activeLayoutIndex: {
        if (typeof keyboard !== "undefined" && keyboard && typeof keyboard.currentLayout === "number") {
            return keyboard.currentLayout;
        }
        return mockLayoutIndex;
    }

    readonly property string currentLayoutShortName: {
        if (availableLayouts.length > activeLayoutIndex && activeLayoutIndex >= 0) {
            var l = availableLayouts[activeLayoutIndex];
            if (l && l.shortName) return l.shortName.toUpperCase();
        }
        return "US";
    }

    readonly property string currentLayoutFullName: {
        if (availableLayouts.length > activeLayoutIndex && activeLayoutIndex >= 0) {
            var l = availableLayouts[activeLayoutIndex];
            if (l && l.longName) return "Розкладка: " + l.longName;
        }
        return "Розкладка клавіатури";
    }

    function nextKeyboardLayout() {
        if (availableLayouts.length <= 1) return;
        var nextIdx = (activeLayoutIndex + 1) % availableLayouts.length;
        if (typeof keyboard !== "undefined" && keyboard && typeof keyboard.currentLayout === "number") {
            keyboard.currentLayout = nextIdx;
        }
        mockLayoutIndex = nextIdx;
    }

    // Feedback States (SDDM Design System)
    property string inputFeedbackState: "idle" // "idle", "success", "error"
    property real pulseAlpha: 1.0
    property real pulseBorderWidth: 1.5

    // Success animation: pulse vibrant green border for 500ms
    SequentialAnimation {
        id: successPulseAnim
        running: false
        ScriptAction {
            script: {
                root.inputFeedbackState = "success";
                root.pulseBorderWidth = 3.0;
                root.pulseAlpha = 1.0;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.55; duration: 250; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 2.2; duration: 250; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 0.55; to: 1.0; duration: 250; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 2.2; to: 3.0; duration: 250; easing.type: Easing.InOutQuad }
        }
    }

    // Error animation: clear text immediately, pulse red border twice without shaking, then smooth exit fade
    SequentialAnimation {
        id: errorPulseAnim
        running: false
        ScriptAction {
            script: {
                passwordInput.text = "";
                root.inputFeedbackState = "error";
                root.pulseBorderWidth = 3.0;
                root.pulseAlpha = 1.0;
                passwordInput.forceActiveFocus();
            }
        }
        // Pulse 1
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.55; duration: 200; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 2.2; duration: 200; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 0.55; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 2.2; to: 3.0; duration: 200; easing.type: Easing.InOutQuad }
        }
        // Pulse 2
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.55; duration: 200; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 2.2; duration: 200; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 0.55; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 2.2; to: 3.0; duration: 200; easing.type: Easing.InOutQuad }
        }
        // Smooth exit fade to idle (400 ms)
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.0; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 1.5; duration: 400; easing.type: Easing.InOutQuad }
        }
        ScriptAction {
            script: {
                root.inputFeedbackState = "idle";
                root.pulseAlpha = 1.0;
                root.pulseBorderWidth = 1.5;
            }
        }
    }

    function onUnlockFailed() {
        errorPulseAnim.restart();
    }

    function onUnlockSucceeded() {
        successPulseAnim.restart();
    }

    // Base dark grey rectangle (#222222, matching SDDM login card)
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 20
        color: "#222222"
        visible: false
    }

    // Hardware-accelerated smooth inner shadow (matching banner inner glow effect)
    InnerShadow {
        id: bgInnerShadow
        anchors.fill: bgRect
        source: bgRect
        radius: 16.0
        samples: 32
        horizontalOffset: 0
        verticalOffset: 0
        color: "#dd000000"
        spread: 0.2
    }

    // Crisp outer border (#3a3a3a, matching SDDM login card)
    Rectangle {
        id: bgBorder
        anchors.fill: parent
        radius: 20
        color: "transparent"
        border.color: "#3a3a3a"
        border.width: 1.5
    }

    // Left: Round Avatar (~124x124 px matching SDDM theme)
    Item {
        id: avatarContainer
        width: 124
        height: 124
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter

        Image {
            id: avatarImg
            anchors.fill: parent
            source: root.effectiveUserImage
            sourceSize: Qt.size(248, 248)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            visible: false
            asynchronous: true
        }

        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: width / 2
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: avatarImg
            maskSource: avatarMask
            visible: avatarImg.status === Image.Ready
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 60
            height: 60
            source: "user-identity"
            visible: avatarImg.status !== Image.Ready
        }

        // Cyan Neon Border Ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: "#00d2ff"
            border.width: 3
        }
    }

    // Right Content Area (124px height, matching avatar)
    Item {
        id: rightContent
        anchors.left: avatarContainer.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        height: 124

        // Top Row: Username and Power buttons
        Item {
            id: topRow
            width: parent.width
            height: 48
            anchors.top: parent.top

            // User name
            Item {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: userNameText.implicitWidth
                height: userNameText.implicitHeight

                Text {
                    id: userNameText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.userRealName && root.userRealName.length > 0 ? root.userRealName : root.userName
                    color: "#ffffff"
                    font.family: root.mainFontFamily
                    font.pixelSize: 22
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Action Buttons (Keyboard Layout Switcher + Power buttons, matching SDDM exactly)
            Row {
                id: actionButtonsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Keyboard Layout Switcher Button
                Rectangle {
                    id: kbBtn
                    width: 48
                    height: 48
                    radius: 24
                    color: kbMouse.containsMouse ? "#152535" : "#282828"
                    border.color: kbMouse.containsMouse ? "#00d2ff" : "#3c3c3c"
                    border.width: 1.5
                    visible: {
                        if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts) {
                            if (keyboard.layouts.length > 1) return true;
                            if (keyboard.layouts.length === 1) return false;
                        }
                        return true;
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.currentLayoutShortName
                        color: kbMouse.containsMouse ? "#00d2ff" : "#d0d0dc"
                        font.family: root.mainFontFamily
                        font.pixelSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: kbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextKeyboardLayout()
                    }

                    ToolTip.visible: kbMouse.containsMouse
                    ToolTip.text: root.currentLayoutFullName
                    ToolTip.delay: 350
                }

                // Suspend
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: suspendMouse.containsMouse ? "#152535" : "#282828"
                    border.color: suspendMouse.containsMouse ? "#00d2ff" : "#3c3c3c"
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: suspendMouse.containsMouse ? Qt.resolvedUrl("../assets/suspend_hover.svg") : Qt.resolvedUrl("../assets/suspend_normal.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: suspendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.sessionManagement && root.sessionManagement.canSuspend) {
                                root.sessionManagement.suspend();
                            }
                        }
                    }

                    ToolTip.visible: suspendMouse.containsMouse
                    ToolTip.text: "Сон"
                    ToolTip.delay: 350
                }

                // Reboot
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: rebootMouse.containsMouse ? "#251835" : "#282828"
                    border.color: rebootMouse.containsMouse ? "#c77dff" : "#3c3c3c"
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: rebootMouse.containsMouse ? Qt.resolvedUrl("../assets/reboot_hover.svg") : Qt.resolvedUrl("../assets/reboot_normal.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.sessionManagement && root.sessionManagement.canReboot) {
                                root.sessionManagement.reboot();
                            }
                        }
                    }

                    ToolTip.visible: rebootMouse.containsMouse
                    ToolTip.text: "Перезавантаження"
                    ToolTip.delay: 350
                }

                // Shutdown
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: powerMouse.containsMouse ? "#381520" : "#282828"
                    border.color: powerMouse.containsMouse ? "#ff4d6d" : "#3c3c3c"
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: powerMouse.containsMouse ? Qt.resolvedUrl("../assets/shutdown_hover.svg") : Qt.resolvedUrl("../assets/shutdown_normal.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.sessionManagement && root.sessionManagement.canPowerOff) {
                                root.sessionManagement.powerOff();
                            }
                        }
                    }

                    ToolTip.visible: powerMouse.containsMouse
                    ToolTip.text: "Вимкнення"
                    ToolTip.delay: 350
                }
            }
        }

        // Password Input Container (matching SDDM passInputBox)
        Rectangle {
            id: passwordBox
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56
            radius: 12
            color: {
                if (root.inputFeedbackState === "success") {
                    return Qt.rgba(0.0, 0.90, 0.46, 0.08 * root.pulseAlpha);
                } else if (root.inputFeedbackState === "error") {
                    return Qt.rgba(1.0, 0.20, 0.40, 0.08 * root.pulseAlpha);
                }
                return "#161616";
            }
            border.color: {
                if (root.inputFeedbackState === "success") {
                    return Qt.rgba(0.0, 0.90, 0.46, root.pulseAlpha);
                } else if (root.inputFeedbackState === "error") {
                    return Qt.rgba(1.0, 0.20, 0.40, root.pulseAlpha);
                }
                return passwordInput.activeFocus ? "#00d2ff" : "#2e2e2e";
            }
            border.width: {
                if (root.inputFeedbackState === "success" || root.inputFeedbackState === "error") {
                    return root.pulseBorderWidth;
                }
                return passwordInput.activeFocus ? 2 : 1.5;
            }

            Behavior on color { ColorAnimation { duration: 150 } }

            // Caps Lock Warning Badge (Inside input box on the left, matching SDDM)
            Rectangle {
                id: capsLockBadge
                width: root.isCapsLockOn ? (capsBadgeRow.width + 16) : 0
                height: 32
                radius: 8
                anchors.left: parent.left
                anchors.leftMargin: root.isCapsLockOn ? 10 : 0
                anchors.verticalCenter: parent.verticalCenter
                color: capsMouse.containsMouse ? "#3d2700" : "#2a1c00"
                border.color: capsMouse.containsMouse ? "#ffc300" : "#ffb703"
                border.width: 1.5
                visible: width > 0
                opacity: root.isCapsLockOn ? 1.0 : 0.0
                clip: true

                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: capsBadgeRow
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("../assets/capslock_warning.svg")
                        sourceSize: Qt.size(72, 72)
                        smooth: true
                        mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "CAPS"
                        color: "#ffb703"
                        font.family: root.mainFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: capsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                ToolTip.visible: capsMouse.containsMouse
                ToolTip.text: "Caps Lock увімкнено! Пароль чутливий до регістру"
                ToolTip.delay: 150
            }

            TextInput {
                id: passwordInput
                anchors.left: capsLockBadge.right
                anchors.leftMargin: root.isCapsLockOn ? 10 : 16
                anchors.right: eyeBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                font.family: root.mainFontFamily
                font.pixelSize: 18
                echoMode: TextInput.Password
                clip: true
                focus: true

                Behavior on anchors.leftMargin { NumberAnimation { duration: 150 } }

                Text {
                    anchors.fill: parent
                    text: "Введіть пароль..."
                    color: "#555566"
                    font.family: root.mainFontFamily
                    font.pixelSize: 17
                    visible: passwordInput.text.length === 0 && !passwordInput.inputMethodComposing
                    verticalAlignment: Text.AlignVCenter
                }

                onAccepted: {
                    if (passwordInput.text.length > 0) {
                        root.unlockRequested(passwordInput.text);
                    }
                }
            }

            // Show / Hide Password Eye Toggle Button
            Rectangle {
                id: eyeBtn
                width: 38
                height: 38
                radius: 8
                anchors.right: submitBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: eyeMouse.containsMouse ? "#22222c" : "transparent"
                opacity: passwordInput.text.length > 0 ? 1.0 : 0.45
                enabled: passwordInput.text.length > 0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                readonly property bool isRevealed: passwordInput.echoMode === TextInput.Normal

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: {
                        if (eyeBtn.isRevealed) {
                            return eyeMouse.containsMouse ? Qt.resolvedUrl("../assets/eye_hide_hover.svg") : Qt.resolvedUrl("../assets/eye_hide_normal.svg")
                        } else {
                            return eyeMouse.containsMouse ? Qt.resolvedUrl("../assets/eye_show_hover.svg") : Qt.resolvedUrl("../assets/eye_show_normal.svg")
                        }
                    }
                    sourceSize: Qt.size(88, 88)
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        passwordInput.echoMode = (passwordInput.echoMode === TextInput.Password) ? TextInput.Normal : TextInput.Password;
                        passwordInput.forceActiveFocus();
                    }
                }

                ToolTip.visible: eyeMouse.containsMouse && parent.enabled
                ToolTip.text: eyeBtn.isRevealed ? "Сховати пароль" : "Показати пароль"
                ToolTip.delay: 350
            }

            // Submit Button with Mathematically Centered Vector Arrow
            Rectangle {
                id: submitBtn
                width: 42
                height: 42
                radius: 8
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (root.inputFeedbackState === "success") {
                        return "#00e676";
                    }
                    return passwordInput.text.length > 0 ? (submitMouse.containsMouse ? "#00e5ff" : "#00b4d8") : "#222222";
                }

                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: passwordInput.text.length > 0 ? Qt.resolvedUrl("../assets/arrow_submit_active.svg") : Qt.resolvedUrl("../assets/arrow_submit_inactive.svg")
                    sourceSize: Qt.size(88, 88)
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: passwordInput.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (passwordInput.text.length > 0) {
                            root.unlockRequested(passwordInput.text);
                        }
                    }
                }
            }
        }
    }
}
