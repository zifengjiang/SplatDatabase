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


public func formatByname(_ byname: String) async -> (adjective: String, subject:String, male:Bool?)? {
    return formatBynameSync(byname)
}

public func formatBynameSync(_ byname: String) -> (adjective: String, subject:String, male:Bool?)? {
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
            let  splitSubjectString = subjectString.split(separator: "_")
            if splitSubjectString.count == 2{
                return (adjective: tag.id, subject: String(splitSubjectString[0]),male: splitSubjectString[1] == "0")
            }
            return (adjective: tag.id, subject:subjectString, male: nil)
        }
    }

    return nil
}


