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
  @DatabasePackableNumbers var nameplate: PackableNumbers
  var nameplateTextColor: UInt32

  // Coop Attributes
  var uniformId: UInt16?

  // Battle Attributes
  var paint: Int?
  var weaponId: UInt16?
  @DatabasePackableNumbers var headGear: PackableNumbers
  @DatabasePackableNumbers var clothingGear: PackableNumbers
  @DatabasePackableNumbers var shoesGear: PackableNumbers
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
  public init(json: JSON, vsTeamId: Int64? = nil, coopPlayerResultId: Int64? = nil, db:Database) {
    self.coopPlayerResultId = coopPlayerResultId
    self.vsTeamId = vsTeamId
    self.sp3PrincipalId = json["id"].stringValue
    self.byname = json["byname"].stringValue
    self.name = json["name"].stringValue
    self.nameId = json["nameId"].stringValue
    self.species = json["species"].stringValue == "INKLING"
    let nameplateBackground = getImageId(for: json["nameplate"]["background"]["id"].stringValue, db: db)
    let nameplateBadge1 = getImageId(for: json["nameplate"]["badges"][0]["id"].string,db: db)
    let nameplateBadge2 = getImageId(for: json["nameplate"]["badges"][1]["id"].string,db: db)
    let nameplateBadge3 = getImageId(for: json["nameplate"]["badges"][2]["id"].string,db: db)

    self.nameplate = PackableNumbers([nameplateBackground,nameplateBadge1, nameplateBadge2, nameplateBadge3])

    self.nameplateTextColor = json["nameplate"]["background"]["textColor"].dictionaryValue.toRGBAUInt32()

    if coopPlayerResultId != nil{
      self.uniformId = getImageId(for:json["uniform"]["id"].string, db: db)
    }

    self.paint = json["paint"].int
    if vsTeamId != nil{
      self.weaponId = getImageId(for: json["weapon"]["id"].string,db: db)
    }
    self.headGear = json["headGear"].dictionary?.toGearPackableNumbers(db: db) ?? PackableNumbers([0])
    self.clothingGear = json["clothingGear"].dictionary?.toGearPackableNumbers(db: db) ?? PackableNumbers([0])
    self.shoesGear = json["shoesGear"].dictionary?.toGearPackableNumbers(db: db) ?? PackableNumbers([0])
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
    self.type = self.uniformId != nil
  }
}






