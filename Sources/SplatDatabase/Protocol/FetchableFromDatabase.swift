import Foundation
import GRDB
import Combine

public protocol FetchableFromDatabase: FetchableRecord, Decodable {
    static func fetchRequest(accountId: Int, groupId: Int) -> SQLRequest<Row>
}

extension FetchableFromDatabase {
    public static func fetchAll(accountId: Int,  groupId: Int) -> AnyPublisher<[Self], Error>{
        ValueObservation
            .tracking { db in
                try Self.fetchAll(db, Self.fetchRequest(accountId: accountId, groupId: groupId))
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
