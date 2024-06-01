import Foundation
import SwiftyJSON
import GRDB

public struct ImageMap:Codable, FetchableRecord, PersistableRecord{
    public var id:Int64?
    public var nameId:String
    public var name:String
    public var hash:String

    public init(id: Int64? = nil, nameId: String, name: String, hash: String) {
        self.id = id
        self.nameId = nameId
        self.name = name
        self.hash = hash
    }
}

public func getImageId(for nameId:String? = nil,hash:String? = nil, db:Database) -> UInt16 {
    if let nameId = nameId {
        let row = try! Row.fetchOne(db, sql: "SELECT id FROM imageMap WHERE nameId = ?",arguments:[nameId])
        return row?["id"] ?? 0
    }
    if let hash = hash {
        let row = try! Row.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?",arguments:[hash])
        if let id:UInt16 = row?["id"]{
            return id
        }
        return 0
    }
    return 0
}

public func getImageName(by id: UInt16, db:Database) -> String {
    let row = try! Row.fetchOne(db, sql: "SELECT name FROM imageMap WHERE id = ?",arguments:[id])
    return row?["name"] ?? ""
}

public func getImageNameId(by id:UInt16,db:Database) -> String{
    let row = try! Row.fetchOne(db, sql: "SELECT nameId FROM imageMap WHERE id = ?",arguments:[id])
    return row?["nameId"] ?? ""
}

extension SplatDatabase {
    public func updateImageMap(db: Database) throws {
            // unknown
        for un in getUnknownMap() {
            try un.insert(db, onConflict: .ignore)
        }

            // Update badges
        try fetchMapAndInsert(
            from: Splat3URLs.badge.filePath(),
            using: getBadgeMap,
            insertFunction: { badge, db in
                if try ImageMap.filter(Column("nameId") == badge.nameId).fetchOne(db) == nil {
                    try badge.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update main weapons
        try fetchMapAndInsert(
            from: Splat3URLs.weaponMain.filePath(),
            using: getWeaponMainMap,
            insertFunction: { weapon, db in
                if try ImageMap.filter(Column("nameId") == weapon.nameId).fetchOne(db) == nil {
                    try weapon.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update special weapons
        try fetchMapAndInsert(
            from: Splat3URLs.weaponSpecial.filePath(),
            using: { json in getWeaponSubspe(from: json, prefix: "Special") },
            insertFunction: { special, db in
                if try ImageMap.filter(Column("nameId") == special.nameId).fetchOne(db) == nil {
                    try special.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update sub weapons
        try fetchMapAndInsert(
            from: Splat3URLs.weaponSub.filePath(),
            using: { json in getWeaponSubspe(from: json, prefix: "Sub") },
            insertFunction: { sub, db in
                if try ImageMap.filter(Column("nameId") == sub.nameId).fetchOne(db) == nil {
                    try sub.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update nameplate background
        try fetchMapAndInsert(
            from: Splat3URLs.nameplate.filePath(),
            using: getNameplateMap,
            insertFunction: { nameplate, db in
                if try ImageMap.filter(Column("nameId") == nameplate.nameId).fetchOne(db) == nil {
                    try nameplate.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update gears
        let gears: [Splat3URLs] = [.head, .clothes, .shoes]
        for gear in gears {
            try fetchMapAndInsert(
                from: gear.filePath(),
                using: getGearMap,
                insertFunction: { gear, db in
                    if try ImageMap.filter(Column("nameId") == gear.nameId).fetchOne(db) == nil {
                        try gear.insert(db, onConflict: .ignore)
                    }
                },
                db: db
            )
        }

            // Update enemy
        try fetchMapAndInsert(
            from: Splat3URLs.enemy.filePath(),
            using: getCoopEnemyMap,
            insertFunction: { enemy, db in
                if try ImageMap.filter(Column("nameId") == enemy.nameId).fetchOne(db) == nil {
                    try enemy.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update skin
        try fetchMapAndInsert(
            from: Splat3URLs.skin.filePath(),
            using: getCoopSkinMap,
            insertFunction: { skin, db in
                if try ImageMap.filter(Column("nameId") == skin.nameId).fetchOne(db) == nil {
                    try skin.insert(db, onConflict: .ignore)
                }
            },
            db: db
        )

            // Update stage
        let stages: [Splat3URLs: String] = [.coopStage: "Coop", .vsStage: "Vs"]
        for (url, mode) in stages {
            try fetchMapAndInsert(
                from: url.filePath(),
                using: { json in getStageMap(from: json, prefix: mode) },
                insertFunction: { stage, db in
                    if try ImageMap.filter(Column("nameId") == stage.nameId).fetchOne(db) == nil {
                        try stage.insert(db, onConflict: .ignore)
                    }
                },
                db: db
            )
        }
    }

    
        /// General function to fetch, map, and insert data
    private func fetchMapAndInsert<T>(
        from url: String,
        using mapFunction: (JSON) -> [T],
        insertFunction: @escaping (T, Database) throws -> Void,
        db: Database
    ) throws {
        let json = JSON(parseJSON: try String(contentsOfFile: url))
        let items = mapFunction(json)
        for item in items {
            try insertFunction(item, db)
        }
    }

}
