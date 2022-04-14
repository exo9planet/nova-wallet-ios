import UIKit

final class DAppAddFavoriteViewLayout: UIView {
    struct Constants {
        static let iconViewSize = CGSize(width: 88.0, height: 88.0)
        static let iconContentInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
        static var iconDisplaySize: CGSize {
            CGSize(
                width: iconViewSize.width - iconContentInsets.left - iconContentInsets.right,
                height: iconViewSize.height - iconContentInsets.top - iconContentInsets.bottom
            )
        }
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let saveButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        button.tintColor = R.color.colorNovaBlue()!
        return button
    }()

    let iconView: DAppIconView = {
        let view = DAppIconView()
        view.backgroundView.cornerRadius = 22.0
        view.contentInsets = Constants.iconContentInsets
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let iconContentView = UIView()
        containerView.stackView.addArrangedSubview(iconContentView)

        iconContentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.size.equalTo(Constants.iconViewSize)
        }

        containerView.stackView.setCustomSpacing(16.0, after: iconContentView)

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(addressLabel)
        containerView.stackView.setCustomSpacing(8.0, after: addressLabel)
    }
}
