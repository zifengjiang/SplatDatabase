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
    
    func getCoopGradeId() -> Int{
        guard let data = Data(base64Encoded: self) else {
            print("Error: String is not a valid Base64 encoded string")
            return 0
        }
        
        let splitted = String(data: data, encoding: .utf8)?.split(separator: "-")
        guard let last = splitted?.last else {
            return 0
        }
        return Int(last) ?? 0
    }
    
    func getPlayerId() -> String{
        guard let data = Data(base64Encoded: self) else {
            print("Error: String is not a valid Base64 encoded string")
            return ""
        }
        
        let splitted = String(data: data, encoding: .utf8)?.split(separator: "-")
        guard let last = splitted?.last else {
            return ""
        }
        return String(last)
    }
    
    func getDetailUUID() -> String{
        guard let data = Data(base64Encoded: self) else {
            print("Error: String is not a valid Base64 encoded string")
            return ""
        }
        
        let splitted = String(data: data, encoding: .utf8)?.split(separator: "_")
        guard let last = splitted?.last else {
            return ""
        }
        return String(last)
    }
    
    
        /// Extracts the substring after the last dash before the first colon using split.
    func extractUserId() -> String {
        guard let data = Data(base64Encoded: self) else {
            print("Error: String is not a valid Base64 encoded string")
            return ""
        }
        let splitted = String(data: data, encoding: .utf8)?.split(separator: ":").first?.split(separator: "-").last
        
        return String(splitted!)
    }
    
    
    
}


    // extension for [String: JSON]
extension Dictionary where Key == String, Value == JSON {
    
    
    func toRGBPackableNumbers() -> PackableNumbers{
        let r = self["r"]?.double ?? 0
        let g = self["g"]?.double ?? 0
        let b = self["b"]?.double ?? 0
        let a = self["a"]?.double ?? 0
        return PackableNumbers([UInt16(r*255),UInt16(g*255),UInt16(b*255),UInt16(a*255)])
    }
    
    
    func toGearPackableNumbers(db:Database) -> PackableNumbers{
        let id = getImageId(hash:self["originalImage"]?["url"].string?.getImageHash(), db: db)
        let primaryGearPower = getImageId(hash:self["primaryGearPower"]?["image"]["url"].string?.getImageHash(),db: db)
        let additionalGearPower:[UInt16] = self["additionalGearPowers"]?.array?.compactMap{getImageId(hash:$0["image"]["url"].string?.getImageHash(),db: db)} ?? []

        return PackableNumbers([id,primaryGearPower] + additionalGearPower)
    }
    
    
}


extension String {
    var extractedDate: Date? {
            // 提取时间部分的字符串
        guard let timeString = self.split(separator: ":").last?.split(separator: "_").first else {
            return nil
        }

            // 定义时间格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

            // 解析时间字符串并转换为Date类型
        return dateFormatter.date(from: String(timeString))
    }
}

extension String {
    var base64DecodedString: String {
        guard let data = Data(base64Encoded: self) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
