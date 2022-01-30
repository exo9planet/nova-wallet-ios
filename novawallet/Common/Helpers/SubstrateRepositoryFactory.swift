import Foundation
import RobinHood

protocol SubstrateRepositoryFactoryProtocol {
    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem>
    func createAssetBalanceRepository() -> AnyDataProviderRepository<AssetBalance>
    func createStashItemRepository() -> AnyDataProviderRepository<StashItem>
    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject>
    func createChainRepository() -> AnyDataProviderRepository<ChainModel>
    func createCustomAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32
    ) -> AnyDataProviderRepository<TransactionHistoryItem>

    func createUtilityAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32
    ) -> AnyDataProviderRepository<TransactionHistoryItem>
}

final class SubstrateRepositoryFactory: SubstrateRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem> {
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

    func createStashItemRepository() -> AnyDataProviderRepository<StashItem> {
        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))

        let repository: CoreDataRepository<StashItem, CDStashItem> =
            storageFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        return AnyDataProviderRepository(repository)
    }

    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject> {
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

    func createChainRepository() -> AnyDataProviderRepository<ChainModel> {
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(
                filter: nil,
                sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix],
                mapper: AnyCoreDataMapper(ChainModelMapper())
            )

        return AnyDataProviderRepository(repository)
    }

    func createCustomAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let txFilter = NSPredicate.filterTransactionsBy(
            address: address,
            chainId: chainId,
            assetId: assetId
        )

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            storageFacade.createRepository(filter: txFilter)
        return AnyDataProviderRepository(txStorage)
    }

    func createUtilityAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let txFilter = NSPredicate.filterUtilityAssetTransactionsBy(
            address: address,
            chainId: chainId,
            utilityAssetId: assetId
        )

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            storageFacade.createRepository(filter: txFilter)
        return AnyDataProviderRepository(txStorage)
    }

    func createAssetBalanceRepository() -> AnyDataProviderRepository<AssetBalance> {
        let mapper = AssetBalanceMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }
}
