import Swift

enum AnnouncerAnnouncementFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pending = "Pending"
    case approved = "Approved"
    case active = "Active"
    case declined = "Declined"
    case expired = "Expired"
    
    var id: String { rawValue }
    
    /// Map UI filter → actual model status
    var status: AnnouncementStatus? {
        switch self {
        case .all:
            return nil
        case .pending:
            return .pending
        case .approved:
            return .approved
        case .active:
            return .active
        case .declined:
            return .declined
        case .expired:
            return .expired
        }
    }
}
