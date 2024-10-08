import Foundation
import GRDB
import SwiftyJSON

public struct CoopEnemyResult:Codable, FetchableRecord, PersistableRecord{
    public var enemyId:UInt16
    public var defeatCount:Int
    public var teamDefeatCount:Int
    public var popCount:Int
    public var isBoss: Bool = false
    public var coopId:Int64?
    
    // MARK: - computed properties
    public var enemyImage: String? = nil
    public var enemyName: String? = nil

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case enemyId
        case defeatCount
        case teamDefeatCount
        case popCount
        case coopId
        case isBoss
    }

    public init(json:JSON, coopId:Int64, db:Database){
        self.coopId = coopId
        self.enemyId = getImageId(for:json["enemy"]["id"].stringValue, db: db)
        self.defeatCount = json["defeatCount"].intValue
        self.teamDefeatCount = json["teamDefeatCount"].intValue
        self.popCount = json["popCount"].intValue
    }

    public init(json:JSON, coopId:Int64,hasDefeated:Bool, db:Database){
        self.coopId = coopId
        self.enemyId = getImageId(for:json["boss"]["id"].stringValue, db: db)
        self.defeatCount = hasDefeated ? 1 : 0
        self.teamDefeatCount = hasDefeated ? 1 : 0
        self.popCount = 1
        self.isBoss = true
    }
}

extension CoopEnemyResult: PreComputable {
    public static func create(from db: Database, identifier: Int64) throws -> [CoopEnemyResult] {
        var rows = try CoopEnemyResult
            .filter(Column("coopId") == identifier)
            .fetchAll(db)

        for index in rows.indices {
            let image = try ImageMap.fetchOne(db, key: rows[index].enemyId)
            rows[index].enemyImage = image?.name
            rows[index].enemyName = image?.nameId
        }
        return rows
    }

}
