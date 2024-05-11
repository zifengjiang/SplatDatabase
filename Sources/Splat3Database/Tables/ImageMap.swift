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
