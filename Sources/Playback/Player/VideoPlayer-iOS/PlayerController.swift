/*****************************************************************************
 * PlayerController.swift
 *
 * Copyright © 2020 VLC authors and VideoLAN
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

struct MediaProjection {
    struct FOV {
        static let `default`: CGFloat = 80
        static let max: CGFloat = 150
        static let min: CGFloat = 20
    }
}

protocol PlayerControllerDelegate: AnyObject {
    func playerControllerExternalScreenDidConnect(_ playerController: PlayerController)
    func playerControllerExternalScreenDidDisconnect(_ playerController: PlayerController)
    func playerControllerApplicationBecameActive(_ playerController: PlayerController)
}

@ObjCImplementation("VLCPlayerController", extensions: ["Extension"])
class PlayerController: NSObjectMethods {
    weak var delegate: PlayerControllerDelegate?

    // MARK: - States

    var isControlsHidden: Bool = false

    var isInterfaceLocked: Bool = false

    // MARK: - UserDefaults computed properties getters

    var isVolumeGestureEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingVolumeGesture)
    }

    var isPlayPauseGestureEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingPlayPauseGesture)
    }

    var isBrightnessGestureEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingBrightnessGesture)
    }

    var isSwipeSeekGestureEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingSeekGesture)
    }

    var isCloseGestureEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingCloseGesture)
    }

    var isSpeedUpGestureEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingPlaybackLongTouchSpeedUp)
    }

    var isShuffleEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCPlayerIsShuffleEnabled)
    }

    var isRepeatEnabled: VLCRepeatMode {
        let storedValue = UserDefaults.standard.integer(forKey: kVLCPlayerIsRepeatEnabled)

        return VLCRepeatMode(rawValue: storedValue) ?? .doNotRepeat
    }

    var isRememberStateEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCPlayerShouldRememberState)
    }

    var isRememberBrightnessEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCPlayerShouldRememberBrightness)
    }

    init() {
        objcInit("init")
        setupObservers()
    }

    private func setupObservers() {
        let notificationCenter = NotificationCenter.default

        // External Screen
        notificationCenter.addObserver(self,
                                       selector: ObjC.selector("handleExternalScreenDidConnect"),
                                       name: NSNotification.Name(rawValue: VLCNonInteractiveWindowSceneBecameActive),
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: ObjC.selector("handleExternalScreenDidDisconnect"),
                                       name: NSNotification.Name(rawValue: VLCNonInteractiveWindowSceneDisconnected),
                                       object: nil)
        // UIApplication
        notificationCenter.addObserver(self,
                                       selector: ObjC.selector("handleAppBecameActive"),
                                       name: UIApplication.didBecomeActiveNotification,
                                       object: nil)
    }
}

// MARK: - Observers

@ObjCExtension("Extension")
extension PlayerController {
    @ObjCMethod func handleExternalScreenDidConnect() {
        delegate?.playerControllerExternalScreenDidConnect(self)
    }

    @ObjCMethod func handleExternalScreenDidDisconnect() {
        delegate?.playerControllerExternalScreenDidDisconnect(self)
    }

    @ObjCMethod func handleAppBecameActive() {
        delegate?.playerControllerApplicationBecameActive(self)
    }
}
