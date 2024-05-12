import Foundation
import GRDB
import SwiftyJSON

public struct Battle:Codable, FetchableRecord, PersistableRecord{
  var id:Int64?
  var sp3PrincipalId:String
  var mode:String
  var rule:String
  var stageId:UInt16
  var playedTime:Date
  var duration:Int
  var judgement:String
  var knockout:String?
  var udemae:String?
  var preDetailId:String?

  // BankaraMatch Attributes
  var earnedUdemaePoint:Int?
  var bankaraMode:String?
  var bankaraPower:Data?

  // LeagueMatch Attributes
  var leagueMatchEventId:String?
  var myLeaguePower:Int?

  // XMatch Attributes
  var lastXPower:Double?
  var entireXPower:Double?

  // FestMatch Attributes
  var festDragonMatchType:String?
  var festContribution:Int?
  var festJewel:Int?
  var myFestPower:Int?
  var awards:String
  var accountId:Int64

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
