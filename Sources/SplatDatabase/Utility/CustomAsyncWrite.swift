import Foundation
import GRDB

extension DatabaseWriter {
    public func customAsyncWrite<T>(
        _ updates: @escaping (Database) throws -> T,
        completion: @escaping (Database, Result<T, Error>) -> Void)
    {
        asyncWriteWithoutTransaction { db in
            do {
                var result: T?

                result = try updates(db)

                completion(db, .success(result!))
            } catch {
                completion(db, .failure(error))
            }
        }
    }
}
