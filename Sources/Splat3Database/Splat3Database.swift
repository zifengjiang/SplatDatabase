// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB
import SwiftyJSON

public class DatabaseManager {
  public static let shared = DatabaseManager()

  public var dbQueue: DatabasePool!

  /// Function to export the current database to a specified location
  public func exportDatabase(to destinationPath: URL? = nil) throws -> URL {
      guard let dbQueue = dbQueue else {
          throw NSError(domain: "DatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])
      }

      // Get the path to the current database file
      let dbPath = dbQueue.path

      // Determine the destination path
      let fileManager = FileManager.default
      let destinationFileName = "Splat3Database_copy.sqlite"
      var destinationURL = destinationPath ?? fileManager.temporaryDirectory.appendingPathComponent(destinationFileName)

      // Check if destinationPath is a directory and append the default file name if it is
      var isDir: ObjCBool = false
      if let path = destinationPath?.path, fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
          destinationURL = destinationPath!.appendingPathComponent(destinationFileName)
      }

      // Remove any existing file at the destination
      if fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.removeItem(at: destinationURL)
      }

      // Perform the export by copying the file
      try fileManager.copyItem(atPath: dbPath, toPath: destinationURL.path)

      return destinationURL
  }


  public func createDatabase(path:String? = nil) throws {
    if let path = path {
      dbQueue = try DatabasePool(path: path)
      try dbQueue.write { db in
        try setupSchema(db: db)
      }
      return
    }
    let databaseURL = try FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("Splat3Database.sqlite")
    
    dbQueue = try DatabasePool(path: databaseURL.path)

    try dbQueue.write { db in
      // 定义数据库模式
      try setupSchema(db: db)
    }
  }

  public init() {
    do {
      try createDatabase()
    } catch {
      print("Failed to create database: \(error)")
    }
  }

  private func setupSchema(db: Database) throws {
    try db.create(table: "coop",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")
      t.column("rule", .text).notNull()
      t.column("sp3PrincipalId", .text).notNull()
      t.column("bossResult", .text) // true_{boss_name} or false_{boss_name}, null means no boss
      t.column("resultWave", .integer).notNull()
      t.column("stage", .text).notNull()
      t.column("afterGrade", .text)
      t.column("afterGradePoint", .integer)
      t.column("afterGradeDiff", .integer)
      t.column("preDetailId", .text)
      t.column("goldScale", .integer)
      t.column("silverScale", .integer)
      t.column("bronzeScale", .integer)
      t.column("jobPoint", .integer)
      t.column("jobScore", .integer)
      t.column("jobRate", .double)
      t.column("jobBonus", .integer)
      t.column("playedTime", .datetime).notNull()
      t.column("dangerRate", .double).notNull()

    }

    try db.create(table: "weapon",ifNotExists: true) { t in
      t.column("imageMapId", .integer).notNull().references("imageMap", column: "id")
      t.column("order", .integer).notNull().defaults(to: 0)
      t.column("coopId", .integer).references("coop", column: "id") // shift weapons
      t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id") // player weapons
      t.column("coopWaveResultId", .integer).references("coopWaveResult", column: "id")
    }

    try db.create(table: "coopPlayerResult",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")
      t.column("order",.integer).notNull()
      t.column("specialWeaponId", .integer).references("imageMap", column: "id")
      t.column("defeatEnemyCount", .integer).notNull()
      t.column("deliverCount", .integer).notNull()
      t.column("goldenAssistCount", .integer).notNull()
      t.column("goldenDeliverCount", .integer).notNull()
      t.column("rescueCount", .integer).notNull()
      t.column("rescuedCount", .integer).notNull()

      t.column("coopId", .integer).references("coop", column: "id")
    }

    try db.create(table: "coopWaveResult",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")

      t.column("waveNumber", .integer).notNull()
      t.column("waterLevel", .integer).notNull()
      t.column("eventWave", .text)
      t.column("deliverNorm", .integer)
      t.column("goldenPopCount", .integer).notNull()
      t.column("teamDeliverCount", .integer)

      t.column("coopId", .integer).references("coop", column: "id")
    }

    try db.create(table: "coopEnemyResult",ifNotExists: true) { t in
      t.column("enemyId", .integer).references("imageMap", column: "id")
      t.column("teamDefeatCount", .text).notNull()
      t.column("defeatCount", .integer).notNull()
      t.column("popCount", .integer).notNull()

      t.column("coopId", .integer).references("coop", column: "id")
    }

    try db.create(table: "player",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")
      t.column("type",.boolean).notNull() // true for coop, false for battle

      /// Common Attributes
      t.column("sp3PrincipalId", .text).notNull()
      t.column("byname", .text).notNull()
      t.column("name", .text).notNull()
      t.column("nameId", .text).notNull()
      t.column("species", .boolean).notNull() // true for octoling, false for inkling
      t.column("nameplate", .integer).notNull()
      t.column("nameplateTextColor", .integer).notNull()

      /// Coop Attributes
      t.column("uniformId", .integer).references("imageMap",column: "id")

      /// Battle Attributes
      t.column("paint", .integer)
      t.column("weaponId", .integer).references("imageMap", column: "id")
      t.column("headGear", .integer)
      t.column("clothingGear", .integer)
      t.column("shoesGear", .integer)
      t.column("crown", .boolean)
      t.column("festDragonCert", .text)
      t.column("festGrade", .text)
      t.column("isMyself", .boolean)

      /// Battle Result Attributes
      t.column("kill", .integer)
      t.column("death", .integer)
      t.column("assist", .integer)
      t.column("special", .integer)
      t.column("noroshiTry", .integer)

      t.column("vsTeamId", .integer).references("vsTeam", column: "id")
      t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id")
    }

    try db.create(table: "vsTeam",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")
      t.column("order", .integer).notNull() // 0 is my team
      t.column("color", .integer).notNull()
      t.column("judgement", .text)

      /// Team Result Attributes
      t.column("paintPoint", .integer)
      t.column("paintRatio", .double)
      t.column("score", .integer)
      t.column("noroshi", .integer)

      t.column("tricolorRole",.text)
      t.column("festTeamName", .text)
      t.column("festUniformName",.text)
      t.column("festUniformBonusRate", .double)
      t.column("festStreakWinCount", .integer)

      t.column("battleId", .integer).references("battle", column: "id")

    }

    try db.create(table: "battle",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")
      t.column("sp3PrincipalId", .text).notNull()
      t.column("mode", .text).notNull()
      t.column("rule", .text).notNull()
      t.column("stage", .text).notNull()
      t.column("playedTime", .datetime).notNull()
      t.column("duration", .integer).notNull()
      t.column("judgement", .text).notNull()
      t.column("knockout", .text)
      t.column("udemae", .text)
      t.column("preDetailId", .text)

      /// BankaraMatch Attributes
      t.column("earnedUdemaePoint",.integer)
      t.column("bankaraMode", .text)
      t.column("bankaraPower", .blob)

      /// LeagueMatch Attributes
      t.column("leagueMatchEventId", .text)
      t.column("myLeaguePower", .integer)

      /// XMatch Attributes
      t.column("lastXPower", .double)
      t.column("entireXPower", .double)

      /// FestMatch Attributes
      t.column("festDragonMatchType", .text)
      t.column("festContribution", .integer)
      t.column("festJewel", .integer)
      t.column("myFestPower", .integer)

      t.column("awards",.text)
    }

    try db.create(table: "imageMap", ifNotExists: true) { t in
      /// badge, brand, coopEnemy, coopSkin, gear, nameplate, skill, stage, weapon, subspecial
      t.autoIncrementedPrimaryKey("id")
      t.column("nameId", .text).notNull().unique()
      t.column("hash", .text).notNull()
      t.column("name",.text).notNull()
    }
  }

  public func updateImageMap(version:String) async throws{
    // Update badges
    try await fetchMapAndInsert(
      from: Splat3URLs.badge.url(for: version),
      using: getBadgeMap,
      insertFunction: { badge, db in
        try badge.insert(db)
      }
    )

    // Update main weapons
    try await fetchMapAndInsert(
      from: Splat3URLs.weaponMain.url(for: version),
      using: getWeaponMainMap,
      insertFunction: { weapon, db in
        try weapon.insert(db)
      }
    )

    // Update special weapons
    try await fetchMapAndInsert(
      from: Splat3URLs.weaponSpecial.url(for: version),
      using: { json in getWeaponSubspe(from: json, prefix: "Special") },
      insertFunction: { special, db in
        try special.insert(db)
      }
    )

    // Update sub weapons
    try await fetchMapAndInsert(
      from: Splat3URLs.weaponSub.url(for: version),
      using: { json in getWeaponSubspe(from: json, prefix: "Sub") },
      insertFunction: { sub, db in
        try sub.insert(db)
      }
    )

    /// nameplate background
    try await fetchMapAndInsert(
      from: Splat3URLs.nameplate.url(for: version),
      using: getNameplateMap,
      insertFunction: { nameplate, db in
        try nameplate.insert(db)
      }
    )

    /// gears
    let gears:[Splat3URLs] = [.head, .clothes, .shoes]
    for gear in gears{
      try await fetchMapAndInsert(
        from: gear.url(for: version),
        using: getGearMap,
        insertFunction: { gear, db in
          try gear.insert(db)
        }
      )
    }

    /// enemy
    try await fetchMapAndInsert(
      from: Splat3URLs.enemy.url(for: version),
      using: getCoopEnemyMap,
      insertFunction: { enemy, db in
        try enemy.insert(db)
      }
    )

    /// skin
    try await fetchMapAndInsert(
      from: Splat3URLs.skin.url(for: version),
      using: getCoopSkinMap,
      insertFunction: { skin, db in
        try skin.insert(db)
      }
    )

    /// stage
    let stages:[Splat3URLs:String] = [.coopStage:"Coop", .vsStage:"Vs"]
    for (url,mode) in stages{
      try await fetchMapAndInsert(
        from: url.url(for: version),
        using: { json in getStageMap(from: json, prefix:  mode) },
        insertFunction: { stage, db in
          try stage.insert(db)
        }
      )
    }

  }

  public func insertCoop(json:JSON) throws{
    try self.dbQueue.writeInTransaction { db in
      do{
        /// insert coop
        try Coop(json:json).insert(db)
        let coopId = db.lastInsertedRowID
        /// insert weapons
        for (index,element) in json["weapons"].arrayValue.enumerated(){
          try Weapon(imageMapId: getImageId(hash:element["image"]["url"].stringValue.getImageHash(), db: db), order: index,coopId: coopId).insert(db)
        }
        /// insert coopPlayerResult
        try CoopPlayerResult(json: json["myResult"], order: 0, coopId: coopId,db: db).insert(db)
        var coopPlayerResultId = db.lastInsertedRowID
        for (index,element) in json["myResult"]["weapons"].arrayValue.enumerated(){
          try Weapon(imageMapId: getImageId(hash:element["image"]["url"].stringValue.getImageHash(), db: db), order: index,coopPlayerResultId: coopPlayerResultId).insert(db)
        }
        try Player(json: json["myResult"]["player"], coopPlayerResultId: coopPlayerResultId, db: db).insert(db)
        for (index,element) in json["memberResults"].arrayValue.enumerated(){
          try CoopPlayerResult(json: element, order: index + 1, coopId: coopId,db: db).insert(db)
          coopPlayerResultId = db.lastInsertedRowID
          for (index,element) in element["weapons"].arrayValue.enumerated(){
            try Weapon(imageMapId: getImageId(hash:element["image"]["url"].stringValue.getImageHash(), db: db), order: index,coopPlayerResultId: coopPlayerResultId).insert(db)
          }
          try Player(json: element["player"], coopPlayerResultId: coopPlayerResultId, db: db).insert(db)
        }
        /// insert coopWaveResult
        for (_,element) in json["waveResults"].arrayValue.enumerated(){
          try CoopWaveResult(json: element, coopId: coopId).insert(db)
          let coopWaveResultId = db.lastInsertedRowID
          for (index,element) in element["specialWeapons"].arrayValue.enumerated(){
            try Weapon(imageMapId: getImageId(hash:element["image"]["url"].stringValue.getImageHash(), db: db), order: index,coopWaveResultId: coopWaveResultId).insert(db)
          }
        }
        /// insert coopEnemyResult
        for (_,element) in json["enemyResults"].arrayValue.enumerated(){
          try CoopEnemyResult(json: element, coopId: coopId,db: db).insert(db)
        }
        return .commit
      } catch{
        print(error)
        return .rollback
      }
    }
  }

  public func insertBattle(json:JSON) throws{
    try self.dbQueue.writeInTransaction { db in
      do{
        /// insert battle
        try Battle(json:json).insert(db)
        let battleId = db.lastInsertedRowID
        /// insert vsTeam
        try VsTeam(json: json["myTeam"], battleId: battleId).insert(db)
        let vsTeamId = db.lastInsertedRowID
        for (_,element) in json["myTeam"]["players"].arrayValue.enumerated(){
          try Player(json: element, vsTeamId: vsTeamId, db: db).insert(db)
        }

        for (_,element) in json["otherTeams"].arrayValue.enumerated(){
          try VsTeam(json: element, battleId: battleId).insert(db)
          let vsTeamId = db.lastInsertedRowID
          for (_,element) in element["players"].arrayValue.enumerated(){
            try Player(json: element, vsTeamId: vsTeamId, db: db).insert(db)
          }
        }
        return .commit
      } catch{
        return .rollback
      }
    }
  }

  /// Function to insert items into the database
  private func insertItems<T>(_ items: [T], using insertFunction: (T, Database) throws -> Void) async throws {
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
  ) async throws {
    let json = try await fetchJSONData(from: url)
    let items = mapFunction(json)
    try await insertItems(items, using: insertFunction)
  }
}
