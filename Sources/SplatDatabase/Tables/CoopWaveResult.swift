import Foundation
import GRDB
import SwiftyJSON

public struct CoopWaveResult:Codable, FetchableRecord,PersistableRecord{
    public var id: Int64?
    public var waveNumber: Int
    public var waterLevel: Int
    public var eventWave: UInt16?
    public var deliverNorm: Int?
    public var goldenPopCount: Int
    public var teamDeliverCount: Int?
    
    public var coopId: Int64?
    
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
