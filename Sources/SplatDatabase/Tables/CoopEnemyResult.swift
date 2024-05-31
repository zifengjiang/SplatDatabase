import Foundation
import GRDB
import SwiftyJSON

public struct CoopEnemyResult:Codable, FetchableRecord, PersistableRecord{
    public var enemyId:UInt16
    public var defeatCount:Int
    public var teamDefeatCount:Int
    public var popCount:Int
    public var coopId:Int64?

    public var enemyImage: String? = nil
    public var enemyName: String? = nil

    public init(json:JSON, coopId:Int64, db:Database){
        self.coopId = coopId
        self.enemyId = getImageId(for:json["enemy"]["id"].stringValue, db: db)
        self.defeatCount = json["defeatCount"].intValue
        self.teamDefeatCount = json["teamDefeatCount"].intValue
        self.popCount = json["popCount"].intValue
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
