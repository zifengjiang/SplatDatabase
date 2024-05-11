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
  var id:String
  var defeatCount:Int
  var teamDefeatCount:Int
  var popCount:Int
  var coopId:Int64?

  public init(json:JSON, coopId:Int64){
    self.coopId = coopId
    self.id = json["enemy"]["id"].stringValue
    self.defeatCount = json["defeatCount"].intValue
    self.teamDefeatCount = json["teamDefeatCount"].intValue
    self.popCount = json["popCount"].intValue
  }
}
