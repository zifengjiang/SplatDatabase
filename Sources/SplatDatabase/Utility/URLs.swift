//
//  File.swift
//
//
//  Created by 姜锋 on 5/11/24.
//

import Foundation


let LeannyUrl = "https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/%@/%@.json"

enum Splat3URLs: String {
  case badge = "BadgeInfo"
  case enemy = "CoopEnemyInfo"
  case skin = "CoopSkinInfo"
  case head = "GearInfoHead"
  case clothes = "GearInfoClothes"
  case shoes = "GearInfoShoes"
  case nameplate = "NamePlateBgInfo"
  case coopStage = "CoopSceneInfo"
  case vsStage = "VersusSceneInfo"
  case weaponMain = "WeaponInfoMain"
  case weaponSpecial = "WeaponInfoSpecial"
  case weaponSub = "WeaponInfoSub"

  func url(for version:String) -> String {
    return String(format: LeannyUrl, version, self.rawValue)
  }

  func filePath() -> String{
    let bundle = Bundle.module
    return bundle.path(forResource: self.rawValue, ofType: "json")!
  }
}
