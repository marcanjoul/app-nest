import Foundation
import SwiftData

@Model
class JobCycle {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \JobApplication.cycle)
    var applications: [JobApplication] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
