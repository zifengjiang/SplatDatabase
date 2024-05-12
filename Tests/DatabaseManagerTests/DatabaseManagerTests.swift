//
//  File.swift
//
//
//  Created by 姜锋 on 5/9/24.
//

import XCTest
import GRDB
import SwiftyJSON
@testable import Splat3Database

import GRDB
import XCTest

class DatabaseManagerTests: XCTestCase {

  var dbManager: DatabaseManager!
  var tempDatabasePath: String!

  override func setUpWithError() throws {
    super.setUp()

    dbManager = DatabaseManager()
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

    //         使用 dbQueue 测试表是否创建成功
    try dbManager.dbQueue.read { db in
      XCTAssertTrue(try db.tableExists("coop"))
      XCTAssertTrue(try db.tableExists("weapon"))
      XCTAssertTrue(try db.tableExists("coopPlayerResult"))
      XCTAssertTrue(try db.tableExists("player"))

    }
  }


  func testInsertCoop() throws{
    let data = try String(contentsOfFile: "/Users/jiangfeng/XcodeProject/Splat3Database/Tests/DatabaseManagerTests/json/CoopDetailHolder.json")
    let json:JSON = JSON(parseJSON: data)

    let value = json["data"]["coopHistoryDetail"]

    try dbManager.insertCoop(json: value)

    let coops = try dbManager.dbQueue.read { db in
      return try Coop.fetchAll(db)
    }

    let players = try dbManager.dbQueue.read { db in
      return try Player.fetchAll(db)
    }
    let coopPlayerResults = try dbManager.dbQueue.read { db in
      return try CoopPlayerResult.fetchAll(db)
    }


    XCTAssertEqual(coops.count, 1)
    XCTAssertEqual(players.count, 4)
    XCTAssertEqual(coopPlayerResults.count, 4)
  }

  func testInsertBattle() async throws{
    var data = try String(contentsOfFile: "/Users/jiangfeng/XcodeProject/Splat3Database/Tests/DatabaseManagerTests/json/VsHistoryDetailQuery.json")
    var json:JSON = JSON(parseJSON: data)

    var values = json["data"]
    try await dbManager.updateImageMap(version: "720")
    try dbManager.insertBattle(json: values[1])

    data = try String(contentsOfFile: "/Users/jiangfeng/XcodeProject/Splat3Database/Tests/DatabaseManagerTests/json/CoopDetailHolder.json")
    json = JSON(parseJSON: data)

    values = json["data"]["coopHistoryDetail"]

    try dbManager.insertCoop(json: values)

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

    let destinationURL = try dbManager.exportDatabase(to: URL(string: "/Users/jiangfeng/XcodeProject/FoodTracker"))

    XCTAssertEqual(imageMap.count, 1991)
    XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    XCTAssertEqual(battles.count, 1)
    XCTAssertEqual(vsTeams.count, 2)
    XCTAssertEqual(players.count, 12)
  }

  func testUpdateImageMap() async throws{
    let versions = ["099","100","110","111","120","200","210","300","310","400","410","500","510","520","600","610","700","710","720"]
    var imageMaps:[[ImageMap]] = []
    for version in versions{
      try await dbManager.updateImageMap(version: version)
      imageMaps.append(try await dbManager.dbQueue.read { db in
        return try ImageMap.fetchAll(db)
      })
    }
    XCTAssertTrue(imageMaps.count > 0)
  }

  func testExportDatabase() async throws{
    try await dbManager.updateImageMap(version: "720")
    let destinationURL = try dbManager.exportDatabase(to: URL(string: "/Users/jiangfeng/XcodeProject/FoodTracker"))
    let imageMap = try await dbManager.dbQueue.read { db in
      return try ImageMap.fetchAll(db)
    }

    XCTAssertEqual(imageMap.count, 1991)
    XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
  }
}
