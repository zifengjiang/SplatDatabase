import Foundation
import SwiftUI
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
    public var nameplate: PackableNumbers
    public var nameplateTextColor: PackableNumbers

    // MARK: - Coop Attributes
    public var uniformId: UInt16?

    // MARK: - Battle Attributes
    public var paint: Int?
    public var weapon: PackableNumbers?
    public var headGear: PackableNumbers
    public var clothingGear: PackableNumbers
    public var shoesGear: PackableNumbers
    public var crown: Bool?
    public var festDragonCert: String?
    public var festGrade: String?
    public var isMyself: Bool?

    // MARK: - Battle Result Attributes
    public var kill: Int?
    public var death: Int?
    public var assist: Int?
    public var special: Int?
    public var noroshiTry: Int?

    // MARK: - References to vsTeam
    public var vsTeamId: Int64?
    public var coopPlayerResultId: Int64?

    // MARK: - Database table name
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
        case weapon
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

    // MARK: - computed properties
    public var uniformName: String? = nil
    public var _nameplate: Nameplate? = nil
    public var _headGear:Gear? = nil
    public var _clothingGear:Gear? = nil
    public var _shoesGear:Gear? = nil
    public var _weapon: Weapon? = nil

    // MARK: - init from json
    public init(json: JSON, vsTeamId: Int64? = nil, coopPlayerResultId: Int64? = nil, db:Database) {
        self.coopPlayerResultId = coopPlayerResultId
        self.vsTeamId = vsTeamId
        self.sp3PrincipalId = json["id"].stringValue.extractPlayerId()
        self.byname = json["byname"].stringValue
        self.name = json["name"].stringValue
        self.nameId = json["nameId"].stringValue
        self.species = json["species"].stringValue == "INKLING"
        let nameplateBackground = getImageId(for: json["nameplate"]["background"]["id"].stringValue, db: db)
        let nameplateBadges = json["nameplate"]["badges"].arrayValue.map{
            getImageId(for:$0["id"].string, db: db)
        }

        self.nameplate = PackableNumbers([nameplateBackground,]+nameplateBadges)

        self.nameplateTextColor = json["nameplate"]["background"]["textColor"].dictionaryValue.toRGBPackableNumbers()

        if coopPlayerResultId != nil{
            self.uniformId = getImageId(for:json["uniform"]["id"].string, db: db)
        }

        self.paint = json["paint"].int
        if vsTeamId != nil{
            let weaponId = getImageId(for: json["weapon"]["id"].string,db: db)
            let weaponSpecial = getImageId(for: json["weapon"]["specialWeapon"]["id"].string,db: db)
            let weaponSub = getImageId(for: json["weapon"]["subWeapon"]["id"].string,db: db)
            self.weapon = PackableNumbers([weaponId, weaponSpecial, weaponSub])
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

        self.isCoop = self.uniformId != nil
    }
}

extension Player{
    public struct Weapon: Codable {
        let mainWeapon: ImageMap
        let specialWeapon: ImageMap
        let subWeapon: ImageMap

        init(with weapon: PackableNumbers, db: Database) {
            let mainWeaponId = weapon[0]
            let specialWeaponId = weapon[1]
            let subWeaponId = weapon[2]

            self.mainWeapon = try! ImageMap.fetchOne(db, key: mainWeaponId)!
            self.specialWeapon = try! ImageMap.fetchOne(db, key: specialWeaponId)!
            self.subWeapon = try! ImageMap.fetchOne(db, key: subWeaponId)!
        }
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
            rows[index]._nameplate = .init(nameplate: rows[index].nameplate, textColor: rows[index].nameplateTextColor, db: db)
            if !rows[index].isCoop{
                rows[index]._headGear  = .init(gear: rows[index].headGear, db: db)
                rows[index]._clothingGear  = .init(gear: rows[index].clothingGear, db: db)
                rows[index]._shoesGear  = .init(gear: rows[index].shoesGear, db: db)
                if let weapon = rows[index].weapon{
                    rows[index]._weapon = .init(with: weapon, db: db)
                }
            }
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
            row._nameplate = .init(nameplate: row.nameplate, textColor: row.nameplateTextColor, db: db)
            if !row.isCoop{
                row._headGear  = .init(gear: row.headGear, db: db)
                row._clothingGear  = .init(gear: row.clothingGear, db: db)
                row._shoesGear  = .init(gear: row.shoesGear, db: db)
                if let weapon = row.weapon{
                    row._weapon = .init(with: weapon, db: db)
                }
            }
            return row
        }
        return row
    }
}

public struct Nameplate {
    public let badges: [String?]
    public let background: String
    public let textColor: Color

    public init(nameplate: PackableNumbers, textColor: PackableNumbers, db: Database) {
        let nameplateId = nameplate[0]
        self.background = Nameplate.fetchName(db: db, key: nameplateId) ?? "Npl_Catalog_Season01_Lv01"

        self.badges = (1..<4).map { i in
            nameplate[i] == 0 ? nil : Nameplate.fetchName(db: db, key: nameplate[i])
        }

        self.textColor = textColor.toColor()
    }

    private static func fetchName(db: Database, key: UInt16) -> String? {
        return try? ImageMap.fetchOne(db, key: key)?.name
    }
}
public struct Gear {
    public let gear: String
    public let gearName: String
    public let primaryPower: String
    public let additionalPowers: [String]

    public init(gear: PackableNumbers, db: Database) {
        let gearId = gear[0]
        let primaryPowerId = gear[1]
        let additionalPowerIds = (2..<5).map { gear[$0] }

        guard let gearRow = try? ImageMap.fetchOne(db, key: gearId) else {
            fatalError("Failed to fetch gear row for gearId \(gearId)")
        }
        self.gear = gearRow.name
        self.gearName = gearRow.hash

        guard let primaryPowerRow = try? ImageMap.fetchOne(db, key: primaryPowerId) else {
            fatalError("Failed to fetch primary power for primaryPowerId \(primaryPowerId)")
        }
        self.primaryPower = primaryPowerRow.name

        self.additionalPowers = additionalPowerIds.compactMap { id in
            guard id != 0, let additionalPowerRow = try? ImageMap.fetchOne(db, key: id) else {
                return nil
            }
            return additionalPowerRow.name
        }
    }
}

