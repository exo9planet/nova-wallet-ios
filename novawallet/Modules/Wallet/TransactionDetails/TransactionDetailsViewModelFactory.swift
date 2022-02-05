import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

final class TransactionDetailsViewModelFactory {
    let chainAccount: ChainAccountResponse
    let selectedAsset: AssetModel
    let utilityAsset: AssetModel
    let explorers: [ChainModel.Explorer]?
    let amountViewModelFactory: BalanceViewModelFactoryProtocol
    let feeViewModelFactory: BalanceViewModelFactoryProtocol?
    let dateFormatter: LocalizableResource<DateFormatter>
    let integerFormatter: LocalizableResource<NumberFormatter>

    let iconGenerator = PolkadotIconGenerator()

    init(
        chainAccount: ChainAccountResponse,
        selectedAsset: AssetModel,
        utilityAsset: AssetModel,
        explorers: [ChainModel.Explorer]?,
        amountViewModelFactory: BalanceViewModelFactoryProtocol,
        feeViewModelFactory: BalanceViewModelFactoryProtocol?,
        dateFormatter: LocalizableResource<DateFormatter>,
        integerFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.chainAccount = chainAccount
        self.selectedAsset = selectedAsset
        self.utilityAsset = utilityAsset
        self.explorers = explorers
        self.dateFormatter = dateFormatter
        self.amountViewModelFactory = amountViewModelFactory
        self.feeViewModelFactory = feeViewModelFactory
        self.integerFormatter = integerFormatter
    }

    func populateStatus(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let viewModel: WalletNewFormDetailsViewModel

        let title = R.string.localizable
            .transactionDetailStatus(preferredLanguages: locale.rLanguages)

        switch data.status {
        case .commited:
            let details = R.string.localizable
                .transactionStatusCompleted(preferredLanguages: locale.rLanguages)
            viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconValid()
            )
        case .pending:
            let details = R.string.localizable
                .transactionStatusPending(preferredLanguages: locale.rLanguages)
            viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconPending()
            )
        case .rejected:
            let details = R.string.localizable
                .transactionStatusFailed(preferredLanguages: locale.rLanguages)
            viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconInvalid()
            )
        }

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateTime(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let transactionDate = Date(timeIntervalSince1970: TimeInterval(data.timestamp))

        let timeDetails = dateFormatter.value(for: locale).string(from: transactionDate)

        let title = R.string.localizable
            .transactionDetailDate(preferredLanguages: locale.rLanguages)
        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: timeDetails,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateAmount(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        data: AssetTransactionData,
        locale: Locale
    ) {
        let amount = data.amount.decimalValue

        let displayAmount = amountViewModelFactory.amountFromValue(amount).value(for: locale)

        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: displayAmount,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateTitleWithDetails(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        details: String
    ) {
        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: details,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateFeeAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let formatter = feeViewModelFactory ?? amountViewModelFactory

        for fee in data.fees {
            let amount = formatter.amountFromValue(fee.amount.decimalValue).value(for: locale)

            let title = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)

            let viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: amount,
                detailsIcon: nil
            )

            let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
            viewModelList.append(separator)
        }
    }

    func populateTransactionId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)

        let actionIcon = R.image.iconMore()

        let command = WalletExtrinsicOpenCommand(
            extrinsicHash: data.transactionId,
            explorers: explorers,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: data.transactionId,
            mainIcon: nil,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )
        viewModelList.append(viewModel)
    }

    func populatePeerViewModel(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        address: String,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let icon: UIImage?
        if let accountId = try? address.toAccountId(using: chainAccount.chainFormat) {
            icon = try? iconGenerator.generateFromAccountId(accountId)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
        } else {
            icon = nil
        }

        let actionIcon = R.image.iconMore()

        let command = WalletAccountOpenCommand(
            address: address,
            explorers: explorers,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: address,
            mainIcon: icon,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )
        viewModelList.append(viewModel)
    }
}

extension TransactionDetailsViewModelFactory: WalletTransactionDetailsFactoryOverriding {
    func createViewModelsFromTransaction(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            return nil
        }

        switch transactionType {
        case .incoming, .outgoing:
            return createTransferViewModels(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .reward, .slash:
            return createRewardAndSlashViewModels(
                isReward: transactionType == .reward,
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .extrinsic:
            return createExtrinsViewModels(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        }
    }

    func createAccessoryViewModelFromTransaction(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            return nil
        }

        switch transactionType {
        case .incoming, .outgoing:
            return createTransferAccessoryViewModel(
                data: data,
                commandFactory: commandFactory,
                isIncoming: transactionType == .incoming,
                locale: locale
            )
        case .reward, .slash:
            return createRewardAndSlashAccessoryViewModel(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .extrinsic:
            return createExtrinsicAccessoryViewModel(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        }
    }
}
