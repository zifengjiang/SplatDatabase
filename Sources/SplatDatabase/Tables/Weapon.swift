import Foundation
import GRDB
import SwiftyJSON

public struct Weapon:Codable, FetchableRecord,PersistableRecord{
    public var imageMapId:UInt16
    public var order:Int
    public var coopId:Int64?
    public var coopPlayerResultId:Int64?
    public var coopWaveResultId:Int64?
}

