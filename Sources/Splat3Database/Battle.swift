//
//  File.swift
//  
//
//  Created by 姜锋 on 5/10/24.
//

import Foundation
import GRDB
import SwiftyJSON


public struct Battle:Codable, FetchableRecord, PersistableRecord{
  var id:Int64?
  var sp3PrincipalId:String
  var mode:String
  var rule:String
  var stage:String
  var playedTime:Date
  var duration:Int
  var judgement:String
  var knockout:String?
  var udemae:String?
  var preDetailId:String?

  // BankaraMatch Attributes
  var earnedUdemaePoint:Int?
  var bankaraMode:String?
  var bankaraPower:Data?

  // LeagueMatch Attributes
  var leagueMatchEventId:String?
  var myLeaguePower:Int?

  // XMatch Attributes
  var lastXPower:Double?
  var entireXPower:Double?

  // FestMatch Attributes
  var festDragonMatchType:String?
  var festContribution:Int?
  var festJewel:Int?
  var myFestPower:Int?
  var awards:String

  public init(json:JSON){
    self.sp3PrincipalId = json["id"].stringValue
    self.mode = json["vsMode"]["mode"].stringValue
    self.rule = json["vsRule"]["rule"].stringValue
    self.stage = json["vsStage"]["id"].stringValue
    self.playedTime = json["playedTime"].stringValue.utcToDate()
    self.duration = json["duration"].intValue
    self.judgement = json["judgement"].stringValue
    self.knockout = json["knockout"].string
    self.udemae = json["udemae"].string
    self.preDetailId = json["previousHistoryDetail"]["id"].string

    // BankaraMatch Attributes
    self.earnedUdemaePoint = json["bankaraMatch"]["earnedUdemaePoint"].int
    self.bankaraMode = json["bankaraMatch"]["mode"].string
    self.bankaraPower = try? json["bankaraMatch"]["bankaraPower"].rawData()

    // LeagueMatch Attributes
    self.leagueMatchEventId = json["leagueMatchEventId"].string
    self.myLeaguePower = json["myLeaguePower"].int

    // XMatch Attributes
    self.lastXPower = json["lastXPower"].double
    self.entireXPower = json["entireXPower"].double

    // FestMatch Attributes
    self.festDragonMatchType = json["festMatch"]["dragonMatchType"].string
    self.festContribution = json["festMatch"]["contribution"].int
    self.festJewel = json["festMatch"]["jewel"].int
    self.myFestPower = json["festMatch"]["myFestPower"].int

    self.awards = json["awards"].arrayValue.map({"\($0["name"].stringValue)_\($0["rank"].stringValue)"}).joined(separator: ",")
  }
}
