import Foundation
import GRDB
import SwiftyJSON

public struct Weapon:Codable, FetchableRecord,PersistableRecord{
  var imageMapId:UInt16
  var order:Int
  var coopId:Int64?
  var coopPlayerResultId:Int64?
  var coopWaveResultId:Int64?
}

