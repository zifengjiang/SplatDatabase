import Foundation
import GRDB
import SwiftyJSON

public struct Battle:Codable, FetchableRecord, PersistableRecord{
    public var id:Int64?
    public var sp3PrincipalId:String
    public var mode:String
    public var rule:String
    public var stageId:UInt16
    public var playedTime:Date
    public var duration:Int
    public var judgement:String
    public var knockout:String?
    public var udemae:String?
    public var preDetailId:String?
    
        // BankaraMatch Attributes
    public var earnedUdemaePoint:Int?
    public var bankaraMode:String?
    public var bankaraPower:Data?
    
        // LeagueMatch Attributes
    public var leagueMatchEventId:String?
    public var myLeaguePower:Int?
    
        // XMatch Attributes
    public var lastXPower:Double?
    public var entireXPower:Double?
    
        // FestMatch Attributes
    public var festDragonMatchType:String?
    public var festContribution:Int?
    public var festJewel:Int?
    public var myFestPower:Int?
    public var awards:String
    public var accountId:Int64

    // MARK: Computed
    public var teams:[VsTeam] = []
    public var stage:ImageMap? = nil

    enum CodingKeys: String, CodingKey {
        case sp3PrincipalId, mode, rule, stageId, playedTime, duration, judgement, knockout, udemae, preDetailId
        case earnedUdemaePoint, bankaraMode, bankaraPower, leagueMatchEventId, myLeaguePower, lastXPower, entireXPower, festDragonMatchType, festContribution, festJewel, myFestPower, awards, accountId
    }

    public init(json:JSON, db:Database){
        self.sp3PrincipalId = json["id"].stringValue.getDetailUUID()
        self.mode = json["vsMode"]["mode"].stringValue
        self.rule = json["vsRule"]["rule"].stringValue
        self.stageId = getImageId(for:json["vsStage"]["id"].stringValue, db: db)
        self.playedTime = json["id"].stringValue.base64DecodedString.extractedDate!
        self.duration = json["duration"].intValue
        self.judgement = json["judgement"].stringValue
        self.knockout = json["knockout"].string
        self.udemae = json["udemae"].string
        self.preDetailId = json["previousHistoryDetail"]["id"].string?.getDetailUUID()
        
            // BankaraMatch Attributes
        self.earnedUdemaePoint = json["bankaraMatch"]["earnedUdemaePoint"].int
        self.bankaraMode = json["bankaraMatch"]["mode"].string
        self.bankaraPower = try? json["bankaraMatch"]["bankaraPower"].rawData()
        
            // LeagueMatch Attributes
        self.leagueMatchEventId = json["leagueMatchEventId"].string
        self.myLeaguePower = json["myLeaguePower"].int
        
            // XMatch Attributes
        self.lastXPower = json["lastXPower"].double
        self.entireXPower = json["entireXPower"].double
        
            // FestMatch Attributes
        self.festDragonMatchType = json["festMatch"]["dragonMatchType"].string
        self.festContribution = json["festMatch"]["contribution"].int
        self.festJewel = json["festMatch"]["jewel"].int
        self.myFestPower = json["festMatch"]["myFestPower"].int
        
        self.awards = json["awards"].arrayValue.map({"\($0["name"].stringValue)_\($0["rank"].stringValue)"}).joined(separator: ",")
        self.accountId = getAccountId(by: json["id"].stringValue.extractUserId(), db: db)
    }
}

extension SplatDatabase {
    public func insertBattle(json:JSON) throws{
        try self.dbQueue.writeInTransaction { db in
            do{
                if try isBattleExist(id: json["id"].stringValue,db: db){
                    return .commit
                }
                try insertBattle(json: json, db: db)
                return .commit
            } catch{
                return .rollback
            }
        }
    }

    public func insertBattle(json: JSON, db:Database) throws {
        
        let userId = json["id"].stringValue.extractUserId()
        let userCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM account WHERE sp3Id = ?", arguments: [userId])!
        if userCount == 0{
            var account = Account()
            account.sp3Id = userId
            try account.insert(db)
        }
            /// insert battle
        try Battle(json:json, db: db).insert(db)
        let battleId = db.lastInsertedRowID
            /// insert vsTeam
        try VsTeam(json: json["myTeam"], battleId: battleId).insert(db)
        let vsTeamId = db.lastInsertedRowID
        for (_,element) in json["myTeam"]["players"].arrayValue.enumerated(){
            try Player(json: element, vsTeamId: vsTeamId, db: db).insert(db)
        }

        for (_,element) in json["otherTeams"].arrayValue.enumerated(){
            try VsTeam(json: element, battleId: battleId).insert(db)
            let vsTeamId = db.lastInsertedRowID
            for (_,element) in element["players"].arrayValue.enumerated(){
                try Player(json: element, vsTeamId: vsTeamId, db: db).insert(db)
            }
        }
    }

    public func insertBattles(jsons: [JSON], checkExist: Bool = true) async throws {
        try await self.dbQueue.write { db in
            for json in jsons{
                if try checkExist && self.isBattleExist(id: json["id"].stringValue,db: db){
                    continue
                }
                try self.insertBattle(json: json, db: db)
            }
        }
    }

    /// 删除指定的battle记录及其所有相关数据
    /// - Parameter battleId: battle记录的ID
    public func deleteBattle(battleId: Int64) throws {
        try dbQueue.write { db in
            // 删除顺序：先删除子表，再删除主表
            
            // 1. 删除vsTeam相关的player记录
            let vsTeamIds = try Int64.fetchAll(db, sql: "SELECT id FROM vsTeam WHERE battleId = ?", arguments: [battleId])
            for vsTeamId in vsTeamIds {
                try db.execute(sql: "DELETE FROM player WHERE vsTeamId = ?", arguments: [vsTeamId])
            }
            
            // 2. 删除vsTeam记录
            try db.execute(sql: "DELETE FROM vsTeam WHERE battleId = ?", arguments: [battleId])
            
            // 3. 最后删除battle主记录
            try db.execute(sql: "DELETE FROM battle WHERE id = ?", arguments: [battleId])
        }
    }
    
    /// 删除指定的battle记录及其所有相关数据（通过sp3PrincipalId）
    /// - Parameter sp3PrincipalId: battle记录的sp3PrincipalId
    public func deleteBattle(sp3PrincipalId: String) throws {
        try dbQueue.write { db in
            let battleIds = try Int64.fetchAll(db, sql: "SELECT id FROM battle WHERE sp3PrincipalId = ?", arguments: [sp3PrincipalId])
            for battleId in battleIds {
                try deleteBattle(battleId: battleId, db: db)
            }
        }
    }
    
    /// 删除所有battle记录及其相关数据
    public func deleteAllBattles() throws {
        try dbQueue.write { db in
            // 删除所有player记录（与battle相关的）
            try db.execute(sql: "DELETE FROM player WHERE vsTeamId IS NOT NULL")
            
            // 删除所有vsTeam记录
            try db.execute(sql: "DELETE FROM vsTeam")
            
            // 删除所有battle记录
            try db.execute(sql: "DELETE FROM battle")
        }
    }
    
    /// 内部删除方法，在事务中执行
    private func deleteBattle(battleId: Int64, db: Database) throws {
        // 1. 删除vsTeam相关的player记录
        let vsTeamIds = try Int64.fetchAll(db, sql: "SELECT id FROM vsTeam WHERE battleId = ?", arguments: [battleId])
        for vsTeamId in vsTeamIds {
            try db.execute(sql: "DELETE FROM player WHERE vsTeamId = ?", arguments: [vsTeamId])
        }
        
        // 2. 删除vsTeam记录
        try db.execute(sql: "DELETE FROM vsTeam WHERE battleId = ?", arguments: [battleId])
        
        // 3. 最后删除battle主记录
        try db.execute(sql: "DELETE FROM battle WHERE id = ?", arguments: [battleId])
    }
    
    /// 按时间范围删除battle记录及其相关数据
    /// - Parameters:
    ///   - startDate: 开始时间
    ///   - endDate: 结束时间
    public func deleteBattles(from startDate: Date, to endDate: Date) throws {
        try dbQueue.write { db in
            let battleIds = try Int64.fetchAll(db, sql: "SELECT id FROM battle WHERE playedTime BETWEEN ? AND ?", arguments: [startDate, endDate])
            for battleId in battleIds {
                try deleteBattle(battleId: battleId, db: db)
            }
        }
    }
    
    /// 按账户ID删除battle记录及其相关数据
    /// - Parameter accountId: 账户ID
    public func deleteBattles(accountId: Int64) throws {
        try dbQueue.write { db in
            let battleIds = try Int64.fetchAll(db, sql: "SELECT id FROM battle WHERE accountId = ?", arguments: [accountId])
            for battleId in battleIds {
                try deleteBattle(battleId: battleId, db: db)
            }
        }
    }
}


extension Battle:PreComputable{
    static public func create(from db: Database, identifier: (Int)) throws -> Battle? {
        let id = identifier
        var row = try Battle.fetchOne(db, key: id)
        row?.teams =  try VsTeam.create(from: db, identifier: id)
        if let stageId = row?.stageId{
            row?.stage = try ImageMap.fetchOne(db, key: stageId)
        }
        return row
    }
}

