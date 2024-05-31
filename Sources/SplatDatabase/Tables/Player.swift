import Foundation
import GRDB
import SwiftyJSON

    /// struct for player table
public struct Player: Codable, FetchableRecord, PersistableRecord {
    public var id: Int64?
    public var isCoop: Bool

    // Common Attributes
    public var sp3PrincipalId: String
    public var byname: String
    public var name: String
    public var nameId: String
    public var species: Bool
    @Packable public var nameplate: PackableNumbers
    @Packable public var nameplateTextColor: PackableNumbers

    // Coop Attributes
    public var uniformId: UInt16?

    // MARK: - computed properties
    public var uniformName: String? = nil

    // Battle Attributes
    public var paint: Int?
    public var weaponId: UInt16?
    @Packable public var headGear: PackableNumbers
    @Packable public var clothingGear: PackableNumbers
    @Packable public var shoesGear: PackableNumbers
    public var crown: Bool?
    public var festDragonCert: String?
    public var festGrade: String?
    public var isMyself: Bool?

    // Battle Result Attributes
    public var kill: Int?
    public var death: Int?
    public var assist: Int?
    public var special: Int?
    public var noroshiTry: Int?

    // References to vsTeam
    public var vsTeamId: Int64?
    public var coopPlayerResultId: Int64?

    // Database table name
    public static let databaseTableName = "player"

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case isCoop
        case sp3PrincipalId
        case byname
        case name
        case nameId
        case species
        case nameplate
        case nameplateTextColor
        case uniformId
        case paint
        case weaponId
        case headGear
        case clothingGear
        case shoesGear
        case crown
        case festDragonCert
        case festGrade
        case isMyself
        case kill
        case death
        case assist
        case special
        case noroshiTry
        case vsTeamId
        case coopPlayerResultId
    }

    // MARK: - init from json
    public init(json: JSON, vsTeamId: Int64? = nil, coopPlayerResultId: Int64? = nil, db:Database) {
        self.coopPlayerResultId = coopPlayerResultId
        self.vsTeamId = vsTeamId
        self.sp3PrincipalId = json["id"].stringValue.extractUserId()
        self.byname = json["byname"].stringValue
        self.name = json["name"].stringValue
        self.nameId = json["nameId"].stringValue
        self.species = json["species"].stringValue == "INKLING"
        let nameplateBackground = getImageId(for: json["nameplate"]["background"]["id"].stringValue, db: db)
        let nameplateBadge1 = getImageId(for: json["nameplate"]["badges"][0]["id"].string,db: db)
        let nameplateBadge2 = getImageId(for: json["nameplate"]["badges"][1]["id"].string,db: db)
        let nameplateBadge3 = getImageId(for: json["nameplate"]["badges"][2]["id"].string,db: db)

        self.nameplate = PackableNumbers([nameplateBackground,nameplateBadge1, nameplateBadge2, nameplateBadge3])

        self.nameplateTextColor = json["nameplate"]["background"]["textColor"].dictionaryValue.toRGBPackableNumbers()

        if coopPlayerResultId != nil{
            self.uniformId = getImageId(for:json["uniform"]["id"].string, db: db)
        }

        self.paint = json["paint"].int
        if vsTeamId != nil{
            self.weaponId = getImageId(for: json["weapon"]["id"].string,db: db)
        }
        self.headGear = json["headGear"].dictionary?.toGearPackableNumbers(db: db) ?? PackableNumbers([0])
        self.clothingGear = json["clothingGear"].dictionary?.toGearPackableNumbers(db: db) ?? PackableNumbers([0])
        self.shoesGear = json["shoesGear"].dictionary?.toGearPackableNumbers(db: db) ?? PackableNumbers([0])
        self.crown = json["crown"].bool
        self.festDragonCert = json["festDragonCert"].string
        self.festGrade = json["festGrade"].string
        self.isMyself = json["isMyself"].bool

        self.kill = json["result"]["kill"].int
        self.death = json["result"]["death"].int
        self.assist = json["result"]["assist"].int
        self.special = json["result"]["special"].int
        self.special = json["result"]["special"].int

            //    self.vsTeamId = 00
        self.isCoop = self.uniformId != nil
    }
}

extension Player: PreComputable {
    public static func create(from db: Database, identifier: (Int64, String)) throws -> [Player] {
        let (id, column) = identifier
        var rows = try Player
            .filter(Column(column) == id)
            .fetchAll(db)

        for index in rows.indices {
            let uniform = try ImageMap.fetchOne(db, key: rows[index].uniformId)
            rows[index].uniformName = uniform?.name
        }
        return rows
    }

    public static func create(from db: Database, identifier: (Int64, String)) throws -> Player? {
        let (id, column) = identifier
        let row = try Player
            .filter(Column(column) == id)
            .fetchOne(db)

        if var row = row {
            row.uniformName = try ImageMap.fetchOne(db, key: row.uniformId)?.name
            return row
        }
        return row
    }
}





