import Foundation
import GRDB
import SwiftyJSON

public class SplatDatabase {
    public static let shared = try! SplatDatabase()

    public var dbQueue: DatabasePool!


    public init() throws{
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        self.dbQueue = try DatabasePool(path: databaseURL.path)

        try migrator.migrate(dbQueue)
    }

        /// test use
    public init(path:String) {
        do {
            try createDatabase(path: path)
        }catch{
            print(#file,#line,error.localizedDescription)
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createDatabase") { db in
            try self.setupSchema(db: db)
        }

        migrator.registerMigration("insertI18nForVersion800") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion800") { db in
            try self.updateImageMap(db: db) // 你可能需要类似修改 updateImageMap 方法
        }

        migrator.registerMigration("coop_group_status_view") { db in
            try db.execute(sql: coop_group_status_view)
        }

        migrator.registerMigration("createIndexes") { db in
            try db.execute(sql: """
                    CREATE INDEX idx_coop_accountId ON coop (accountId);
                    CREATE INDEX idx_coop_playedTime ON coop (playedTime);
                    CREATE INDEX idx_coopEnemyResult_coopId ON coopEnemyResult (coopId);
                    CREATE INDEX idx_imageMap_id ON imageMap (id);
                    CREATE INDEX idx_coopPlayerResult_coopId ON coopPlayerResult(coopId);
                    CREATE INDEX idx_coopPlayerResult_order ON coopPlayerResult('order');
                    CREATE INDEX idx_weapon_coopPlayerResultId ON weapon(coopPlayerResultId);
                    CREATE INDEX idx_coopWaveResult_coopId ON coopWaveResult(coopId);
                    CREATE INDEX idx_player_coopPlayerResultId ON player(coopPlayerResultId);
                    CREATE INDEX idx_coop_boss ON coop(boss);
                    CREATE INDEX idx_coop_stageId ON coop(stageId);
                """)
        }


        migrator.registerMigration("insertI18nForVersion810") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion810") { db in
            try self.updateImageMap(db: db)
        }

        migrator.registerMigration("insertI18nForVersion900") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion900") { db in
            try self.updateImageMap(db: db)
        }

        migrator.registerMigration("insertI18nForVersion910") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion910") { db in
            try self.updateImageMap(db: db)
        }

        migrator.registerMigration("addIsBossColumnToCoopEnemyResult") { db in
                // Check if the column already exists
            let columns = try db.columns(in: "coopEnemyResult")
            if !columns.contains(where: { $0.name == "isBoss" }) {
                try db.alter(table: "coopEnemyResult") { t in
                    t.add(column: "isBoss", .boolean).notNull().defaults(to: false)
                }
            }
        }

        migrator.registerMigration("alterPlayerTableColumnWeaponId2Weapon") { db in
            let columns = try db.columns(in: "player")
            if columns.contains(where: { $0.name == "weaponId" }) {
                try db.alter(table: "player") { t in
                    t.rename(column: "weaponId", to: "weapon")
                }
            }
        }

        migrator.registerMigration("removeForeignKeyConstraint") { db in
            try db.create(table: "new_player",ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("isCoop",.boolean).notNull() // true for coop, false for battle

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
                t.column("weapon", .integer)
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

            try db.execute(sql: """
                    INSERT INTO new_player
                    SELECT id,isCoop,sp3PrincipalId,byname,name,nameId,species,nameplate,nameplateTextColor,uniformId,paint,weapon,headGear,clothingGear,shoesGear,crown,festDragonCert,festGrade,isMyself,kill,death,assist,special,noroshiTry,vsTeamId,coopPlayerResultId
                    FROM player;
                """)
            try db.drop(table: "player")
            try db.rename(table: "new_player", to: "player")

        }
        // CREATE INDEX idx_player_coopPlayerResultId ON player(coopPlayerResultId)
        migrator.registerMigration("createIdx_player_coopPlayerResultId") { db in
            try db.execute(sql: "CREATE INDEX idx_player_coopPlayerResultId ON player(coopPlayerResultId);")
        }

        migrator.registerMigration("fixTriumvirateIssue") { db in
            try I18n(key: "Q29vcEVuZW15LTMw", translations: ["zhCN": "头目联合", "zhTW": "頭目聯合", "en": "Triumvirate", "ja": "トリアムバレイト", "ko": "트리엄버레이트", "ru": "Триумвирейт", "fr": "Triumvirat", "de": "Triumvirat", "es": "Triunvirato", "it": "Triumvirato", "nl": "Triumviraat"]).insert(db)
            // Update
            try db.execute(sql: """
                UPDATE coopWaveResult
                SET eventWave = (
                SELECT i18n.id FROM i18n
                WHERE i18n.'key' = 'Q29vcEVuZW15LTMw'
                )
                WHERE eventWave IS NULL 
                AND waveNumber = 4
                AND coopId IN (
                SELECT id FROM coop 
                WHERE rule != 'TEAM_CONTEST'
                );
            """)
        }

        
    migrator.registerMigration("insertI18nForVersion920") { db in
        try self.updateI18n(db: db)
    }

    migrator.registerMigration("insertImageMapForVersion920") { db in
        try self.updateImageMap(db: db)
    }
    return migrator
    



    }



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

            // Perform the export by copying the file
        try fileManager.copyItem(atPath: dbPath, toPath: destinationURL.path)

        return destinationURL
    }

    public func createDatabase(path: String) throws {

        self.dbQueue = try DatabasePool(path: path)

        try self.migrator.migrate(dbQueue)
    }


    private func setupSchema(db: Database) throws {
        try db.create(table: "i18n", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("key", .text).notNull().unique()
            t.column("zhCN", .text) // 中文简体
            t.column("zhTW", .text) // 中文繁体
            t.column("en", .text) // 英文
            t.column("ja", .text) // 日文
            t.column("ko", .text) // 韩文
            t.column("ru", .text) // 俄文
            t.column("fr", .text) // 法文
            t.column("de", .text) // 德文
            t.column("es", .text) // 西班牙文
            t.column("it", .text) // 意大利文
            t.column("nl", .text) // 荷兰文
        }

        try I18n(key: "Q29vcEVuZW15LTMw", translations: ["zhCN": "头目联合", "zhTW": "頭目聯合", "en": "Triumvirate", "ja": "トリアムバレイト", "ko": "트리엄버레이트", "ru": "Триумвирейт", "fr": "Triumvirat", "de": "Triumvirat", "es": "Triunvirato", "it": "Triumvirato", "nl": "Triumviraat"]).insert(db)

        try db.create(table: "coop",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("rule", .text).notNull()
            t.column("sp3PrincipalId", .text).notNull()
            t.column("boss", .integer).references("imageMap",column: "id")
            t.column("suppliedWeapon",.integer).notNull()
            t.column("egg",.integer).notNull()
            t.column("powerEgg", .integer).notNull()
            t.column("bossDefeated", .boolean)
            t.column("wave", .integer).notNull()
            t.column("stageId", .integer).notNull().references("imageMap", column: "id")
            t.column("afterGrade", .integer)
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
            t.column("smellMeter", .integer)
            t.column("accountId", .integer).notNull().references("account", column: "id")

            t.uniqueKey(["sp3PrincipalId","playedTime", "accountId"], onConflict: .ignore)
        }

        try db.create(table: "battle",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("sp3PrincipalId", .text).notNull()
            t.column("mode", .text).notNull()
            t.column("rule", .text).notNull()
            t.column("stageId", .integer).notNull().references("imageMap", column: "id")
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
            t.column("accountId", .integer).notNull().references("account", column: "id")

            t.uniqueKey(["sp3PrincipalId","playedTime", "accountId"], onConflict: .ignore)
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
            t.column("eventWave", .integer).references("i18n", column: "id")
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
            t.column("isBoss",.boolean).notNull().defaults(to: false)

            t.column("coopId", .integer).references("coop", column: "id")
        }

        try db.create(table: "player",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("isCoop",.boolean).notNull() // true for coop, false for battle

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
            t.column("weapon", .integer)
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

        try db.create(table: "imageMap", ifNotExists: true) { t in
                /// badge, brand, coopEnemy, coopSkin, gear, nameplate, skill, stage, weapon, subspecial
            t.autoIncrementedPrimaryKey("id")
            t.column("nameId", .text).notNull().unique()
            t.column("hash", .text).notNull()
            t.column("name",.text).notNull()
        }

        try db.create(table: "account", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("sp3Id", .text).unique()
            t.column("avatar", .blob)
            t.column("name",.text)
            t.column("code",.text).unique()
            t.column("sessionToken",.text)
            t.column("lastRefresh", .datetime)
        }

        try db.create(table: "schedule", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("startTime", .datetime).notNull()
            t.column("endTime", .datetime).notNull()
            t.column("mode", .integer).notNull()
            t.column("rule1", .integer)
            t.column("rule2", .integer)
            t.column("stage", .integer).notNull()
            t.column("weapons", .integer)
            t.column("boss", .integer)
            t.column("event", .text)

            t.uniqueKey(["startTime","endTime", "mode"], onConflict: .replace)
        }

        try db.execute(sql: coop_view_sql)
    }

}


extension SplatDatabase {
    public enum Mode:String{
        case battle = "battle"
        case coop = "coop"
    }

    public func filterNotExists(in kind: Mode, ids: [String]) throws -> [String] {
            // 提取所有需要的字段
        let sp3PrincipalIds = ids.map { $0.getDetailUUID() }
        let playedTimes = ids.map { $0.base64DecodedString.extractedDate! }
        let sp3Ids = ids.map { $0.extractUserId() }

            // 构建SQL查询语句
        let sql = """
                SELECT
                sp3PrincipalId, playedTime, sp3Id
                FROM
                \(kind)
                JOIN account ON \(kind).accountId = account.id
                WHERE
                sp3PrincipalId IN (\(sp3PrincipalIds.map { _ in "?" }.joined(separator: ", ")))
                AND playedTime IN (\(playedTimes.map { _ in "?" }.joined(separator: ", ")))
                AND sp3Id IN (\(sp3Ids.map { _ in "?" }.joined(separator: ", ")))
              """

            // 将所有参数转换为DatabaseValueConvertible数组
        let arguments: [DatabaseValueConvertible] = sp3PrincipalIds + playedTimes + sp3Ids

        let existingRecords = try dbQueue.read { db in
                // 执行查询，获取存在的记录
            try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }


            // 创建一个Set用于存储已存在的记录ID
        var existingSet: Set<String> = []
        for record in existingRecords {
            let sp3PrincipalId: String = record["sp3PrincipalId"]
            let playedTime: Date = record["playedTime"]
            let sp3Id: String = record["sp3Id"]

                // 重建原始ID
            if let originalId = ids.first(where: {
                $0.getDetailUUID() == sp3PrincipalId &&
                $0.base64DecodedString.extractedDate! == playedTime &&
                $0.extractUserId() == sp3Id
            }) {
                existingSet.insert(originalId)
            }
        }

            // 计算不存在的ID
        let notExistIds = ids.filter { !existingSet.contains($0) }

        return notExistIds
    }

}



