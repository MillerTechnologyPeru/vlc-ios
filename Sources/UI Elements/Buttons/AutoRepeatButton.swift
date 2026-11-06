/*****************************************************************************
 * AutoRepeatButton.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit

@ObjCImplementation
final class AutoRepeatButton: UIButtonMethods {
    init() { objcInit() }

    private var repeatTimer: Timer?
    private var trackingStartTime: CFTimeInterval = 0
    private var hasRepeated = false

    @ObjCMethod("beginTrackingWithTouch:withEvent:") func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let shouldTrack = (callSuper("beginTrackingWithTouch:withEvent:", touch, event) as Bool)
        trackingStartTime = CACurrentMediaTime()
        hasRepeated = false
        scheduleRepeat(after: 0.5)
        return shouldTrack
    }

    @ObjCMethod("endTrackingWithTouch:withEvent:") func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        callSuper("endTrackingWithTouch:withEvent:", touch, event)
        stopRepeating()
        if !hasRepeated && isTouchInside {
            sendActions(for: .valueChanged)
        }
    }

    @ObjCMethod("cancelTrackingWithEvent:") func cancelTracking(with event: UIEvent?) {
        callSuper("cancelTrackingWithEvent:", event)
        stopRepeating()
    }

    @ObjCMethod("didMoveToWindow") func didMoveToWindow() {
        callSuper("didMoveToWindow")
        if window == nil {
            stopRepeating()
        }
    }

    @ObjCMethod("accessibilityActivate") func accessibilityActivate() -> Bool {
        sendActions(for: .valueChanged)
        return true
    }

    private func scheduleRepeat(after interval: TimeInterval) {
        let timer = Timer(timeInterval: interval, target: self, selector: ObjC.selector("repeatTimerFired"), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    @ObjCMethod private func repeatTimerFired() {
        guard isTracking else {
            stopRepeating()
            return
        }

        hasRepeated = true
        sendActions(for: .valueChanged)

        let heldDuration = CACurrentMediaTime() - trackingStartTime
        let interval: TimeInterval
        if heldDuration > 4 {
            interval = 0.15 / 9
        } else if heldDuration > 2 {
            interval = 0.15 / 3
        } else {
            interval = 0.15
        }
        scheduleRepeat(after: interval)
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
