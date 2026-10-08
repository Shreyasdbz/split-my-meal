import SwiftUI
import SwiftData

/// Selects the tax or tip adjustment, retaining the existing percentage-of-tax-inclusive-total tip rule.
enum ChargeKind: String, Identifiable {
    case tax, tip
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// One draft editor for percentage and fixed-dollar adjustments; changing modes converts valid input.
struct ChargeEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let meal: Meal
    private let kind: ChargeKind
    @State private var mode: Mode
    @State private var value: String
    @State private var clearRequested = false
    @State private var errorMessage: String?
    @FocusState private var valueFocused: Bool
    private enum Mode: String, CaseIterable { case percentage = "Percentage", amount = "Amount" }

    init(meal: Meal, kind: ChargeKind) {
        self.meal = meal
        self.kind = kind
        let percentage = kind == .tax ? meal.taxPercentage : meal.tipPercentage
        let amount = kind == .tax ? meal.taxAmount : meal.tipAmount
        _mode = State(initialValue: amount == nil ? .percentage : .amount)
        _value = State(initialValue: (amount ?? percentage).map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...4))) } ?? "0")
    }

    private var baseCents: Int64 {
        let amounts = MealAmounts(meal: meal)
        return kind == .tax ? amounts.subtotalCents : amounts.subtotalCents + amounts.taxCents
    }

    private var base: Double { Double(baseCents) / 100 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Calculation", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent(mode == .percentage ? "Percentage" : "Amount (USD)") {
                        TextField("0", text: Binding(get: { value }, set: {
                            value = $0
                            clearRequested = false
                        }))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($valueFocused)
                            .accessibilityLabel("\(kind.title) \(mode == .percentage ? "percentage" : "amount in US dollars")")
                            .accessibilityIdentifier("charge-value")
                    }
                } footer: {
                    if mode == .percentage {
                        Text(kind == .tax ? "Applied to the item subtotal." : "Applied to subtotal plus tax.")
                            .foregroundStyle(Color.mealSecondaryText)
                    }
                }
                Section {
                    if mode == .percentage {
                        AmountRow(title: kind == .tax ? "Subtotal" : "Subtotal + tax", amount: base)
                    }
                    if let parsed = try? DecimalInput.parse(value, allowZero: true, maximumFractionDigits: mode == .percentage ? 4 : 2),
                       let cents = mode == .amount ? Money.cents(parsed) : Money.percentageCents(parsed, baseCents: baseCents) {
                        AmountRow(title: kind.title, amount: Double(cents) / 100, emphasized: true)
                    }
                }
                Section {
                    Button("Clear \(kind.rawValue)", role: .destructive) {
                        valueFocused = false
                        value = "0"
                        clearRequested = true
                    }
                        .accessibilityIdentifier("clear-charge")
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).accessibilityIdentifier("save-charge")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { valueFocused = false }
                }
            }
            .onChange(of: mode) { oldMode, newMode in
                // Clearing is a draft operation in either mode; only typing a
                // replacement restores a numeric charge before Save.
                guard !clearRequested else { return }
                guard let parsed = try? DecimalInput.parse(value, allowZero: true, maximumFractionDigits: oldMode == .percentage ? 4 : 2) else { return }
                do {
                    let converted = try DecimalInput.convert(parsed, toPercentage: newMode == .percentage, base: base)
                    value = converted.formatted(.number.grouping(.never).precision(.fractionLength(newMode == .amount ? 2...2 : 0...4)))
                } catch {
                    value = "0"
                    errorMessage = error.localizedDescription
                }
            }
            .alert("Couldn’t update \(kind.rawValue)", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        do {
            let parsed = clearRequested ? nil : try DecimalInput.parse(value, allowZero: true, maximumFractionDigits: mode == .percentage ? 4 : 2)
            let percentage = mode == .percentage ? parsed : nil
            let amount = mode == .amount ? parsed : nil
            if kind == .tax { try MealStore.setTax(meal, percentage: percentage, amount: amount, in: context) }
            else { try MealStore.setTip(meal, percentage: percentage, amount: amount, in: context) }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

/// Parses the entire localized decimal string, rejecting signs, grouping, suffixes, and nonfinite values.
enum DecimalInput {
    static func parse(_ text: String, allowZero: Bool, maximumFractionDigits: Int = 2, locale: Locale = .current) throws -> Double {
        let separator = locale.decimalSeparator ?? "."
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A period is grouping in locales such as German; normalizing first would turn a pasted thousand into one.
        if let grouping = locale.groupingSeparator, grouping != separator, trimmed.contains(grouping) {
            throw InputError.invalid(allowZero: allowZero, fractionDigits: maximumFractionDigits)
        }
        let localized = trimmed.replacingOccurrences(of: separator, with: ".")
        let normalized = localized.map { character -> String in
            if character.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }), let digit = character.wholeNumberValue {
                return String(digit)
            }
            return String(character)
        }.joined()
        let pattern = "^(?:[0-9]+(?:\\.[0-9]{0,\(maximumFractionDigits)})?|\\.[0-9]{1,\(maximumFractionDigits)})$"
        guard normalized.range(of: pattern, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite,
              value <= Money.maximumAmount, allowZero ? value >= 0 : value > 0 else {
            throw InputError.invalid(allowZero: allowZero, fractionDigits: maximumFractionDigits)
        }
        return value
    }

    /// Converts a staged adjustment using its actual calculation base; positive amounts need a nonzero base.
    static func convert(_ value: Double, toPercentage: Bool, base: Double) throws -> Double {
        guard value.isFinite, value >= 0, base.isFinite, base >= 0 else { throw InputError.invalid(allowZero: true, fractionDigits: 4) }
        if toPercentage {
            guard base > 0 else {
                if value == 0 { return 0 }
                throw InputError.emptyBase
            }
            return value / base * 100
        }
        guard let cents = Money.roundedCents(Money.decimal(base) * 100, maximum: Money.maximumCalculatedCents),
              let charge = Money.percentageCents(value, baseCents: cents) else {
            throw InputError.invalid(allowZero: true, fractionDigits: 4)
        }
        return Double(charge) / 100
    }

    private enum InputError: LocalizedError {
        case invalid(allowZero: Bool, fractionDigits: Int)
        case emptyBase
        var errorDescription: String? {
            switch self {
            case let .invalid(allowZero, digits):
                "Enter a \(allowZero ? "nonnegative" : "positive") number with at most \(digits) decimal places."
            case .emptyBase:
                "Add priced items before converting an amount to a percentage."
            }
        }
    }
}
