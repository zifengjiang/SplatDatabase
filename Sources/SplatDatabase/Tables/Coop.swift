import Foundation
import GRDB
import SwiftyJSON

public struct Coop: Codable, FetchableRecord, PersistableRecord {
    public var id: Int64?
    public var sp3PrincipalId: String
    public var rule:String
    public var boss:UInt16?
    @Packable public var suppliedWeapon: PackableNumbers
    public var egg:Int
    public var powerEgg:Int
    public var bossDefeated:Bool?
    public var wave:Int
    public var stageId:UInt16
    public var afterGrade:Int?
    public var afterGradePoint:Int?
    public var afterGradeDiff:Int?
    public var preDetailId:String?
    public var goldScale:Int?
    public var silverScale:Int?
    public var bronzeScale:Int?
    public var jobPoint:Int?
    public var jobScore:Int?
    public var jobRate:Double?
    public var jobBonus:Int?
    public var playedTime:Date
    public var dangerRate:Double
    public var smellMeter:Int?
    public var accountId:Int64

    public init(json:JSON, db:Database){
        self.sp3PrincipalId = json["id"].stringValue.getDetailUUID()
        self.rule = json["rule"].stringValue
        if var boss = json["boss"]["id"].string{
            if boss == "Q29vcEVuZW15LTMx"{
                boss = "Q29vcEVuZW15LTIz"
            }
            self.boss = getImageId(for:boss ,db: db)
        }
        if let bossDefeated = json["bossResult"]["hasDefeatBoss"].bool{
            self.bossDefeated = bossDefeated
        }
        self.suppliedWeapon = PackableNumbers(json["weapons"].arrayValue.map({ j in
            return getImageId(hash:j["image"]["url"].stringValue.getImageHash(), db: db)
        }))
        let resultWave = json["resultWave"].intValue
        self.wave = (resultWave == 0) ? ((self.rule == "TEAM_CONTEST") ? 5 : 3) : (resultWave - 1)
        self.stageId = getImageId(for: json["coopStage"]["id"].stringValue, db: db)
        self.afterGrade = json["afterGrade"]["id"].string?.getCoopGradeId()
        self.afterGradePoint = json["afterGradePoint"].int
        self.afterGradeDiff = 0/*json["afterGradeDiff"].int*/
        self.preDetailId = json["previousHistoryDetail"]["id"].string?.getDetailUUID()
        self.goldScale = json["scale"]["gold"].int
        self.silverScale = json["scale"]["silver"].int
        self.bronzeScale = json["scale"]["bronze"].int
        self.jobPoint = json["jobPoint"].int
        self.jobScore = json["jobScore"].int
        self.jobRate = json["jobRate"].double
        self.jobBonus = json["jobBonus"].int
        self.playedTime = json["id"].stringValue.base64DecodedString.extractedDate!
        self.dangerRate = json["dangerRate"].doubleValue
        self.smellMeter = json["smellMeter"].int
        self.accountId = getAccountId(by: json["id"].stringValue.extractUserId(), db: db)
        self.egg = json["waveResults"].arrayValue.reduce(0, { (result, wave) in
            return result + wave["teamDeliverCount"].intValue
        })
        self.powerEgg = json["memberResults"].arrayValue.reduce(0, { (result, wave) in
            return result + wave["deliverCount"].intValue
        }) + json["myResult"]["deliverCount"].intValue

    }
}


extension SplatDatabase{
    public func insertCoop(json:JSON) throws{
        try self.dbQueue.writeInTransaction { db in
            do{
                if try self.isCoopExist(id: json["id"].stringValue,db: db){
                    return .commit
                }
                try insertCoop(json: json, db: db)
                return .commit
            } catch{
                print("insertCoop error \(error)")
                print(json["id"].stringValue)
                return .rollback
            }
        }
    }

    public func insertCoop(json:JSON, db:Database) throws{
        let userId = json["id"].stringValue.extractUserId()
        let userCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM account WHERE sp3Id = ?", arguments: [userId])!
        if userCount == 0{
            var account = Account()
            account.sp3Id = userId
            try account.insert(db)
        }
            /// insert coop
        let coop = Coop(json:json, db: db)
        try coop.insert(db)
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
        for (index,element) in json["waveResults"].arrayValue.enumerated(){
            try CoopWaveResult(json: element,bossId: index == 3 ? json["bossResult"]["boss"]["id"].string : nil, coopId: coopId,db: db).insert(db)
            let coopWaveResultId = db.lastInsertedRowID
            for (index,element) in element["specialWeapons"].arrayValue.enumerated(){
                try Weapon(imageMapId: getImageId(hash:element["image"]["url"].stringValue.getImageHash(), db: db), order: index,coopWaveResultId: coopWaveResultId).insert(db)
            }
        }
            /// insert coopEnemyResult
        for (_,element) in json["enemyResults"].arrayValue.enumerated(){
            try CoopEnemyResult(json: element, coopId: coopId,db: db).insert(db)
        }
    }
}

extension SplatDatabase.Filter {
    func buildCoopQuery() -> SQLRequest<Row> {
        var conditions: [String] = []
        var arguments: [DatabaseValueConvertible] = []

        if let rules = rules, !rules.isEmpty {
            let rulePlaceholders = rules.map { _ in "?" }.joined(separator: ", ")
            conditions.append("coop.rule IN (\(rulePlaceholders))")
            arguments.append(contentsOf: rules)
        }

        if let stageIds = stageIds, !stageIds.isEmpty {
            let stageIdPlaceholders = stageIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("coop.stageId IN (\(stageIdPlaceholders))")
            arguments.append(contentsOf: stageIds)
        }

        if let weaponIds = weaponIds, !weaponIds.isEmpty {
            let weaponIdPlaceholders = weaponIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("weapon.imageMapId IN (\(weaponIdPlaceholders)) AND coopPlayerResult.\"order\" = 0")
            arguments.append(contentsOf: weaponIds)
        }

        if let start = start {
            conditions.append("coop.playedTime >= ?")
            arguments.append(start)
        }

        if let end = end {
            conditions.append("coop.playedTime <= ?")
            arguments.append(end)
        }

        let whereClause = conditions.isEmpty ? "1" : conditions.joined(separator: " AND ")
        let sql = """
            SELECT
                coop.*
                coop_view.GroupID
            FROM
                coop
                JOIN coopPlayerResult ON coop.id = coopPlayerResult.coopId
                JOIN weapon ON coopPlayerResult.id = weapon.coopPlayerResultId
                JOIN coop_view on coop_view.id = coop.id
            WHERE \(whereClause) AND accountId = \(accountId)
        """

        return SQLRequest<Row>(sql: sql, arguments: StatementArguments(arguments))
    }
}

extension SplatDatabase {
    public func eachCoops(db:Database, filter:Filter, handler: (Coop) throws -> Void) throws {
        let cursor = try Row.fetchCursor(db, filter.buildCoopQuery())
        while let row = try cursor.next() {
            try handler(Coop(row: row))
        }
    }
}

extension SplatDatabase {
    public func isCoopExist(id:String, db:Database?) throws -> Bool {
        return try isDetailExist(id: id, db: db)
    }

    public func isBattleExist(id:String, db:Database?) throws -> Bool {
        return try isDetailExist(id: id, table: "battle", db: db)
    }

    private func isDetailExist(id:String, table:String = "coop",db:Database?) throws -> Bool {
        let sp3PrincipalId = id.getDetailUUID()
        let playedTime = id.base64DecodedString.extractedDate!
        let sp3Id = id.extractUserId()
        let sql = """
                    SELECT
                    COUNT(*)
                    FROM
                    \(table)
                    JOIN account ON \(table).accountId = account.id
                    WHERE
                    sp3PrincipalId = ?
                    AND playedTime = ?
                    AND sp3Id = ?
                    """
        var count = 0

        if let db = db{
            count = try Int.fetchOne(db, sql: sql, arguments: [sp3PrincipalId,playedTime, sp3Id])!
        }else{
            try self.dbQueue.read { db in
                count = try Int.fetchOne(db, sql: sql, arguments: [sp3PrincipalId,playedTime, sp3Id])!
            }
        }
        return count > 0
    }
}

extension SplatDatabase {
    public func filterNotExistsCoop(ids: [String]) throws -> [String] {
            // 提取所有需要的字段
        let sp3PrincipalIds = ids.map { $0.getDetailUUID() }
        let playedTimes = ids.map { $0.base64DecodedString.extractedDate! }
        let sp3Ids = ids.map { $0.extractUserId() }

            // 构建SQL查询语句
        let sql = """
                SELECT
                sp3PrincipalId, playedTime, sp3Id
                FROM
                coop
                JOIN account ON coop.accountId = account.id
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

