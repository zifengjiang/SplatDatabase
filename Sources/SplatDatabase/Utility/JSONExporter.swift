import Foundation
import GRDB
import SwiftyJSON

public class JSONExporter {
    private let dbPool: DatabasePool
    
    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }
    
    // MARK: - 导出Coop数据
    public func exportCoopToJSON(coopId: Int64) throws -> JSON {
        return try dbPool.read { db in
            guard let coop = try Coop.fetchOne(db, key: coopId) else {
                throw ExportError.recordNotFound
            }
            
            // 获取关联数据
            let playerResults = try CoopPlayerResult.filter(Column("coopId") == coopId).fetchAll(db)
            let enemyResults = try CoopEnemyResult.filter(Column("coopId") == coopId).fetchAll(db)
            let waveResults = try CoopWaveResult.filter(Column("coopId") == coopId).fetchAll(db)
            
            // 构建JSON结构
            var json: [String: Any] = [:]
            json["coopHistoryDetail"] = buildCoopHistoryDetail(coop: coop, playerResults: playerResults, enemyResults: enemyResults, waveResults: waveResults, db: db)
            
            return JSON(json)
        }
    }
    
    // MARK: - 导出Battle数据
    public func exportBattleToJSON(battleId: Int64) throws -> JSON {
        return try dbPool.read { db in
            guard let battle = try Battle.fetchOne(db, key: battleId) else {
                throw ExportError.recordNotFound
            }
            
            // 获取关联数据
            let teams = try VsTeam.filter(Column("battleId") == battleId).fetchAll(db)
            let teamIds = teams.compactMap { $0.id }
            let players = try Player.filter(teamIds.contains(Column("vsTeamId"))).fetchAll(db)
            
            // 构建JSON结构
            var json: [String: Any] = [:]
            json["vsHistoryDetail"] = buildVsHistoryDetail(battle: battle, teams: teams, players: players, db: db)
            
            return JSON(json)
        }
    }
    
    // MARK: - 私有方法 - Coop相关
    private func buildCoopHistoryDetail(coop: Coop, playerResults: [CoopPlayerResult], enemyResults: [CoopEnemyResult], waveResults: [CoopWaveResult], db: Database) -> [String: Any] {
        var detail: [String: Any] = [:]
        
        // 基本信息
        detail["__typename"] = "CoopHistoryDetail"
        detail["id"] = buildCoopId(coop: coop, db: db)
        detail["rule"] = coop.rule
        detail["resultWave"] = coop.wave == 0 ? 0 : coop.wave + 1
        detail["playedTime"] = formatDate(coop.playedTime)
        detail["dangerRate"] = coop.dangerRate
        detail["smellMeter"] = coop.smellMeter
        
        // 等级信息
        if let afterGrade = coop.afterGrade {
            detail["afterGrade"] = buildGradeInfo(gradeId: afterGrade, db: db)
            detail["afterGradePoint"] = coop.afterGradePoint
        }
        
        // 工作信息
        detail["jobPoint"] = coop.jobPoint
        detail["jobScore"] = coop.jobScore
        detail["jobRate"] = coop.jobRate
        detail["jobBonus"] = coop.jobBonus
        
        // 金蛋信息
        if let goldScale = coop.goldScale, let silverScale = coop.silverScale, let bronzeScale = coop.bronzeScale {
            detail["scale"] = [
                "gold": goldScale,
                "silver": silverScale,
                "bronze": bronzeScale
            ]
        }
        
        // 关卡信息
        detail["coopStage"] = buildStageInfo(stageId: coop.stageId, db: db)
        
        // 武器信息
        detail["weapons"] = buildWeaponsInfo(weaponIds: coop.suppliedWeapon.numbers, db: db)
        
        // 玩家结果
        detail["myResult"] = buildMyResult(coop: coop, playerResults: playerResults, db: db)
        detail["memberResults"] = buildMemberResults(playerResults: playerResults, db: db)
        
        // 敌人结果
        detail["enemyResults"] = buildEnemyResults(enemyResults: enemyResults, db: db)
        
        // 波次结果
        detail["waveResults"] = buildWaveResults(waveResults: waveResults, db: db)
        
        // Boss结果
        if let boss = coop.boss, let bossDefeated = coop.bossDefeated {
            detail["bossResult"] = buildBossResult(bossId: boss, defeated: bossDefeated, db: db)
        }
        
        // 前后记录链接
        if let preDetailId = coop.preDetailId {
            detail["previousHistoryDetail"] = ["id": preDetailId]
        }
        
        return detail
    }
    
    private func buildCoopId(coop: Coop, db: Database) -> String {
        // 从account表获取sp3Id
        let account = try? Account.fetchOne(db, key: coop.accountId)
        let sp3Id = account?.sp3Id ?? "unknown"
        
        // 构建完整的ID
        let baseString = "CoopHistoryDetail-u-\(sp3Id):\(coop.rule):\(formatDateForId(coop.playedTime))_\(coop.sp3PrincipalId)"
        return Data(baseString.utf8).base64EncodedString()
    }
    
    private func buildMyResult(coop: Coop, playerResults: [CoopPlayerResult], db: Database) -> [String: Any] {
        // 找到我的结果（通常是第一个）
        guard let myResult = playerResults.first else { return [:] }
        
        var result: [String: Any] = [:]
        
        // 玩家信息 - 需要从CoopPlayerResult获取玩家信息
        if let player = try? Player.filter(Column("coopPlayerResultId") == myResult.id).fetchOne(db) {
            result["player"] = buildPlayerInfo(player: player, db: db)
        }
        
        // 武器信息
        result["weapons"] = buildWeaponsInfo(weaponIds: coop.suppliedWeapon.numbers, db: db)
        
        // 特殊武器
        if let specialWeaponId = myResult.specialWeaponId {
            result["specialWeapon"] = buildSpecialWeaponInfo(weaponId: specialWeaponId, db: db)
        }
        
        // 统计数据
        result["defeatEnemyCount"] = myResult.defeatEnemyCount
        result["deliverCount"] = myResult.deliverCount
        result["goldenAssistCount"] = myResult.goldenAssistCount
        result["goldenDeliverCount"] = myResult.goldenDeliverCount
        result["rescueCount"] = myResult.rescueCount
        result["rescuedCount"] = myResult.rescuedCount
        
        return result
    }
    
    private func buildMemberResults(playerResults: [CoopPlayerResult], db: Database) -> [[String: Any]] {
        return playerResults.dropFirst().map { result in
            var memberResult: [String: Any] = [:]
            
            // 玩家信息 - 需要从CoopPlayerResult获取玩家信息
            if let player = try? Player.filter(Column("coopPlayerResultId") == result.id).fetchOne(db) {
                memberResult["player"] = buildPlayerInfo(player: player, db: db)
            }
            
            // 武器信息 - 需要从Weapon表获取
            let weapons = try? Weapon.filter(Column("coopPlayerResultId") == result.id).fetchAll(db)
            if let weapons = weapons {
                memberResult["weapons"] = weapons.map { weapon in
                    return buildWeaponInfo(weaponId: weapon.imageMapId, db: db)
                }
            }
            
            // 特殊武器
            if let specialWeaponId = result.specialWeaponId {
                memberResult["specialWeapon"] = buildSpecialWeaponInfo(weaponId: specialWeaponId, db: db)
            }
            
            // 统计数据
            memberResult["defeatEnemyCount"] = result.defeatEnemyCount
            memberResult["deliverCount"] = result.deliverCount
            memberResult["goldenAssistCount"] = result.goldenAssistCount
            memberResult["goldenDeliverCount"] = result.goldenDeliverCount
            memberResult["rescueCount"] = result.rescueCount
            memberResult["rescuedCount"] = result.rescuedCount
            
            return memberResult
        }
    }
    
    private func buildEnemyResults(enemyResults: [CoopEnemyResult], db: Database) -> [[String: Any]] {
        return enemyResults.map { result in
            var enemyResult: [String: Any] = [:]
            
            // 敌人信息
            if let enemy = try? ImageMap.fetchOne(db, key: result.enemyId) {
                enemyResult["enemy"] = buildEnemyInfo(enemy: enemy, db: db)
            }
            
            // 统计数据
            enemyResult["defeatCount"] = result.defeatCount
            enemyResult["teamDefeatCount"] = result.teamDefeatCount
            enemyResult["popCount"] = result.popCount
            
            return enemyResult
        }
    }
    
    private func buildWaveResults(waveResults: [CoopWaveResult], db: Database) -> [[String: Any]] {
        return waveResults.map { result in
            var waveResult: [String: Any] = [:]
            
            waveResult["waveNumber"] = result.waveNumber
            waveResult["waterLevel"] = result.waterLevel
            waveResult["deliverNorm"] = result.deliverNorm
            waveResult["goldenPopCount"] = result.goldenPopCount
            waveResult["teamDeliverCount"] = result.teamDeliverCount
            
            // 事件波次
            if let eventWave = result.eventWave {
                waveResult["eventWave"] = buildEventWaveInfo(eventId: eventWave, db: db)
            }
            
            // 特殊武器 - 需要从Weapon表获取
            let specialWeapons = try? Weapon.filter(Column("coopWaveResultId") == result.id).fetchAll(db)
            if let specialWeapons = specialWeapons {
                waveResult["specialWeapons"] = specialWeapons.map { weapon in
                    return buildSpecialWeaponInfo(weaponId: weapon.imageMapId, db: db)
                }
            }
            
            return waveResult
        }
    }
    
    // MARK: - 私有方法 - Battle相关
    private func buildVsHistoryDetail(battle: Battle, teams: [VsTeam], players: [Player], db: Database) -> [String: Any] {
        var detail: [String: Any] = [:]
        
        // 基本信息
        detail["__typename"] = "VsHistoryDetail"
        detail["id"] = buildBattleId(battle: battle, db: db)
        detail["vsRule"] = buildVsRule(rule: battle.rule, db: db)
        detail["vsMode"] = buildVsMode(mode: battle.mode, db: db)
        detail["judgement"] = battle.judgement
        detail["playedTime"] = formatDate(battle.playedTime)
        detail["duration"] = battle.duration
        
        // 关卡信息
        detail["vsStage"] = buildStageInfo(stageId: battle.stageId, db: db)
        
        // 我的信息
        if let myPlayer = players.first(where: { $0.isMyself == true }) {
            detail["player"] = buildPlayerInfo(player: myPlayer, db: db)
        }
        
        // 队伍信息
        detail["myTeam"] = buildTeamInfo(teams: teams, players: players, isMyTeam: true, db: db)
        detail["otherTeam"] = buildTeamInfo(teams: teams, players: players, isMyTeam: false, db: db)
        
        // 特殊模式信息
        if let knockout = battle.knockout {
            detail["knockout"] = knockout
        }
        
        if let udemae = battle.udemae {
            detail["udemae"] = udemae
        }
        
        // 前后记录链接
        if let preDetailId = battle.preDetailId {
            detail["previousHistoryDetail"] = ["id": preDetailId]
        }
        
        return detail
    }
    
    private func buildBattleId(battle: Battle, db: Database) -> String {
        // 从account表获取sp3Id
        let account = try? Account.fetchOne(db, key: battle.accountId)
        let sp3Id = account?.sp3Id ?? "unknown"
        
        // 构建完整的ID
        let baseString = "VsHistoryDetail-u-\(sp3Id):\(battle.rule):\(formatDateForId(battle.playedTime))_\(battle.sp3PrincipalId)"
        return Data(baseString.utf8).base64EncodedString()
    }
    
    private func buildTeamInfo(teams: [VsTeam], players: [Player], isMyTeam: Bool, db: Database) -> [String: Any] {
        guard let team = teams.first(where: { $0.order == (isMyTeam ? 0 : 1) }) else { return [:] }
        
        var teamInfo: [String: Any] = [:]
        
        // 颜色
        teamInfo["color"] = buildColorInfo(color: team.color)
        
        // 结果
        teamInfo["result"] = [
            "paintRatio": team.paintRatio as Any,
            "score": team.score as Any,
            "noroshi": team.noroshi as Any
        ]
        
        // 判断
        teamInfo["judgement"] = team.judgement
        
        // 玩家
        let teamPlayers = players.filter { $0.vsTeamId == team.id }
        teamInfo["players"] = teamPlayers.map { buildPlayerInfo(player: $0, db: db) }
        
        return teamInfo
    }
    
    // MARK: - 辅助方法
    private func buildPlayerInfo(player: Player, db: Database) -> [String: Any] {
        var playerInfo: [String: Any] = [:]
        
        playerInfo["__isPlayer"] = player.isCoop ? "CoopPlayer" : "VsPlayer"
        playerInfo["byname"] = player.byname
        playerInfo["name"] = player.name
        playerInfo["nameId"] = player.nameId
        playerInfo["species"] = player.species ? "OCTOLING" : "INKLING"
        
        // 名牌信息
        playerInfo["nameplate"] = buildNameplateInfo(nameplate: player.nameplate, textColor: player.nameplateTextColor, db: db)
        
        // 装备信息（根据类型）
        if player.isCoop {
            if let uniformId = player.uniformId {
                playerInfo["uniform"] = buildUniformInfo(uniformId: uniformId, db: db)
            }
        } else {
            if let weapon = player.weapon {
                playerInfo["weapon"] = buildWeaponsInfo(weaponIds: weapon.numbers, db: db)
            }
            if let paint = player.paint {
                playerInfo["paint"] = paint
            }
            playerInfo["headGear"] = buildGearInfo(gearIds: player.headGear.numbers, db: db)
            playerInfo["clothingGear"] = buildGearInfo(gearIds: player.clothingGear.numbers, db: db)
            playerInfo["shoesGear"] = buildGearInfo(gearIds: player.shoesGear.numbers, db: db)
            
            // 战斗结果
            if let kill = player.kill, let death = player.death {
                playerInfo["result"] = [
                    "kill": kill,
                    "death": death,
                    "assist": player.assist ?? 0,
                    "special": player.special ?? 0,
                    "noroshiTry": player.noroshiTry
                ]
            }
        }
        
        return playerInfo
    }
    
    private func buildNameplateInfo(nameplate: PackableNumbers, textColor: PackableNumbers, db: Database) -> [String: Any] {
        var nameplateInfo: [String: Any] = [:]
        
        // 徽章
        let badgeIds = nameplate.numbers
        nameplateInfo["badges"] = badgeIds.map { badgeId -> Any in
            if badgeId == 0 {
                return NSNull()
            } else {
                return buildBadgeInfo(badgeId: badgeId, db: db)
            }
        }
        
        // 背景
        if let backgroundId = badgeIds.first {
            nameplateInfo["background"] = buildBackgroundInfo(backgroundId: backgroundId, textColor: textColor, db: db)
        }
        
        return nameplateInfo
    }
    
    private func buildWeaponsInfo(weaponIds: [UInt16], db: Database) -> [[String: Any]] {
        return weaponIds.map { weaponId in
            return buildWeaponInfo(weaponId: weaponId, db: db)
        }
    }
    
    private func buildWeaponInfo(weaponId: UInt16, db: Database) -> [String: Any] {
        guard let weapon = try? ImageMap.fetchOne(db, key: weaponId) else {
            return ["name": "Unknown Weapon", "image": ["url": ""]]
        }
        
        return [
            "name": weapon.name,
            "image": [
                "url": buildImageUrl(hash: weapon.hash)
            ]
        ]
    }
    
    private func buildWeaponInfo(name: String, db: Database) -> [String: Any] {
        return [
            "name": name,
            "image": [
                "url": buildImageUrl(hash: generateHash(from: name))
            ]
        ]
    }
    
    private func buildSpecialWeaponInfo(weaponId: UInt16, db: Database) -> [String: Any] {
        guard let weapon = try? ImageMap.fetchOne(db, key: weaponId) else {
            return ["name": "Unknown Special", "image": ["url": ""]]
        }
        
        return [
            "name": weapon.name,
            "image": [
                "url": buildImageUrl(hash: weapon.hash)
            ],
            "weaponId": weaponId
        ]
    }
    
    private func buildSpecialWeaponInfo(name: String, db: Database) -> [String: Any] {
        return [
            "name": name,
            "image": [
                "url": buildImageUrl(hash: generateHash(from: name))
            ]
        ]
    }
    
    private func buildStageInfo(stageId: UInt16, db: Database) -> [String: Any] {
        guard let stage = try? ImageMap.fetchOne(db, key: stageId) else {
            return ["name": "Unknown Stage", "image": ["url": ""], "id": ""]
        }
        
        return [
            "name": stage.name,
            "image": [
                "url": buildImageUrl(hash: stage.hash)
            ],
            "id": stage.nameId
        ]
    }
    
    private func buildEnemyInfo(enemy: ImageMap, db: Database) -> [String: Any] {
        return [
            "name": enemy.name,
            "image": [
                "url": buildImageUrl(hash: enemy.hash)
            ],
            "id": enemy.nameId
        ]
    }
    
    private func buildBadgeInfo(badgeId: UInt16, db: Database) -> [String: Any] {
        guard let badge = try? ImageMap.fetchOne(db, key: badgeId) else {
            return ["image": ["url": ""], "id": ""]
        }
        
        return [
            "image": [
                "url": buildImageUrl(hash: badge.hash)
            ],
            "id": badge.nameId
        ]
    }
    
    private func buildBackgroundInfo(backgroundId: UInt16, textColor: PackableNumbers, db: Database) -> [String: Any] {
        guard let background = try? ImageMap.fetchOne(db, key: backgroundId) else {
            return ["textColor": [:], "image": ["url": ""], "id": ""]
        }
        
        return [
            "textColor": buildColorInfo(color: textColor),
            "image": [
                "url": buildImageUrl(hash: background.hash)
            ],
            "id": background.nameId
        ]
    }
    
    private func buildUniformInfo(uniformId: UInt16, db: Database) -> [String: Any] {
        guard let uniform = try? ImageMap.fetchOne(db, key: uniformId) else {
            return ["name": "Unknown Uniform", "image": ["url": ""], "id": ""]
        }
        
        return [
            "name": uniform.name,
            "image": [
                "url": buildImageUrl(hash: uniform.hash)
            ],
            "id": uniform.nameId
        ]
    }
    
    private func buildGearInfo(gearIds: [UInt16], db: Database) -> [String: Any] {
        guard let gearId = gearIds.first, let gear = try? ImageMap.fetchOne(db, key: gearId) else {
            return ["name": "Unknown Gear", "image": ["url": ""]]
        }
        
        return [
            "name": gear.name,
            "image": [
                "url": buildImageUrl(hash: gear.hash)
            ]
        ]
    }
    
    private func buildColorInfo(color: PackableNumbers) -> [String: Any] {
        let colors = color.numbers
        guard colors.count >= 4 else {
            return ["r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0]
        }
        
        return [
            "r": Double(colors[0]) / 255.0,
            "g": Double(colors[1]) / 255.0,
            "b": Double(colors[2]) / 255.0,
            "a": Double(colors[3]) / 255.0
        ]
    }
    
    private func buildVsRule(rule: String, db: Database) -> [String: Any] {
        // 这里可以根据规则类型返回相应的信息
        return [
            "name": rule,
            "id": "VnNSdWxlLTA=",
            "rule": rule
        ]
    }
    
    private func buildVsMode(mode: String, db: Database) -> [String: Any] {
        return [
            "mode": mode,
            "id": "VnNNb2RlLTE="
        ]
    }
    
    private func buildGradeInfo(gradeId: Int, db: Database) -> [String: Any] {
        // 这里可以根据等级ID返回相应的信息
        return [
            "name": "Grade \(gradeId)",
            "id": "Q29vcEdyYWRlLTA="
        ]
    }
    
    private func buildBossResult(bossId: UInt16, defeated: Bool, db: Database) -> [String: Any] {
        guard let boss = try? ImageMap.fetchOne(db, key: bossId) else {
            return ["hasDefeatBoss": defeated, "boss": ["name": "Unknown Boss", "image": ["url": ""], "id": ""]]
        }
        
        return [
            "hasDefeatBoss": defeated,
            "boss": [
                "name": boss.name,
                "image": [
                    "url": buildImageUrl(hash: boss.hash)
                ],
                "id": boss.nameId
            ]
        ]
    }
    
    private func buildEventWaveInfo(eventId: UInt16, db: Database) -> [String: Any] {
        // 这里可以根据事件ID返回相应的信息
        return [
            "name": "Event Wave",
            "id": "Q29vcEV2ZW50V2F2ZS0z"
        ]
    }
    
    // MARK: - 工具方法
    private func buildImageUrl(hash: String) -> String {
        // 构建图片URL，确保包含正确的sha256值
        return "https://api.lp1.av5ja.srv.nintendo.net/resources/prod/v2/weapon_illust/\(hash)_0.png?Expires=1704844800&Signature=placeholder&Key-Pair-Id=KNBS2THMRC385"
    }
    
    private func generateHash(from string: String) -> String {
        // 生成字符串的SHA256哈希
        let data = string.data(using: .utf8) ?? Data()
        if #available(macOS 10.15, *) {
            let hash = SHA256.hash(data: data)
            return hash.map { String(format: "%02hhx", $0) }.joined()
        } else {
            // 对于较老的macOS版本，使用简单的哈希
            return String(data.hashValue)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    
    private func formatDateForId(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - 错误类型
public enum ExportError: Error {
    case recordNotFound
    case invalidData
}

// MARK: - SHA256扩展
import CryptoKit

@available(macOS 10.15, *)
extension SHA256 {
    static func hashData(_ data: Data) -> Data {
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
}
