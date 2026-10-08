import SwiftUI
import SwiftData

@main
struct SplitMyMeal_Prod_AApp: App {
    @State private var container: ModelContainer?
    @State private var failure: String?

    var body: some Scene {
        WindowGroup { MealStartupView(container: $container, failure: $failure) }
    }
}

/// Opens the existing store without deleting it if migration or iCloud fails.
private struct MealStartupView: View {
    @Binding var container: ModelContainer?
    @Binding var failure: String?
    #if DEBUG
    @State private var didInjectStoreFailure = false
    #endif

    var body: some View {
        Group {
            if let container {
                HomeScreen().modelContainer(container)
            } else if let failure {
                ContentUnavailableView {
                    Label("Couldn’t open your meals", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data has been kept.")
                    DisclosureGroup("Error details") {
                        Text(failure).font(.caption)
                    }
                } actions: {
                    Button { openStore() } label: {
                        Text("Try again").foregroundStyle(Color.mealPrimaryText)
                    }.modifier(MealPrimaryButtonStyle())
                    Link("Contact support", destination: URL(string: "mailto:shreyassane@outlook.com")!)
                }
            } else {
                ProgressView("Opening meals…")
            }
        }
        .preferredColorScheme(testAppearance)
        .task { if container == nil && failure == nil { openStore() } }
    }

    private var testAppearance: ColorScheme? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting") {
            if arguments.contains("--appearance-dark") { return .dark }
            if arguments.contains("--appearance-light") { return .light }
        }
        #endif
        return nil
    }

    @MainActor private func openStore() {
        failure = nil
        do {
            let schema = Schema(versionedSchema: MealSchemaV2.self)
            let configuration: ModelConfiguration
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            let isTesting = arguments.contains("--uitesting")
            if isTesting, arguments.contains("--fail-first-store-open"), !didInjectStoreFailure {
                didInjectStoreFailure = true
                throw NSError(domain: "SplitMyMealUITesting", code: 1, userInfo: [NSLocalizedDescriptionKey: "A test store-open failure was requested. Your production meals are untouched."])
            }
            if isTesting {
                let url = URL.documentsDirectory.appending(path: "SplitMyMeal-UITesting.store")
                configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            } else {
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            }
            #else
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            #endif
            let opened = try ModelContainer(for: schema, migrationPlan: MealMigrationPlan.self, configurations: [configuration])
            #if DEBUG
            if isTesting {
                let context = opened.mainContext
                if arguments.contains("--reset-test-data") {
                    for meal in try context.fetch(FetchDescriptor<Meal>()) { try MealStore.deleteMeal(meal, in: context) }
                }
                if arguments.contains("--seed-demo") || arguments.contains("--seed-invalid-demo"), try context.fetchCount(FetchDescriptor<Meal>()) == 0 {
                    let meal = try MealDemo.seed(in: context)
                    if arguments.contains("--invalid-restaurant-location") {
                        meal.restaurantDetails?.lattitude = 100
                        try context.save()
                    }
                    if arguments.contains("--unknown-item-consumer") {
                        meal.items?.first(where: { $0.name == "Edamame" })?.consumerIds.append("historical-unknown-consumer")
                        try context.save()
                    }
                    if arguments.contains("--seed-invalid-demo") {
                        // Historical corruption fixtures deliberately bypass the validated editing boundary.
                        meal.items?.first?.price = -1
                        meal.receiptPhoto = Data([1, 2, 3])
                        meal.charm = "Invalid historical icon"
                        for person in meal.people ?? [] { person.itemIds = [] }
                        try context.save()
                    }
                }
            }
            #endif
            container = opened
        } catch {
            failure = error.localizedDescription
        }
    }
}
