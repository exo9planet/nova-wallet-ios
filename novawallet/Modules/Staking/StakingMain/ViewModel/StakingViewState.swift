import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(
        viewModel: LocalizableResource<NominationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>,
        analyticsViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?,
        actions: [StakingManageOption]
    )
    case validator(
        viewModel: LocalizableResource<ValidationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>,
        analyticsViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?,
        actions: [StakingManageOption]
    )
    case noStash(
        viewModel: StakingEstimationViewModel,
        alerts: [StakingAlert]
    )
}
