//
//  File.swift
//
//
//  Created by 姜锋 on 5/11/24.
//

import Foundation
import SwiftyJSON
import CryptoKit

func getBadgeMap(from json: JSON) -> [ImageMap] {
  var badges = [ImageMap]()

  for (_, badgeJSON):(String, JSON) in json {
    guard let badgeId = badgeJSON["Id"].int else {
      continue
    }
    let nameId = Data("Badge-\(badgeId)".utf8).base64EncodedString()
    if let badgeName = badgeJSON["Name"].string,
       let imageData = badgeName.data(using: .utf8) {
      let digest = SHA256.hash(data: imageData)
      let hash = digest.map { String(format: "%02hhx", $0) }.joined()

      let badge = ImageMap(nameId: nameId, name: "Badge_\(badgeName)", hash: hash)
      badges.append(badge)
    }
  }

  return badges
}

func getWeaponMainMap(from json:JSON) -> [ImageMap]{
  var weapons = [ImageMap]()

  for (_, weaponJSON):(String, JSON) in json {

    if let type = weaponJSON["Type"].string, let isCoopRare = weaponJSON["IsCoopRare"].bool, type == "Versus" || type == "Coop" && isCoopRare{
      guard let weaponId = weaponJSON["Id"].int else {
        continue
      }
      let name = "Weapon-\(weaponId)"
      let nameId = Data(name.utf8).base64EncodedString()
      if let weaponName = weaponJSON["__RowId"].string,
         let imageData = weaponName.data(using: .utf8) {
        let digest = SHA256.hash(data: imageData)
        let hash = digest.map { String(format: "%02hhx", $0) }.joined()

        let weapon = ImageMap(nameId: nameId, name: "Wst_\(weaponName)", hash: hash)
        weapons.append(weapon)
      }
    }
  }

  return weapons
}

func getWeaponSubspe(from json:JSON, prefix:String) -> [ImageMap]{
  var specials = [ImageMap]()

  for (_, weaponJSON):(String, JSON) in json{
    if let type = weaponJSON["Type"].string, type == "Versus" || type == "Coop"{
      guard let weaponId = weaponJSON["Id"].int else {
        continue
      }
      let name = "\(prefix)Weapon-\(weaponId)"
      let nameId = Data(name.utf8).base64EncodedString()
      if let weaponName = weaponJSON["__RowId"].string?.replacingOccurrences(of: "_Coop", with: ""),
         let imageData = weaponName.data(using: .utf8) {
        let digest = SHA256.hash(data: imageData)
        let hash = digest.map { String(format: "%02hhx", $0) }.joined()

          let weapon = ImageMap(nameId: nameId, name: "\(prefix == "Sub" ? "Wsb" : "Wsp")_\(weaponName)", hash: hash)
        specials.append(weapon)
      }
    }
  }
  return specials
}

func getNameplateMap(from json:JSON) -> [ImageMap]{
  var backgrounds = [ImageMap]()

  for (_, backgroundJSON):(String, JSON) in json{
    guard let backgroundId = backgroundJSON["Id"].int else{
      continue
    }
    let name = "NameplateBackground-\(backgroundId)"
    let nameId = Data(name.utf8).base64EncodedString()
    if let backgroundName = backgroundJSON["__RowId"].string,
       let imageData = backgroundName.data(using: .utf8) {
      let digest = SHA256.hash(data: imageData)
      let hash = digest.map { String(format: "%02hhx", $0) }.joined()

      let background = ImageMap(nameId: nameId, name: backgroundName, hash: hash)
      backgrounds.append(background)
    }
  }

  return backgrounds
}

func getGearMap(from json:JSON) -> [ImageMap]{
  var gears = [ImageMap]()
  
  for (_, gearJSON):(String, JSON) in json{
    guard let brand = gearJSON["Brand"].string,let skill = gearJSON["Skill"].string,let rowId = gearJSON["__RowId"].string else{
      continue
    }
    if let brandMap = getImageMap(brand) { gears.append(brandMap) }
    if let skillMap = getImageMap(skill) { gears.append(skillMap) }
    if let rowIdMap = getImageMap(rowId) { gears.append(rowIdMap) }
  }

  return gears
}

func getImageMap(_ name:String) -> ImageMap?{
  let nameId = Data(name.utf8).base64EncodedString()
  if let imageData = name.data(using: .utf8) {
    let digest = SHA256.hash(data: imageData)
    let hash = digest.map { String(format: "%02hhx", $0) }.joined()

    return ImageMap(nameId: nameId, name: name, hash: hash)
  }
  return nil
}


func getCoopEnemyMap(from json:JSON) -> [ImageMap]{
  var salmonids = [ImageMap]()

  let map = [
    "SakelienBomber": 4,
    "SakelienCupTwins": 5,
    "SakelienShield": 6,
    "SakelienSnake": 7,
    "SakelienTower": 8,
    "Sakediver": 9,
    "Sakerocket": 10,
    "SakePillar": 11,
    "SakeDolphin": 12,
    "SakeArtillery": 13,
    "SakeSaucer": 14,
    "SakelienGolden": 15,
    "Sakedozer": 17,
    "SakeBigMouth": 20,
    "SakelienGiant": 23,
    "SakeRope": 24,
    "SakeJaw":25
  ]

  for (_, salmonidJSON):(String, JSON) in json{
    if let type = salmonidJSON["Type"].string, let id = map[type]{
      let name = "CoopEnemy-\(id)"
      let nameId = Data(name.utf8).base64EncodedString()
      if let imageData = type.data(using: .utf8) {
        let digest = SHA256.hash(data: imageData)
        let hash = digest.map { String(format: "%02hhx", $0) }.joined()

        let salmonid = ImageMap(nameId: nameId, name: type, hash: hash)
        salmonids.append(salmonid)
      }
    }
  }

  return salmonids
}

func getCoopSkinMap(from json:JSON) -> [ImageMap]{
  var workSuits = [ImageMap]()

  for (_, workSuitJSON):(String, JSON) in json{
    guard let workSuitId = workSuitJSON["Id"].int else{
      continue
    }
    let name = "CoopUniform-\(workSuitId)"
    let nameId = Data(name.utf8).base64EncodedString()
    if let workSuitName = workSuitJSON["__RowId"].string,
       let imageData = workSuitName.data(using: .utf8) {
      let digest = SHA256.hash(data: imageData)
      let hash = digest.map { String(format: "%02hhx", $0) }.joined()

      let workSuit = ImageMap(nameId: nameId, name: workSuitName, hash: hash)
      workSuits.append(workSuit)
    }
  }

  return workSuits
}

func getStageMap(from json:JSON, prefix:String) -> [ImageMap]{
  var stages = [ImageMap]()

  for (_, stageJSON):(String, JSON) in json{
    guard let stageId = stageJSON["Id"].int else{
      continue
    }
    let name = "\(prefix)Stage-\(stageId)"
    let nameId = Data(name.utf8).base64EncodedString()
    if var stageName = stageJSON["__RowId"].string?.replacingOccurrences(of: "\\d", with: "", options: .regularExpression),
       let imageData = stageName.data(using: .utf8) {
      let digest = SHA256.hash(data: imageData)
      let hash = digest.map { String(format: "%02hhx", $0) }.joined()
      
        if let isBigRun = stageJSON["IsBigRun"].bool, isBigRun{
            stageName = stageName.replacingOccurrences(of: "Cop", with: "Vss")
        }
      let stage = ImageMap(nameId: nameId, name: name, hash: hash)
      stages.append(stage)
    }
  }

  return stages
}

func getUnknownMap() -> [ImageMap]{
  var unknowns = [ImageMap]()
  unknowns.append(ImageMap(nameId: Data("Unknown-1".utf8).base64EncodedString(), name: "Unknown-1", hash: "473fffb2442075078d8bb7125744905abdeae651b6a5b7453ae295582e45f7d1"))
  unknowns.append(ImageMap(nameId: Data("Unknown-2".utf8).base64EncodedString(), name: "Unknown-2", hash: "9d7272733ae2f2282938da17d69f13419a935eef42239132a02fcf37d8678f10"))
  return unknowns
}
