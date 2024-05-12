import Foundation
import GRDB
import SwiftyJSON

public struct VsTeam:Codable, FetchableRecord, PersistableRecord{
    var id:Int64?
    var order:Int
    @Packable var color:PackableNumbers
    var judgement:String?

        // Team Result Attributes
    var paintPoint:Int?
    var paintRatio:Double?
    var score:Int?
    var noroshi:Int?

    var tricolorRole:String?
    var festTeamName:String?
    var festUniformName:String?
    var festUniformBonusRate:Double?
    var festStreakWinCount:Int?

    var battleId:Int64?

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
