import SwiftUI
import UIKit

extension View {
    /// Gives in-depth meal editing and settlement their own iPad window surface;
    /// phones retain sheets. The presented view must provide explicit dismissal.
    @ViewBuilder
    func mealFocusedPresentation<Presented: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Presented) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            fullScreenCover(isPresented: isPresented, content: content)
        } else {
            sheet(isPresented: isPresented, content: content)
        }
    }

    /// Centers report and form content at readable widths in focused iPad views.
    /// Accessibility sizes use the entire available window width.
    func mealFocusedContent() -> some View {
        modifier(MealFocusedContent())
    }
}

private struct MealFocusedContent: ViewModifier {
    @Environment(\.dynamicTypeSize) private var textSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .frame(maxWidth: textSize.isAccessibilitySize ? .infinity : 720)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
        } else {
            content
        }
    }
}

/// Currency presentation for the app's existing USD meal contract.
func mealCurrency(_ amount: Double) -> String {
    amount.formatted(.currency(code: "USD"))
}

/// Bounds malformed historical icons without changing the stored meal or its editable draft.
func mealDisplayCharm(_ charm: String) -> String {
    MealStore.isValidCharm(charm) ? charm.trimmingCharacters(in: .whitespacesAndNewlines) : "🍱"
}

extension Color {
    /// Uses dark lettering on the brighter dark-appearance primary action tint.
    static var mealPrimaryText: Color { Color("PrimaryActionText") }

    /// Keeps small explanatory text readable in both appearances, including accent-tinted controls.
    static var mealSecondaryText: Color { Color.primary.opacity(0.72) }
}

/// A labeled amount row that stacks rather than truncates at accessibility sizes.
struct AmountRow: View {
    let title: String
    let amount: Double
    var emphasized = false
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Group {
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(mealCurrency(amount)).monospacedDigit()
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                    Spacer(minLength: 16)
                    Text(mealCurrency(amount)).monospacedDigit()
                }
            }
        }
        .fontWeight(emphasized ? .semibold : .regular)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Uses native glass for stable primary actions on current systems.
struct MealPrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

extension MealItemCategory {
    var displayName: String {
        switch self {
        case .Snack: "Snack"
        case .Entree: "Entrée"
        case .Dessert: "Dessert"
        case .Drink: "Drink"
        }
    }

    var symbol: String {
        switch self {
        case .Snack: "carrot"
        case .Entree: "fork.knife"
        case .Dessert: "birthday.cake"
        case .Drink: "cup.and.saucer"
        }
    }
}
