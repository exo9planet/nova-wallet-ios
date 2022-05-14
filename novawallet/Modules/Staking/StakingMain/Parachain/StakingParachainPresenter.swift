import Foundation

final class StakingParachainPresenter {
    weak var view: StakingMainViewProtocol?

    let interactor: StakingParachainInteractorInputProtocol
    let logger: LoggerProtocol

    let stateMachine: ParaStkStateMachineProtocol
    let networkInfoViewModelFactory: ParaStkNetworkInfoViewModelFactoryProtocol
    let stateViewModelFactory: ParaStkStateViewModelFactoryProtocol

    init(
        interactor: StakingParachainInteractorInputProtocol,
        networkInfoViewModelFactory: ParaStkNetworkInfoViewModelFactoryProtocol,
        stateViewModelFactory: ParaStkStateViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.networkInfoViewModelFactory = networkInfoViewModelFactory
        self.stateViewModelFactory = stateViewModelFactory
        self.logger = logger

        let stateMachine = ParachainStaking.StateMachine()
        self.stateMachine = stateMachine
        stateMachine.delegate = self
    }

    private func provideNetworkInfo() {
        let optCommonData = stateMachine.viewState { (state: ParachainStaking.BaseState) in
            state.commonData
        }

        if
            let networkInfo = optCommonData?.networkInfo,
            let chainAsset = optCommonData?.chainAsset {
            let viewModel = networkInfoViewModelFactory.createViewModel(
                from: networkInfo,
                chainAsset: chainAsset,
                price: optCommonData?.price
            )
            view?.didRecieveNetworkStakingInfo(viewModel: viewModel)
        } else {
            view?.didRecieveNetworkStakingInfo(viewModel: nil)
        }
    }

    private func provideStateViewModel() {
        let stateViewModel = stateViewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: stateViewModel)
    }
}

extension StakingParachainPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        provideNetworkInfo()
        provideStateViewModel()

        interactor.setup()
    }

    func performMainAction() {}

    func performRewardInfoAction() {}

    func performChangeValidatorsAction() {}

    func performSetupValidatorsForBondedAction() {}

    func performStakeMoreAction() {}

    func performRedeemAction() {}

    func performRebondAction() {}

    func performAnalyticsAction() {}

    func performManageAction(_: StakingManageOption) {}
}

extension StakingParachainPresenter: StakingParachainInteractorOutputProtocol {
    func didReceiveChainAsset(_ chainAsset: ChainAsset) {
        stateMachine.state.process(chainAsset: chainAsset)
    }

    func didReceiveAccount(_ account: MetaChainAccountResponse?) {
        stateMachine.state.process(account: account)
    }

    func didReceivePrice(_ price: PriceData?) {
        stateMachine.state.process(price: price)

        provideNetworkInfo()
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        stateMachine.state.process(balance: assetBalance)
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        stateMachine.state.process(delegatorState: delegator)
    }

    func didReceiveScheduledRequests(_ requests: [ParachainStaking.ScheduledRequest]?) {
        stateMachine.state.process(scheduledRequests: requests)
    }

    func didReceiveSelectedCollators(_ collatorsInfo: SelectedRoundCollators) {
        stateMachine.state.process(collatorsInfo: collatorsInfo)
    }

    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol) {
        stateMachine.state.process(calculatorEngine: calculator)
    }

    func didReceiveNetworkInfo(_ networkInfo: ParachainStaking.NetworkInfo) {
        stateMachine.state.process(networkInfo: networkInfo)

        provideNetworkInfo()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")
    }
}

extension StakingParachainPresenter: ParaStkStateMachineDelegate {
    func stateMachineDidChangeState(_: ParaStkStateMachineProtocol) {
        provideStateViewModel()
    }
}
