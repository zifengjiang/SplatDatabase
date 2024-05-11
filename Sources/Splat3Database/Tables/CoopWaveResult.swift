//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON

/*
 try db.create(table: "coopWaveResult",ifNotExists: true) { t in
   t.autoIncrementedPrimaryKey("id")

   t.column("waveNumber", .integer).notNull()
   t.column("waterLevel", .integer).notNull()
   t.column("eventWave", .text)
   t.column("deliverNorm", .integer)
   t.column("goldenPopCount", .integer).notNull()
   t.column("teamDeliverCount", .integer)

   t.column("coopId", .integer).references("coop", column: "id")
 }
 */

public struct CoopWaveResult:Codable, FetchableRecord,PersistableRecord{
  var id: Int64?
  var waveNumber: Int
  var waterLevel: Int
  var eventWave: String?
  var deliverNorm: Int?
  var goldenPopCount: Int
  var teamDeliverCount: Int?
  
  var coopId: Int64?
  
  public static let databaseTableName = "coopWaveResult"
  
  public init(json: JSON, coopId: Int64? = nil) {
    self.coopId = coopId
    self.waveNumber = json["waveNumber"].intValue
    self.waterLevel = json["waterLevel"].intValue
    self.eventWave = json["eventWave"]["id"].string
    self.deliverNorm = json["deliverNorm"].int
    self.goldenPopCount = json["goldenPopCount"].intValue
    self.teamDeliverCount = json["teamDeliverCount"].int
  }
}
