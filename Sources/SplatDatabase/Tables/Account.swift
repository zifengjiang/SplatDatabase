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
