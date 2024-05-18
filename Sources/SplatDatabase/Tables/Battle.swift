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
    
    public init(json:JSON, db:Database){
        self.sp3PrincipalId = json["id"].stringValue.getDetailUUID()
        self.mode = json["vsMode"]["mode"].stringValue
        self.rule = json["vsRule"]["rule"].stringValue
        self.stageId = getImageId(for:json["vsStage"]["id"].stringValue, db: db)
        self.playedTime = json["playedTime"].stringValue.utcToDate()
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
        let sp3CoopId = json["id"].stringValue.extractUserId()
        try insertAccount(id: sp3CoopId)
        try self.dbQueue.writeInTransaction { db in
            do{
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
                return .commit
            } catch{
                return .rollback
            }
        }
    }
}

extension SplatDatabase.Filter {
    func buildBattleQuery() -> SQLRequest<Row> {
        var conditions: [String] = []
        var arguments: [DatabaseValueConvertible] = []
        
        if let modes = modes, !modes.isEmpty {
            let modePlaceholders = modes.map { _ in "?" }.joined(separator: ", ")
            conditions.append("battle.mode IN (\(modePlaceholders))")
            arguments.append(contentsOf: modes)
        }
        
        if let rules = rules, !rules.isEmpty {
            let rulePlaceholders = rules.map { _ in "?" }.joined(separator: ", ")
            conditions.append("battle.rule IN (\(rulePlaceholders))")
            arguments.append(contentsOf: rules)
        }
        
        if let stageIds = stageIds, !stageIds.isEmpty {
            let stageIdPlaceholders = stageIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("battle.stageId IN (\(stageIdPlaceholders))")
            arguments.append(contentsOf: stageIds)
        }
        
        if let weaponIds = weaponIds, !weaponIds.isEmpty {
            let weaponIdPlaceholders = weaponIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("player.weaponId IN (\(weaponIdPlaceholders)) AND player.isCoop = 0")
            arguments.append(contentsOf: weaponIds)
        }
        
        if let start = start {
            conditions.append("battle.playedTime >= ?")
            arguments.append(start)
        }
        
        if let end = end {
            conditions.append("battle.playedTime <= ?")
            arguments.append(end)
        }
        
        let whereClause = conditions.isEmpty ? "1" : conditions.joined(separator: " AND ")
        let sql = """
        SELECT battle.* FROM battle
        JOIN vsTeam ON battle.id = vsTeam.battleId
        JOIN player ON vsTeam.id = player.vsTeamId
        WHERE \(whereClause) AND player.isMyself = 1 AND accountId = \(accountId)
        """
        
        return SQLRequest<Row>(sql: sql, arguments: StatementArguments(arguments))
    }
}

extension SplatDatabase {
    public func eachBattles(db:Database, filter:Filter, body: (Battle) -> Void) throws {
        let cursor = try Row.fetchCursor(db, filter.buildBattleQuery())
        while let row = try cursor.next() {
            try body(Battle(row: row))
        }
    }
}
