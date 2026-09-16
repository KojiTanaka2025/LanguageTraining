import Foundation
import SwiftUI

/// A named, colored tag stored in the library (`cards.xml`) and assigned to cards.
struct LibraryTag: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// Hex RGB without `#`, e.g. `2563EB`.
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = LibraryTag.normalizedName(name)
        self.colorHex = LibraryTag.normalizedColor(colorHex)
    }

    var color: Color {
        Color(hex: colorHex) ?? Color.secondary
    }

    static let uncategorizedID = ""
    static let uncategorizedLabel = "未分類"
    static let allFilterID = "__all__"
    static let allFilterLabel = "すべて"
    static let defaultColorHex = "57534E"

    /// Suggested colors for new tags.
    static let palette: [String] = [
        "2563EB", // blue
        "16A34A", // green
        "DC2626", // red
        "D97706", // amber
        "7C3AED", // violet
        "0891B2", // cyan
        "DB2777", // pink
        "57534E", // stone
    ]

    static let builtInDefaults: [LibraryTag] = [
        LibraryTag(
            id: UUID(uuidString: "A1111111-1111-4111-8111-111111111111")!,
            name: "仕事用",
            colorHex: "2563EB"
        ),
        LibraryTag(
            id: UUID(uuidString: "A2222222-2222-4222-8222-222222222222")!,
            name: "日常会話",
            colorHex: "16A34A"
        ),
    ]

    static func normalizedName(_ name: String?) -> String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func normalizedColor(_ hex: String?) -> String {
        let cleaned = (hex ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard cleaned.count == 6,
              cleaned.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEF").contains($0) }) else {
            return defaultColorHex
        }
        return cleaned
    }

    static func displayName(_ tagName: String) -> String {
        let trimmed = normalizedName(tagName)
        return trimmed.isEmpty ? uncategorizedLabel : trimmed
    }

    /// Merge catalog entries and names already used on cards (no forced built-ins).
    static func mergedCatalog(existing: [LibraryTag], usedNames: [String], extras: [LibraryTag] = []) -> [LibraryTag] {
        var byName: [String: LibraryTag] = [:]
        for tag in existing + extras {
            let name = normalizedName(tag.name)
            guard !name.isEmpty else { continue }
            if byName[name] == nil {
                byName[name] = LibraryTag(id: tag.id, name: name, colorHex: tag.colorHex)
            }
        }
        for raw in usedNames {
            let name = normalizedName(raw)
            guard !name.isEmpty, byName[name] == nil else { continue }
            byName[name] = LibraryTag(name: name, colorHex: defaultColorHex)
        }
        var seen = Set<String>()
        var result: [LibraryTag] = []
        for tag in existing + extras {
            let key = normalizedName(tag.name)
            guard !key.isEmpty, !seen.contains(key), let resolved = byName[key] else { continue }
            seen.insert(key)
            result.append(resolved)
        }
        for raw in usedNames {
            let key = normalizedName(raw)
            guard !key.isEmpty, !seen.contains(key), let resolved = byName[key] else { continue }
            seen.insert(key)
            result.append(resolved)
        }
        return result
    }
}

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct TagSwatch: View {
    let colorHex: String
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex) ?? Color.secondary)
            .frame(width: size, height: size)
    }
}

struct TagLabel: View {
    let name: String
    let colorHex: String
    var font: Font = .caption2

    var body: some View {
        HStack(spacing: 5) {
            TagSwatch(colorHex: colorHex, size: 8)
            Text(LibraryTag.displayName(name))
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct NewTagSheet: View {
    @Binding var isPresented: Bool
    var title: String = "New Tag"
    var onCreate: (String, String) -> Bool

    @State private var name = ""
    @State private var colorHex = LibraryTag.palette[0]
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tag name", text: $name)
                    .onSubmit(create)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(LibraryTag.palette, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .secondary)
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if colorHex == hex {
                                            Circle()
                                                .strokeBorder(.primary, lineWidth: 2)
                                                .padding(-3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(hex)
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        create()
                    }
                    .disabled(LibraryTag.normalizedName(name).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 220)
        #endif
    }

    private func create() {
        let trimmed = LibraryTag.normalizedName(name)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a tag name."
            return
        }
        guard onCreate(trimmed, colorHex) else {
            errorMessage = "“\(trimmed)” already exists."
            return
        }
        isPresented = false
    }
}

/// Compatibility alias used while migrating from the previous category naming.
typealias CardCategory = LibraryTag
