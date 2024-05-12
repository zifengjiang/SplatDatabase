import Foundation
import GRDB
import SwiftyJSON

public struct Coop: Codable, FetchableRecord, PersistableRecord {
  var id: Int64?
  var sp3PrincipalId: String
  var rule:String
  var boss:UInt16?
  @Packable var suppliedWeapon: PackableNumbers
  var egg:Int
  var bossDefeated:Bool?
  var wave:Int
  var stageId:UInt16
  var afterGrade:Int?
  var afterGradePoint:Int?
  var afterGradeDiff:Int?
  var preDetailId:String?
  var goldScale:Int?
  var silverScale:Int?
  var bronzeScale:Int?
  var jobPoint:Int?
  var jobScore:Int?
  var jobRate:Double?
  var jobBonus:Int?
  var playedTime:Date
  var dangerRate:Double
  var accountId:Int64

  public init(json:JSON, db:Database){
    self.sp3PrincipalId = json["id"].stringValue.getDetailUUID()
    self.rule = json["rule"].stringValue
    if let boss = json["bossResult"]["boss"]["id"].string{
      self.bossDefeated = json["bossResult"]["hasDefeatBoss"].boolValue
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
    self.playedTime = json["playedTime"].stringValue.utcToDate()
    self.dangerRate = json["dangerRate"].doubleValue
    self.accountId = getAccountId(by: json["id"].stringValue.extractUserId(), db: db)
    self.egg = json["waveResults"].arrayValue.reduce(0, { (result, wave) in
      return result + wave["teamDeliverCount"].intValue
    })
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

extension SplatDatabase {
    public func eachCoops(db:Database, handler: (Coop) throws -> Void) throws {
        let rows = try Row.fetchCursor(db, sql: "SELECT * FROM coop")
        while let row = try? rows.next() {

        }
    }
}
