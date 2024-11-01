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

    public func deleteAllBattles() throws {
        try dbQueue.write { db in
            try db.execute(literal: "DELETE FROM player WHERE vsTeamId IS NOT NULL;")
            try db.execute(literal: "DELETE FROM vsTeam;")
            try db.execute(literal: "DELETE FROM battle;")
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

