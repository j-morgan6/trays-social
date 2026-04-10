import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreatePostViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type picker
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
                            .background(Color.white.opacity(0.06))
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
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if viewModel.postType == .recipe {
                        recipeFields
                    }

                    // Tags
                    TextField("Tags (comma separated)", text: $viewModel.tags)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
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
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(viewModel.isPublishing)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("New \(viewModel.postType == .recipe ? "Recipe" : "Post")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading) {
                Text("Servings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("4", text: $viewModel.servings)
                    .keyboardType(.numberPad)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
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
                Button { viewModel.addIngredient() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .font(.subheadline)
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        // Steps
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .foregroundStyle(Theme.accent)
                    Text(step.description)
                    Spacer()
                    Button { viewModel.removeStep(at: index) } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
            }

            HStack {
                TextField("Describe the step", text: $viewModel.newStepText)
                Button { viewModel.addStep() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .font(.subheadline)
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            }

            HStack {
                TextField("Tool name", text: $viewModel.newToolName)
                Button { viewModel.addTool() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .font(.subheadline)
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
