import Foundation
import GRDB
import SwiftyJSON

public struct CoopPlayerResult:Codable, FetchableRecord,PersistableRecord{
    public var id:Int64?
    public var order:Int
    public var specialWeaponId:UInt16?
    public var defeatEnemyCount:Int
    public var deliverCount:Int
    public var goldenAssistCount:Int
    public var goldenDeliverCount:Int
    public var rescueCount:Int
    public var rescuedCount:Int
    public var coopId:Int64?

    // MARK: - computed properties
    public var player: Player? = nil
    public var specialWeaponName: String? = nil
    public var weapons:[String]? = nil

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case order
        case specialWeaponId
        case defeatEnemyCount
        case deliverCount
        case goldenAssistCount
        case goldenDeliverCount
        case rescueCount
        case rescuedCount
        case coopId
    }

    public init(json:JSON, order:Int, coopId:Int64,db:Database){
        self.coopId = coopId
        self.order = order
        let specialWeaponId = getImageId(hash:json["specialWeapon"]["image"]["url"].string?.getImageHash(),db: db)
        if specialWeaponId == 0{
            self.specialWeaponId = nil
        }else{
            self.specialWeaponId = UInt16(specialWeaponId)
        }
        self.defeatEnemyCount = json["defeatEnemyCount"].intValue
        self.deliverCount = json["deliverCount"].intValue
        self.goldenAssistCount = json["goldenAssistCount"].intValue
        self.goldenDeliverCount = json["goldenDeliverCount"].intValue
        self.rescueCount = json["rescueCount"].intValue
        self.rescuedCount = json["rescuedCount"].intValue
    }
}

extension CoopPlayerResult: PreComputable {
    public static func create(from db: Database, identifier: Int64) throws -> [CoopPlayerResult] {
        var rows = try CoopPlayerResult
            .filter(Column("coopId") == identifier)
            .fetchAll(db)

        for index in rows.indices {
            rows[index].player = try Player.create(from: db, identifier: (rows[index].id!, "coopPlayerResultId"))
            let specialWeapon = try ImageMap.fetchOne(db, key: rows[index].specialWeaponId)
            rows[index].specialWeaponName = specialWeapon?.name
            rows[index].weapons = try String.fetchAll(db, sql: """
                                            SELECT
                                                imageMap.'name'
                                            FROM
                                                weapon
                                            JOIN coopPlayerResult ON coopPlayerResult.id = weapon.coopPlayerResultId
                                            JOIN imageMap ON weapon.imageMapId = imageMap.id
                                            WHERE
                                                coopPlayerResultId = ?
                                            ORDER BY
                                                weapon.'order'
            """, arguments: [rows[index].id])
        }
        return rows
    }

}
