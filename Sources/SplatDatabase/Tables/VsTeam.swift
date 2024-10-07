import Foundation
import GRDB
import SwiftyJSON

public struct VsTeam:Codable, FetchableRecord, PersistableRecord{
    public var id:Int64?
    public var order:Int
    public var color:PackableNumbers
    public var judgement:String?

        // Team Result Attributes
    public var paintPoint:Int?
    public var paintRatio:Double?
    public var score:Int?
    public var noroshi:Int?

    public var tricolorRole:String?
    public var festTeamName:String?
    public var festUniformName:String?
    public var festUniformBonusRate:Double?
    public var festStreakWinCount:Int?

    public var battleId:Int64?

    // MARK: computed
    public var players:[Player] = []

    enum CodingKeys: String, CodingKey {
        case id
        case order
        case color
        case judgement
        case paintPoint
        case paintRatio
        case score
        case noroshi
        case tricolorRole
        case festTeamName
        case festUniformName
        case festUniformBonusRate
        case festStreakWinCount
        case battleId
    }

    public init(json:JSON, battleId:Int64){
        self.battleId = battleId
        self.order = json["order"].intValue
        self.color = json["color"].dictionary!.toRGBPackableNumbers()
        self.judgement = json["judgement"].string

        self.paintPoint = json["result"]["paintPoint"].int
        self.paintRatio = json["result"]["paintRatio"].double
        self.score = json["result"]["score"].int
        self.noroshi = json["result"]["noroshi"].int

        self.tricolorRole = json["tricolorRole"].string
        self.festTeamName = json["festTeamName"].string
        self.festUniformName = json["festUniformName"].string
        self.festUniformBonusRate = json["festUniformBonusRate"].double
        self.festStreakWinCount = json["festStreakWinCount"].int
    }
}

extension VsTeam: PreComputable{
    static public func create(from db: Database, identifier: (Int)) throws -> [VsTeam] {
        let battleId = identifier
        var rows = try VsTeam.fetchAll(db,sql: "SELECT * FROM vsTeam WHERE battleId = \(battleId)")

        for i in rows.indices{
            let players:[Player] = try! Player.create(from: db, identifier: (rows[i].id!, "vsTeamId"))
            rows[i].players = players
        }

        return rows
    }
}
