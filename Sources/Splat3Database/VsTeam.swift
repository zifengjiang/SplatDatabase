//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON

/// struct for vsTeam table
///// try db.create(table: "vsTeam",ifNotExists: true) { t in
//t.autoIncrementedPrimaryKey("id")
//t.column("order", .integer).notNull() // 0 is my team
//t.column("color", .text).notNull()
//t.column("judgement", .text)
//
///// Team Result Attributes
//t.column("paintPoint", .integer)
//t.column("paintRatio", .double)
//t.column("score", .integer)
//t.column("noroshi", .integer)
//
//t.column("tricolorRole",.text)
//t.column("festTeamName", .text)
//t.column("festUniformName",.text)
//t.column("festUniformBonusRate", .double)
//t.column("festStreakWinCount", .integer)
//
//t.column("battleId", .integer).references("battle", column: "id")
//
//}
public struct VsTeam:Codable, FetchableRecord, PersistableRecord{
  var id:Int64?
  var order:Int
  var color:UInt32
  var judgement:String?

  // Team Result Attributes
  var paintPoint:Int?
  var paintRatio:Double?
  var score:Int?
  var noroshi:Int?

  var tricolorRole:String?
  var festTeamName:String?
  var festUniformName:String?
  var festUniformBonusRate:Double?
  var festStreakWinCount:Int?

  var battleId:Int64?

  public init(json:JSON, battleId:Int64){
    self.battleId = battleId
    self.order = json["order"].intValue
    self.color = json["color"].dictionary!.toRGBAUInt32()
    self.judgement = json["judgement"].string

    self.paintPoint = json["result"]["paintPoint"].int
    self.paintRatio = json["result"]["paintRatio"].double
    self.score = json["result"]["score"].int
    self.noroshi = json["result"]["noroshi"].int

    self.tricolorRole = json["tricolorRole"].string
    self.festTeamName = json["festTeamName"].string
    self.festUniformName = json["festUniformName"].string
    self.festUniformBonusRate = json["festUniformBonusRate"].double
    self.festStreakWinCount = json["festStreakWinCount"].int
  }
}
