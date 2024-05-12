//
//  File.swift
//
//
//  Created by 姜锋 on 5/9/24.
//

import XCTest
import GRDB
import SwiftyJSON
@testable import SplatDatabase3

import GRDB
import XCTest

class Splat3DatabaseTests: XCTestCase {

  var dbManager: SplatDatabase!
  var tempDatabasePath: String!

  override func setUpWithError() throws {
    super.setUp()

    dbManager = SplatDatabase()
    try dbManager.createDatabase(path: "/Users/jiangfeng/XcodeProject/FoodTracker/ink.sqlite")
  }

  override func tearDownWithError() throws {
    try dbManager.dbQueue.write { db in
//      // 先删除所有子表
//      try db.drop(table: "imageMap")
//      try db.drop(table: "weapon")
//      try db.drop(table: "coopEnemyResult")
//      try db.drop(table: "player")
//      try db.drop(table: "coopPlayerResult")
//      try db.drop(table: "coopWaveResult")
//
//      // 再删除父表
//      try db.drop(table: "vsTeam")
//      try db.drop(table: "battle")
//      try db.drop(table: "coop")
    }

    // 清理和关闭数据库
    dbManager.dbQueue = nil
    dbManager = nil



    super.tearDown()
  }


  func testCreateDatabase() throws {
    try dbManager.createDatabase()
    try dbManager.dbQueue.read { db in
      XCTAssertTrue(try db.tableExists("coop"))
      XCTAssertTrue(try db.tableExists("weapon"))
      XCTAssertTrue(try db.tableExists("coopPlayerResult"))
      XCTAssertTrue(try db.tableExists("player"))

    }
  }


  func testInsertCoop() async throws{
    try dbManager.updateImageMap()
    let bundle = Bundle.module
    let path = bundle.url(forResource: "CoopDetailHolder", withExtension: "json")
    let json:JSON = JSON(parseJSON: try String(contentsOfFile: path!.path))

    let value = json["data"]["coopHistoryDetail"]

    try dbManager.insertCoop(json: value)

    let coops = try await dbManager.dbQueue.read { db in
      return try Coop.fetchAll(db)
    }

    let players = try await dbManager.dbQueue.read { db in
      return try Player.fetchAll(db)
    }
    let coopPlayerResults = try await dbManager.dbQueue.read { db in
      return try CoopPlayerResult.fetchAll(db)
    }


    XCTAssertEqual(coops.count, 1)
    XCTAssertEqual(players.count, 4)
    XCTAssertEqual(coopPlayerResults.count, 4)
  }

  func testInsertBattle() async throws{
    try dbManager.updateImageMap()
    let bundle = Bundle.module
    let path = bundle.url(forResource: "VsHistoryDetailQuery", withExtension: "json")
    let json:JSON = JSON(parseJSON: try String(contentsOfFile: path!.path))

    let values = json["data"]

    try dbManager.insertBattle(json: values[1])

    let battles = try await dbManager.dbQueue.read { db in
      return try Battle.fetchAll(db)
    }

    let players = try await dbManager.dbQueue.read { db in
      return try Player.fetchAll(db)
    }
    let vsTeams = try await dbManager.dbQueue.read { db in
      return try VsTeam.fetchAll(db)
    }

    let imageMap = try await dbManager.dbQueue.read { db in
      return try ImageMap.fetchAll(db)
    }


    XCTAssertEqual(imageMap.count, 1993)
    XCTAssertEqual(battles.count, 1)
    XCTAssertEqual(vsTeams.count, 2)
    XCTAssertEqual(players.count, 8)
  }

  func testImportDatabaseFromConchBay() async throws{
    let dbPath = "/Users/jiangfeng/XcodeProject/conch-bay.db"
    try dbManager.importFromConchBay(dbPath: dbPath){ progress in
      print(progress)
    }
  }

  func testImportDatabaseFromInkMe() async throws{
    let dbPath = "/Users/jiangfeng/Downloads/InkCompanion.sqlite"
    try dbManager.importFromInkMe(dbPath: dbPath){ progress in
      print(progress)
    }
  }
}


