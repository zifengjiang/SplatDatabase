// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB
import SwiftyJSON


public class DatabaseManager {
  public static let shared = DatabaseManager()

  public var dbQueue: DatabasePool!

  public func createDatabase() throws {
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
      t.column("id", .text).notNull()
      t.column("order", .integer).notNull().defaults(to: 0)
      t.column("coopId", .integer).references("coop", column: "id") // shift weapons
      t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id") // player weapons
      t.column("coopWaveResultId", .integer).references("coopWaveResult", column: "id")
    }

    try db.create(table: "coopPlayerResult",ifNotExists: true) { t in
      t.autoIncrementedPrimaryKey("id")
      t.column("order",.integer).notNull()
      t.column("specialWeapon", .text)
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
      t.column("id", .text).notNull()
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
      t.column("nameplateBackground", .text).notNull()
      t.column("nameplateTextColor", .integer).notNull()
      t.column("nameplateBadge1", .text)
      t.column("nameplateBadge2", .text)
      t.column("nameplateBadge3", .text)

      /// Coop Attributes
      t.column("uniform", .text)

      /// Battle Attributes
      t.column("paint", .integer)
      t.column("weapon", .text)
      t.column("headGear", .text)
      t.column("clothingGear", .text)
      t.column("shoesGear", .text)
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
      t.column("color", .text).notNull()
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

    }

    try db.create(table: "vsAward",ifNotExists: true) { t in
      t.column("name", .text).notNull()
      t.column("rank", .boolean).notNull() // true for gold, false for silver

      t.column("battle", .integer).references("battle", column: "id")
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
    }
  }

  public func insertCoop(json:JSON) throws{
    try self.dbQueue.write { db in
      /// insert coop
      try Coop(json:json).insert(db)
      let coopId = db.lastInsertedRowID
      /// insert weapons
      for (index,element) in json["weapons"].arrayValue.enumerated(){
        try Weapon(id: element["image"]["url"].stringValue.getImageHash(), order: index,coopId: coopId).insert(db)
      }
      /// insert coopPlayerResult
      try CoopPlayerResult(json: json["myResult"], order: 0, coopId: coopId).insert(db)
      try Player(json: json["myResult"]["player"], coopPlayerResultId: db.lastInsertedRowID).insert(db)
      for (index,element) in json["memberResults"].arrayValue.enumerated(){
        try CoopPlayerResult(json: element, order: index + 1, coopId: coopId).insert(db)
        try Player(json: element["player"], coopPlayerResultId: db.lastInsertedRowID).insert(db)
      }
      /// insert coopWaveResult
      for (_,element) in json["waveResults"].arrayValue.enumerated(){
        try CoopWaveResult(json: element, coopId: coopId).insert(db)
        let coopWaveResultId = db.lastInsertedRowID
        for (index,element) in element["specialWeapons"].arrayValue.enumerated(){
          try Weapon(id: element["image"]["url"].stringValue.getImageHash(), order: index,coopWaveResultId: coopWaveResultId).insert(db)
        }
      }
      /// insert coopEnemyResult
      for (_,element) in json["enemyResults"].arrayValue.enumerated(){
        try CoopEnemyResult(json: element, coopId: coopId).insert(db)
      }
    }
  }
}
