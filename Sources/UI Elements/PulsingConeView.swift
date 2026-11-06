/*****************************************************************************
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit

@ObjCImplementation("VLCPulsingConeView")
class PulsingConeView: UIViewMethods {

    private let coneImageView: UIImageView = {
        let cone = UIImage(named: "LaunchCone") ?? UIImage(named: "cone")
        let coneImageView = UIImageView(image: cone?.withRenderingMode(.alwaysTemplate))
        coneImageView.contentMode = .scaleAspectFit
        coneImageView.translatesAutoresizingMaskIntoConstraints = false
        return coneImageView
    }()

    private let coneSize: CGFloat
    private let appearanceDelay: TimeInterval
    private var delayTimer: Timer?

    init(frame: CGRect) {
        coneSize = 80
        appearanceDelay = 1.0
        objcInit("initWithFrame:", frame)
        setupView()
    }

    init(coneSize: CGFloat) {
        self.coneSize = coneSize
        appearanceDelay = 0
        objcInit("initWithFrame:", CGRect(x: 0, y: 0, width: coneSize, height: coneSize))
        setupView()
    }

    init?(coder: NSCoder) {
        coneSize = 80
        appearanceDelay = 1.0
        objcInit("initWithCoder:", coder)
        setupView()
    }

    private func setupView() {
        isUserInteractionEnabled = false
        alpha = 0.0
        addSubview(coneImageView)
        NSLayoutConstraint.activate([
            coneImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            coneImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            coneImageView.widthAnchor.constraint(equalToConstant: coneSize),
            coneImageView.heightAnchor.constraint(equalToConstant: coneSize)
        ])
    }

    @ObjCMethod func startAnimating() {
        if delayTimer != nil || coneImageView.layer.animation(forKey: "pulse") != nil {
            return
        }
        delayTimer = Timer.scheduledTimer(timeInterval: appearanceDelay,
                                          target: self,
                                          selector: ObjC.selector("beginPulsing"),
                                          userInfo: nil,
                                          repeats: false)
    }

    @ObjCMethod private func beginPulsing() {
        delayTimer = nil
        coneImageView.tintColor = PresentationTheme.current.colors.orangeDarkAccent
        alpha = 1.0

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.8
        scale.toValue = 1.2

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.4
        opacity.toValue = 1.0

        let pulse = CAAnimationGroup()
        pulse.animations = [scale, opacity]
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        coneImageView.layer.add(pulse, forKey: "pulse")
    }

    @ObjCMethod func stopAnimating() {
        delayTimer?.invalidate()
        delayTimer = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        coneImageView.layer.removeAnimation(forKey: "pulse")
        alpha = 0.0
        CATransaction.commit()
    }
}
