import Foundation
import RobinHood
import BigInt
import SubstrateSdk

class OnChainTransferInteractor: RuntimeConstantFetching {
    weak var presenter: OnChainTransferSetupInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let asset: AssetModel
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var assetStorageInfoFactory = AssetStorageInfoOperationFactory()

    private var sendingAssetProvider: StreamableProvider<AssetBalance>?
    private var utilityAssetProvider: StreamableProvider<AssetBalance>?
    private var sendingAssetPriceProvider: AnySingleValueProvider<PriceData>?
    private var utilityAssetPriceProvider: AnySingleValueProvider<PriceData>?

    private var setupCall: CancellableCall?

    private var recepientAccountId: AccountId?

    private var sendingAssetInfo: AssetStorageInfo?
    private var utilityAssetInfo: AssetStorageInfo?

    private var sendingAssetSubscriptionId: UUID?
    private var utilityAssetSubscriptionId: UUID?

    private var recepientSendingAssetProvider: StreamableProvider<AssetBalance>?
    private var recepientUtilityAssetProvider: StreamableProvider<AssetBalance>?

    var isUtilityTransfer: Bool { chain.utilityAssets().first?.assetId == asset.assetId }

    private lazy var chainStorage: AnyDataProviderRepository<ChainStorageItem> = {
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()
        return AnyDataProviderRepository(storage)
    }()

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.asset = asset
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.walletRemoteWrapper = walletRemoteWrapper
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
    }

    deinit {
        cancelSetupCall()

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
    }

    private func fetchStatemineMinBalance(
        for extras: StatemineAssetExtras,
        completionClosure: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                .assetsDetails,
                encodableElement: extras.assetId,
                chainId: chain.chainId
            )

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let localRequestFactory = LocalStorageRequestFactory()

            let fetchWrapper: CompoundOperationWrapper<LocalStorageResponse<AssetDetails>> =
                localRequestFactory.queryItems(
                    repository: chainStorage,
                    key: { localKey },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .assetsDetails, shouldFallback: false)
                )

            fetchWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<BigUInt> {
                let details = try fetchWrapper.targetOperation.extractNoCancellableResultData()
                return details.value?.minBalance ?? 0
            }

            let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

            dependencies.forEach { mappingOperation.addDependency($0) }

            mappingOperation.completionBlock = {
                DispatchQueue.main.async {
                    do {
                        let minBalance = try mappingOperation.extractNoCancellableResultData()
                        completionClosure(.success(minBalance))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }

            operationQueue.addOperations(dependencies + [mappingOperation], waitUntilFinished: false)
        } catch {
            completionClosure(.failure(error))
        }
    }

    private func fetchMinBalance(
        for assetStorageInfo: AssetStorageInfo,
        completionClosure: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        switch assetStorageInfo {
        case .native:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: OperationManager(operationQueue: operationQueue),
                closure: completionClosure
            )
        case let .statemine(extras):
            fetchStatemineMinBalance(for: extras, completionClosure: completionClosure)
        case let .orml(_, _, _, existentialDeposit):
            completionClosure(.success(existentialDeposit))
        }
    }

    private func createAssetExtractionWrapper() -> CompoundOperationWrapper<(AssetStorageInfo, AssetStorageInfo?)> {
        let sendingAssetWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeService
        )

        var dependencies = sendingAssetWrapper.allOperations

        let utilityAssetWrapper: CompoundOperationWrapper<AssetStorageInfo>?

        if !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first {
            let wrapper = assetStorageInfoFactory.createStorageInfoWrapper(
                from: utilityAsset,
                runtimeProvider: runtimeService
            )

            utilityAssetWrapper = wrapper

            dependencies.append(contentsOf: wrapper.allOperations)
        } else {
            utilityAssetWrapper = nil
        }

        let mergeOperation = ClosureOperation<(AssetStorageInfo, AssetStorageInfo?)> {
            let sending = try sendingAssetWrapper.targetOperation.extractNoCancellableResultData()
            let utility = try utilityAssetWrapper?.targetOperation.extractNoCancellableResultData()

            return (sending, utility)
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    private func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupUtilityAssetBalanceProviderIfNeeded()
        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
    }

    private func setupSendingAssetBalanceProvider() {
        sendingAssetProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func setupUtilityAssetBalanceProviderIfNeeded() {
        if !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first {
            utilityAssetProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.accountId,
                chainId: chain.chainId,
                assetId: utilityAsset.assetId
            )
        }
    }

    private func setupSendingAssetPriceProviderIfNeeded() {
        if let priceId = asset.priceId {
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            sendingAssetPriceProvider = subscribeToPrice(for: priceId, options: options)
        } else {
            presenter?.didReceiveSendingAssetPrice(nil)
        }
    }

    private func setupUtilityAssetPriceProviderIfNeeded() {
        guard !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first else {
            return
        }

        if let priceId = utilityAsset.priceId {
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            utilityAssetPriceProvider = subscribeToPrice(for: priceId, options: options)
        } else {
            presenter?.didReceiveUtilityAssetPrice(nil)
        }
    }

    private func provideMinBalance() {
        if let sendingAssetInfo = sendingAssetInfo {
            fetchMinBalance(for: sendingAssetInfo) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveSendingAssetMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let utilityAssetInfo = utilityAssetInfo {
            fetchMinBalance(for: utilityAssetInfo) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveUtilityAssetMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: BigUInt,
        recepient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let sendingAssetInfo = sendingAssetInfo else {
            return (builder, nil)
        }

        switch sendingAssetInfo {
        case let .orml(currencyId, _, module, _):
            let call = callFactory.ormlTransfer(
                in: module,
                currencyId: currencyId,
                receiverId: recepient,
                amount: amount
            )

            let newBuilder = try builder.adding(call: call)
            return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        case let .statemine(extras):
            let call = callFactory.assetsTransfer(
                to: recepient,
                assetId: extras.assetId,
                amount: amount
            )

            let newBuilder = try builder.adding(call: call)
            return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        case .native:
            let call = callFactory.nativeTransfer(to: recepient, amount: amount)
            let newBuilder = try builder.adding(call: call)
            return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        }
    }

    private func cancelSetupCall() {
        let cancellingCall = setupCall
        setupCall = nil
        cancellingCall?.cancel()
    }

    private func subscribeUtilityRecepientAssetBalance() {
        guard
            let utilityAssetInfo = utilityAssetInfo,
            let recepientAccountId = recepientAccountId,
            let utilityAsset = chain.utilityAssets().first else {
            return
        }

        utilityAssetSubscriptionId = walletRemoteWrapper.subscribe(
            using: utilityAssetInfo,
            accountId: recepientAccountId,
            chainAsset: ChainAsset(chain: chain, asset: utilityAsset),
            completion: nil
        )

        recepientUtilityAssetProvider = subscribeToAssetBalanceProvider(
            for: recepientAccountId,
            chainId: chain.chainId,
            assetId: utilityAsset.assetId
        )
    }

    private func subscribeSendingRecepientAssetBalance() {
        guard
            let sendingAssetInfo = sendingAssetInfo,
            let recepientAccountId = recepientAccountId else {
            return
        }

        sendingAssetSubscriptionId = walletRemoteWrapper.subscribe(
            using: sendingAssetInfo,
            accountId: recepientAccountId,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            completion: nil
        )

        recepientSendingAssetProvider = subscribeToAssetBalanceProvider(
            for: recepientAccountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func clearSendingAssetRemoteRecepientSubscription() {
        guard
            let sendingAssetInfo = sendingAssetInfo,
            let recepientAccountId = recepientAccountId,
            let sendingAssetSubscriptionId = sendingAssetSubscriptionId else {
            return
        }

        walletRemoteWrapper.unsubscribe(
            from: sendingAssetSubscriptionId,
            assetStorageInfo: sendingAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            completion: nil
        )

        self.sendingAssetSubscriptionId = nil
    }

    private func clearSendingAssetLocaleRecepientSubscription() {
        recepientSendingAssetProvider?.removeObserver(self)
        recepientSendingAssetProvider = nil
    }

    private func clearUtilityAssetRemoteRecepientSubscriptions() {
        guard
            let utilityAssetInfo = utilityAssetInfo,
            let recepientAccountId = recepientAccountId,
            let utilityAssetSubscriptionId = utilityAssetSubscriptionId,
            let utilityAsset = chain.utilityAssets().first else {
            return
        }

        walletRemoteWrapper.unsubscribe(
            from: utilityAssetSubscriptionId,
            assetStorageInfo: utilityAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: utilityAsset.assetId),
            completion: nil
        )

        self.utilityAssetSubscriptionId = nil
    }

    private func clearUtilityAssetLocaleRecepientSubscriptions() {
        recepientUtilityAssetProvider?.removeObserver(self)
        recepientUtilityAssetProvider = nil
    }
}

extension OnChainTransferInteractor {
    func setup() {
        let wrapper = createAssetExtractionWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.setupCall === wrapper else {
                    return
                }

                self?.setupCall = nil

                do {
                    let (sending, utility) = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.sendingAssetInfo = sending
                    self?.utilityAssetInfo = utility
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        setupCall = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func estimateFee(for amount: BigUInt, recepient: AccountAddress?) {
        do {
            let recepientAccountId: AccountId

            if let recepient = recepient {
                recepientAccountId = try recepient.toAccountId()
            } else {
                recepientAccountId = selectedAccount.accountId
            }

            let identifier = String(amount) + "-" + recepientAccountId.toHex()

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: identifier
            ) { [weak self] builder in
                let (newBuilder, _) = try self?.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: recepientAccountId
                ) ?? (builder, nil)

                return newBuilder
            }
        } catch {
            presenter?.didReceiveError(CommonError.dataCorruption)
        }
    }

    func change(recepient: AccountAddress?) {
        guard
            let newRecepientAccountId = try? recepient?.toAccountId(),
            newRecepientAccountId != recepientAccountId else {
            return
        }

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
        clearSendingAssetLocaleRecepientSubscription()
        clearUtilityAssetLocaleRecepientSubscriptions()

        recepientAccountId = newRecepientAccountId

        subscribeSendingRecepientAssetBalance()
        subscribeUtilityRecepientAssetBalance()
    }
}

extension OnChainTransferInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(optBalance):
            let balance = optBalance ??
                AssetBalance.createZero(
                    for: ChainAssetId(chainId: chainId, assetId: assetId),
                    accountId: accountId
                )

            if accountId == selectedAccount.accountId {
                if asset.assetId == assetId {
                    presenter?.didReceiveSendingAssetSenderBalance(balance)
                } else if chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetSenderBalance(balance)
                }
            } else if accountId == recepientAccountId {
                if asset.assetId == assetId {
                    presenter?.didReceiveSendingAssetRecepientBalance(balance)
                } else if chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetRecepientBalance(balance)
                }
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension OnChainTransferInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            if asset.priceId == priceId {
                presenter?.didReceiveSendingAssetPrice(priceData)
            } else if chain.utilityAssets().first?.priceId == priceId {
                presenter?.didReceiveUtilityAssetPrice(priceData)
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension OnChainTransferInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<RuntimeDispatchInfo, Error>,
        for _: ExtrinsicFeeId
    ) {
        switch result {
        case let .success(info):
            let fee = BigUInt(info.fee) ?? 0
            presenter?.didReceiveFee(result: .success(fee))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}
