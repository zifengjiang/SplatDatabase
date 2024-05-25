import Foundation
import GRDB
import SwiftyJSON

public struct Account:Codable,FetchableRecord,PersistableRecord{
    public var id:Int64?
    public var sp3Id:String?
    public var avatar:Data?
    public var name:String?
    public var code:String?
    public var sessionToken:String?
    public var lastRefresh:Date?

    public init(id: Int64? = nil, sp3Id: String? = nil, avatar: Data? = nil, name: String? = nil, code: String? = nil, sessionToken: String? = nil, lastRefresh: Date? = nil) {
        self.id = id
        self.sp3Id = sp3Id
        self.avatar = avatar
        self.name = name
        self.code = code
        self.sessionToken = sessionToken
        self.lastRefresh = lastRefresh
    }
}

func getAccountId(by sp3ID:String,db:Database) -> Int64{
    let row = try! Row.fetchOne(db, sql: "SELECT id FROM account WHERE sp3Id = ?",arguments:[sp3ID])
    return row?["id"] ?? 0
}

extension SplatDatabase {
    func insertAccount(id:String) throws{
        var account = Account()
        account.sp3Id = id
        try dbQueue.writeInTransaction { db in
            do{
                try account.insert(db)
                return .commit
            }catch{
                return .rollback
            }
        }
    }
}
