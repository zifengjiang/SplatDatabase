import Foundation
import GRDB
import SwiftyJSON

public struct CoopEnemyResult:Codable, FetchableRecord, PersistableRecord{
 public var enemyId:UInt16
 public var defeatCount:Int
 public var teamDefeatCount:Int
 public var popCount:Int
 public var coopId:Int64?

  public init(json:JSON, coopId:Int64, db:Database){
    self.coopId = coopId
    self.enemyId = getImageId(for:json["enemy"]["id"].stringValue, db: db)
    self.defeatCount = json["defeatCount"].intValue
    self.teamDefeatCount = json["teamDefeatCount"].intValue
    self.popCount = json["popCount"].intValue
  }
}
