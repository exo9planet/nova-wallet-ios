import Foundation
import SoraKeystore
import SoraFoundation
import SubstrateSdk
import BigInt

struct DAppOperationConfirmViewFactory {
    static func createView(
        for request: DAppOperationRequest,
        type: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        switch type {
        case let .extrinsic(chain):
            let interactor = createExtrinsicInteractor(for: request, chain: chain)
            return createGenericView(for: interactor, chain: .left(chain), delegate: delegate)
        case let .bytes(chain):
            let interactor = createSignBytesInteractor(for: request, chain: chain)
            return createGenericView(for: interactor, chain: .left(chain), delegate: delegate)
        case let .ethereumSendTransaction(chain):
            return createEvmTransactionView(
                for: chain,
                request: request,
                delegate: delegate,
                shouldSendTransaction: true
            )
        case let .ethereumSignTransaction(chain):
            return createEvmTransactionView(
                for: chain,
                request: request,
                delegate: delegate,
                shouldSendTransaction: false
            )
        case let .ethereumBytes(chain):
            let interactor = createEthereumPersonalSignInteractor(for: request)
            return createGenericView(for: interactor, chain: chain, delegate: delegate)
        }
    }

    private static func createEvmTransactionView(
        for chain: DAppEitherChain,
        request: DAppOperationRequest,
        delegate: DAppOperationConfirmDelegate,
        shouldSendTransaction: Bool
    ) -> DAppOperationConfirmViewProtocol? {
        guard
            let assetInfo = chain.utilityAssetBalanceInfo,
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = DAppOperationEvmConfirmWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let validationProviderFactory = EvmValidationProviderFactory(
            presentable: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            assetInfo: assetInfo
        )

        guard
            let interactor = createEthereumInteractor(
                for: request,
                chain: chain,
                validationProviderFactory: validationProviderFactory,
                shouldSendTransaction: shouldSendTransaction
            ) else {
            return nil
        }

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationConfirmViewModelFactory(chain: chain),
            balanceViewModelFactory: balanceViewModelFactory,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DAppOperationConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createGenericView(
        for interactor: (DAppOperationBaseInteractor & DAppOperationConfirmInteractorInputProtocol)?,
        chain: DAppEitherChain,
        delegate: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        guard
            let interactor = interactor,
            let assetInfo = chain.utilityAssetBalanceInfo,
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = DAppOperationConfirmWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationConfirmViewModelFactory(chain: chain),
            balanceViewModelFactory: balanceViewModelFactory,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DAppOperationConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createExtrinsicInteractor(
        for request: DAppOperationRequest,
        chain: ChainModel
    ) -> DAppOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        return DAppOperationConfirmInteractor(
            request: request,
            chain: chain,
            runtimeProvider: runtimeProvider,
            connection: connection,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            priceProviderFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    private static func createSignBytesInteractor(
        for request: DAppOperationRequest,
        chain: ChainModel
    ) -> DAppSignBytesConfirmInteractor {
        DAppSignBytesConfirmInteractor(
            request: request,
            chain: chain,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    private static func createEthereumInteractor(
        for request: DAppOperationRequest,
        chain: Either<ChainModel, DAppUnknownChain>,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        shouldSendTransaction: Bool
    ) -> DAppEthereumConfirmInteractor? {
        let operationFactory: EthereumOperationFactoryProtocol
        let chainId: String

        switch chain {
        case let .left(knownChain):
            guard
                let connection = ChainRegistryFacade.sharedRegistry.getOneShotConnection(
                    for: knownChain.chainId
                ) else {
                return nil
            }

            operationFactory = EvmWebSocketOperationFactory(connection: connection)
            chainId = BigUInt(knownChain.addressPrefix).toHexString()
        case let .right(unknownChain):
            guard let connection = HTTPEngine(
                urls: [unknownChain.rpcUrl],
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ) else {
                return nil
            }

            operationFactory = EvmWebSocketOperationFactory(connection: connection)
            chainId = unknownChain.chainId
        }

        return DAppEthereumConfirmInteractor(
            chainId: chainId,
            request: request,
            ethereumOperationFactory: operationFactory,
            validationProviderFactory: validationProviderFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            shouldSendTransaction: shouldSendTransaction
        )
    }

    private static func createEthereumPersonalSignInteractor(
        for request: DAppOperationRequest
    ) -> DAppEthereumSignBytesInteractor {
        DAppEthereumSignBytesInteractor(
            request: request,
            signingWrapperFactory: SigningWrapperFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
