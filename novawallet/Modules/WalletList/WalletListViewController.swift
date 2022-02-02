import UIKit
import SoraFoundation

final class WalletListViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletListViewLayout

    let presenter: WalletListPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private var headerViewModel: WalletListHeaderViewModel?
    private var groupsViewModels: [WalletListGroupViewModel] = []

    init(presenter: WalletListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.collectionView.registerCellClass(WalletListAssetCell.self)
        rootView.collectionView.registerCellClass(WalletListTotalBalanceCell.self)
        rootView.collectionView.registerCellClass(WalletListAccountCell.self)
        rootView.collectionView.registerCellClass(WalletListSettingsCell.self)
        rootView.collectionView.registerClass(
            WalletListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        collectionViewLayout?.register(
            TokenGroupDecorationView.self,
            forDecorationViewOfKind: WalletListFlowLayout.assetGroupDecoration
        )

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    @objc func actionSelectAccount() {
        presenter.selectWallet()
    }

    @objc func actionRefresh() {
        presenter.refresh()
    }

    @objc func actionSettings() {}
}

extension WalletListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let cellType = WalletListFlowLayout.CellType(indexPath: indexPath)
        return CGSize(width: collectionView.frame.width, height: cellType.height)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        switch WalletListFlowLayout.SectionType(section: section) {
        case .assetGroup:
            return CGSize(
                width: collectionView.frame.width,
                height: WalletListFlowLayout.Constants.assetHeaderHeight
            )

        case .summary, .settings:
            return .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            presenter.selectAsset(at: indexPath.row, in: groupIndex)
        }
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        WalletListFlowLayout.SectionType(section: section).cellSpacing
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        WalletListFlowLayout.SectionType(section: section).insets
    }
}

extension WalletListViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        WalletListFlowLayout.SectionType.assetsStartingSection + groupsViewModels.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch WalletListFlowLayout.SectionType(section: section) {
        case .summary:
            return headerViewModel != nil ? 2 : 0
        case .settings:
            return 1
        case .assetGroup:
            if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(section) {
                return groupsViewModels[groupIndex].assets.count
            } else {
                return 0
            }
        }
    }

    private func provideAccountCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> WalletListAccountCell {
        let accountCell = collectionView.dequeueReusableCellWithType(
            WalletListAccountCell.self,
            for: indexPath
        )!

        if let viewModel = headerViewModel {
            accountCell.bind(viewModel: viewModel)
        }

        accountCell.iconButton.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )

        return accountCell
    }

    private func provideTotalBalanceCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> WalletListTotalBalanceCell {
        let totalBalanceCell = collectionView.dequeueReusableCellWithType(
            WalletListTotalBalanceCell.self,
            for: indexPath
        )!

        totalBalanceCell.locale = selectedLocale

        if let viewModel = headerViewModel {
            totalBalanceCell.bind(viewModel: viewModel)
        }

        return totalBalanceCell
    }

    private func provideSettingsCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> WalletListSettingsCell {
        let settingsCell = collectionView.dequeueReusableCellWithType(
            WalletListSettingsCell.self,
            for: indexPath
        )!

        settingsCell.locale = selectedLocale

        settingsCell.actionButton.addTarget(
            self,
            action: #selector(actionSettings),
            for: .touchUpInside
        )

        return settingsCell
    }

    private func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        assetIndex: Int
    ) -> WalletListAssetCell {
        let assetCell = collectionView.dequeueReusableCellWithType(
            WalletListAssetCell.self,
            for: indexPath
        )!

        if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            let viewModel = groupsViewModels[groupIndex].assets[assetIndex]
            assetCell.bind(viewModel: viewModel)
        }

        return assetCell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch WalletListFlowLayout.CellType(indexPath: indexPath) {
        case .account:
            return provideAccountCell(collectionView, indexPath: indexPath)
        case .totalBalance:
            return provideTotalBalanceCell(collectionView, indexPath: indexPath)
        case .settings:
            return provideSettingsCell(collectionView, indexPath: indexPath)
        case let .asset(assetIndex):
            return provideAssetCell(collectionView, indexPath: indexPath, assetIndex: assetIndex)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            WalletListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            let viewModel = groupsViewModels[groupIndex]
            view.bind(viewModel: viewModel)
        }

        return view
    }
}

extension WalletListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

extension WalletListViewController: HiddableBarWhenPushed {}

extension WalletListViewController: WalletListViewProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel) {
        headerViewModel = viewModel

        rootView.collectionView.reloadData()
    }

    func didReceiveGroups(viewModels: [WalletListGroupViewModel]) {
        groupsViewModels = viewModels

        rootView.collectionView.reloadData()
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }
}
