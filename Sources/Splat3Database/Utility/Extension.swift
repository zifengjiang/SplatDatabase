//
//  File.swift
//
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import SwiftyJSON
import GRDB

extension String {
  func getImageHash() -> String {
    let splitted = self.split(separator: "/")
    guard let last = splitted.last else {
      return ""
    }
    let hashPart = last.split(separator: "_")
    return String(hashPart.first ?? "")
  }

  func utcToDate() -> Date {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
      return formatter.date(from: self) ?? Date()
  }

}


// extension for [String: JSON]
extension Dictionary where Key == String, Value == JSON {
  /// convert to string {a}_b_{c}_d_{e}
  func toRGBAUInt32() -> UInt32 {
    let r = self["r"]?.double ?? 0
    let g = self["g"]?.double ?? 0
    let b = self["b"]?.double ?? 0
    let a = self["a"]?.double ?? 0
    return rgbaToUInt(r: r, g: g, b: b, a: a)
  }

  func toGearPackableNumbers(db:Database) -> PackableNumbers{
    let id = getImageId(hash:self["originalImage"]?["url"].string?.getImageHash(), db: db)
    let primaryGearPower = getImageId(hash:self["primaryGearPower"]?["image"]["url"].string?.getImageHash(),db: db)
    let additonalGearPower:[UInt16] = self["additionalGearPowers"]?.array?.compactMap{getImageId(hash:$0["image"]["url"].string?.getImageHash(),db: db)} ?? []

    return PackableNumbers([id,primaryGearPower] + additonalGearPower)
  }
}

