import SwiftUI
import SwiftData
import PhotosUI
import ImageIO

/// Edits an isolated draft; only Save writes meal and receipt changes to persistent storage.
struct MealEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let existingMeal: Meal?
    private let onSaved: (Meal) -> Void
    private let onDeleted: () -> Void
    @State private var title: String
    @State private var charm: String
    @State private var restaurant: RestaurantDraft?
    @State private var receipt: Data?
    @State private var receiptPreview: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoTask: Task<Void, Never>?
    @State private var photoRequest = UUID()
    @State private var isLoadingPhoto = false
    @State private var customEmojiExpanded: Bool
    @State private var showDraftReceipt = false
    @State private var showLocationSearch = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    private enum Field { case title, emoji }
    private static let charms = ["🍱", "🍽️", "🍕", "🍔", "🌮", "🍜", "🍣", "🥗", "🥞", "☕️", "🥂", "🎉"]

    init(meal: Meal?, onSaved: @escaping (Meal) -> Void, onDeleted: @escaping () -> Void = {}) {
        existingMeal = meal
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _title = State(initialValue: meal?.title ?? "")
        _charm = State(initialValue: meal?.charm ?? "🍱")
        _customEmojiExpanded = State(initialValue: !Self.charms.contains(meal?.charm ?? "🍱"))
        _receipt = State(initialValue: meal?.receiptPhoto)
        _receiptPreview = State(initialValue: meal?.receiptPhoto.flatMap { ReceiptPhoto.preview($0, maximumPixelSize: 600) })
        _restaurant = State(initialValue: meal?.restaurantDetails.map {
            RestaurantDraft(title: $0.title, address: $0.address, latitude: $0.lattitude, longitude: $0.longitude)
        })
    }

    var body: some View {
        let receiptPickerTitle = receipt == nil ? "Add photo" : "Replace photo"
        return NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Meal title", text: $title)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .accessibilityIdentifier("meal-title")
                    Picker("Meal icon", selection: $charm) {
                        ForEach(Self.charms, id: \.self) { icon in
                            Text(icon).tag(icon)
                        }
                        if !Self.charms.contains(charm) {
                            Text(charm.utf8.count <= 64 && charm.count == 1 ? charm : "Choose an emoji").tag(charm)
                        }
                    }
                    .accessibilityIdentifier("meal-icon-picker")
                    DisclosureGroup(isExpanded: $customEmojiExpanded) {
                        LabeledContent("Custom emoji") {
                            TextField("", text: $charm)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .emoji)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .accessibilityIdentifier("meal-emoji")
                        }
                        if charm.utf8.count > 64 || charm.count != 1 {
                            Button("Reset meal icon") { charm = "🍱" }
                                .accessibilityIdentifier("reset-meal-emoji")
                        }
                    } label: {
                        Text("Custom emoji").accessibilityIdentifier("custom-emoji")
                    }
                }
                Section("Restaurant") {
                    Button {
                        focusedField = nil
                        showLocationSearch = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(restaurant?.title ?? "Choose a restaurant").foregroundStyle(Color.primary)
                                if let restaurant {
                                    Text(restaurant.address).font(.caption).foregroundStyle(Color.mealSecondaryText)
                                }
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .accessibilityIdentifier("choose-restaurant")
                    if restaurant != nil {
                        Button("Remove restaurant", role: .destructive) { restaurant = nil }
                            .accessibilityIdentifier("remove-restaurant")
                    }
                }
                Section("Receipt") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(receiptPickerTitle, systemImage: "photo")
                    }
                    .accessibilityIdentifier("choose-receipt")
                    .accessibilityLabel(receipt == nil ? "Add receipt photo" : "Replace receipt photo")
                    if isLoadingPhoto {
                        ProgressView("Preparing receipt…")
                    }
                    if receipt != nil {
                        if let receiptPreview {
                            Button {
                                focusedField = nil
                                showDraftReceipt = true
                            } label: {
                                Image(uiImage: receiptPreview)
                                    .resizable().scaledToFit().frame(maxHeight: 220)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingPhoto)
                            .accessibilityLabel("Preview receipt")
                            .accessibilityHint("Open this draft photo to zoom")
                            .accessibilityIdentifier("preview-receipt")
                        } else {
                            Text("Photo unavailable. Replace or remove it.")
                                .foregroundStyle(Color.mealSecondaryText)
                        }
                        Button("Remove receipt", role: .destructive) {
                            cancelPhotoLoad()
                            selectedPhoto = nil
                            self.receipt = nil
                            receiptPreview = nil
                        }
                    }
                }
                if existingMeal != nil {
                    Section {
                        Button("Delete meal", role: .destructive) { showDeleteConfirmation = true }
                            .accessibilityIdentifier("delete-meal")
                    }
                }
            }
            .mealFocusedContent()
            .navigationTitle(existingMeal == nil ? "New meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelPhotoLoad(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isLoadingPhoto)
                        .accessibilityIdentifier("save-meal")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchModal { restaurant = $0 }
            }
            .fullScreenCover(isPresented: $showDraftReceipt) {
                if let receipt { ReceiptViewer(data: receipt) }
            }
            .confirmationDialog("Delete meal?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete meal", role: .destructive) { deleteMeal() }
                    .accessibilityIdentifier("confirm-delete-meal")
            } message: {
                Text("Deletes its items, people and receipt. This can’t be undone.")
            }
            .alert("Couldn’t update meal", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: selectedPhoto) { _, selection in loadPhoto(selection) }
            .onDisappear { cancelPhotoLoad() }
        }
    }

    private func save() {
        guard !isLoadingPhoto else { return }
        do {
            let meal = existingMeal ?? Meal()
            try MealStore.saveMeal(meal, title: title, charm: charm, restaurant: restaurant, receiptPhoto: receipt, isNew: existingMeal == nil, in: context)
            dismiss()
            onSaved(meal)
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteMeal() {
        guard let existingMeal else { return }
        do {
            try MealStore.deleteMeal(existingMeal, in: context)
            dismiss()
            onDeleted()
        } catch { errorMessage = error.localizedDescription }
    }

    private func cancelPhotoLoad() {
        photoTask?.cancel()
        photoTask = nil
        photoRequest = UUID()
        isLoadingPhoto = false
    }

    private func loadPhoto(_ selection: PhotosPickerItem?) {
        cancelPhotoLoad()
        guard let selection else { return }
        isLoadingPhoto = true
        let request = photoRequest
        photoTask = Task { @MainActor in
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    throw ReceiptPhotoError.unavailable
                }
                try Task.checkCancellation()
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try ReceiptPhoto.prepare(data)
                }.value
                try Task.checkCancellation()
                guard photoRequest == request else { return }
                receipt = prepared
                receiptPreview = ReceiptPhoto.preview(prepared, maximumPixelSize: 600)
                isLoadingPhoto = false
            } catch {
                guard photoRequest == request, !Task.isCancelled else { return }
                isLoadingPhoto = false
                selectedPhoto = nil
                errorMessage = error.localizedDescription
            }
        }
    }

}

/// Downsamples without decoding a full-resolution image, bounding stored receipt dimensions and size.
enum ReceiptPhoto {
    /// Bounds decoding of historical attachments too; unreadable or oversized data returns nil without changing storage.
    nonisolated static func preview(_ data: Data, maximumPixelSize: Int = 2400) -> UIImage? {
        guard data.count <= 40 * 1024 * 1024, maximumPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(maximumPixelSize, 2400),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    nonisolated static func prepare(_ data: Data) throws -> Data {
        guard let image = preview(data),
              let compressed = image.jpegData(compressionQuality: 0.85),
              compressed.count <= 8 * 1024 * 1024 else { throw ReceiptPhotoError.unsupported }
        return compressed
    }
}

private enum ReceiptPhotoError: LocalizedError {
    case unavailable, unsupported
    var errorDescription: String? {
        switch self {
        case .unavailable: "The photo couldn’t be downloaded. Check your connection and choose it again."
        case .unsupported: "Choose a readable image smaller than 40 MB."
        }
    }
}
