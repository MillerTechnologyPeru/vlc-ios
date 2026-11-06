/*****************************************************************************
 * ActionSheet.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *          Diogo Simao Marques <dogo@videolabs.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation
import UIKit

protocol ActionSheetDataSource {
    func numberOfRows() -> Int
    func actionSheet(collectionView: UICollectionView,
                           cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
}

protocol ActionSheetDelegate {
    optional func headerViewTitle() -> String?
    func itemAtIndexPath(_ indexPath: IndexPath) -> Any?
    optional func actionSheet(collectionView: UICollectionView,
                                    didSelectItem item: Any, At indexPath: IndexPath)
    optional func actionSheetDidFinishClosingAnimation(_ actionSheet: ActionSheet)
}

// MARK: ActionSheet

@ObjCImplementation("VLCActionSheet", protocols: ["UICollectionViewDelegateFlowLayout", "UICollectionViewDelegate", "UICollectionViewDataSource", "UIGestureRecognizerDelegate"], extensions: ["Extension", "UICollectionViewDelegateFlowLayout", "UICollectionViewDelegate", "UICollectionViewDataSource", "UIGestureRecognizerDelegate"])
class ActionSheet: UIViewControllerMethods {

    private let cellHeight: CGFloat = 50

    weak var dataSource: ActionSheetDataSource?
    weak var delegate: ActionSheetDelegate?

    var excludesWhiteTheme: Bool = false

    var themeColors: ColorPalette {
        return excludesWhiteTheme ? PresentationTheme.currentExcludingWhite.colors
                                  : PresentationTheme.current.colors
    }

    var action: ((_ item: Any) -> Void)?

    lazy var backgroundView: UIView = {
        let backgroundView = UIView()
        backgroundView.alpha = 0
        backgroundView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                   action: ObjC.selector("removeActionSheet")))
        return backgroundView
    }()

    private lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.minimumLineSpacing = 1
        collectionViewLayout.minimumInteritemSpacing = 0
        return collectionViewLayout
    }()

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero,
                                              collectionViewLayout: collectionViewLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = themeColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.showsHorizontalScrollIndicator = false

        collectionView.register(ActionSheetCell.self,
                                forCellWithReuseIdentifier: ActionSheetCell.identifier)
        collectionView.register(DoubleActionSheetCell.self,
                                forCellWithReuseIdentifier: DoubleActionSheetCell.reusableIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    lazy var collectionWrapperView: UIView = {
        let collectionWrapperView: UIView = UIView(frame: .zero)
        collectionWrapperView.backgroundColor = themeColors.background
        return collectionWrapperView
    }()

    private(set) lazy var headerView: ActionSheetSectionHeader = {
        let headerView = ActionSheetSectionHeader()
        headerView.title.text = delegate?.headerViewTitle?() ?? "Default header title"
        headerView.title.textColor = themeColors.cellTextColor
        headerView.title.backgroundColor = themeColors.background
        headerView.backgroundColor = themeColors.background
        headerView.translatesAutoresizingMaskIntoConstraints = false
        return headerView
    }()

    private lazy var downGesture: UIPanGestureRecognizer = {
        let downGesture = UIPanGestureRecognizer(target: self, action: ObjC.selector("handleDismissSender:"))
        return downGesture
    }()

    private lazy var mainStackView: UIStackView = {
        let mainStackView = UIStackView()
        mainStackView.spacing = 0
        mainStackView.axis = .vertical
        mainStackView.alignment = .center
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.backgroundColor = .clear
        mainStackView.addGestureRecognizer(downGesture)
        return mainStackView
    }()

    private lazy var maxCollectionViewHeightConstraint: NSLayoutConstraint = {
        let maxCollectionViewHeightConstraint = collectionView.heightAnchor.constraint(
            lessThanOrEqualToConstant: maxCollectionViewHeight)
        maxCollectionViewHeightConstraint.priority = .defaultHigh
        return maxCollectionViewHeightConstraint
    }()

    private lazy var collectionViewHeightConstraint: NSLayoutConstraint = {
        let collectionViewHeightConstraint = collectionView.heightAnchor.constraint(
            equalToConstant: collectionViewHeight)
        collectionViewHeightConstraint.priority = .defaultLow
        return collectionViewHeightConstraint
    }()

    let collectionViewEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 0, right: 0)

    var collectionViewHeight: CGFloat {
        let rowsCount: CGFloat = CGFloat(dataSource?.numberOfRows() ?? 0)
        let collectionViewHeight = rowsCount * ((cellHeight + collectionViewEdgeInsets.top) / numberOfColums)
        return collectionViewHeight
    }

    var maxCollectionViewHeight: CGFloat {
        let maxMargin: CGFloat = 75
        let minCollectionViewHeight: CGFloat = cellHeight * 1.5 + collectionViewEdgeInsets.top * 2
        let maxCollectionViewHeight = max(view.safeAreaLayoutGuide.layoutFrame.height - headerView.bounds.height - maxMargin, minCollectionViewHeight)
        return maxCollectionViewHeight
    }

    var offScreenFrame: CGRect {
        let y = headerView.cellHeight
        let w = collectionView.frame.size.width
        let h = collectionView.frame.size.height
        return CGRect(x: w, y: y, width: w, height: h)
    }

    var numberOfColums: CGFloat = 1 {
        didSet {
            if numberOfColums == 0 {
                numberOfColums = 1
            }
        }
    }

    private var mainStackViewTranslation = CGPoint(x: 0, y: 0)

    @ObjCMethod("updateViewConstraints") func updateViewConstraints() {
        callSuper("updateViewConstraints")
        updateCollectionViewContraints()
    }

    private func updateCollectionViewContraints() {
        collectionViewHeightConstraint.constant = collectionViewHeight
        maxCollectionViewHeightConstraint.constant = maxCollectionViewHeight
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()
    }

    private func updateCollectionViewScrollIndicatorVisibility() {
        if maxCollectionViewHeight > collectionViewHeight {
            collectionView.showsVerticalScrollIndicator = false
        } else {
            collectionView.showsVerticalScrollIndicator = true
            collectionView.flashScrollIndicatorsIfNeeded()
        }
    }

    // MARK: UIViewController

    init () {
        objcInit("initWithNibName:bundle:", nil, nil)
    }

    init(header: ActionSheetSectionHeader) {
        objcInit("initWithNibName:bundle:", nil, nil)
        headerView = header
    }


    @ObjCMethod("viewDidLoad") func viewDidLoad() {
        callSuper("viewDidLoad")
        
        NotificationCenter.default.addObserver(self, selector: ObjC.selector("updateTheme"),
                                               name: .VLCThemeDidChangeNotification, object: nil)

        view.addSubview(backgroundView)
        view.addSubview(mainStackView)

        mainStackView.addArrangedSubview(headerView)
        mainStackView.addArrangedSubview(collectionWrapperView)

        backgroundView.frame = self.view.frame

        backgroundView.accessibilityLabel = NSLocalizedString("ACTIONSHEET_BACKGROUND_LABEL",
                                                              comment: "")
        backgroundView.accessibilityHint = NSLocalizedString("ACTIONSHEET_BACKGROUND_HINT",
                                                             comment: "")

        backgroundView.accessibilityTraits = .allowsDirectInteraction

        setupMainStackViewConstraints()
        setupHeaderViewConstraints()
        setupCollectionWrapperView()
        setupCollectionViewConstraints()
    }

    @ObjCMethod("viewWillAppear:") func viewWillAppear(_ animated: Bool) {
        callSuper("viewWillAppear:", animated)
        mainStackView.isHidden = true
        collectionView.reloadData()
        headerView.title.text = delegate?.headerViewTitle?()
        updateViewConstraints()
    }

    @ObjCMethod("viewDidAppear:") func viewDidAppear(_ animated: Bool) {
        callSuper("viewDidAppear:", animated)

        setHeaderRoundedCorners()

        // This is to avoid a horrible visual glitch!
        mainStackView.isHidden = false

        updateCollectionViewContraints()
        updateCollectionViewScrollIndicatorVisibility()

        let realMainStackView = mainStackView.frame

        mainStackView.frame.origin.y += mainStackView.frame.origin.y

        UIView.animate(withDuration: 0.65, delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: .curveEaseOut,
                       animations: {
                        [mainStackView, backgroundView] in
                        mainStackView.frame = realMainStackView
                        mainStackView.transform = .identity
                        backgroundView.alpha = 1
        })
    }

    @ObjCMethod("viewWillTransitionToSize:withTransitionCoordinator:") func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        callSuper("viewWillTransitionToSize:withTransitionCoordinator:", size, coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.updateCollectionViewContraints()
            self?.setHeaderRoundedCorners()
        }) { [weak self] _ in
            self?.updateCollectionViewScrollIndicatorVisibility()
        }
    }

    @ObjCMethod("viewWillLayoutSubviews") func viewWillLayoutSubviews() {
        callSuper("viewWillLayoutSubviews")
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @ObjCMethod func updateTheme() {
        let colors = themeColors
        collectionView.backgroundColor = colors.background
        collectionWrapperView.backgroundColor = colors.background
        headerView.backgroundColor = colors.background
        headerView.title.textColor = colors.cellTextColor
        headerView.title.backgroundColor = colors.background
        collectionView.layoutIfNeeded()
    }
    
    func addChildToStackView(_ child: UIView) {
        mainStackView.addSubview(child)
    }

    func updateDragDownGestureDelegate(to delegate: ActionSheet?) {
        downGesture.delegate = delegate
    }

    func shouldDisableDragDownGesture(_ disable: Bool) {
        downGesture.isEnabled = !disable
    }
}

// MARK: Private setup methods

private extension ActionSheet {
    private func setupCollectionWrapperView() {
        collectionWrapperView.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionWrapperView.widthAnchor.constraint(equalTo: mainStackView.widthAnchor),
        ])
    }

    private func setupHeaderViewConstraints() {
        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: headerView.cellHeight),
            headerView.widthAnchor.constraint(equalTo: mainStackView.widthAnchor)
        ])
    }

    private func setupCollectionViewConstraints() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: collectionWrapperView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: collectionWrapperView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: collectionWrapperView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: collectionWrapperView.safeAreaLayoutGuide.bottomAnchor),
            collectionViewHeightConstraint,
            maxCollectionViewHeightConstraint,
            collectionView.widthAnchor.constraint(equalTo: collectionWrapperView.widthAnchor),
        ])
    }

    private func setupMainStackViewConstraints() {
        NSLayoutConstraint.activate([
            // Extra padding for spring animation
            mainStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            mainStackView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: Helpers

private extension ActionSheet {
    private func setHeaderRoundedCorners() {
        let roundedCornerPath = UIBezierPath(roundedRect: headerView.bounds,
                                             byRoundingCorners: [.topLeft, .topRight],
                                             cornerRadii: CGSize(width: 10, height: 10))
        let maskLayer = CAShapeLayer()
        maskLayer.path = roundedCornerPath.cgPath
        headerView.layer.mask = maskLayer
    }
}

// MARK: Actions

@ObjCExtension("Extension")
extension ActionSheet {
    @ObjCMethod func setAction(closure action: @escaping (_ item: Any) -> Void) {
        self.action = action
    }


    @ObjCMethod func removeActionSheet() {
        let realMainStackView = mainStackView.frame

        UIView.animate(withDuration: 0.55, delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 0,
                       options: .curveEaseIn,
                       animations: {
                        [mainStackView, backgroundView] in
                        // Dismiss the mainStackView to the bottom of the screen
                        mainStackView.frame.origin.y += mainStackView.frame.size.height
                        backgroundView.alpha = 0
            }, completion: {
                [mainStackView, presentingViewController, headerView] finished in
                // When everything is complete, reset the frame for the re-use
                mainStackView.isHidden = true
                mainStackView.frame = realMainStackView
                presentingViewController?.dismiss(animated: false)
                headerView.accessoryViewsDelegate = nil
                headerView.updateAccessoryViews()
                headerView.previousButton.isHidden = true
                self.delegate?.actionSheetDidFinishClosingAnimation?(self)
        })
    }

    @ObjCMethod func handleDismiss(sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .changed:
            mainStackViewTranslation = sender.translation(in: mainStackView)
            if mainStackViewTranslation.y < 0 {
                return
            }
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.mainStackView.transform = CGAffineTransform(translationX: 0, y: self.mainStackViewTranslation.y)
            })
        case .ended:
            let halfHeight = mainStackView.frame.height / 2
            if mainStackViewTranslation.y < halfHeight {
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                    self.mainStackView.transform = .identity
                })
            } else {
                removeActionSheet()
            }
        default:
            break
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout

@ObjCExtension("UICollectionViewDelegateFlowLayout")
extension ActionSheet {
    @ObjCMethod("collectionView:layout:sizeForItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width / numberOfColums, height: cellHeight)
    }

    @ObjCMethod("collectionView:layout:insetForSectionAtIndex:") func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return collectionViewEdgeInsets
    }
}

// MARK: UICollectionViewDelegate

@ObjCExtension("UICollectionViewDelegate")
extension ActionSheet {
    @ObjCMethod("collectionView:didSelectItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        if let delegate = delegate, let item = delegate.itemAtIndexPath(indexPath) {
            delegate.actionSheet?(collectionView: collectionView, didSelectItem: item, At: indexPath)
            action?(item)
        }
        removeActionSheet()
    }
}

// MARK: UICollectionViewDataSource

@ObjCExtension("UICollectionViewDataSource")
extension ActionSheet {
    @ObjCMethod("collectionView:numberOfItemsInSection:") func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if let dataSource = dataSource {
            return dataSource.numberOfRows()
        }
        preconditionFailure("VLCActionSheet: No data source")
    }

    @ObjCMethod("collectionView:cellForItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let dataSource = dataSource {
            return dataSource.actionSheet(collectionView: collectionView,
                                          cellForItemAt: indexPath)
        }
        preconditionFailure("VLCActionSheet: No data source")
    }
}

@ObjCExtension("UIGestureRecognizerDelegate")
extension ActionSheet {
    @ObjCMethod("gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:") func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
