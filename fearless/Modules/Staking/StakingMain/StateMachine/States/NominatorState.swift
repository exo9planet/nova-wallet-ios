import Foundation

final class NominatorState: BaseStashNextState {
    private(set) var ledgerInfo: DyStakingLedger
    private(set) var nomination: Nomination

    init(stateMachine: StakingStateMachineProtocol,
         commonData: StakingStateCommonData,
         stashItem: StashItem,
         ledgerInfo: DyStakingLedger,
         nomination: Nomination) {
        self.ledgerInfo = ledgerInfo
        self.nomination = nomination

        super.init(stateMachine: stateMachine, commonData: commonData, stashItem: stashItem)
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(ledgerInfo: DyStakingLedger?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo {
            self.ledgerInfo = ledgerInfo

            newState = self
        } else {
            newState = StashState(stateMachine: stateMachine,
                                  commonData: commonData,
                                  stashItem: stashItem,
                                  ledgerInfo: nil)
        }

        stateMachine.transit(to: newState)
    }

    override func process(nomination: Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let nomination = nomination {
            self.nomination = nomination

            newState = self
        } else {
            newState = PendingValidatorState(stateMachine: stateMachine,
                                             commonData: commonData,
                                             stashItem: stashItem,
                                             ledgerInfo: ledgerInfo)
        }

        stateMachine.transit(to: newState)
    }

    override func process(validatorPrefs: ValidatorPrefs?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let prefs = validatorPrefs {
            newState = ValidatorState(stateMachine: stateMachine,
                                      commonData: commonData,
                                      stashItem: stashItem,
                                      ledgerInfo: ledgerInfo,
                                      prefs: prefs)
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
