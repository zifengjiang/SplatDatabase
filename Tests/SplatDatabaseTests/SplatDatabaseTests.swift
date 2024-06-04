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

}


