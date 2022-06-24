import Foundation
import BigInt
import SubstrateSdk

class CrossChainTransferPresenter {
    let originChainAsset: ChainAsset
    let destinationChainAsset: ChainAsset

    let senderAccountAddress: AccountAddress

    private(set) var senderSendingAssetBalance: AssetBalance?
    private(set) var senderUtilityAssetBalance: AssetBalance?

    private(set) var recepientSendingAssetBalance: AssetBalance?
    private(set) var recepientUtilityAssetBalance: AssetBalance?

    private(set) var sendingAssetPrice: PriceData?
    private(set) var utilityAssetPrice: PriceData?

    private(set) var sendingAssetMinBalance: BigUInt?
    private(set) var utilityAssetMinBalance: BigUInt?
    private(set) var destinationAssetMinBalance: BigUInt?

    var senderUtilityAssetTotal: BigUInt? {
        isUtilityTransfer ? senderSendingAssetBalance?.totalInPlank :
            senderUtilityAssetBalance?.totalInPlank
    }

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    private(set) var originFee: BigUInt?
    private(set) var crossChainFee: FeeWithWeight?

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

    let dataValidatingFactory: TransferDataValidatorFactoryProtocol

    let logger: LoggerProtocol?

    var isUtilityTransfer: Bool {
        originChainAsset.chain.utilityAssets().first?.assetId == originChainAsset.asset.assetId
    }

    init(
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.originChainAsset = originChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.networkViewModelFactory = networkViewModelFactory
        self.sendingBalanceViewModelFactory = sendingBalanceViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory
        self.senderAccountAddress = senderAccountAddress
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    func refreshOriginFee() {
        fatalError("Child classes must implement this method")
    }

    func askOriginFeeRetry() {
        fatalError("Child classes must implement this method")
    }

    func updateOriginFee(_ newValue: BigUInt?) {
        originFee = newValue
    }

    func refreshCrossChainFee() {
        fatalError("Child classes must implement this method")
    }

    func askCrossChainFeeRetry() {
        fatalError("Child classes must implement this method")
    }

    func updateCrossChainFee(_ newValue: BigUInt?) {
        originFee = newValue
    }

    func baseValidators(
        for sendingAmount: Decimal?,
        recepientAddress: AccountAddress?,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validators: [DataValidating] = [
            dataValidatingFactory.receiverMatchesChain(
                recepient: recepientAddress,
                chainFormat: destinationChainAsset.chain.chainFormat,
                chainName: destinationChainAsset.chain.name,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverDiffers(
                recepient: recepientAddress,
                sender: senderAccountAddress,
                locale: selectedLocale
            ),

            dataValidatingFactory.has(fee: originFee, locale: selectedLocale) { [weak self] in
                self?.refreshOriginFee()
                return
            },

            dataValidatingFactory.has(fee: crossChainFee?.fee, locale: selectedLocale) { [weak self] in
                self?.refreshCrossChainFee()
                return
            },

            dataValidatingFactory.canSend(
                amount: sendingAmount,
                fee: isUtilityTransfer ? originFee : 0,
                transferable: senderSendingAssetBalance?.transferable,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPay(
                fee: originFee,
                total: senderUtilityAssetTotal,
                minBalance: isUtilityTransfer ? sendingAssetMinBalance : utilityAssetMinBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverWillHaveAssetAccount(
                sendingAmount: sendingAmount,
                totalAmount: recepientSendingAssetBalance?.totalInPlank,
                minBalance: sendingAssetMinBalance,
                locale: selectedLocale
            )
        ]

        if !isUtilityTransfer {
            validators.append(
                dataValidatingFactory.receiverHasUtilityAccount(
                    totalAmount: recepientUtilityAssetBalance?.totalInPlank,
                    minBalance: utilityAssetMinBalance,
                    locale: selectedLocale
                )
            )
        }

        return validators
    }

    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        senderSendingAssetBalance = balance
    }

    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance) {
        senderUtilityAssetBalance = balance
    }

    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance) {
        recepientSendingAssetBalance = balance
    }

    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance) {
        recepientUtilityAssetBalance = balance
    }

    func didReceiveOriginFee(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(fee):
            originFee = fee
        case .failure:
            askOriginFeeRetry()
        }
    }

    func didReceiveCrossChainFee(result: Result<FeeWithWeight, Error>) {
        switch result {
        case let .success(fee):
            crossChainFee = fee
        case .failure:
            askCrossChainFeeRetry()
        }
    }

    func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        sendingAssetPrice = priceData
    }

    func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        utilityAssetPrice = priceData
    }

    func didReceiveUtilityAssetMinBalance(_ value: BigUInt) {
        utilityAssetMinBalance = value
    }

    func didReceiveSendingAssetMinBalance(_ value: BigUInt) {
        sendingAssetMinBalance = value
    }

    func didReceiveDestinationAssetMinBalance(_ value: BigUInt) {
        destinationAssetMinBalance = value
    }

    func didCompleteSetup() {}

    func didReceiveError(_: Error) {}
}
