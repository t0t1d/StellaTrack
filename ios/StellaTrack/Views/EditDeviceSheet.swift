import SwiftUI

struct EditDeviceSheet: View {
    @ObservedObject var device: TrackedDevice
    @Binding var isPresented: Bool

    @State private var nameDraft: String = ""
    @State private var selectedIcon: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: selectedIcon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.blue)
                }
                .padding(.top, 20)

                TextField("Device Name", text: $nameDraft)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(TrackedDevice.iconSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                    ForEach(section.icons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedIcon == icon ? Color.blue.opacity(0.15) : Color(.systemGray6))
                                                    .frame(height: 56)
                                                Image(systemName: icon)
                                                    .font(.system(size: 22))
                                                    .foregroundStyle(selectedIcon == icon ? Color.blue : Color.primary)
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Edit Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            device.name = trimmed
                        }
                        device.setIcon(selectedIcon)
                        isPresented = false
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .onAppear {
                nameDraft = device.name
                selectedIcon = device.icon
            }
        }
    }
}
