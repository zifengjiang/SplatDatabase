import Foundation
import GRDB
import Combine

public protocol PreComputable: FetchableRecord {
    associatedtype Identifier
    static func create(from db: Database, identifier: Identifier) throws -> Self?
}

extension PreComputable {
    public static func fetch(identifier: Identifier) -> AnyPublisher<Self?, Error>{
        ValueObservation
            .tracking { db in
                try Self.create(from: db, identifier: identifier)
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}


