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

    // 创建一个临时文件路径用于测试数据库
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let temporaryFile = temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
    tempDatabasePath = temporaryFile.path

    // 初始化 DatabaseManager，使用临时文件路径
    dbManager = DatabaseManager()
    dbManager.dbQueue = try DatabasePool(path: tempDatabasePath)

    try dbManager.createDatabase()
  }

  override func tearDownWithError() throws {
      try dbManager.dbQueue.write { db in
          // 先删除所有子表
          try db.drop(table: "weapon")
          try db.drop(table: "coopEnemyResult")
          try db.drop(table: "player")
          try db.drop(table: "coopPlayerResult")
          try db.drop(table: "coopWaveResult")

          // 再删除父表
        try db.drop(table: "vsTeam")
        try db.drop(table: "battle")
          try db.drop(table: "coop")
      }

      // 清理和关闭数据库
      dbManager.dbQueue = nil
      dbManager = nil

      // 删除临时数据库文件
      try FileManager.default.removeItem(atPath: tempDatabasePath)

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
    let weapons = try dbManager.dbQueue.read { db in
      return try Weapon.fetchAll(db)
    }
    let players = try dbManager.dbQueue.read { db in
      return try Player.fetchAll(db)
    }
    let coopPlayerResults = try dbManager.dbQueue.read { db in
      return try CoopPlayerResult.fetchAll(db)
    }
    let coopWaveResults = try dbManager.dbQueue.read { db in
      return try CoopWaveResult.fetchAll(db)
    }
    let coopEnemyResults = try dbManager.dbQueue.read { db in
      return try CoopEnemyResult.fetchAll(db)
    }

    XCTAssertEqual(coops.count, 1)
    XCTAssertEqual(players.count, 4)
    XCTAssertEqual(coopPlayerResults.count, 4)
  }
  
  func testInsertBattle() throws{
    let data = try String(contentsOfFile: "/Users/jiangfeng/XcodeProject/Splat3Database/Tests/DatabaseManagerTests/json/VsHistoryDetailQuery.json")
    let json:JSON = JSON(parseJSON: data)

    let values = json["data"]

    try dbManager.insertBattle(json: values[1])

    let battles = try dbManager.dbQueue.read { db in
      return try Battle.fetchAll(db)
    }

    let players = try dbManager.dbQueue.read { db in
      return try Player.fetchAll(db)
    }
    let vsTeams = try dbManager.dbQueue.read { db in
      return try VsTeam.fetchAll(db)
    }
    

    XCTAssertEqual(battles.count, 1)
    XCTAssertEqual(players.count, 8)
  }

}
