import Foundation
import GRDB
import SwiftyJSON

public struct CoopPlayerResult:Codable, FetchableRecord,PersistableRecord{
    public var id:Int64?
    public var order:Int
    public var specialWeaponId:UInt16?
    public var defeatEnemyCount:Int
    public var deliverCount:Int
    public var goldenAssistCount:Int
    public var goldenDeliverCount:Int
    public var rescueCount:Int
    public var rescuedCount:Int
    public var coopId:Int64?

    public init(json:JSON, order:Int, coopId:Int64,db:Database){
        self.coopId = coopId
        self.order = order
        let specialWeaponId = getImageId(hash:json["specialWeapon"]["image"]["url"].string?.getImageHash(),db: db)
        if specialWeaponId == 0{
            self.specialWeaponId = nil
        }else{
            self.specialWeaponId = UInt16(specialWeaponId)
        }
        self.defeatEnemyCount = json["defeatEnemyCount"].intValue
        self.deliverCount = json["deliverCount"].intValue
        self.goldenAssistCount = json["goldenAssistCount"].intValue
        self.goldenDeliverCount = json["goldenDeliverCount"].intValue
        self.rescueCount = json["rescueCount"].intValue
        self.rescuedCount = json["rescuedCount"].intValue
    }
}
