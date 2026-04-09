import SwiftUI

struct BLELogView: View {
    @ObservedObject private var log = BLEDebugLog.shared

    var body: some View {
        List {
            if log.entries.isEmpty {
                Text("No BLE events yet. Try scanning and pairing a device.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(log.entries) { entry in
                    Text(entry.formatted)
                        .font(.system(size: 11, design: .monospaced))
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("BLE Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        log.clear()
                    } label: {
                        Label("Clear Log", systemImage: "trash")
                    }
                    ShareLink(item: logText) {
                        Label("Copy Log", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var logText: String {
        log.entries.map(\.formatted).joined(separator: "\n")
    }
}
