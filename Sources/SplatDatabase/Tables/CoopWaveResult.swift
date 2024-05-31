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

    // MARK: - computed properties
    public var eventName:String? = nil
    public var usedSpecialWeapons:[String]? = nil

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case waveNumber
        case waterLevel
        case eventWave
        case deliverNorm
        case goldenPopCount
        case teamDeliverCount
        case coopId
    }

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

extension CoopWaveResult: PreComputable {
    public static func create(from db: Database, identifier: Int64) throws -> [CoopWaveResult] {
        var rows = try CoopWaveResult
            .filter(Column("coopId") == identifier)
            .fetchAll(db)

        for index in rows.indices {
            let event = try I18n.fetchOne(db, key: rows[index].eventWave)
            rows[index].eventName = try String.fetchOne(db, sql:"SELECT key FROM i18n WHERE id = ?", arguments: [rows[index].eventWave])
            rows[index].usedSpecialWeapons = try String.fetchAll(db, sql: """
                SELECT
                    imageMap.'name'
                FROM
                    weapon
                JOIN coopWaveResult ON coopWaveResult.id = weapon.coopWaveResultId
                JOIN imageMap ON weapon.imageMapId = imageMap.id
                WHERE
                    coopWaveResultId = ?
                ORDER BY
                    weapon.'order'
                """, arguments: [rows[index].id])
        }
        return rows
    }
}

