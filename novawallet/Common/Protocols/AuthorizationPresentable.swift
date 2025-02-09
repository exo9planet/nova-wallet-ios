import UIKit

typealias AuthorizationCompletionBlock = (Bool) -> Void

protocol AuthorizationPresentable: ScreenAuthorizationWireframeProtocol {
    func authorize(
        animated: Bool,
        cancellable: Bool,
        with completionBlock: @escaping AuthorizationCompletionBlock
    )
}

protocol AuthorizationAccessible {
    var isAuthorizing: Bool { get }
}

private let authorization = UUID().uuidString

private enum AuthorizationConstants {
    static var completionBlockKey: String = "co.jp.novawallet.auth.delegate"
    static var authorizationViewKey: String = "co.jp.novawallet.auth.view"
}

extension AuthorizationAccessible {
    var isAuthorizing: Bool {
        let view = objc_getAssociatedObject(
            authorization,
            &AuthorizationConstants.authorizationViewKey
        )
            as? PinSetupViewProtocol

        return view != nil
    }
}

extension AuthorizationPresentable {
    private var completionBlock: AuthorizationCompletionBlock? {
        get {
            objc_getAssociatedObject(authorization, &AuthorizationConstants.completionBlockKey)
                as? AuthorizationCompletionBlock
        }

        set {
            objc_setAssociatedObject(
                authorization,
                &AuthorizationConstants.completionBlockKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    private var authorizationView: PinSetupViewProtocol? {
        get {
            objc_getAssociatedObject(authorization, &AuthorizationConstants.authorizationViewKey)
                as? PinSetupViewProtocol
        }

        set {
            objc_setAssociatedObject(
                authorization,
                &AuthorizationConstants.authorizationViewKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    private var isAuthorizing: Bool {
        authorizationView != nil
    }
}

extension AuthorizationPresentable {
    func authorize(animated: Bool, with completionBlock: @escaping AuthorizationCompletionBlock) {
        authorize(animated: animated, cancellable: false, with: completionBlock)
    }

    func authorizeByPinCode(
        animated: Bool,
        cancellable: Bool,
        with completionBlock: @escaping AuthorizationCompletionBlock
    ) {
        authorize(animated: animated, cancellable: cancellable, usingBiometry: false, with: completionBlock)
    }

    func authorize(
        animated: Bool,
        cancellable: Bool,
        with completionBlock: @escaping AuthorizationCompletionBlock
    ) {
        authorize(animated: animated, cancellable: cancellable, usingBiometry: true, with: completionBlock)
    }

    func authorize(
        animated: Bool,
        cancellable: Bool,
        usingBiometry: Bool,
        with completionBlock: @escaping AuthorizationCompletionBlock
    ) {
        guard !isAuthorizing else {
            return
        }

        guard let presentingController = UIApplication.shared.keyWindow?.rootViewController?
            .topModalViewController else {
            return
        }

        guard let authorizationView = PinViewFactory.createScreenAuthorizationView(
            with: self,
            usingBiometry: usingBiometry,
            cancellable: cancellable
        ) else {
            completionBlock(false)
            return
        }

        self.completionBlock = completionBlock
        self.authorizationView = authorizationView

        authorizationView.controller.modalTransitionStyle = .crossDissolve
        authorizationView.controller.modalPresentationStyle = .overFullScreen
        presentingController.present(authorizationView.controller, animated: animated, completion: nil)
    }
}

extension AuthorizationPresentable {
    func showAuthorizationCompletion(with result: Bool) {
        guard let completionBlock = completionBlock else {
            return
        }

        self.completionBlock = nil

        guard let authorizationView = authorizationView else {
            return
        }

        authorizationView.controller.presentingViewController?.dismiss(animated: true) {
            self.authorizationView = nil
            completionBlock(result)
        }
    }
}
