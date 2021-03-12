import Foundation

extension UUID {
    var lowerString: String {
        uuidString.lowercased()
    }
}

extension UUID: Comparable {
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        lhs.hashValue < rhs.hashValue
    }
}
