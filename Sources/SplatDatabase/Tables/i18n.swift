import Foundation
import GRDB
import SwiftyJSON

// 定义一个结构体来匹配 i18n 表的结构
struct I18n: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var key: String
    var zhCN: String?
    var zhTW: String?
    var en: String?
    var ja: String?
    var ko: String?
    var ru: String?
    var fr: String?
    var de: String?
    var es: String?
    var it: String?
    var nl: String?

    // 使用字典初始化本地化数据
    init(key: String, translations: [String: String?]) {
        self.key = key
        self.zhCN = translations["zhCN"] ?? nil
        self.zhTW = translations["zhTW"] ?? nil
        self.en = translations["en"] ?? nil
        self.ja = translations["ja"] ?? nil
        self.ko = translations["ko"] ?? nil
        self.ru = translations["ru"] ?? nil
        self.fr = translations["fr"] ?? nil
        self.de = translations["de"] ?? nil
        self.es = translations["es"] ?? nil
        self.it = translations["it"] ?? nil
        self.nl = translations["nl"] ?? nil
    }
}

public func getI18nId(by key:String?, db:Database) -> UInt16?{
  guard let key = key else{ return nil }
  let row = try! Row.fetchOne(db, sql: "SELECT id FROM i18n WHERE key = ?",arguments:[key])
  return row?["id"] ?? nil
}



extension SplatDatabase{
    private func parseLocalizationFile(named fileName: String, in bundle: Bundle) -> [String: String]? {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            print("Failed to locate \(fileName).json in bundle.")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let parsedData = try JSONDecoder().decode([String: String].self, from: data)
            return parsedData
        } catch {
            print("Error parsing \(fileName).json: \(error)")
            return nil
        }
    }

    private func insertLocalizationData(localizationData: [String: [String: String?]]) throws {
        for (key, translations) in localizationData {
            let k = key.split(separator: "_").first!
            let record = I18n(key: String(k), translations: translations)
            try self.dbQueue.writeInTransaction { db in
                do{
                    try record.insert(db)
                    return .commit
                }catch{
                    return .rollback
                }
            }
        }
    }

    func updateI18n() throws {
        let bundle = Bundle.module

            // 文件名列表，不包括.json扩展名
        let jsonFileNames = [
            "de",
            "en",
            "es",
            "fr",
            "it",
            "ja",
            "nl",
            "kr",
            "ru",
            "zhCN",
            "zhTW"
        ]

        var localizationData: [String: [String: String?]] = [:]

        for fileName in jsonFileNames {
            if let parsedData = parseLocalizationFile(named: fileName, in: bundle) {
                for (key, value) in parsedData {
                        // 将单个语言的翻译整合到全局的localizationData中
                    localizationData[key, default: [:]][fileName] = value
                }
            }
        }

        try insertLocalizationData(localizationData: localizationData)
    }
}
