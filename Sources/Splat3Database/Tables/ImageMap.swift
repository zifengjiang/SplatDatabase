//
//  File.swift
//
//
//  Created by 姜锋 on 5/11/24.
//

import Foundation
import SwiftyJSON
import GRDB

public struct ImageMap:Codable, FetchableRecord, PersistableRecord{
  var id:Int64?
  var nameId:String
  var name:String
  var hash:String

  public init(id: Int64? = nil, nameId: String, name: String, hash: String) {
    self.id = id
    self.nameId = nameId
    self.name = name
    self.hash = hash
  }
}

public func getImageId(for nameId:String? = nil,hash:String? = nil, db:Database) -> UInt16 {
  if let nameId = nameId {
    let row = try! Row.fetchOne(db, sql: "SELECT id FROM imageMap WHERE nameId = ?",arguments:[nameId])
    return row?["id"] ?? 0
  }
  if let hash = hash {
    let row = try! Row.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?",arguments:[hash])
    return row?["id"] ?? 0
  }
  return 0
}

