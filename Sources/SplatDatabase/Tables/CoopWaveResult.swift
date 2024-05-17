import Foundation
import GRDB
import SwiftyJSON

public struct CoopWaveResult:Codable, FetchableRecord,PersistableRecord{
  var id: Int64?
  var waveNumber: Int
  var waterLevel: Int
  var eventWave: UInt16?
  var deliverNorm: Int?
  var goldenPopCount: Int
  var teamDeliverCount: Int?

  var coopId: Int64?

  public static let databaseTableName = "coopWaveResult"

  public init(json: JSON, bossId:String?, coopId: Int64? = nil, db:Database) {
    self.coopId = coopId
    self.waveNumber = json["waveNumber"].intValue
    self.waterLevel = json["waterLevel"].intValue
    if let bossId = bossId {
      self.eventWave = getI18nId(by: bossId, db: db)
    }else{
      self.eventWave = getI18nId(by: json["eventWave"]["id"].string, db: db)
    }
    self.deliverNorm = json["deliverNorm"].int
    self.goldenPopCount = json["goldenPopCount"].intValue
    self.teamDeliverCount = json["teamDeliverCount"].int
  }
}
