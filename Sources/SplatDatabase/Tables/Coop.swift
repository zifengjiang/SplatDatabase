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
        if let boss = json["boss"]["id"].string{
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
        self.playedTime = json["playedTime"].stringValue.utcToDate()
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
        let sp3CoopId = json["id"].stringValue.extractUserId()
        try insertAccount(id: sp3CoopId)
        try self.dbQueue.writeInTransaction { db in
            do{
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
                return .commit
            } catch{
                print("insertCoop error \(error)")
                print(json["id"].stringValue)
                return .rollback
            }
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
