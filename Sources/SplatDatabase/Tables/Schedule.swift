import Foundation
import GRDB
import SwiftyJSON

public struct Schedule: Codable, FetchableRecord, PersistableRecord{
    public var id:Int64?
    public var startTime:Date
    public var endTime:Date
    public var mode:Mode
    public var stage:PackableNumbers
    public var weapons:PackableNumbers?
    public var boss:UInt16?

    public enum CodingKeys: String, CodingKey {
        case startTime
        case endTime
        case mode
        case stage
        case weapons
        case boss
    }

    // MARK: - Computed Properties
    var _stage: [ImageMap] = []
    var _weapons: [ImageMap] = []
    var _boss: ImageMap? = nil

    public enum Mode: Int, Codable {
        case regular = 0
        case bankara
        case x
        case event
        case fest
        case festTriColor
        case salmonRunRegular
        case salmonRunBigRun
        case salmonRunTeamContest
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
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .regular, stage: PackableNumbers(stages))
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
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .bankara, stage: PackableNumbers(stages))
            try schedule.insert(db)
        }
    }

    try eventSchedules.forEach{
        let vsStages = $0["eventMatchSetting"]["vsStages"].arrayValue
        let stages = try vsStages.compactMap{
            if let hash = $0["image"]["url"].stringValue.getImageHash(){
                return try UInt16.fetchOne(db, sql: "SELECT id FROM imageMap WHERE hash = ?", arguments:[hash])
            }
            return nil
        }

        let timePeriods = $0["timePeriods"].arrayValue

        try timePeriods.forEach{
            try Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .event, stage: PackableNumbers(stages)).insert(db)
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
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .regular, stage: PackableNumbers(stages))
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
            let schedule = Schedule(startTime: $0["startTime"].stringValue.utcToDate(), endTime: $0["endTime"].stringValue.utcToDate(), mode: .bankara, stage: PackableNumbers(stages))
            try schedule.insert(db)
            print("insert festSchedules")
        }
    }

    let name2hash = [
        "Horrorboros":"0ee5853c43ebbef00ee2faecbd6c74f8a2d5e5b62b2cfa96d3838894b71381cb",
        "Megalodontia":"82905ebab16b4790142de406c78b1bf68a84056b366d9e19ae3360fb432fe0a9",
        "Cohozuna":"75f39ca054c76c0c33cd71177780708e679d088c874a66101e9b76b001df8254",
        "Random": "randomboss"
    ]

    try salmonRunRegularSchedules.forEach {
        try getCoopSchedule(json: $0, mode: .salmonRunRegular, db: db, name2hash: name2hash)
    }

    try salmonRunBigRunSchedules.forEach {
        try getCoopSchedule(json: $0, mode: .salmonRunBigRun, db: db, name2hash: name2hash)
    }

    try salmonRunTeamContestSchedules.forEach {
        try getCoopSchedule(json: $0, mode: .salmonRunTeamContest, db: db, name2hash: name2hash)
    }
}

func getCoopSchedule(json:JSON, mode:Schedule.Mode, db:Database, name2hash:[String:String]) throws {
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
    }

    try Schedule(startTime: json["startTime"].stringValue.utcToDate(), endTime: json["endTime"].stringValue.utcToDate(), mode: mode, stage: PackableNumbers([stage]), weapons: PackableNumbers(weapons), boss: boss).insert(db)
}


extension Schedule {
    public init(from json: JSON, mode: Mode){
        startTime = json["startTime"].stringValue.utcToDate()
        endTime = json["endTime"].stringValue.utcToDate()
        stage = PackableNumbers([0])
        self.mode = mode
    }
}

extension Schedule: PreComputable{
    public static func create(from db: Database, identifier: SQLRequest<Schedule>) throws -> Self? {
        let row = try Schedule.fetchOne(db, identifier)
        if var row = row{
            row._stage = try Array(0..<2).compactMap{
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
            row._boss = try ImageMap.fetchOne(db, key: row.boss)
            return row
        }
        return row
    }
}
