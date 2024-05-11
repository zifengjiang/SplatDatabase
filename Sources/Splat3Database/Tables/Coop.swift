//
//  Coop.swift
//
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON

/*
 try db.create(table: "coop",ifNotExists: true) { t in
   t.autoIncrementedPrimaryKey("id")
   t.column("rule", .text).notNull()
   t.column("sp3PrincipalId", .text).notNull()
   t.column("bossResult", .text) // true_{boss_name} or false_{boss_name}, null means no boss
   t.column("resultWave", .integer).notNull()
   t.column("stage", .text).notNull()
   t.column("afterGrade", .text)
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
 }
 */

public struct Coop: Codable, FetchableRecord, PersistableRecord {
  var id: Int64?
  var sp3PrincipalId: String
  var rule:String
  var bossResult:String?
  var resultWave:Int
  var stage:String
  var afterGrade:String?
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

  public init(json:JSON){
    self.sp3PrincipalId = json["id"].stringValue
    self.rule = json["rule"].stringValue
    if let bossResult = json["bossResult"]["boss"]["id"].string{
      let defeated = json["bossResult"]["hasDefeatBoss"].boolValue
      self.bossResult = "\(defeated)_\(bossResult)"
    }

    self.resultWave = json["resultWave"].intValue
    self.stage = json["coopStage"]["id"].stringValue
    self.afterGrade = json["afterGrade"]["id"].string
    self.afterGradePoint = json["afterGradePoint"].int
    self.afterGradeDiff = 0/*json["afterGradeDiff"].int*/
    self.preDetailId = json["previousHistoryDetail"]["id"].string
    self.goldScale = json["scale"]["gold"].int
    self.silverScale = json["scale"]["silver"].int
    self.bronzeScale = json["scale"]["bronze"].int
    self.jobPoint = json["jobPoint"].int
    self.jobScore = json["jobScore"].int
    self.jobRate = json["jobRate"].double
    self.jobBonus = json["jobBonus"].int
    self.playedTime = json["playedTime"].stringValue.utcToDate()
    self.dangerRate = json["dangerRate"].doubleValue
  }
}
