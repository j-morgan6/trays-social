import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreatePostViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var keyboardVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type picker — also swipe horizontally on the form to toggle
                    Picker("Type", selection: $viewModel.postType) {
                        Text("Recipe").tag(CreatePostViewModel.PostType.recipe)
                        Text("Post").tag(CreatePostViewModel.PostType.post)
                    }
                    .pickerStyle(.segmented)

                    // Photo display + picker
                    if let image = viewModel.photoImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .bottomTrailing) {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Text("Change")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .padding(8)
                                }
                            }
                    } else {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera")
                                    .font(.title)
                                Text("Add photo")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Load photo when selection changes
                    EmptyView()
                        .onChange(of: selectedPhoto) {
                            viewModel.selectedPhoto = selectedPhoto
                            Task { await viewModel.loadPhoto() }
                        }

                    // Caption
                    TextField("Caption", text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if viewModel.postType == .recipe {
                        recipeFields
                    }

                    // Tags
                    TextField("Tags (comma separated)", text: $viewModel.tags)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Publish button
                    Button {
                        Task {
                            if await viewModel.publish() {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isPublishing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Serve it")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(viewModel.isPublishing)
                }
                .padding(16)
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            // Only act on clearly horizontal swipes and only when the keyboard is down,
                            // to avoid destroying in-progress text or fighting keyboard gestures.
                            guard !keyboardVisible else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.postType = dx < 0 ? .post : .recipe
                            }
                        }
                )
            }
            .background(Theme.background)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .navigationTitle("New \(viewModel.postType == .recipe ? "Recipe" : "Post")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .tint(Theme.primary)
    }

    // MARK: - Recipe Fields

    @ViewBuilder
    private var recipeFields: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text("Cook time (min)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("30", text: $viewModel.cookingTimeMinutes)
                    .keyboardType(.numberPad)
                    .padding(10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading) {
                Text("Servings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("4", text: $viewModel.servings)
                    .keyboardType(.numberPad)
                    .padding(10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }

        // Ingredients
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(viewModel.ingredients.enumerated()), id: \.element.id) { index, ing in
                HStack {
                    Text("\(ing.quantity) \(ing.unit) \(ing.name)")
                        .font(.subheadline)
                    Spacer()
                    Button { viewModel.removeIngredient(at: index) } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Name", text: $viewModel.newIngredientName)
                    .frame(maxWidth: .infinity)
                TextField("Qty", text: $viewModel.newIngredientQuantity)
                    .frame(width: 50)
                TextField("Unit", text: $viewModel.newIngredientUnit)
                    .frame(width: 50)
                    .onSubmit { viewModel.addIngredient() }
            }
            .font(.subheadline)
            .padding(10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button { viewModel.addIngredient() } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Ingredient")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }

        // Steps
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .foregroundStyle(Theme.primary)
                    Text(step.description)
                    Spacer()
                    Button { viewModel.removeStep(at: index) } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
            }

            TextField("Describe the step", text: $viewModel.newStepText)
                .font(.subheadline)
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { viewModel.addStep() }

            Button { viewModel.addStep() } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Step")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }

        // Tools
        VStack(alignment: .leading, spacing: 8) {
            Text("Tools")
                .font(.subheadline.weight(.semibold))

            FlowLayout(spacing: 6) {
                ForEach(Array(viewModel.tools.enumerated()), id: \.offset) { index, tool in
                    HStack(spacing: 4) {
                        Text(tool)
                        Button { viewModel.removeTool(at: index) } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                }
            }

            TextField("Tool name", text: $viewModel.newToolName)
                .font(.subheadline)
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { viewModel.addTool() }

            Button { viewModel.addTool() } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Tool")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
