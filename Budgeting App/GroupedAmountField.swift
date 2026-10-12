import SwiftUI
#if os(iOS) || os(visionOS)
import UIKit
#endif

struct GroupedAmountField<Field: Hashable>: View {
    @Binding var text: String
    var focusedField: FocusState<Field?>.Binding
    let field: Field
    let identifier: String
    let label: String
    let keyboardDoneIdentifier: String
    var large = false
    var signed = false
    var alignment: TextAlignment = .leading
    var advances = false
    var onSubmit: (() -> Void)? = nil
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        #if os(iOS) || os(visionOS)
        NativeGroupedAmountField(text: $text, focused: focusedField.wrappedValue == field,
            setFocused: { active in
                if active { focusedField.wrappedValue = field }
                else if focusedField.wrappedValue == field { focusedField.wrappedValue = nil }
            }, identifier: identifier, label: label, keyboardDoneIdentifier: keyboardDoneIdentifier,
           large: large, signed: signed, alignment: alignment, advances: advances, enabled: isEnabled,
           submit: { if let onSubmit { onSubmit() } else { focusedField.wrappedValue = nil } },
           done: { focusedField.wrappedValue = nil })
        #else
        TextField("0", text: Binding(get: { AmountEditing.displayText(text) }, set: { value in
            // Non-UIKit fallback uses a full replacement through the same editor.
            if let change = AmountEditing.applying(to: "", range: NSRange(location: 0, length: 0), replacement: value) { text = change.text }
        }))
        .focused(focusedField, equals: field).multilineTextAlignment(alignment)
        .font(large ? .largeTitle.weight(.semibold) : .body).monospacedDigit()
        .submitLabel(advances ? .next : .done)
        .onSubmit { if let onSubmit { onSubmit() } else { focusedField.wrappedValue = nil } }
        .accessibilityIdentifier(identifier).accessibilityLabel(label)
        #endif
    }
}

#if os(iOS) || os(visionOS)
private struct NativeGroupedAmountField: UIViewRepresentable {
    @Binding var text: String
    let focused: Bool
    let setFocused: (Bool) -> Void
    let identifier: String
    let label: String
    let keyboardDoneIdentifier: String
    let large: Bool
    let signed: Bool
    let alignment: TextAlignment
    let advances: Bool
    let enabled: Bool
    let submit: () -> Void
    let done: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.placeholder = "0"
        field.borderStyle = .none
        field.textColor = .label
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.adjustsFontForContentSizeCategory = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.accessibilityIdentifier = identifier
        field.accessibilityLabel = label
        field.isEnabled = enabled
        field.keyboardType = signed ? .numbersAndPunctuation : .decimalPad
        field.returnKeyType = advances ? .next : .done
        if context.coordinator.accessoryAdvances != advances || context.coordinator.accessoryDoneID != keyboardDoneIdentifier {
            let toolbar = UIToolbar()
            var items: [UIBarButtonItem] = []
            if advances {
                let next = UIBarButtonItem(title: "Next", style: .plain, target: context.coordinator, action: #selector(Coordinator.nextField))
                next.accessibilityIdentifier = "transferKeyboardNext"
                items.append(next)
            }
            let done = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.dismissKeyboard))
            done.accessibilityIdentifier = keyboardDoneIdentifier
            items += [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
            toolbar.items = items; toolbar.sizeToFit(); field.inputAccessoryView = toolbar
            context.coordinator.accessoryAdvances = advances
            context.coordinator.accessoryDoneID = keyboardDoneIdentifier
            if field.isFirstResponder { field.reloadInputViews() }
        }
        field.textAlignment = alignment == .trailing ? .right : (alignment == .center ? .center : .natural)
        field.font = UIFontMetrics(forTextStyle: large ? .largeTitle : .body).scaledFont(
            for: UIFont.monospacedDigitSystemFont(ofSize: large ? 34 : 17, weight: large ? .semibold : .regular))
        let displayed = AmountEditing.displayText(text)
        // Delegate edits set text/caret together. Avoid resetting either on the
        // subsequent SwiftUI update, especially while editing in the middle.
        if field.text != displayed { field.text = displayed }
        context.coordinator.updatingFocus = true
        if focused && enabled && !field.isFirstResponder {
            field.becomeFirstResponder()
            if field.window == nil {
                DispatchQueue.main.async { [weak field, weak coordinator = context.coordinator] in
                    guard let field, let coordinator, coordinator.parent.focused, coordinator.parent.enabled else { return }
                    field.becomeFirstResponder()
                }
            }
        } else if !focused && field.isFirstResponder { field.resignFirstResponder() }
        context.coordinator.updatingFocus = false
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? max(80, uiView.intrinsicContentSize.width), height: max(44, uiView.intrinsicContentSize.height))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeGroupedAmountField
        var updatingFocus = false
        var accessoryAdvances: Bool?
        var accessoryDoneID: String?
        init(_ parent: NativeGroupedAmountField) { self.parent = parent }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !updatingFocus { parent.setFocused(true) }
            if AmountEditing.canonicalText(parent.text) == "0" {
                DispatchQueue.main.async { [weak textField] in
                    if textField?.text == "0" { textField?.selectAll(nil) }
                }
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if !updatingFocus { parent.setFocused(false) }
        }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string == "\n" || string == "\r" { parent.submit(); return false }
            guard parent.enabled, let change = AmountEditing.applying(to: parent.text, range: range, replacement: string) else { return false }
            field.text = change.display
            if let position = field.position(from: field.beginningOfDocument, offset: change.caret) {
                field.selectedTextRange = field.textRange(from: position, to: position)
            }
            parent.text = change.text
            return false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool { parent.submit(); return false }
        @objc func nextField() { parent.submit() }
        @objc func dismissKeyboard() { parent.done() }
    }
}
#endif
