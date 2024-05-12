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
 try db.create(table: "weapon",ifNotExists: true) { t in
   t.column("id", .text).notNull()
   t.column("order", .integer).notNull().defaults(to: 0)
   t.column("coopId", .integer).references("coop", column: "id") // shift weapons
   t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id") // player weapons
 }
 */

public struct Weapon:Codable, FetchableRecord,PersistableRecord{
  var imageMapId:UInt16
  var order:Int
  var coopId:Int64?
  var coopPlayerResultId:Int64?
  var coopWaveResultId:Int64?
}

