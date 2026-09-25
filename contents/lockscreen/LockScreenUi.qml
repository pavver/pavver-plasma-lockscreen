import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

import "components"

Item {
    id: lockScreenUi
    anchors.fill: parent

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    FontLoader {
        id: cascadiaFont
        source: Qt.resolvedUrl("fonts/CascadiaCode.ttf")
    }

    // =========================================================================
    // Screensaver & Idle State Machine
    // =========================================================================
    // Starts in Screensaver mode upon screen lock
    property bool isScreensaverMode: true
    property bool animationsEnabled: false
    property bool ignoreWakeup: true

    Component.onCompleted: {
        Qt.callLater(function() {
            lockScreenUi.animationsEnabled = true;
        });
    }

    Timer {
        id: screensaverCooldownTimer
        interval: 2500
        repeat: false
        running: true
        onTriggered: {
            lockScreenUi.ignoreWakeup = false;
        }
    }

    function wakeUp() {
        if (ignoreWakeup) {
            return;
        }
        if (isScreensaverMode) {
            isScreensaverMode = false;
        }
        idleScreensaverTimer.restart();
        compactLockCard.focusPassword();
        if (typeof authenticator !== "undefined" && authenticator && typeof authenticator.startAuthenticating === "function") {
            authenticator.startAuthenticating();
        }
    }

    Timer {
        id: idleScreensaverTimer
        interval: 20000 // 20 seconds of idle returns to screensaver
        repeat: false
        running: !lockScreenUi.isScreensaverMode && !compactLockCard.isTyping
        onTriggered: {
            lockScreenUi.isScreensaverMode = true;
            lockScreenUi.ignoreWakeup = true;
            screensaverCooldownTimer.restart();
        }
    }

    // =========================================================================
    // Mathematical Layout Solver
    // =========================================================================
    readonly property bool showBanner: lockScreenUi.height >= 520 && lockScreenUi.width >= 750
    readonly property bool showClock: lockScreenUi.width >= 750

    // -------------------------------------------------------------------------
    // 1. Screensaver Mode Metrics:
    // Large prominent banner occupying 85% of screen width in the center
    // -------------------------------------------------------------------------
    readonly property real screensaverVisualW: Math.round(Math.min(lockScreenUi.width * 0.85, (lockScreenUi.height * 0.70) * (675.0 / 190.0)))
    readonly property real screensaverVisualH: Math.round(screensaverVisualW * (190.0 / 675.0))
    readonly property real screensaverScale: screensaverVisualW / 675.0
    readonly property real screensaverCenterX: Math.round(lockScreenUi.width / 2.0)
    readonly property real screensaverCenterY: Math.round(lockScreenUi.height / 2.0)

    // -------------------------------------------------------------------------
    // 2. Unlock Mode Metrics (Matching SDDM Theme Exactly):
    // -------------------------------------------------------------------------
    readonly property real unlockVisualTop: Math.round(Math.max(16, lockScreenUi.height * 0.048))
    readonly property real unlockVisualH: {
        if (!showBanner) return 0;
        var fromWidth = (lockScreenUi.width * 0.85) / (675.0 / 190.0);
        var maxRatioHeight = lockScreenUi.height * 0.45;
        var minCardSpace = (180 * horizontalCardScale) + 60;
        var topMargin = unlockVisualTop;
        var maxSpaceHeight = Math.max(100, lockScreenUi.height - topMargin - minCardSpace);
        return Math.round(Math.min(fromWidth, Math.min(maxRatioHeight, maxSpaceHeight)));
    }
    readonly property real unlockVisualW: Math.round(unlockVisualH * (675.0 / 190.0))
    readonly property real unlockScale: showBanner ? (unlockVisualW / 675.0) : screensaverScale
    readonly property real unlockVisualBottom: unlockVisualTop + unlockVisualH
    readonly property real unlockCenterX: Math.round(lockScreenUi.width / 2.0)
    readonly property real unlockCenterY: {
        if (!showBanner) {
            // Smoothly slides UP off the top on small screens
            return Math.round(- (screensaverVisualH / 2.0) - 40);
        }
        return Math.round(unlockVisualTop + (unlockVisualH / 2.0));
    }

    // Card scaling
    readonly property real horizontalCardScale: {
        if (!showClock) {
            return Math.min(1.0, Math.max(0.55, (lockScreenUi.width - 40) / 680.0));
        }
        return Math.min(1.0, Math.max(0.55, (lockScreenUi.width - 60) / 1176.0));
    }
    readonly property real verticalCardScale: {
        var availH = showBanner ? (lockScreenUi.height - unlockVisualBottom - 20) : (lockScreenUi.height - 40);
        return Math.min(1.0, Math.max(0.55, availH / 220.0));
    }
    readonly property real cardScale: Math.min(horizontalCardScale, verticalCardScale)

    // -------------------------------------------------------------------------
    // 3. Dynamic Target Routing
    // -------------------------------------------------------------------------
    readonly property real activeBannerCenterX: isScreensaverMode ? screensaverCenterX : unlockCenterX
    readonly property real activeBannerCenterY: isScreensaverMode ? screensaverCenterY : unlockCenterY
    readonly property real activeBannerScale: isScreensaverMode ? screensaverScale : unlockScale
    readonly property real activeBannerOpacity: {
        if (isScreensaverMode) return 1.0;
        if (!showBanner) return 0.0;
        return 1.0;
    }

    // Dynamic card Y positioning in unlock mode
    readonly property real unlockCardTargetY: {
        if (!showBanner) {
            return Math.round((lockScreenUi.height - (compactLockCard.height * cardScale)) / 2.0);
        }
        var availSpace = lockScreenUi.height - unlockVisualBottom;
        var cardH = compactLockCard.height * cardScale;
        return Math.round(unlockVisualBottom + Math.max(16, (availSpace - cardH) / 2.0));
    }

    // Active bottom row coordinates (slides smoothly down beyond bottom in screensaver mode)
    readonly property real activeBottomRowY: isScreensaverMode ? (lockScreenUi.height + 70) : unlockCardTargetY
    readonly property real activeBottomRowOpacity: isScreensaverMode ? 0.0 : 1.0

    // =========================================================================
    // Animated Background and Banner
    // =========================================================================
    PavverAnimatedBackground {
        id: wallpaper
        anchors.fill: parent
        bannerTargetCenterX: lockScreenUi.activeBannerCenterX
        bannerTargetCenterY: lockScreenUi.activeBannerCenterY
        bannerTargetScale: lockScreenUi.activeBannerScale
        bannerTargetOpacity: lockScreenUi.activeBannerOpacity
        enableAnimations: lockScreenUi.animationsEnabled
    }

    // =========================================================================
    // Interaction Root & Event Dispatcher
    // =========================================================================
    MouseArea {
        id: interactionRoot
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: lockScreenUi.isScreensaverMode ? Qt.BlankCursor : Qt.ArrowCursor

        onPressed: function(mouse) {
            if (!lockScreenUi.ignoreWakeup) lockScreenUi.wakeUp();
        }
        onPositionChanged: function(mouse) {
            if (!lockScreenUi.ignoreWakeup) lockScreenUi.wakeUp();
        }

        Keys.onPressed: function(event) {
            if (!lockScreenUi.ignoreWakeup) {
                lockScreenUi.wakeUp();
                event.accepted = false;
            }
        }

        // =====================================================================
        // Bottom Row: Clock + CompactLockCard (Unified Centered Row)
        // =====================================================================
        Row {
            id: bottomRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: lockScreenUi.activeBottomRowY
            opacity: lockScreenUi.activeBottomRowOpacity
            visible: opacity > 0.0
            spacing: Math.round(36 * lockScreenUi.cardScale)
            layer.enabled: opacity < 1.0

            Behavior on y {
                enabled: lockScreenUi.animationsEnabled
                NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: lockScreenUi.animationsEnabled
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            // Clock & Date (Left)
            Clock {
                id: clock
                visible: lockScreenUi.showClock
                anchors.verticalCenter: parent.verticalCenter
                scaleFactor: lockScreenUi.cardScale
            }

            // Lock Card (Right, or centered if clock hidden)
            Item {
                id: cardWrapper
                width: compactLockCard.width * lockScreenUi.cardScale
                height: compactLockCard.height * lockScreenUi.cardScale
                anchors.verticalCenter: parent.verticalCenter

                CompactLockCard {
                    id: compactLockCard
                    anchors.top: parent.top
                    anchors.left: parent.left
                    transformOrigin: Item.TopLeft
                    scale: lockScreenUi.cardScale

                    sessionManagement: sessionManagement
                    authenticator: typeof authenticator !== "undefined" ? authenticator : null

                    onUnlockRequested: function(password) {
                        if (typeof authenticator !== "undefined" && authenticator && typeof authenticator.respond === "function") {
                            authenticator.respond(password);
                        } else {
                            // Fallback simulation mode
                            if (password === "error") {
                                compactLockCard.onUnlockFailed();
                            } else {
                                compactLockCard.onUnlockSucceeded();
                                unlockTimer.start();
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // System Session Management & Plasma Authenticator
    // =========================================================================
    SessionManagement {
        id: sessionManagement
    }

    Timer {
        id: unlockTimer
        interval: 500
        repeat: false
        onTriggered: {
            Qt.quit(); // Closes kscreenlocker and unlocks KDE Plasma
        }
    }

    Connections {
        target: typeof authenticator !== "undefined" ? authenticator : null
        ignoreUnknownSignals: true

        function onFailed(kind) {
            compactLockCard.onUnlockFailed();
        }

        function onSucceeded() {
            compactLockCard.onUnlockSucceeded();
            unlockTimer.start();
        }

        function onPromptForSecretChanged() {
            compactLockCard.focusPassword();
        }
    }
}
