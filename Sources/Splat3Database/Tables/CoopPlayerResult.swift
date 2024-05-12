//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON
//try db.create(table: "coopPlayerResult",ifNotExists: true) { t in
//  t.autoIncrementedPrimaryKey("id")
//  t.column("order",.integer).notNull()
//  t.column("player", .integer).notNull().references("player", column: "id")
//  t.column("specialWeapon", .text)
//  t.column("defeatEnemyCount", .integer).notNull()
//  t.column("deliverCount", .integer).notNull()
//  t.column("goldenAssistCount", .integer).notNull()
//  t.column("goldenDeliverCount", .integer).notNull()
//  t.column("rescueCount", .integer).notNull()
//  t.column("rescuedCount", .integer).notNull()
//
//  t.column("coopId", .integer).references("coop", column: "id")
//}

public struct CoopPlayerResult:Codable, FetchableRecord,PersistableRecord{
  var id:Int64?
  var order:Int
  var specialWeaponId:UInt16?
  var defeatEnemyCount:Int
  var deliverCount:Int
  var goldenAssistCount:Int
  var goldenDeliverCount:Int
  var rescueCount:Int
  var rescuedCount:Int
  var coopId:Int64?

  public init(json:JSON, order:Int, coopId:Int64,db:Database){
    self.coopId = coopId
    self.order = order
    let specialWeaponId = getImageId(hash:json["specialWeapon"]["image"]["url"].string?.getImageHash(),db: db)
    if specialWeaponId == 0{
      self.specialWeaponId = nil
    }else{
      self.specialWeaponId = UInt16(specialWeaponId)
    }
    self.defeatEnemyCount = json["defeatEnemyCount"].intValue
    self.deliverCount = json["deliverCount"].intValue
    self.goldenAssistCount = json["goldenAssistCount"].intValue
    self.goldenDeliverCount = json["goldenDeliverCount"].intValue
    self.rescueCount = json["rescueCount"].intValue
    self.rescuedCount = json["rescuedCount"].intValue
  }
}
