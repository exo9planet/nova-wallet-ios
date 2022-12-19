import CommonWallet
import RobinHood

protocol TransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func startLoading()
    func stopLoading()
    func didReceive(viewModel: [TransactionSectionModel])
}

protocol TransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
    func select(item: TransactionItemViewModel)
    func loadNext()
    func showFilter()
}

protocol TransactionHistoryInteractorInputProtocol: AnyObject {
    func setup(historyFilter: WalletHistoryFilter)
    func refresh()
    func loadNext()
}

protocol TransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(error: TransactionHistoryError)
    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>])
    func didReceive(nextItems: [TransactionHistoryItem])
    func didReceive(accountAddress: AccountAddress)
}

protocol TransactionHistoryWireframeProtocol: AnyObject {
    func showFilter(
        from view: TransactionHistoryViewProtocol,
        filter: WalletHistoryFilter,
        delegate: TransactionHistoryFilterEditingDelegate?
    )
    func showOperationDetails(
        from view: TransactionHistoryViewProtocol,
        operation: TransactionHistoryItem
    )
    func closeTopModal(from view: TransactionHistoryViewProtocol)
}

enum TransactionHistoryError: Error {
    case loadingInProgress
    case dataProvider(Error)
    case fetchProvider(Error)
}
