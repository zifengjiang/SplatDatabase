import Foundation
import GRDB
import SwiftyJSON

class TitleList {
    static let shared = TitleList()

    let titleList: JSON

    private init() {
        let url = Bundle.module.url(forResource: "titles", withExtension: "json")!
        let jsonData = try! Data(contentsOf: url)
        titleList = try! JSON(data: jsonData)
    }
}


public func _formatByname(_ byname: String) -> (adjective: String, subject:String)? {
    let titleList = TitleList.shared.titleList
    var tags: [(adjective: String, id: String, index: Int)] = []
    var adjectives = titleList["adjectives"]
    var current = ""

    for char in byname {
        let charString = String(char)
        if adjectives[charString].exists() {
            adjectives = adjectives[charString]
            current += charString
            for tag in adjectives["tags"].arrayValue {
                tags.append((adjective: current, id: tag["id"].stringValue, index: tag["index"].intValue))
            }
        } else {
            break
        }
    }

    for tag in tags {
        let subject = byname.dropFirst(tag.adjective.count).trimmingCharacters(in: .whitespaces)
        if let subjectString = titleList["subjects"][tag.index][subject].string {
            return (adjective: tag.id, subject:subjectString)
        }
    }

    return nil
}

public func formatByname(_ byname: String, db:Database) -> PackableNumbers{
    let formatted = _formatByname(byname)
    if let adjectiveId = getI18nId(by: formatted?.adjective, db: db), let subjectId = getI18nId(by: formatted?.subject, db: db){
        return PackableNumbers([adjectiveId, subjectId])
    }
    return PackableNumbers([0, 0])
}

