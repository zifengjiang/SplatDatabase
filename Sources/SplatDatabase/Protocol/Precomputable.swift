import Foundation
import GRDB
import Combine

public protocol PreComputable: FetchableRecord {
    associatedtype Identifier
    static func create(from db: Database, identifier: Identifier) throws -> Self?
    static func create(from db: Database, identifier: Identifier) throws -> [Self]
}

extension PreComputable {
    public static func create(from db: Database, identifier: Identifier) throws -> Self? {nil}

    public static func create(from db: Database, identifier: Identifier) throws -> [Self] {[]}
}

extension PreComputable {
    public static func fetchOne(identifier: Identifier) -> AnyPublisher<Self?, Error>{
        ValueObservation
            .tracking { db in
                try Self.create(from: db, identifier: identifier)
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
    
    public static func fetchAll(identifier: Identifier) -> AnyPublisher<[Self], Error>{
        ValueObservation
            .tracking { db in
                try Self.create(from: db, identifier: identifier)
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}


