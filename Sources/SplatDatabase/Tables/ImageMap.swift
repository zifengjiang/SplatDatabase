import Foundation
import SwiftyJSON
import GRDB

public struct ImageMap:Codable, FetchableRecord, PersistableRecord{
    var id:Int64?
    var nameId:String
    var name:String
    var hash:String

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

extension SplatDatabase {
    public func updateImageMap() throws{
            // unknown
        try self.dbQueue.writeInTransaction { db in
            do{
                for un in getUnknownMap(){
                    try un.insert(db)
                }
                return .commit
            }catch{
                return .rollback
            }
        }

            // Update badges
        try fetchMapAndInsert(
            from: Splat3URLs.badge.filePath(),
            using: getBadgeMap,
            insertFunction: { badge, db in
                try badge.insert(db)
            }
        )

            // Update main weapons
        try fetchMapAndInsert(
            from: Splat3URLs.weaponMain.filePath(),
            using: getWeaponMainMap,
            insertFunction: { weapon, db in
                try weapon.insert(db)
            }
        )

            // Update special weapons
        try fetchMapAndInsert(
            from: Splat3URLs.weaponSpecial.filePath(),
            using: { json in getWeaponSubspe(from: json, prefix: "Special") },
            insertFunction: { special, db in
                try special.insert(db)
            }
        )

            // Update sub weapons
        try fetchMapAndInsert(
            from: Splat3URLs.weaponSub.filePath(),
            using: { json in getWeaponSubspe(from: json, prefix: "Sub") },
            insertFunction: { sub, db in
                try sub.insert(db)
            }
        )

            /// nameplate background
        try fetchMapAndInsert(
            from: Splat3URLs.nameplate.filePath(),
            using: getNameplateMap,
            insertFunction: { nameplate, db in
                try nameplate.insert(db)
            }
        )

            /// gears
        let gears:[Splat3URLs] = [.head, .clothes, .shoes]
        for gear in gears{
            try fetchMapAndInsert(
                from: gear.filePath(),
                using: getGearMap,
                insertFunction: { gear, db in
                    try gear.insert(db)
                }
            )
        }

            /// enemy
        try fetchMapAndInsert(
            from: Splat3URLs.enemy.filePath(),
            using: getCoopEnemyMap,
            insertFunction: { enemy, db in
                try enemy.insert(db)
            }
        )

            /// skin
        try fetchMapAndInsert(
            from: Splat3URLs.skin.filePath(),
            using: getCoopSkinMap,
            insertFunction: { skin, db in
                try skin.insert(db)
            }
        )

            /// stage
        let stages:[Splat3URLs:String] = [.coopStage:"Coop", .vsStage:"Vs"]
        for (url,mode) in stages{
            try fetchMapAndInsert(
                from: url.filePath(),
                using: { json in getStageMap(from: json, prefix:  mode) },
                insertFunction: { stage, db in
                    try stage.insert(db)
                }
            )
        }

    }

        /// Function to insert items into the database
    private func insertItems<T>(_ items: [T], using insertFunction: (T, Database) throws -> Void) throws {
        for item in items {
            try dbQueue.writeInTransaction { db in
                do {
                    try insertFunction(item, db)
                    return .commit
                } catch {
                    return .rollback
                }
            }
        }
    }

        /// General function to fetch, map, and insert data
    private func fetchMapAndInsert<T>(
        from url: String,
        using mapFunction: (JSON) -> [T],
        insertFunction: @escaping (T, Database) throws -> Void
    ) throws {
        let json = JSON(parseJSON: try String(contentsOfFile: url))
        let items = mapFunction(json)
        try insertItems(items, using: insertFunction)
    }
}
