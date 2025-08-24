import Foundation
import GRDB
import SwiftyJSON
import os

public struct Coop: Codable, FetchableRecord, PersistableRecord {
    public var id: Int64?
    public var sp3PrincipalId: String
    public var rule:String
    public var boss:UInt16?
    public var suppliedWeapon: PackableNumbers
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

        // MARK: - computed properties
    public var suppliedWeapons: [String]? = nil
    public var bossName: String? = nil
    public var stageImage:String? = nil
    public var stageName: String? = nil

        // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case sp3PrincipalId
        case rule
        case boss
        case suppliedWeapon
        case egg
        case powerEgg
        case bossDefeated
        case wave
        case stageId
        case afterGrade
        case afterGradePoint
        case afterGradeDiff
        case preDetailId
        case goldScale
        case silverScale
        case bronzeScale
        case jobPoint
        case jobScore
        case jobRate
        case jobBonus
        case playedTime
        case dangerRate
        case smellMeter
        case accountId
            // 这里不包括计算属性
    }

    public init(json:JSON, db:Database){
        self.sp3PrincipalId = json["id"].stringValue.getDetailUUID()
        self.rule = json["rule"].stringValue
        if let bossDefeated = json["bossResult"]["hasDefeatBoss"].bool{
            self.bossDefeated = bossDefeated
            let boss = json["bossResult"]["boss"]["id"].stringValue
            self.boss = getImageId(for:boss ,db: db)
        }else if let boss = json["boss"]["id"].string{
            self.boss = getImageId(for:boss ,db: db)
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

extension Coop: PreComputable {
    public static func create(from db: Database, identifier: Int64) throws -> Coop? {
        let row = try Coop.fetchOne(db, key: identifier)
        if var row = row {
            row.suppliedWeapons = try Array(0..<4).compactMap { try ImageMap.fetchOne(db, key: row.suppliedWeapon[$0])?.name}
            if let boss = row.boss{
                row.bossName = try ImageMap.fetchOne(db, key: boss)?.name
            }
            row.stageImage = try ImageMap.fetchOne(db, key: row.stageId)?.name
            row.stageName = try ImageMap.fetchOne(db, key: row.stageId)?.nameId
            return row
        }
        return row
    }
}


extension SplatDatabase{
    public func insertCoop(json:JSON) throws {
        self.dbQueue.customAsyncWrite { db in
            do{
                if try self.isCoopExist(id: json["id"].stringValue,db: db){
                    return
                }
                try self.insertCoop(json: json, db: db)
            } catch{
                print("insertCoop error \(error)")
                print(json["id"].stringValue)
            }
        } completion: { _, error in
            if case let .failure(error) = error {
                os_log("Database Error: [saveJob] \(error.localizedDescription)")
            }
        }
    }

    public func insertCoop(json:JSON, db:Database) throws {

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

            /// insert Boss Result
        if let bossResults = json["bossResults"].array{
            for (_,element) in bossResults.enumerated(){
                try CoopEnemyResult(json: element, coopId: coopId, hasDefeated: element["hasDefeatBoss"].boolValue, db: db).insert(db)
            }
        }

        if let hasDefeatBoss = json["bossResult"]["hasDefeatBoss"].bool{
            if json["bossResult"]["boss"]["id"].stringValue.order != 30{
                try CoopEnemyResult(json: json["bossResult"], coopId: coopId, hasDefeated: hasDefeatBoss, db: db)
            }
        }

    }


    public func insertCoops(jsons:[JSON], checkExist:Bool = true) async throws {
        try await self.dbQueue.write { db in
            for json in jsons{
                if try checkExist && self.isCoopExist(id: json["id"].stringValue,db: db){
                    continue
                }
                try self.insertCoop(json: json, db: db)
            }
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

extension SplatDatabase {
    /// 删除指定的coop记录及其所有相关数据
    /// - Parameter coopId: coop记录的ID
    public func deleteCoop(coopId: Int64) throws {
        try dbQueue.write { db in
            // 删除顺序：先删除子表，再删除主表
            
            // 1. 删除weapon表中与coop相关的记录
            try db.execute(sql: "DELETE FROM weapon WHERE coopId = ?", arguments: [coopId])
            
            // 2. 删除coopEnemyResult记录
            try db.execute(sql: "DELETE FROM coopEnemyResult WHERE coopId = ?", arguments: [coopId])
            
            // 3. 删除coopWaveResult相关的weapon记录
            let waveResultIds = try Int64.fetchAll(db, sql: "SELECT id FROM coopWaveResult WHERE coopId = ?", arguments: [coopId])
            for waveResultId in waveResultIds {
                try db.execute(sql: "DELETE FROM weapon WHERE coopWaveResultId = ?", arguments: [waveResultId])
            }
            
            // 4. 删除coopWaveResult记录
            try db.execute(sql: "DELETE FROM coopWaveResult WHERE coopId = ?", arguments: [coopId])
            
            // 5. 删除coopPlayerResult相关的weapon记录
            let playerResultIds = try Int64.fetchAll(db, sql: "SELECT id FROM coopPlayerResult WHERE coopId = ?", arguments: [coopId])
            for playerResultId in playerResultIds {
                try db.execute(sql: "DELETE FROM weapon WHERE coopPlayerResultId = ?", arguments: [playerResultId])
            }
            
            // 6. 删除player记录（通过coopPlayerResultId关联）
            for playerResultId in playerResultIds {
                try db.execute(sql: "DELETE FROM player WHERE coopPlayerResultId = ?", arguments: [playerResultId])
            }
            
            // 7. 删除coopPlayerResult记录
            try db.execute(sql: "DELETE FROM coopPlayerResult WHERE coopId = ?", arguments: [coopId])
            
            // 8. 最后删除coop主记录
            try db.execute(sql: "DELETE FROM coop WHERE id = ?", arguments: [coopId])
        }
    }
    
    /// 删除指定的coop记录及其所有相关数据（通过sp3PrincipalId）
    /// - Parameter sp3PrincipalId: coop记录的sp3PrincipalId
    public func deleteCoop(sp3PrincipalId: String) throws {
        try dbQueue.write { db in
            let coopIds = try Int64.fetchAll(db, sql: "SELECT id FROM coop WHERE sp3PrincipalId = ?", arguments: [sp3PrincipalId])
            for coopId in coopIds {
                try deleteCoop(coopId: coopId, db: db)
            }
        }
    }
    
    /// 删除所有coop记录及其相关数据
    public func deleteAllCoops() throws {
        try dbQueue.write { db in
            // 删除所有weapon记录（与coop相关的）
            try db.execute(sql: "DELETE FROM weapon WHERE coopId IS NOT NULL OR coopPlayerResultId IS NOT NULL OR coopWaveResultId IS NOT NULL")
            
            // 删除所有coopEnemyResult记录
            try db.execute(sql: "DELETE FROM coopEnemyResult")
            
            // 删除所有coopWaveResult记录
            try db.execute(sql: "DELETE FROM coopWaveResult")
            
            // 删除所有player记录（与coop相关的）
            try db.execute(sql: "DELETE FROM player WHERE coopPlayerResultId IS NOT NULL")
            
            // 删除所有coopPlayerResult记录
            try db.execute(sql: "DELETE FROM coopPlayerResult")
            
            // 删除所有coop记录
            try db.execute(sql: "DELETE FROM coop")
        }
    }
    
    /// 内部删除方法，在事务中执行
    private func deleteCoop(coopId: Int64, db: Database) throws {
        // 1. 删除weapon表中与coop相关的记录
        try db.execute(sql: "DELETE FROM weapon WHERE coopId = ?", arguments: [coopId])
        
        // 2. 删除coopEnemyResult记录
        try db.execute(sql: "DELETE FROM coopEnemyResult WHERE coopId = ?", arguments: [coopId])
        
        // 3. 删除coopWaveResult相关的weapon记录
        let waveResultIds = try Int64.fetchAll(db, sql: "SELECT id FROM coopWaveResult WHERE coopId = ?", arguments: [coopId])
        for waveResultId in waveResultIds {
            try db.execute(sql: "DELETE FROM weapon WHERE coopWaveResultId = ?", arguments: [waveResultId])
        }
        
        // 4. 删除coopWaveResult记录
        try db.execute(sql: "DELETE FROM coopWaveResult WHERE coopId = ?", arguments: [coopId])
        
        // 5. 删除coopPlayerResult相关的weapon记录
        let playerResultIds = try Int64.fetchAll(db, sql: "SELECT id FROM coopPlayerResult WHERE coopId = ?", arguments: [coopId])
        for playerResultId in playerResultIds {
            try db.execute(sql: "DELETE FROM weapon WHERE coopPlayerResultId = ?", arguments: [playerResultId])
        }
        
        // 6. 删除player记录（通过coopPlayerResultId关联）
        for playerResultId in playerResultIds {
            try db.execute(sql: "DELETE FROM player WHERE coopPlayerResultId = ?", arguments: [playerResultId])
        }
        
        // 7. 删除coopPlayerResult记录
        try db.execute(sql: "DELETE FROM coopPlayerResult WHERE coopId = ?", arguments: [coopId])
        
        // 8. 最后删除coop主记录
        try db.execute(sql: "DELETE FROM coop WHERE id = ?", arguments: [coopId])
    }
    
    /// 按时间范围删除coop记录及其相关数据
    /// - Parameters:
    ///   - startDate: 开始时间
    ///   - endDate: 结束时间
    public func deleteCoops(from startDate: Date, to endDate: Date) throws {
        try dbQueue.write { db in
            let coopIds = try Int64.fetchAll(db, sql: "SELECT id FROM coop WHERE playedTime BETWEEN ? AND ?", arguments: [startDate, endDate])
            for coopId in coopIds {
                try deleteCoop(coopId: coopId, db: db)
            }
        }
    }
    
    /// 按账户ID删除coop记录及其相关数据
    /// - Parameter accountId: 账户ID
    public func deleteCoops(accountId: Int64) throws {
        try dbQueue.write { db in
            let coopIds = try Int64.fetchAll(db, sql: "SELECT id FROM coop WHERE accountId = ?", arguments: [accountId])
            for coopId in coopIds {
                try deleteCoop(coopId: coopId, db: db)
            }
        }
    }
}

