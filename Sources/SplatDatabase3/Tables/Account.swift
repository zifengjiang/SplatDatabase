import Foundation
import GRDB
import SwiftyJSON

public struct Account:Codable,FetchableRecord,PersistableRecord{
  var id:Int64?
  var sp3Id:String?
  var avatar:Data?
  var name:String?
  var code:String?
  var sessionToken:String?
  var bulletToken:String?
  var accessToken:String?
  var country:String?
  var language:String?
  var lastRefresh:Date?

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
