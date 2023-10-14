import Foundation
import SoraFoundation

struct SwapSlippageViewFactory {
    static func createView(
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let interactor = SwapSlippageInteractor()
        let wireframe = SwapSlippageWireframe()

        let amountFormatter = NumberFormatter.amount
        let percentFormatter = NumberFormatter.percent

        let presenter = SwapSlippagePresenter(
            interactor: interactor,
            wireframe: wireframe,
            numberFormatterLocalizable: amountFormatter.localizableResource(),
            percentFormatterLocalizable: percentFormatter.localizableResource(),
            localizationManager: LocalizationManager.shared,
            completionHandler: completionHandler
        )

        let view = SwapSlippageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
