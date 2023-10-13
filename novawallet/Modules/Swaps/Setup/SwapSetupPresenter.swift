import Foundation
import SoraFoundation
import BigInt

final class SwapSetupPresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let viewModelFactory: SwapsSetupViewModelFactoryProtocol

    private var assetBalance: AssetBalance?
    private var payChainAsset: ChainAsset?
    private var payAssetPriceData: PriceData?
    private var receiveAssetPriceData: PriceData?
    private var receiveChainAsset: ChainAsset?
    private var payAmountInput: AmountInputResult?
    private var receiveAmountInput: Decimal?
    private var fee: BigUInt?
    private var quote: AssetConversion.Quote?
    private var quoteArgs: AssetConversion.QuoteArgs? {
        didSet {
            provideDetailsViewModel(isAvailable: quoteArgs != nil)
        }
    }

    private var feeIdentifier: String?
    private var accountId: AccountId?

    init(
        interactor: SwapSetupInteractorInputProtocol,
        wireframe: SwapSetupWireframeProtocol,
        viewModelFactory: SwapsSetupViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideButtonState() {
        let buttonState = viewModelFactory.buttonState(
            assetIn: payChainAsset?.chainAssetId,
            assetOut: receiveChainAsset?.chainAssetId,
            amountIn: getPayAmount(for: payAmountInput),
            amountOut: receiveAmountInput
        )
        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled
        )
    }

    private func providePayTitle() {
        let payTitleViewModel = viewModelFactory.payTitleViewModel(
            assetDisplayInfo: payChainAsset?.assetDisplayInfo,
            maxValue: assetBalance?.transferable,
            locale: selectedLocale
        )
        view?.didReceiveTitle(payViewModel: payTitleViewModel)
    }

    private func providePayAssetViewModel() {
        let payAssetViewModel = viewModelFactory.payAssetViewModel(
            chainAsset: payChainAsset,
            locale: selectedLocale
        )
        view?.didReceiveInputChainAsset(payViewModel: payAssetViewModel)
    }

    private func providePayInputPriceViewModel() {
        guard let assetDisplayInfo = payChainAsset?.assetDisplayInfo else {
            view?.didReceiveAmountInputPrice(payViewModel: nil)
            return
        }
        let inputPriceViewModel = viewModelFactory.inputPriceViewModel(
            assetDisplayInfo: assetDisplayInfo,
            amount: getPayAmount(for: payAmountInput),
            priceData: payAssetPriceData,
            locale: selectedLocale
        )
        view?.didReceiveAmountInputPrice(payViewModel: inputPriceViewModel)
    }

    private func provideReceiveTitle() {
        let receiveTitleViewModel = viewModelFactory.receiveTitleViewModel(locale: selectedLocale)
        view?.didReceiveTitle(receiveViewModel: receiveTitleViewModel)
    }

    private func provideReceiveAssetViewModel() {
        let receiveAssetViewModel = viewModelFactory.receiveAssetViewModel(
            chainAsset: receiveChainAsset,
            locale: selectedLocale
        )
        view?.didReceiveInputChainAsset(receiveViewModel: receiveAssetViewModel)
    }

    private func provideReceiveInputPriceViewModel() {
        guard let assetDisplayInfo = receiveChainAsset?.assetDisplayInfo else {
            view?.didReceiveAmountInputPrice(receiveViewModel: nil)
            return
        }
        let inputPriceViewModel = viewModelFactory.inputPriceViewModel(
            assetDisplayInfo: assetDisplayInfo,
            amount: receiveAmountInput,
            priceData: receiveAssetPriceData,
            locale: selectedLocale
        )
        view?.didReceiveAmountInputPrice(receiveViewModel: inputPriceViewModel)
    }

    private func providePayAmountInputViewModel() {
        guard let payChainAsset = payChainAsset else {
            return
        }
        let amountInputViewModel = viewModelFactory.amountInputViewModel(
            chainAsset: payChainAsset,
            amount: getPayAmount(for: payAmountInput),
            locale: selectedLocale
        )
        view?.didReceiveAmount(payInputViewModel: amountInputViewModel)
    }

    private func provideReceiveAmountInputViewModel() {
        guard let receiveChainAsset = receiveChainAsset else {
            return
        }
        let amountInputViewModel = viewModelFactory.amountInputViewModel(
            chainAsset: receiveChainAsset,
            amount: receiveAmountInput,
            locale: selectedLocale
        )
        view?.didReceiveAmount(receiveInputViewModel: amountInputViewModel)
    }

    private func getPayAmount(for input: AmountInputResult?) -> Decimal? {
        guard
            let input = input,
            let payChainAsset = payChainAsset else {
            return nil
        }
        let includedFee: BigUInt
        switch input {
        case .rate:
            includedFee = fee ?? 0
        case .absolute:
            includedFee = 0
        }

        let transferable = assetBalance?.transferable ?? 0
        let balance = max(transferable - includedFee, 0)
        guard let balanceDecimal = Decimal.fromSubstrateAmount(
            balance,
            precision: payChainAsset.asset.displayInfo.assetPrecision
        ) else {
            return nil
        }
        return input.absoluteValue(from: balanceDecimal)
    }

    private func providePayAssetViews() {
        providePayTitle()
        providePayAssetViewModel()
        providePayInputPriceViewModel()
        providePayAmountInputViewModel()
    }

    private func provideReceiveAssetViews() {
        provideReceiveTitle()
        provideReceiveAssetViewModel()
        provideReceiveInputPriceViewModel()
        provideReceiveAmountInputViewModel()
    }

    private func provideDetailsViewModel(isAvailable: Bool) {
        view?.didReceiveDetailsState(isAvailable: isAvailable)
    }

    private func provideRateViewModel() {
        guard
            let assetDisplayInfoIn = payChainAsset?.assetDisplayInfo,
            let assetDisplayInfoOut = receiveChainAsset?.assetDisplayInfo,
            let quote = quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }
        let rateViewModel = viewModelFactory.rateViewModel(from: .init(
            assetDisplayInfoIn: assetDisplayInfoIn,
            assetDisplayInfoOut: assetDisplayInfoOut,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        ), locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: rateViewModel))
    }

    private func provideFeeViewModel() {
        guard let payChainAsset = payChainAsset, receiveChainAsset != nil else {
            return
        }
        guard let fee = fee else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }
        let viewModel = viewModelFactory.feeViewModel(
            amount: fee,
            assetDisplayInfo: payChainAsset.assetDisplayInfo,
            priceData: payAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func estimateFee() {
        guard let quote = quote, let accountId = accountId else {
            return
        }

        // TODO: Provide slippage and direction
        let args = AssetConversion.CallArgs(
            assetIn: quote.assetIn,
            amountIn: quote.amountIn,
            assetOut: quote.assetOut,
            amountOut: quote.amountOut,
            receiver: accountId,
            direction: .sell,
            slippage: .percent(of: 1)
        )

        guard args.identifier != feeIdentifier else {
            return
        }

        feeIdentifier = args.identifier
        interactor.calculateFee(args: args)
    }

    private func refreshQuote(direction: AssetConversion.Direction, forceUpdate: Bool = true) {
        guard
            let payChainAsset = payChainAsset,
            let receiveChainAsset = receiveChainAsset else {
            return
        }

        quote = nil

        switch direction {
        case .buy:
            if let receiveInPlank = receiveAmountInput?.toSubstrateAmount(precision: Int16(receiveChainAsset.asset.precision)), receiveInPlank > 0 {
                let quoteArgs = AssetConversion.QuoteArgs(
                    assetIn: payChainAsset.chainAssetId,
                    assetOut: receiveChainAsset.chainAssetId,
                    amount: receiveInPlank,
                    direction: direction
                )
                self.quoteArgs = quoteArgs
                interactor.calculateQuote(for: quoteArgs)
            } else {
                quoteArgs = nil
                if forceUpdate {
                    payAmountInput = nil
                    providePayAmountInputViewModel()
                } else {
                    refreshQuote(direction: .sell)
                }
            }
        case .sell:
            if let payInPlank = getPayAmount(for: payAmountInput)?.toSubstrateAmount(
                precision: Int16(payChainAsset.asset.precision)), payInPlank > 0 {
                let quoteArgs = AssetConversion.QuoteArgs(
                    assetIn: payChainAsset.chainAssetId,
                    assetOut: receiveChainAsset.chainAssetId,
                    amount: payInPlank,
                    direction: direction
                )
                self.quoteArgs = quoteArgs
                interactor.calculateQuote(for: quoteArgs)
            } else {
                quoteArgs = nil
                if forceUpdate {
                    receiveAmountInput = nil
                    provideReceiveAmountInputViewModel()
                } else {
                    refreshQuote(direction: .buy)
                }
            }
        default:
            break
        }

        provideRateViewModel()
        provideFeeViewModel()
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideDetailsViewModel(isAvailable: false)
        provideButtonState()
        interactor.setup()
    }

    func selectPayToken() {
        wireframe.showPayTokenSelection(from: view, chainAsset: receiveChainAsset) { [weak self] chainAsset in
            self?.payChainAsset = chainAsset
            self?.providePayAssetViews()
            self?.provideButtonState()
            self?.refreshQuote(direction: .sell, forceUpdate: false)
            self?.interactor.update(payChainAsset: chainAsset)
        }
    }

    func selectReceiveToken() {
        wireframe.showReceiveTokenSelection(from: view, chainAsset: payChainAsset) { [weak self] chainAsset in
            self?.receiveChainAsset = chainAsset
            self?.provideReceiveAssetViews()
            self?.provideButtonState()
            self?.refreshQuote(direction: .buy, forceUpdate: false)
            self?.interactor.update(receiveChainAsset: chainAsset)
        }
    }

    func updatePayAmount(_ amount: Decimal?) {
        payAmountInput = amount.map { .absolute($0) }
        refreshQuote(direction: .sell)
        provideButtonState()
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        refreshQuote(direction: .buy)
        provideButtonState()
    }

    func swap() {
        Swift.swap(&payChainAsset, &receiveChainAsset)
        interactor.update(payChainAsset: payChainAsset)
        interactor.update(receiveChainAsset: receiveChainAsset)
        payAmountInput = nil
        receiveAmountInput = nil
        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
        refreshQuote(direction: .sell, forceUpdate: false)
    }

    func selectMaxPayAmount() {
        payAmountInput = .rate(1)
        providePayAssetViews()
        refreshQuote(direction: .sell)
        provideButtonState()
    }

    // TODO: show editing fee
    func showFeeActions() {}

    func showFeeInfo() {
        let title = LocalizableResource {
            R.string.localizable.commonNetwork(
                preferredLanguages: $0.rLanguages
            )
        }
        let details = LocalizableResource {
            R.string.localizable.swapsNetworkFeeDescription(
                preferredLanguages: $0.rLanguages
            )
        }
        wireframe.showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showRateInfo() {
        let title = LocalizableResource {
            R.string.localizable.swapsSetupDetailsRate(
                preferredLanguages: $0.rLanguages
            )
        }
        let details = LocalizableResource {
            R.string.localizable.swapsRateDescription(
                preferredLanguages: $0.rLanguages
            )
        }
        wireframe.showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    // TODO: navigate to confirm screen
    func proceed() {}
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {
    func didReceive(error: SwapSetupError) {
        switch error {
        case let .quote(_, args):
            guard args == quoteArgs else {
                return
            }
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshQuote(direction: args.direction)
            }
        case let .fetchFeeFailed(_, id):
            guard id == feeIdentifier else {
                return
            }
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            }
        case let .price(_, priceId):
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            }
        case let .assetBalance(_, chainAssetId, accountId):
            guard accountId == self.accountId,
                  let payChainAsset = payChainAsset,
                  payChainAsset.chainAssetId == chainAssetId else {
                return
            }
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.update(payChainAsset: payChainAsset)
            }
        }
    }

    func didReceive(quote: AssetConversion.Quote, for quoteArgs: AssetConversion.QuoteArgs) {
        guard quoteArgs == self.quoteArgs else {
            return
        }

        self.quote = quote

        switch quoteArgs.direction {
        case .buy:
            let payAmount = payChainAsset.map {
                Decimal.fromSubstrateAmount(
                    quote.amountIn,
                    precision: Int16($0.asset.precision)
                ) ?? 0
            }
            payAmountInput = payAmount.map { .absolute($0) }
            providePayAmountInputViewModel()
        case .sell:
            receiveAmountInput = receiveChainAsset.map {
                Decimal.fromSubstrateAmount(
                    quote.amountOut,
                    precision: Int16($0.asset.precision)
                ) ?? 0
            }
            provideReceiveAmountInputViewModel()
        default:
            break
        }

        provideRateViewModel()
        estimateFee()
        provideButtonState()
    }

    func didReceive(fee: BigUInt?, transactionId: TransactionFeeId) {
        guard feeIdentifier == transactionId else {
            return
        }
        self.fee = fee
        provideFeeViewModel()
        provideButtonState()
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        if payChainAsset?.asset.priceId == priceId {
            payAssetPriceData = price
            providePayInputPriceViewModel()
        } else if receiveChainAsset?.asset.priceId == priceId {
            receiveAssetPriceData = price
            provideReceiveInputPriceViewModel()
        }
    }

    func didReceive(payAccountId: AccountId?) {
        accountId = payAccountId
    }

    func didReceive(balance: AssetBalance?, for chainAsset: ChainAssetId, accountId: AccountId) {
        guard accountId == self.accountId, payChainAsset?.chainAssetId == chainAsset else {
            return
        }
        assetBalance = balance
        providePayTitle()
    }
}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            setup()
        }
    }
}
