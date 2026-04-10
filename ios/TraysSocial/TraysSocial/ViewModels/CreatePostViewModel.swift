import SwiftUI
import PhotosUI

@MainActor
@Observable
final class CreatePostViewModel {
    var postType: PostType = .recipe
    var caption = ""
    var cookingTimeMinutes = ""
    var servings = ""
    var ingredients: [IngredientEntry] = []
    var steps: [StepEntry] = []
    var tools: [String] = []
    var tags = ""
    var selectedPhoto: PhotosPickerItem?
    var photoData: Data?
    var photoImage: Image?
    var isUploading = false
    var isPublishing = false
    var errorMessage: String?

    // Ingredient/step entry
    var newIngredientName = ""
    var newIngredientQuantity = ""
    var newIngredientUnit = ""
    var newStepText = ""
    var newToolName = ""

    enum PostType: String, CaseIterable {
        case recipe, post
    }

    struct IngredientEntry: Identifiable {
        let id = UUID()
        let name: String
        let quantity: String
        let unit: String
    }

    struct StepEntry: Identifiable {
        let id = UUID()
        let description: String
    }

    func loadPhoto() async {
        guard let item = selectedPhoto else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            photoData = data
            if let uiImage = UIImage(data: data) {
                photoImage = Image(uiImage: uiImage)
            }
        }
    }

    func addIngredient() {
        guard !newIngredientName.isEmpty else { return }
        ingredients.append(IngredientEntry(name: newIngredientName, quantity: newIngredientQuantity, unit: newIngredientUnit))
        newIngredientName = ""
        newIngredientQuantity = ""
        newIngredientUnit = ""
    }

    func addStep() {
        guard !newStepText.isEmpty else { return }
        steps.append(StepEntry(description: newStepText))
        newStepText = ""
    }

    func addTool() {
        guard !newToolName.isEmpty else { return }
        tools.append(newToolName)
        newToolName = ""
    }

    func removeIngredient(at index: Int) { ingredients.remove(at: index) }
    func removeStep(at index: Int) { steps.remove(at: index) }
    func removeTool(at index: Int) { tools.remove(at: index) }

    func publish() async -> Bool {
        guard let photoData else {
            errorMessage = "Please select a photo"
            return false
        }

        isPublishing = true
        errorMessage = nil

        do {
            // Upload photo first
            let photoURL = try await APIClient.shared.upload(
                path: "/uploads",
                imageData: photoData,
                filename: "photo.jpg"
            )

            // Build post params
            var params: [String: Any] = [
                "type": postType.rawValue,
                "caption": caption,
                "post_photos": [["photo_url": photoURL, "position": 0]]
            ]

            if postType == .recipe {
                if let time = Int(cookingTimeMinutes) { params["cooking_time_minutes"] = time }
                if let srv = Int(servings) { params["servings"] = srv }
                params["ingredients"] = ingredients.enumerated().map { i, ing in
                    ["name": ing.name, "quantity": ing.quantity, "unit": ing.unit, "order": i]
                }
                params["cooking_steps"] = steps.enumerated().map { i, step in
                    ["description": step.description, "order": i]
                }
                params["tools"] = tools.enumerated().map { i, tool in
                    ["name": tool, "order": i]
                }
            }

            let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if !tagList.isEmpty {
                params["post_tags"] = tagList.map { ["tag": $0] }
            }

            // Create post — use raw JSON since mixed types
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            var request = URLRequest(url: URL(string: Configuration.apiBaseURL + "/api/v1/posts")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = KeychainService.getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
                let httpResponse = response as? HTTPURLResponse
                let body = String(data: data, encoding: .utf8) ?? "no body"
                errorMessage = "Failed to create post (\(httpResponse?.statusCode ?? 0)): \(body)"
                isPublishing = false
                return false
            }

            isPublishing = false
            return true
        } catch {
            errorMessage = "Failed to publish: \(error.localizedDescription)"
            isPublishing = false
            return false
        }
    }
}
