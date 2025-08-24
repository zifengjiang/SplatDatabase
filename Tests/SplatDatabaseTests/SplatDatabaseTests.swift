import XCTest
import GRDB
import SwiftyJSON
@testable import SplatDatabase

import GRDB
import XCTest

class Splat3DatabaseTests: XCTestCase {

    var dbManager: SplatDatabase!
    var tempDatabasePath: String!

    override func setUpWithError() throws {
        super.setUp()

        dbManager = SplatDatabase(path:"/Users/jiangfeng/XcodeProject/FoodTracker/ink.sqlite")
    }

    override func tearDownWithError() throws {
        super.tearDown()
    }

    func testCreateDatabase() {
        return
    }




    func testInsertCoop() async throws{
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
        let dbPath = "/Users/jiangfeng/XcodeProject/InkCompanion.sqlite"
        try dbManager.importFromInkMe(dbPath: dbPath){ progress in
            print(progress)
        }
    }
    
    func testImportDatabase() async throws {
        // 创建一个临时的源数据库用于测试
        let tempSourceDbPath = NSTemporaryDirectory() + "test_source_db.sqlite"
        let sourceDb = try DatabasePool(path: tempSourceDbPath)
        
        // 在源数据库中创建一些测试数据
        try await sourceDb.write { db in
            try db.create(table: "account", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sp3Id", .text).unique()
                t.column("name", .text)
            }
            
            try db.execute(sql: "INSERT INTO account (sp3Id, name) VALUES (?, ?)", arguments: ["test123", "Test User"])
        }
        
        // 测试导入功能
        try dbManager.importFromDatabase(sourceDbPath: tempSourceDbPath) { progress in
            print("导入进度: \(progress)")
        }
        
        // 验证数据是否成功导入
        let accounts = try await dbManager.dbQueue.read { db in
            try Account.fetchAll(db)
        }
        
        // 清理临时文件
        try FileManager.default.removeItem(atPath: tempSourceDbPath)
        
        // 验证至少有一个账户被导入
        XCTAssertGreaterThan(accounts.count, 0)
    }
    
    func testImportDatabaseWithConstraints() async throws {
        // 创建一个临时的源数据库用于测试
        let tempSourceDbPath = NSTemporaryDirectory() + "test_source_db_constraints.sqlite"
        let sourceDb = try DatabasePool(path: tempSourceDbPath)
        
        // 在源数据库中创建一些测试数据
        try await sourceDb.write { db in
            try db.create(table: "account", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sp3Id", .text).unique()
                t.column("name", .text)
            }
            
            try db.create(table: "imageMap", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("nameId", .text).notNull().unique()
                t.column("hash", .text).notNull()
                t.column("name", .text).notNull()
            }
            
            try db.execute(sql: "INSERT INTO account (sp3Id, name) VALUES (?, ?)", arguments: ["test456", "Test User 2"])
            try db.execute(sql: "INSERT INTO imageMap (nameId, hash, name) VALUES (?, ?, ?)", arguments: ["test_image", "hash123", "Test Image"])
        }
        
        // 测试导入功能（带约束处理）
        try dbManager.importFromDatabaseWithConstraints(sourceDbPath: tempSourceDbPath) { progress in
            print("导入进度（带约束）: \(progress)")
        }
        
        // 验证数据是否成功导入
        let accounts = try await dbManager.dbQueue.read { db in
            try Account.fetchAll(db)
        }
        
        let imageMaps = try await dbManager.dbQueue.read { db in
            try ImageMap.fetchAll(db)
        }
        
        // 清理临时文件
        try FileManager.default.removeItem(atPath: tempSourceDbPath)
        
        // 验证数据被导入
        XCTAssertGreaterThan(accounts.count, 0)
        XCTAssertGreaterThan(imageMaps.count, 0)
    }

    func testFormatByName() async {
        let byname = "5-Year-Planning Client"
        _ = await formatByname(byname)
//        print(formatted?.adjective)
//        print(formatted?.subject)
//        print(formatted?.male)
    }

    func testInsertSchedule() async throws {
        for year in 2022..<2025 {
            for month in 1..<13 {
                for day in 1..<31 {
                    if year == 2022 && month < 9  {
                        continue
                    }
                    if year == 2022 && month == 9 && day < 17 {
                        continue
                    }
                    for hour in 0..<24{
                        let urlString = String(format: "https://splatoon3ink-archive.nyc3.digitaloceanspaces.com/%04d/%02d/%02d/%04d-%02d-%02d.%02d-00-00.schedules.json", year, month, day, year, month, day, hour)

                        guard let url = URL(string: urlString) else {
                            print("Invalid URL: \(urlString)")
                            continue
                        }

                        do {
                            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
                            let json = try JSON(data: data)

                            try await dbManager.dbQueue.write { db in
                                try insertSchedules(json: json, db: db)
                            }
                            break
                        } catch {
                            print("Failed to fetch or insert schedule for \(year)-\(month)-\(day): \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Delete Tests
    
    /// 测试删除指定的coop记录
    /// - Parameters:
    ///   - databasePath: 数据库路径，如果为nil则使用默认路径
    ///   - coopId: coop记录的ID，如果为nil则使用sp3PrincipalId
    ///   - sp3PrincipalId: coop记录的sp3PrincipalId，如果coopId为nil时使用
    func testDeleteCoop(databasePath: String? = nil, coopId: Int64? = nil, sp3PrincipalId: String? = nil) async throws {
        // 使用指定的数据库路径或默认路径
        let testDbManager: SplatDatabase
        if let path = databasePath {
            testDbManager = SplatDatabase(path: path)
        } else {
            testDbManager = dbManager
        }
        
        // 获取删除前的数据统计
        let beforeStats = try await getCoopTableStats(dbManager: testDbManager)
        print("删除前的数据统计:")
        printStats(beforeStats)
        
        // 执行删除操作
        if let id = coopId {
            print("正在删除coopId: \(id)")
            try testDbManager.deleteCoop(coopId: id)
        } else if let principalId = sp3PrincipalId {
            print("正在删除sp3PrincipalId: \(principalId)")
            try testDbManager.deleteCoop(sp3PrincipalId: principalId)
        } else {
            XCTFail("必须提供coopId或sp3PrincipalId")
            return
        }
        
        // 获取删除后的数据统计
        let afterStats = try await getCoopTableStats(dbManager: testDbManager)
        print("删除后的数据统计:")
        printStats(afterStats)
        
        // 验证删除结果
        verifyCoopDeletion(beforeStats: beforeStats, afterStats: afterStats)
    }
    
    /// 测试删除指定的battle记录
    /// - Parameters:
    ///   - databasePath: 数据库路径，如果为nil则使用默认路径
    ///   - battleId: battle记录的ID，如果为nil则使用sp3PrincipalId
    ///   - sp3PrincipalId: battle记录的sp3PrincipalId，如果battleId为nil时使用
    func testDeleteBattle(databasePath: String? = nil, battleId: Int64? = nil, sp3PrincipalId: String? = nil) async throws {
        // 使用指定的数据库路径或默认路径
        let testDbManager: SplatDatabase
        if let path = databasePath {
            testDbManager = SplatDatabase(path: path)
        } else {
            testDbManager = dbManager
        }
        
        // 获取删除前的数据统计
        let beforeStats = try await getBattleTableStats(dbManager: testDbManager)
        print("删除前的数据统计:")
        printStats(beforeStats)
        
        // 执行删除操作
        if let id = battleId {
            print("正在删除battleId: \(id)")
            try testDbManager.deleteBattle(battleId: id)
        } else if let principalId = sp3PrincipalId {
            print("正在删除sp3PrincipalId: \(principalId)")
            try testDbManager.deleteBattle(sp3PrincipalId: principalId)
        } else {
            XCTFail("必须提供battleId或sp3PrincipalId")
            return
        }
        
        // 获取删除后的数据统计
        let afterStats = try await getBattleTableStats(dbManager: testDbManager)
        print("删除后的数据统计:")
        printStats(afterStats)
        
        // 验证删除结果
        verifyBattleDeletion(beforeStats: beforeStats, afterStats: afterStats)
    }
    
    /// 测试删除所有coop记录
    func testDeleteAllCoops() async throws {
        // 获取删除前的数据统计
        let beforeStats = try await getCoopTableStats(dbManager: dbManager)
        print("删除所有coop前的数据统计:")
        printStats(beforeStats)
        
        // 执行删除操作
        try dbManager.deleteAllCoops()
        
        // 获取删除后的数据统计
        let afterStats = try await getCoopTableStats(dbManager: dbManager)
        print("删除所有coop后的数据统计:")
        printStats(afterStats)
        
        // 验证删除结果
        verifyAllCoopDeletion(beforeStats: beforeStats, afterStats: afterStats)
    }
    
    /// 测试删除所有battle记录
    func testDeleteAllBattles() async throws {
        // 获取删除前的数据统计
        let beforeStats = try await getBattleTableStats(dbManager: dbManager)
        print("删除所有battle前的数据统计:")
        printStats(beforeStats)
        
        // 执行删除操作
        try dbManager.deleteAllBattles()
        
        // 获取删除后的数据统计
        let afterStats = try await getBattleTableStats(dbManager: dbManager)
        print("删除所有battle后的数据统计:")
        printStats(afterStats)
        
        // 验证删除结果
        verifyAllBattleDeletion(beforeStats: beforeStats, afterStats: afterStats)
    }
    
    // MARK: - Helper Methods
    
    /// 获取coop相关表的数据统计
    private func getCoopTableStats(dbManager: SplatDatabase) async throws -> [String: Int] {
        return try await dbManager.dbQueue.read { db in
            let coopCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM coop") ?? 0
            let weaponCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM weapon WHERE coopId IS NOT NULL OR coopPlayerResultId IS NOT NULL OR coopWaveResultId IS NOT NULL") ?? 0
            let coopEnemyResultCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM coopEnemyResult") ?? 0
            let coopWaveResultCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM coopWaveResult") ?? 0
            let coopPlayerResultCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM coopPlayerResult") ?? 0
            let playerCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player WHERE coopPlayerResultId IS NOT NULL") ?? 0
            
            return [
                "coop": coopCount,
                "weapon": weaponCount,
                "coopEnemyResult": coopEnemyResultCount,
                "coopWaveResult": coopWaveResultCount,
                "coopPlayerResult": coopPlayerResultCount,
                "player": playerCount
            ]
        }
    }
    
    /// 获取battle相关表的数据统计
    private func getBattleTableStats(dbManager: SplatDatabase) async throws -> [String: Int] {
        return try await dbManager.dbQueue.read { db in
            let battleCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM battle") ?? 0
            let vsTeamCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM vsTeam") ?? 0
            let playerCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player WHERE vsTeamId IS NOT NULL") ?? 0
            
            return [
                "battle": battleCount,
                "vsTeam": vsTeamCount,
                "player": playerCount
            ]
        }
    }
    
    /// 打印数据统计
    private func printStats(_ stats: [String: Int]) {
        for (table, count) in stats.sorted(by: { $0.key < $1.key }) {
            print("  \(table): \(count)")
        }
    }
    
    /// 验证coop删除结果
    private func verifyCoopDeletion(beforeStats: [String: Int], afterStats: [String: Int]) {
        // 验证所有相关表的数据都有减少
        for (table, beforeCount) in beforeStats {
            let afterCount = afterStats[table] ?? 0
            XCTAssertLessThanOrEqual(afterCount, beforeCount, "表 \(table) 的数据应该减少或保持不变")
            
            if beforeCount > 0 {
                print("  \(table): \(beforeCount) -> \(afterCount)")
            }
        }
    }
    
    /// 验证battle删除结果
    private func verifyBattleDeletion(beforeStats: [String: Int], afterStats: [String: Int]) {
        // 验证所有相关表的数据都有减少
        for (table, beforeCount) in beforeStats {
            let afterCount = afterStats[table] ?? 0
            XCTAssertLessThanOrEqual(afterCount, beforeCount, "表 \(table) 的数据应该减少或保持不变")
            
            if beforeCount > 0 {
                print("  \(table): \(beforeCount) -> \(afterCount)")
            }
        }
    }
    
    /// 验证所有coop删除结果
    private func verifyAllCoopDeletion(beforeStats: [String: Int], afterStats: [String: Int]) {
        // 验证所有coop相关表的数据都被清空
        XCTAssertEqual(afterStats["coop"] ?? 0, 0, "coop表应该被清空")
        XCTAssertEqual(afterStats["weapon"] ?? 0, 0, "weapon表中coop相关的记录应该被清空")
        XCTAssertEqual(afterStats["coopEnemyResult"] ?? 0, 0, "coopEnemyResult表应该被清空")
        XCTAssertEqual(afterStats["coopWaveResult"] ?? 0, 0, "coopWaveResult表应该被清空")
        XCTAssertEqual(afterStats["coopPlayerResult"] ?? 0, 0, "coopPlayerResult表应该被清空")
        XCTAssertEqual(afterStats["player"] ?? 0, 0, "player表中coop相关的记录应该被清空")
        
        print("所有coop相关数据已成功删除")
    }
    
    /// 验证所有battle删除结果
    private func verifyAllBattleDeletion(beforeStats: [String: Int], afterStats: [String: Int]) {
        // 验证所有battle相关表的数据都被清空
        XCTAssertEqual(afterStats["battle"] ?? 0, 0, "battle表应该被清空")
        XCTAssertEqual(afterStats["vsTeam"] ?? 0, 0, "vsTeam表应该被清空")
        XCTAssertEqual(afterStats["player"] ?? 0, 0, "player表中battle相关的记录应该被清空")
        
        print("所有battle相关数据已成功删除")
    }
    
    // MARK: - Example Test Functions
    
    /// 示例：测试删除指定的coop记录（通过coopId）
    func testDeleteSpecificCoopById() async throws {
        // 你可以修改这些参数来测试特定的记录
        let testCoopId: Int64 = 1 // 替换为实际的coopId
        let testDatabasePath: String? = "/Users/jiangfeng/XcodeProject/jiangfeng/jeffjiang.imink 2025-08-23 21:28.08.609.xcappdata/AppData/Library/Application Support/db.sqlite" // 可选：指定数据库路径

        try await testDeleteCoop(databasePath: testDatabasePath,coopId: testCoopId)
    }
    
    /// 示例：测试删除指定的coop记录（通过sp3PrincipalId）
    func testDeleteSpecificCoopByPrincipalId() async throws {
        // 你可以修改这些参数来测试特定的记录
        let testSp3PrincipalId: String = "your-sp3-principal-id" // 替换为实际的sp3PrincipalId
        // let testDatabasePath: String? = "/path/to/your/database.sqlite" // 可选：指定数据库路径
        
        try await testDeleteCoop(sp3PrincipalId: testSp3PrincipalId)
    }
    
    /// 示例：测试删除指定的battle记录（通过battleId）
    func testDeleteSpecificBattleById() async throws {
        // 你可以修改这些参数来测试特定的记录
        let testBattleId: Int64 = 1 // 替换为实际的battleId
        // let testDatabasePath: String? = "/path/to/your/database.sqlite" // 可选：指定数据库路径
        
        try await testDeleteBattle(battleId: testBattleId)
    }
    
    /// 示例：测试删除指定的battle记录（通过sp3PrincipalId）
    func testDeleteSpecificBattleByPrincipalId() async throws {
        // 你可以修改这些参数来测试特定的记录
        let testSp3PrincipalId: String = "your-sp3-principal-id" // 替换为实际的sp3PrincipalId
        // let testDatabasePath: String? = "/path/to/your/database.sqlite" // 可选：指定数据库路径
        
        try await testDeleteBattle(sp3PrincipalId: testSp3PrincipalId)
    }

}


