import Foundation
import GRDB
import SwiftyJSON

public struct Schedule: Codable, FetchableRecord, PersistableRecord{
    public var id:Int64?
    public var startTime:Date
    public var endTime:Date
    public var mode:Mode
    public var rule1:Rule
    public var rule2:Rule?
    public var stage:PackableNumbers
    public var weapons:PackableNumbers?
    public var boss:UInt16?
    public var event:String?

    public enum CodingKeys: String, CodingKey {
        case startTime
        case endTime
        case mode
        case rule1
        case rule2
        case stage
        case weapons
        case boss
        case event
    }

    // MARK: - Computed Properties
    public var _stage: [ImageMap] = []
    public var _weapons: [ImageMap] = []
    public var _boss: ImageMap? = nil

    public enum Mode: Int, Codable {
        case regular = 0
        case bankara
        case x
        case event
        case fest
        case salmonRun
    }

    public enum Rule: Int, Codable, CaseIterable{
        case turfWar = 0
        case splatZones
        case towerControl
        case rainmaker
        case clamBlitz
        case triColor
        case salmonRun
        case bigRun
        case teamContest
    }
}

public func insertSchedules(json:JSON, db:Database) throws {
    let regularSchedules = json["data"]["regularSchedules"]["nodes"].arrayValue
    let bankaraSchedules = json["data"]["bankaraSchedules"]["nodes"].arrayValue
    let xSchedules = json["data"]["xSchedules"]["nodes"].arrayValue
    let eventSchedules = json["data"]["eventSchedules"]["nodes"].arrayValue
    let festSchedules = json["data"]["festSchedules"]["nodes"].arrayValue
    let salmonRunBigRunSchedules = json["data"]["coopGroupingSchedule"]["bigRunSchedules"]["nodes"].arrayValue
    let salmonRunRegularSchedules = json["data"]["coopGroupingSchedule"]["regularSchedules"]["nodes"].arrayValue
    let salmonRunTeamContestSchedules = json["data"]["coopGroupingSchedule"]["teamContestSchedules"]["nodes"].arrayValue

    try regularSchedules.forEach{
        let vsStages = $0["regularMatchSetting"]["vsStages"].arrayValue
        let stages = try vsStages.compactMap{
            if let hash = $0["image"]["url"].stringValue.getImageHash(){
                return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
            }
            return nil
        }
        if !stages.isEmpty{
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .regular, rule1:.turfWar, stage: PackableNumbers(stages))
            try schedule.insert(db)
        }
    }

    try bankaraSchedules.forEach{
        let settings = $0["bankaraMatchSettings"].arrayValue
        let stages = try settings.flatMap{
            let vsStages = $0["vsStages"].arrayValue
            return try vsStages.compactMap{
                if let hash = $0["image"]["url"].stringValue.getImageHash(){
                    return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
                }
                return nil
            }
        }

        if !stages.isEmpty{
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .bankara,
                                    rule1:Schedule.Rule(rawValue: settings[0]["vsRule"]["id"].stringValue.order) ?? .turfWar,
                                    rule2:Schedule.Rule(rawValue: settings[1]["vsRule"]["id"].stringValue.order) ?? .turfWar,
                                    stage: PackableNumbers(stages))
            try schedule.insert(db)
        }
    }

    try eventSchedules.forEach{
        let vsStages = $0["leagueMatchSetting"]["vsStages"].arrayValue
        let stages = try vsStages.compactMap{
            if let hash = $0["image"]["url"].stringValue.getImageHash(){
                return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
            }
            return nil
        }

        let timePeriods = $0["timePeriods"].arrayValue
        if !stages.isEmpty{
            try timePeriods.forEach{
                try Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .event, rule1: Schedule.Rule(rawValue: $0["eventMatchSetting"]["vsRule"]["id"].stringValue.order) ?? .turfWar,stage: PackableNumbers(stages), event: $0["leagueMatchSetting"]["leagueMatchEvent"]["id"].string).insert(db)
            }
        }
    }

    try xSchedules.forEach{
        let vsStages = $0["xMatchSetting"]["vsStages"].arrayValue
        let stages = try vsStages.compactMap{
            if let hash = $0["image"]["url"].stringValue.getImageHash(){
                return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
            }
            return nil
        }
        if !stages.isEmpty{
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .x, rule1: Schedule.Rule(rawValue: $0["xMatchSetting"]["vsRule"]["id"].stringValue.order) ?? .splatZones, stage: PackableNumbers(stages))
            try schedule.insert(db)
        }
    }


    try festSchedules.forEach{
        let settings = $0["festMatchSettings"].arrayValue
        let stages = try settings.flatMap{
            let vsStages = $0["vsStages"].arrayValue
            return try vsStages.compactMap{
                if let hash = $0["image"]["url"].stringValue.getImageHash(){
                    return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
                }
                return nil
            }
        }
        if !stages.isEmpty{
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .fest, rule1: .turfWar, rule2: .turfWar, stage: PackableNumbers(stages))
            try schedule.insert(db)
        }
    }

    let name2hash = [
        "Horrorboros":"0ee5853c43ebbef00ee2faecbd6c74f8a2d5e5b62b2cfa96d3838894b71381cb",
        "Megalodontia":"82905ebab16b4790142de406c78b1bf68a84056b366d9e19ae3360fb432fe0a9",
        "Cohozuna":"75f39ca054c76c0c33cd71177780708e679d088c874a66101e9b76b001df8254",
        "Random": "randomboss"
    ]

    try salmonRunRegularSchedules.forEach {
        try getCoopSchedule(json: $0, mode: .salmonRun, rule:.salmonRun,db: db, name2hash: name2hash)
    }

    try salmonRunBigRunSchedules.forEach {
        try getCoopSchedule(json: $0, mode: .salmonRun, rule:.bigRun, db: db, name2hash: name2hash)
    }

    try salmonRunTeamContestSchedules.forEach {
        try getCoopSchedule(json: $0, mode: .salmonRun, rule: .teamContest, db: db, name2hash: name2hash)
    }
}


func getCoopSchedule(json:JSON, mode:Schedule.Mode, rule: Schedule.Rule, db:Database, name2hash:[String:String]) throws {
    let weapons = try json["setting"]["weapons"].arrayValue.compactMap {
        if let hash = $0["image"]["url"].stringValue.getImageHash(){
            return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
        }
        return nil
    }

    let stage = try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[json["setting"]["coopStage"]["image"]["url"].stringValue.getImageHash()]) ?? 0

    var boss:UInt16? = nil

    if let name = json["setting"]["boss"]["name"].string{
        boss = try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[name2hash[name]])
    }else if let name = json["__splatoon3ink_king_salmonid_guess"].string{
        boss = try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[name2hash[name]])
    }else{
        boss = try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[name2hash["Cohozuna"]])
    }

    try Schedule(startTime: json["startTime"].stringValue.utcToDate(), endTime: json["endTime"].stringValue.utcToDate(), mode: mode, rule1:rule, stage: PackableNumbers([stage]), weapons: PackableNumbers(weapons), boss: boss).insert(db)
}



extension Schedule: PreComputable{
    public static func create(from db: Database, identifier: SQLRequest<Schedule>) throws -> Self? {
        let row = try Schedule.fetchOne(db, identifier)
        if var row = row{
            row._stage = try Array(0..<4).compactMap{
                if row.stage[$0] != 0{
                    return try ImageMap.fetchOne(db, key: row.stage[$0])
                }
                return nil
            }
            if let weapons = row.weapons{
                row._weapons = try Array(0..<4).compactMap{
                    if weapons[$0] != 0{
                        return try ImageMap.fetchOne(db, key: weapons[$0])
                    }
                    return nil
                }
            }
            if let boss = row.boss{
                row._boss = try ImageMap.fetchOne(db, key: boss)
            }
            return row
        }
        return row
    }

    public static func create(from db: Database, identifier: SQLRequest<Schedule>) throws -> [Schedule] {
        var rows = try Schedule.fetchAll(db, identifier)
        for index in rows.indices{
            rows[index]._stage = try Array(0..<4).compactMap{
                if rows[index].stage[$0] != 0{
                    return try ImageMap.fetchOne(db, key: rows[index].stage[$0])
                }
                return nil
            }
            if let weapons = rows[index].weapons{
                rows[index]._weapons = try Array(0..<4).compactMap{
                    if weapons[$0] != 0{
                        return try ImageMap.fetchOne(db, key: weapons[$0])
                    }
                    return nil
                }
            }
            if let boss = rows[index].boss{
                rows[index]._boss = try ImageMap.fetchOne(db, key: boss)
            }
        }
        return rows
    }
}
