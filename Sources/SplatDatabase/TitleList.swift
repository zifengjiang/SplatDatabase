    //
    //  File.swift
    //
    //
    //  Created by 姜锋 on 5/14/24.
    //

import Foundation
import SwiftyJSON
import GRDB

class TitleList {
    static let shared = TitleList()

    let titleList: JSON

    private init() {
        let url = Bundle.module.url(forResource: "titles", withExtension: "json")!
        let jsonData = try! Data(contentsOf: url)
        titleList = try! JSON(data: jsonData)
    }
}

public func formatByname(_ byname: String,language: String,db: Database) -> String {
    let titleList = TitleList.shared.titleList
    var tags: [(adjective: String, id: String, index: Int)] = []
    var node = titleList["adjectives"]
    var current = ""

    for char in byname {
        let charString = String(char)
        if node[charString].exists() {
            node = node[charString]
            current += charString
            for tag in node["tags"].arrayValue {
                tags.append((adjective: current, id: tag["id"].stringValue, index: tag["index"].intValue))
            }
        } else {
            break
        }
    }

    for tag in tags {
        let subject = String(byname.dropFirst(tag.adjective.count)).trimmingCharacters(in: .whitespaces)
        if let subjectId = titleList["subjects"][tag.index][subject].string {
            let subjectRow = try? Row.fetchOne(db, sql: "SELECT \(language) FROM i18n WHERE key = ?", arguments: [subjectId])
            let adjectiveRow = try? Row.fetchOne(db, sql: "SELECT \(language) FROM i18n WHERE key = ?", arguments: [tag.id])

            return "\(adjectiveRow?[language] ?? "") \(subjectRow?[language] ?? "")"
        }
    }

    return byname
}
