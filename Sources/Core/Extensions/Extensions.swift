import Foundation

// MARK: - String Extensions

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func truncated(to limit: Int, trailing: String = "…") -> String {
        count > limit ? String(prefix(limit)) + trailing : self
    }
}

// MARK: - Date Extensions

extension Date {
    func formatted(style: DateFormatter.Style = .medium) -> String {
        DateFormatter.localizedString(from: self, dateStyle: style, timeStyle: .none)
    }

    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - Collection Extensions

extension Collection {
    var isNotEmpty: Bool { !isEmpty }

    func safe(_ index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
