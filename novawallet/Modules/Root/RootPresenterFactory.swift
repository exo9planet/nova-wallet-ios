import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe(inAppUpdatesServiceFactory: InAppUpdatesServiceFactory())
        let keychain = Keychain()
        let settings = SettingsManager.shared

        let userDatabaseMigrator = createUserDatabaseMigration()
        
        let substrateDatabaseMigrator = createSubstrateDatabaseMigration()
        
        let sharedSettingsMigrator = SharedSettingsMigrator(
            settingsManager: SettingsManager.shared,
            sharedSettingsManager: SharedSettingsManager()
        )

        let interactor = RootInteractor(
            settings: SelectedWalletSettings.shared,
            keystore: keychain,
            applicationConfig: ApplicationConfig.shared,
            securityLayerInteractor: SecurityLayerService.shared.interactor,
            chainRegistryClosure: { ChainRegistryFacade.sharedRegistry },
            eventCenter: EventCenter.shared,
            migrators: [sharedSettingsMigrator, userSerialMigrator, substrateSerialMigrator],
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
    
    private static func createUserDatabaseMigration() -> Migrating {
        let storePathMigrator = StorePathMigrator(
            currentStoreLocation: UserStorageParams.storageURL,
            sharedStoreLocation: UserStorageParams.sharedStorageURL,
            fileManager: FileManager.default
        )
        
        let storageMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.sharedStorageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )
        
        return SerialMigrator(migrations: [storePathMigrator, storageMigrator])
        
        return SerialMigrator(
            migration: userStorePathMigrator,
            dependentMigration: userStorageMigrator
        )
    }
    
    private static func createSubstrateDatabaseMigration() -> Migrating {
        let storePathMigrator = StorePathMigrator(
            currentStoreLocation: SubstrateStorageParams.storageURL,
            sharedStoreLocation: SubstrateStorageParams.sharedStorageURL,
            fileManager: FileManager.default
        )
        
        let storageMigrator = SubstrateStorageMigrator(
            storeURL: SubstrateStorageParams.sharedStorageURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            model: SubstrateStorageParams.modelVersion,
            fileManager: FileManager.default
        )
        
        return SerialMigrator(migrations: [storePathMigrator, storageMigrator])
    }
}
