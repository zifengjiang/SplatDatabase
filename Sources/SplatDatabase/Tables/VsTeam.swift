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
