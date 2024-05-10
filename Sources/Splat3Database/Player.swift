//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON

/// struct for player table
public struct Player: Codable, FetchableRecord, PersistableRecord {
  var id: Int64?
  var type: Bool

  // Common Attributes
  var sp3PrincipalId: String
  var byname: String
  var name: String
  var nameId: String
  var species: Bool
  var nameplateBackground: String
  var nameplateTextColor: UInt32
  var nameplateBadge1: String?
  var nameplateBadge2: String?
  var nameplateBadge3: String?

  // Coop Attributes
  var uniform: String?

  // Battle Attributes
  var paint: Int?
  var weapon: String?
  var headGear: String?
  var clothingGear: String?
  var shoesGear: String?
  var crown: Bool?
  var festDragonCert: String?
  var festGrade: String?
  var isMyself: Bool?

  // Battle Result Attributes
  var kill: Int?
  var death: Int?
  var assist: Int?
  var special: Int?
  var noroshiTry: Int?

  // References to vsTeam
  var vsTeamId: Int64?
  var coopPlayerResultId: Int64?

  // Database table name
  public static let databaseTableName = "player"

  /// init from json
  public init(json: JSON, vsTeamId: Int64? = nil, coopPlayerResultId: Int64? = nil) {
    self.coopPlayerResultId = coopPlayerResultId
    self.vsTeamId = vsTeamId
    self.sp3PrincipalId = json["id"].stringValue
    self.byname = json["byname"].stringValue
    self.name = json["name"].stringValue
    self.nameId = json["nameId"].stringValue
    self.species = json["species"].stringValue == "INKLING"
    self.nameplateBackground = json["nameplate"]["background"]["id"].stringValue
    self.nameplateTextColor = json["nameplate"]["background"]["textColor"].dictionaryValue.toRGBAUInt32()
    self.nameplateBadge1 = json["nameplate"]["badges"][0]["id"].string
    self.nameplateBadge2 = json["nameplate"]["badges"][1]["id"].string
    self.nameplateBadge3 = json["nameplate"]["badges"][2]["id"].string

    self.uniform = json["uniform"]["id"].string

    self.paint = json["paint"].int
    self.weapon = json["weapon"]["id"].string
    self.headGear = json["headGear"].dictionary?.toGearString()
    self.clothingGear = json["clothingGear"].dictionary?.toGearString()
    self.shoesGear = json["shoesGear"].dictionary?.toGearString()
    self.crown = json["crown"].bool
    self.festDragonCert = json["festDragonCert"].string
    self.festGrade = json["festGrade"].string
    self.isMyself = json["isMyself"].bool

    self.kill = json["result"]["kill"].int
    self.death = json["result"]["death"].int
    self.assist = json["result"]["assist"].int
    self.special = json["result"]["special"].int
    self.special = json["result"]["special"].int

//    self.vsTeamId = 00
    self.type = self.uniform != nil
  }
}






