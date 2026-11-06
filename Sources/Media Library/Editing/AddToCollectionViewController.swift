/*****************************************************************************
 * AddToCollectionViewController.swift
 *
 * Copyright © 2020 VLC authors and VideoLAN
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *          Andrew Breckenridge <asbreckenridge # me.com>
 *          Diogo Simao Marques <dogo@videolabs.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation
import UIKit

protocol AddToCollectionViewControllerDelegate: AnyObject {
    func addToCollectionViewController(_ addToCollectionViewController: AddToCollectionViewController,
                                       didSelectCollection collection: MediaCollectionModel)
    func addToCollectionViewController(_ addToPlaylistViewController: AddToCollectionViewController,
                                       newCollectionName name: String,
                                       from mlType: MediaCollectionModel.Type)
    func addToCollectionViewControllerMoveCollections(_
                                                      addToCollectionViewController: AddToCollectionViewController)
}

@ObjCImplementation(protocols: ["UICollectionViewDelegateFlowLayout", "UICollectionViewDelegate", "UICollectionViewDataSource"], extensions: ["UICollectionViewDelegateFlowLayout", "UICollectionViewDelegate", "UICollectionViewDataSource"])
class AddToCollectionViewController: UIViewControllerMethods {
    @IBOutlet private weak var newCollectionButton: UIButton!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewTopConstraint: NSLayoutConstraint!

    private let sidePadding: CGFloat = 10
    private var collectionModelType: MediaCollectionModel.Type?

    var mlCollection = [MediaCollectionModel]()

    private lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.minimumLineSpacing = 10
        collectionViewLayout.minimumInteritemSpacing = 0
        return collectionViewLayout
    }()

    weak var delegate: AddToCollectionViewControllerDelegate?

    @ObjCMethod("viewWillAppear:") func viewWillAppear(_ animated: Bool) {
        callSuper("viewWillAppear:", animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.isTranslucent = false
        collectionView.reloadData()
    }

    init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        objcInit("initWithNibName:bundle:", nibNameOrNil, nibBundleOrNil)
        initViews()
        NotificationCenter.default.addObserver(self,
                                               selector: ObjC.selector("themeDidChange"),
                                               name: .VLCThemeDidChangeNotification,
                                               object: nil)
    }


    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PresentationTheme.current.colors.statusBarStyle
    }

    @ObjCMethod("viewSafeAreaInsetsDidChange") func viewSafeAreaInsetsDidChange() {
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @ObjCMethod("viewDidLayoutSubviews") func viewDidLayoutSubviews() {
        callSuper("viewDidLayoutSubviews")
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @ObjCMethod private func themeDidChange() {
        view.backgroundColor = PresentationTheme.current.colors.background
        collectionView.backgroundColor = PresentationTheme.current.colors.background
#if os(iOS)
        setNeedsStatusBarAppearanceUpdate()
#endif
    }

    @ObjCMethod private func dismissView() {
        dismiss(animated: true, completion: nil)
    }

    func updateInterface(for collectionModelType: MediaCollectionModel.Type, isOnlyCreation: Bool = false) {
        if collectionModelType is VLCMLPlaylist.Type {
            title = isOnlyCreation ? NSLocalizedString("PLAYLIST_CREATION", comment: "") : NSLocalizedString("ADD_TO_PLAYLIST", comment: "")
            collectionViewTopConstraint.constant = 10
            collectionView.allowsSelection = !isOnlyCreation
        } else {
            title = NSLocalizedString("ADD_TO_MEDIA_GROUP", comment: "")
            collectionViewTopConstraint.constant = 0
        }
        self.collectionModelType = collectionModelType
        setupNewCollectionButton(for: collectionModelType)
    }

    // MARK: - Create new Actions

    @IBAction private func handleMoveCollection() {
        delegate?.addToCollectionViewControllerMoveCollections(self)
    }

    @IBAction private func handleNewCollection(_ sender: UIButton) {
        guard let collectionModelType = collectionModelType else {
            assertionFailure("AddToCollectionViewController: handleNewCollection: Failed to retrieve type")
            return
        }

        var title: String
        var description: String
        var placeholder: String

        if collectionModelType is VLCMLPlaylist.Type {
            title = NSLocalizedString("PLAYLISTS", comment: "")
            description = NSLocalizedString("PLAYLIST_DESCRIPTION", comment: "")
            placeholder = NSLocalizedString("PLAYLIST_PLACEHOLDER", comment: "")
        } else {
            title = NSLocalizedString("MEDIA_GROUPS", comment: "")
            description = NSLocalizedString("MEDIA_GROUPS_DESCRIPTION", comment: "")
            placeholder = NSLocalizedString("MEDIA_GROUPS_PLACEHOLDER", comment: "")
        }

        let alertController = UIAlertController(title: title,
                                                message: description,
                                                preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            textField in
            textField.placeholder = placeholder
        })

        let cancelButton = UIAlertAction(title: NSLocalizedString("BUTTON_CANCEL", comment: ""),
                                         style: .default)

        let confirmAction = UIAlertAction(title: NSLocalizedString("BUTTON_DONE", comment: ""),
                                          style: .default) {
            [weak alertController] _ in
            guard let alertController = alertController,
                  let textField = alertController.textFields?.first else { return }

            guard let text = textField.text, text != "" else {
                DispatchQueue.main.async {
                    VLCAlertViewController.alertViewManager(title: NSLocalizedString("ERROR_EMPTY_NAME",
                                                                                     comment: ""),
                                                            viewController: self)
                }
                return
            }
            self.delegate?.addToCollectionViewController(self,
                                                         newCollectionName: text,
                                                         from: collectionModelType)
        }
        alertController.addAction(cancelButton)
        alertController.addAction(confirmAction)
        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - Private initializers

private extension AddToCollectionViewController {
    private func initViews() {
        Bundle.main.loadNibNamed("AddToCollectionView", owner: self, options: nil)
        view.backgroundColor = PresentationTheme.current.colors.background
        setupNavigationBar()
        setupCollectionView()
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("BUTTON_CANCEL",
                                                                                    comment: ""),
                                                           style: .done,
                                                           target: self,
                                                           action: ObjC.selector("dismissView"))
    }

    private func setupNewCollectionButton(for type: MediaCollectionModel.Type) {
        newCollectionButton.layer.masksToBounds = true
        newCollectionButton.layer.cornerRadius = 10
        newCollectionButton.backgroundColor = PresentationTheme.current.colors.orangeUI

        var title: String
        var hint: String

        if type is VLCMLPlaylist.Type {
            title = NSLocalizedString("PLAYLIST_CREATION", comment: "")
            hint = NSLocalizedString("PLAYLIST_CREATION_HINT", comment: "")
        } else {
            title = NSLocalizedString("MEDIA_GROUP_CREATION", comment: "")
            hint = NSLocalizedString("MEDIA_GROUP_CREATION_HINT", comment: "")
        }

        newCollectionButton.setTitle(title, for: .normal)
        newCollectionButton.titleLabel?.font = UIFont.preferredCustomFont(forTextStyle: .headline)
        newCollectionButton.accessibilityLabel = title
        newCollectionButton.accessibilityHint = hint
    }

    private func setupCollectionView() {
        let cellNib = UINib(nibName: MediaCollectionViewCell.nibName, bundle: nil)
        collectionView.register(cellNib,
                                forCellWithReuseIdentifier: MediaCollectionViewCell.defaultReuseIdentifier)
        collectionView.register(MoveToRootHeader.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: MoveToRootHeader.headerID)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.collectionViewLayout = collectionViewLayout
        collectionView.backgroundColor = PresentationTheme.current.colors.background
    }
}

// MARK: - UICollectionViewFlowLayout

@ObjCExtension("UICollectionViewDelegateFlowLayout")
extension AddToCollectionViewController {
    @ObjCMethod("collectionView:layout:sizeForItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return MediaCollectionViewCell.cellSizeForWidth(collectionView.bounds.size.width,
                                                        safeAreaInsets: collectionView.safeAreaInsets)
    }

    @ObjCMethod("collectionView:layout:insetForSectionAtIndex:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: sidePadding, bottom: 0, right: sidePadding)
    }

    @ObjCMethod("collectionView:layout:referenceSizeForHeaderInSection:") func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        guard collectionModelType is VLCMLMediaGroup.Type else { return .zero }
        return CGSize(width: collectionView.frame.width, height: MediaCollectionViewCell.getDefaultConstant())
    }
}

// MARK: - UICollectionViewDelegate

@ObjCExtension("UICollectionViewDelegate")
extension AddToCollectionViewController {
    @ObjCMethod("collectionView:didSelectItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.row <= mlCollection.count else {
            assertionFailure("AddToPlaylistViewController: didSelectItemAt: IndexPath out of range.")
            return
        }

        delegate?.addToCollectionViewController(self, didSelectCollection: mlCollection[indexPath.row])
    }
}

// MARK: - UICollectionViewDataSource

@ObjCExtension("UICollectionViewDataSource")
extension AddToCollectionViewController {

    func reloadData() {
        self.collectionView.reloadData()
    }

    @ObjCMethod("numberOfSectionsInCollectionView:") func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    @ObjCMethod("collectionView:numberOfItemsInSection:") func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return mlCollection.count
    }

    @ObjCMethod("collectionView:cellForItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCollectionViewCell.defaultReuseIdentifier,
                                                            for: indexPath) as? MediaCollectionViewCell else {
            return UICollectionViewCell()
        }

        cell.disableScrollView()

        guard indexPath.row <= mlCollection.count else {
            assertionFailure("AddToPlaylistViewController: cellForItemAt: IndexPath out of range.")
            return UICollectionViewCell()
        }

        cell.media = mlCollection[indexPath.row] as? VLCMLObject
        cell.dragIndicatorImageView.isHidden = !collectionView.allowsSelection
        return cell
    }

    @ObjCMethod("collectionView:viewForSupplementaryElementOfKind:atIndexPath:") func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard collectionModelType is VLCMLMediaGroup.Type,
              kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: MoveToRootHeader.headerID, for: indexPath) as? MoveToRootHeader
        else {
            return UICollectionReusableView()
        }

        header.delegate = self
        return header
    }
}

extension AddToCollectionViewController: MoveToRootHeaderDelegate {
    func moveToRootHeader(didTapHeader header: MoveToRootHeader) {
        guard collectionModelType is VLCMLMediaGroup.Type else { return }
        delegate?.addToCollectionViewControllerMoveCollections(self)
    }

}
