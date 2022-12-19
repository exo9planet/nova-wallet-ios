import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

final class TransactionHistoryPresenter {
    weak var view: TransactionHistoryViewProtocol?
    let wireframe: TransactionHistoryWireframeProtocol
    let interactor: TransactionHistoryInteractorInputProtocol
    let viewModelFactory: TransactionHistoryViewModelFactory2Protocol
    let logger: LoggerProtocol?

    private var viewModel: [Date: [TransactionItemViewModel]] = [:]
    private var items: [String: TransactionHistoryItem] = [:]
    private var accountAddress: AccountAddress?
    private var filter: WalletHistoryFilter = .all

    init(
        interactor: TransactionHistoryInteractorInputProtocol,
        wireframe: TransactionHistoryWireframeProtocol,
        viewModelFactory: TransactionHistoryViewModelFactory2Protocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func reloadView(items: [String: TransactionHistoryItem]) throws {
        guard let view = view, let accountAddress = accountAddress else {
            return
        }
        let pageViewModels = viewModelFactory.createGroupModel(
            Array(items.values),
            address: accountAddress,
            locale: selectedLocale
        )
        viewModel.merge(pageViewModels) { old, new in
            Array(Set(old + new))
        }

        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp < $1.timestamp })
            )
        }.compactMap { $0 }.sorted(by: { $0.date > $1.date })

        view.didReceive(viewModel: sections)
    }

    private func reloadView() {
        guard let view = view else {
            return
        }
        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp < $1.timestamp })
            )
        }.compactMap { $0 }.sorted(by: { $0.date > $1.date })

        view.didReceive(viewModel: sections)
    }
}

extension TransactionHistoryPresenter: TransactionHistoryPresenterProtocol {
    func setup() {
        interactor.setup(historyFilter: .all)
    }

    func viewDidAppear() {
        interactor.refresh()
    }

    func select(item: TransactionItemViewModel) {
        guard let view = view, let operation = items[item.identifier] else {
            return
        }

        wireframe.showOperationDetails(
            from: view,
            operation: operation
        )
    }

    func loadNext() {
        guard let view = view else {
            return
        }
        view.startLoading()
        interactor.loadNext()
    }

    func showFilter() {
        guard let view = view else {
            return
        }
        wireframe.showFilter(
            from: view,
            filter: filter,
            delegate: self
        )
    }
}

extension TransactionHistoryPresenter: TransactionHistoryInteractorOutputProtocol {
    func didReceive(error: TransactionHistoryError) {
        view?.stopLoading()
        logger?.error("Received error \(error.localizedDescription)")
    }

    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>]) {
        items = changes.mergeToDict(items)
        try? reloadView(items: items)
    }

    func didReceive(nextItems: [TransactionHistoryItem]) {
        guard let accountAddress = accountAddress, !nextItems.isEmpty else {
            return
        }
        let pageViewModels = viewModelFactory.createGroupModel(
            nextItems,
            address: accountAddress,
            locale: selectedLocale
        )

        items = nextItems.reduceToDict(items)
        viewModel.merge(pageViewModels) { old, new in
            Array(Set(old + new))
        }
        view?.stopLoading()
        reloadView()
    }

    func didReceive(accountAddress: AccountAddress) {
        self.accountAddress = accountAddress
    }
}

extension TransactionHistoryPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            reloadView()
        }
    }
}

extension TransactionHistoryPresenter: TransactionHistoryFilterEditingDelegate {
    func historyFilterDidEdit(filter: WalletHistoryFilter) {
        view.map { wireframe.closeTopModal(from: $0) }
        self.filter = filter
        interactor.setup(historyFilter: filter)
    }
}
