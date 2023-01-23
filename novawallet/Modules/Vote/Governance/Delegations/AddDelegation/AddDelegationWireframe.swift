import Foundation
import SoraFoundation

final class AddDelegationWireframe: AddDelegationWireframeProtocol {
    func showPicker(
        from view: AddDelegationViewProtocol?,
        title: LocalizableResource<String>?,
        items: [LocalizableResource<SelectableTitleTableViewCell.Model>],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate
    ) {
        guard let pickerView = ModalPickerFactory.createSelectionList(
            title: title,
            items: items,
            selectedIndex: selectedIndex,
            delegate: delegate
        )
        else {
            return
        }

        view?.controller.present(pickerView, animated: true)
    }
}
