/*****************************************************************************
 * PlayerViewController.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation
import ObjCInterop
import UIKit

// The video player: VLCMediaPlayer drawing into a UIView, with play/pause,
// 10 second jumps, a seek slider and the aspect ratios of VLC's video
// player (AspectRatio, shared with the iOS app). UIKit is driven from Swift
// through the generated UIKit module, and this class is the view
// controller's Objective-C class, so UIKit calls its overrides and the
// controls' actions. Frames and autoresizing masks lay it out: iOS 6 has no
// layout anchors.

private enum Autoresizing {
    static let flexibleLeftMargin = 1
    static let flexibleWidth = 2
    static let flexibleRightMargin = 4
    static let flexibleTopMargin = 8
    static let flexibleHeight = 16
    static let flexibleBottomMargin = 32
}

private enum ControlEvent {
    static let touchUpInside = 1 << 6
    static let valueChanged = 1 << 12
}

private let controlStateNormal = 0
private let buttonTypeCustom = 0
private let barHeight: Float = 44

@ObjCImplementation("VLCiOS6PlayerViewController", superclass: "UIViewController")
final class PlayerViewController {
    let player = VLCMediaPlayer()
    private let path: String
    private let name: String
    private var aspectRatio = AspectRatio.Default
    private var seeking = false
    /// Whether playback started: VLCKit reports Stopped when a file ends
    private var started = false
    private var timer: NSTimer?

    private var videoView: UIView?
    private var playButton: UIButton?
    private var aspectButton: UIButton?
    private var slider: UISlider?
    private var timeLabel: UILabel?
    private var remainingLabel: UILabel?

    private init(path: String, name: String) {
        self.path = path
        self.name = name
    }

    /// A player for the file at path, as the view controller to present. The
    /// object owns the Swift instance, so keep it while it's on screen.
    static func make(path: String, name: String) -> ObjCValue {
        let object = objcClass.alloc().send("init")
        PlayerViewController(path: path, name: name).attach(to: object)
        return object
    }

    var viewController: UIViewController { UIViewController(object) }

    // MARK: UIViewController

    /// Full screen, under the hidden status bar, as VLC's video player is
    @ObjCMethod func viewWillAppear(_ animated: Bool) {
        callSuper("viewWillAppear:", animated)
        UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: 1 /* fade */)
    }

    @ObjCMethod func viewWillDisappear(_ animated: Bool) {
        callSuper("viewWillDisappear:", animated)
        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: 1)
    }

    @ObjCMethod func viewDidLoad() {
        callSuper("viewDidLoad")
        viewController.wantsFullScreenLayout = true
        DebugLog.log("player viewDidLoad")
        let view = viewController.view!
        view.backgroundColor = UIColor.blackColor()
        let bounds = view.bounds
        let width = bounds.size.width, height = bounds.size.height

        let video = UIView(frame: bounds)
        video.autoresizingMask = Autoresizing.flexibleWidth | Autoresizing.flexibleHeight
        video.backgroundColor = UIColor.blackColor()
        view.addSubview(video)
        videoView = video

        // Top bar: Done and the file's name
        let top = bar(frame: CGRect(x: 0, y: 0, width: width, height: barHeight),
                      resizing: Autoresizing.flexibleWidth | Autoresizing.flexibleBottomMargin)
        view.addSubview(top)
        let done = button(NSLocalizedString("BUTTON_DONE", comment: ""), action: "done:",
                          frame: CGRect(x: 4, y: 0, width: 70, height: barHeight))
        top.addSubview(done)
        let title = label(frame: CGRect(x: 80, y: 0, width: width - 176, height: barHeight), alignment: 1)
        title.autoresizingMask = Autoresizing.flexibleWidth
        title.text = name
        top.addSubview(title)

        // Bottom bar: times and seek slider, then the controls
        let bottomHeight = barHeight * 2
        let bottom = bar(frame: CGRect(x: 0, y: height - bottomHeight, width: width, height: bottomHeight),
                         resizing: Autoresizing.flexibleWidth | Autoresizing.flexibleTopMargin)
        view.addSubview(bottom)

        let time = label(frame: CGRect(x: 4, y: 0, width: 56, height: barHeight), alignment: 1)
        time.text = "--:--"
        bottom.addSubview(time)
        timeLabel = time

        let remaining = label(frame: CGRect(x: width - 60, y: 0, width: 56, height: barHeight), alignment: 1)
        remaining.autoresizingMask = Autoresizing.flexibleLeftMargin
        remaining.text = "--:--"
        bottom.addSubview(remaining)
        remainingLabel = remaining

        let seek = UISlider(frame: CGRect(x: 64, y: 0, width: width - 128, height: barHeight))
        seek.autoresizingMask = Autoresizing.flexibleWidth
        seek.minimumValue = 0
        seek.maximumValue = 1
        seek.continuous = false
        seek.addTarget(object, action: ObjC.selector("seek:"), forControlEvents: ControlEvent.valueChanged)
        seek.addTarget(object, action: ObjC.selector("seekStarted:"), forControlEvents: 1 /* touchDown */)
        bottom.addSubview(seek)
        slider = seek

        let controlsY = barHeight
        let center = width / 2
        let back = button("-10s", action: "jumpBackward:",
                          frame: CGRect(x: center - 120, y: controlsY, width: 70, height: barHeight))
        back.autoresizingMask = Autoresizing.flexibleLeftMargin | Autoresizing.flexibleRightMargin
        bottom.addSubview(back)

        let play = button("\u{275A}\u{275A}", action: "togglePlay:",
                          frame: CGRect(x: center - 35, y: controlsY, width: 70, height: barHeight))
        play.autoresizingMask = Autoresizing.flexibleLeftMargin | Autoresizing.flexibleRightMargin
        bottom.addSubview(play)
        playButton = play

        let forward = button("+10s", action: "jumpForward:",
                             frame: CGRect(x: center + 50, y: controlsY, width: 70, height: barHeight))
        forward.autoresizingMask = Autoresizing.flexibleLeftMargin | Autoresizing.flexibleRightMargin
        bottom.addSubview(forward)

        // Top bar's right side: the aspect ratio, as in VLC's video player
        let aspect = button(aspectRatio.stringToDisplay, action: "nextAspectRatio:",
                            frame: CGRect(x: width - 92, y: 0, width: 88, height: barHeight))
        aspect.autoresizingMask = Autoresizing.flexibleLeftMargin
        aspect.titleLabel?.font = UIFont.systemFontOfSize(13)
        top.addSubview(aspect)
        aspectButton = aspect

        player.drawable = video.object
        player.media = VLCMedia.mediaWithPath(path)
        player.play()
        DebugLog.log("playing \(path)")
        timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: object, selector: ObjC.selector("tick:"),
                                                       userInfo: ObjC.nil, repeats: true)
    }

    @ObjCMethod func shouldAutorotateToInterfaceOrientation(_ orientation: Int) -> Bool {
        true
    }

    @ObjCMethod func supportedInterfaceOrientations() -> Int {
        30 // UIInterfaceOrientationMaskAll
    }

    // MARK: Actions

    @ObjCMethod func done(_ sender: ObjCValue) {
        timer?.invalidate()
        timer = nil
        player.stop()
        viewController.dismissModalViewControllerAnimated(true)
    }

    @ObjCMethod func togglePlay(_ sender: ObjCValue) {
        if player.playing {
            player.pause()
        } else {
            player.play()
        }
        updatePlayButton()
    }

    @ObjCMethod func jumpBackward(_ sender: ObjCValue) {
        player.jumpBackward(10)
    }

    @ObjCMethod func jumpForward(_ sender: ObjCValue) {
        player.jumpForward(10)
    }

    @ObjCMethod func seekStarted(_ sender: ObjCValue) {
        seeking = true
    }

    @ObjCMethod func seek(_ sender: ObjCValue) {
        seeking = false
        if let slider, player.seekable {
            player.position = slider.value
        }
    }

    @ObjCMethod func nextAspectRatio(_ sender: ObjCValue) {
        let all = AspectRatio.allCases
        let next = (aspectRatio.rawValue + 1) % all.count
        aspectRatio = all.objectAtIndex(index: next) ?? .Default
        switch aspectRatio {
        case .Default, .fillToScreen:
            // The iOS app crops to fill with a video filter; here both show
            // the video's own aspect ratio.
            player.setVideoAspectRatio(nil)
        default:
            player.setVideoAspectRatio(aspectRatio.value)
        }
        aspectButton?.setTitle(aspectRatio.stringToDisplay, forState: controlStateNormal)
    }

    @ObjCMethod func tick(_ timer: ObjCValue) {
        timeLabel?.text = player.time.stringValue
        remainingLabel?.text = player.remainingTime.stringValue
        if !seeking {
            slider?.value = player.position
        }
        updatePlayButton()
        let state = player.playerState
        if player.playing { started = true }
        if state == .ended || state == .error || (started && state == .stopped) {
            DebugLog.log("player state \(player.state), closing")
            done(ObjC.nil)
        }
    }

    // MARK: Helpers

    private func updatePlayButton() {
        playButton?.setTitle(player.playing ? "\u{275A}\u{275A}" : "\u{25B6}", forState: controlStateNormal)
    }

    private func bar(frame: CGRect, resizing: Int) -> UIView {
        let bar = UIView(frame: frame)
        bar.autoresizingMask = resizing
        bar.backgroundColor = UIColor.colorWithWhite(0, alpha: 0.6)
        return bar
    }

    private func label(frame: CGRect, alignment: Int) -> UILabel {
        let label = UILabel(frame: frame)
        label.backgroundColor = UIColor.clearColor()
        label.textColor = UIColor.whiteColor()
        label.font = UIFont.systemFontOfSize(14)
        label.textAlignment = alignment
        return label
    }

    private func button(_ title: String, action: String, frame: CGRect) -> UIButton {
        let button = UIButton.buttonWithType(buttonTypeCustom)
        button.frame = frame
        button.setTitle(title, forState: controlStateNormal)
        button.addTarget(object, action: ObjC.selector(action), forControlEvents: ControlEvent.touchUpInside)
        return button
    }
}
