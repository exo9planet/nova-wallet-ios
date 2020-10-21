import UIKit
import CommonWallet

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: class {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: class {
    func setup()
}

protocol MainTabBarInteractorOutputProtocol: class {
    func didReloadSelectedAccount()
    func didReloadSelectedNetwork()
    func didUpdateWalletInfo()
}

protocol MainTabBarWireframeProtocol: AlertPresentable {
    var walletContext: CommonWalletContextProtocol { get set }

    func showNewWalletView(on view: MainTabBarViewProtocol?)
    func reloadWalletContent()
}

protocol MainTabBarViewFactoryProtocol: class {
    static func createView() -> MainTabBarViewProtocol?
    static func reloadWalletView(on view: MainTabBarViewProtocol,
                                 wireframe: MainTabBarWireframeProtocol)
}
