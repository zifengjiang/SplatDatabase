//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON

public struct CoopEnemyResult:Codable, FetchableRecord, PersistableRecord{
  var enemyId:UInt16
  var defeatCount:Int
  var teamDefeatCount:Int
  var popCount:Int
  var coopId:Int64?

  public init(json:JSON, coopId:Int64, db:Database){
    self.coopId = coopId
    self.enemyId = getImageId(for:json["enemy"]["id"].stringValue, db: db)
    self.defeatCount = json["defeatCount"].intValue
    self.teamDefeatCount = json["teamDefeatCount"].intValue
    self.popCount = json["popCount"].intValue
  }
}
