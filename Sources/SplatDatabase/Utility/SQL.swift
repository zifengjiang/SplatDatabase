import Foundation
import GRDB

let enemy_status_sql = """
  WITH GroupedCoop AS (
      SELECT c.id
      FROM coop_view cv
      JOIN coop c ON cv.id = c.id
      WHERE cv.accountId = ? AND cv.GroupID = ?
  ),
  EnemyResults AS (
      SELECT cer.enemyId,
             SUM(cer.teamDefeatCount) AS totalTeamDefeatCount,
             SUM(cer.defeatCount) AS totalDefeatCount,
             SUM(cer.popCount) AS totalPopCount
      FROM coopEnemyResult cer
      JOIN GroupedCoop gc ON cer.coopId = gc.id
      GROUP BY cer.enemyId
  ),
  BossResults AS (
      SELECT c.boss AS enemyId,
             COUNT(c.boss) AS totalPopCount,
             SUM(CASE WHEN c.bossDefeated = 1 THEN 1 ELSE 0 END) AS totalTeamDefeatCount,
             0 AS totalDefeatCount
      FROM coop c
      JOIN GroupedCoop gc ON c.id = gc.id
      WHERE c.bossDefeated IS NOT NULL
      GROUP BY c.boss
  ),
  CombinedResults AS (
      SELECT enemyId, totalTeamDefeatCount, totalDefeatCount, totalPopCount
      FROM EnemyResults
      UNION ALL
      SELECT enemyId, totalTeamDefeatCount, totalDefeatCount, totalPopCount
      FROM BossResults
  )
  SELECT e.name, e.nameId, cr.totalTeamDefeatCount, cr.totalDefeatCount, cr.totalPopCount
  FROM CombinedResults cr
  JOIN imageMap e ON cr.enemyId = e.id
"""

let weapon_status_sql = """
  SELECT imageMap.'name',imageMap.nameId, COUNT(*) AS count
  FROM coop_view
  JOIN coopPlayerResult ON coop_view.id = coopPlayerResult.coopId
  JOIN weapon ON coopPlayerResult.id = weapon.coopPlayerResultId
  JOIN imageMap ON weapon.imageMapId = imageMap.id
  WHERE coopPlayerResult.'order' = 0 AND accountId = ? AND groupId = ?
  GROUP BY weapon.imageMapId
"""

let coop_view_sql = """
CREATE VIEW coop_view AS
WITH OrderedCoop AS (
    SELECT *,
           LAG(rule) OVER (PARTITION BY accountId ORDER BY playedTime) AS prev_rule,
           LAG(stageId) OVER (PARTITION BY accountId ORDER BY playedTime) AS prev_stageId,
           LAG(suppliedWeapon) OVER (PARTITION BY accountId ORDER BY playedTime) AS prev_suppliedWeapon
    FROM coop
),
GroupingCoop AS (
    SELECT *,
           CASE
               WHEN rule = prev_rule AND stageId = prev_stageId AND suppliedWeapon = prev_suppliedWeapon THEN 0

                WHEN rule = prev_rule AND rule = 'BIG_RUN' AND suppliedWeapon = prev_suppliedWeapon THEN 0
               ELSE 1
           END AS is_new_group
    FROM OrderedCoop
)
SELECT *,
       SUM(is_new_group) OVER (PARTITION BY accountId ORDER BY playedTime) AS GroupID
FROM GroupingCoop
"""

let group_status_sql = """
  SELECT * FROM  coop_group_status_view WHERE (accountId = ?) AND (GroupID = ?)
"""

let wave_result_sql = """
SELECT
    KEY AS eventWaveGroup,
    waterLevel,
    AVG(deliverNorm) AS deliverNorm,
    AVG(goldenPopCount) AS goldenPopCount,
    AVG(teamDeliverCount) AS teamDeliverCount,
    SUM(
        CASE WHEN coopWaveResult.waveNumber > coop_view.wave
            AND coopWaveResult.waveNumber <> 4 THEN
            1
        WHEN coopWaveResult.waveNumber = 4
            AND coop_view.bossDefeated = 0 THEN
            1
        ELSE
            0
        END) AS failCount,
    SUM(
        CASE WHEN coopWaveResult.waveNumber <= coop_view.wave THEN
            1
        WHEN coopWaveResult.waveNumber = 4
            AND coop_view.bossDefeated = 1 THEN
            1
        ELSE
            0
        END) AS successCount
FROM
    coopWaveResult
    JOIN coop_view ON coopWaveResult.coopId = coop_view.id
    LEFT JOIN i18n ON coopWaveResult.eventWave = i18n.id
WHERE
    coop_view.accountId = ?
    AND coop_view.GroupID = ?
GROUP BY
    eventWaveGroup,
    waterLevel
ORDER BY
    eventWaveGroup,
    waterLevel;
"""

let coop_player_status_sql = """
    WITH player_stats AS (
    SELECT
        player.*,
        coop_view.GroupID,
        COUNT(*) OVER (PARTITION BY player.sp3PrincipalId) AS count,
        ROW_NUMBER() OVER (PARTITION BY player.sp3PrincipalId ORDER BY player.id) AS row_num,
        AVG(coopPlayerResult.defeatEnemyCount) OVER (PARTITION BY player.sp3PrincipalId, coop_view.GroupID) AS defeatEnemyCount,
        AVG(coopPlayerResult.deliverCount) OVER (PARTITION BY player.sp3PrincipalId, coop_view.GroupID) AS deliverCount,
        AVG(coopPlayerResult.goldenAssistCount) OVER (PARTITION BY player.sp3PrincipalId, coop_view.GroupID) AS goldenAssistCount,
        AVG(coopPlayerResult.goldenDeliverCount) OVER (PARTITION BY player.sp3PrincipalId, coop_view.GroupID) AS goldenDeliverCount,
        AVG(coopPlayerResult.rescueCount) OVER (PARTITION BY player.sp3PrincipalId, coop_view.GroupID) AS rescueCount,
        AVG(coopPlayerResult.rescuedCount) OVER (PARTITION BY player.sp3PrincipalId, coop_view.GroupID) AS rescuedCount
    FROM
        player
    JOIN
        coopPlayerResult ON coopPlayerResult.id = player.coopPlayerResultId
    JOIN
        coop_view ON coopPlayerResult.coopId = coop_view.id
    WHERE

        coopPlayerResult.'order' <> 0
        AND coop_view.accountId = ?
        AND coop_view.GroupID = ?
    )
    SELECT
        name,
        byname,
        nameId,
        nameplate,
        nameplateTextColor,
        uniformId,
        defeatEnemyCount,
        deliverCount,
        goldenAssistCount,
        goldenDeliverCount,
        rescueCount,
        rescuedCount,
        count
    FROM
        player_stats
    WHERE
        row_num = 1
    ORDER BY
        count DESC;
"""

let last_500_coop_sql = """
    SELECT
        CASE WHEN coop.wave = 3
            AND coop.rule <> 'TEAM_CONTEST' THEN
            1
        WHEN coop.wave = 5
            AND coop.rule = 'TEAM_CONTEST' THEN
            1
        WHEN coop.wave < 0 THEN
            NULL
        ELSE
            0
        END AS result
    FROM
        coop
    WHERE
        coop.accountId = ?
    ORDER BY
        coop.playedTime DESC
    LIMIT 500
"""

let last_500_battle_sql = """
    SELECT
        CASE WHEN battle.judgement = 'WIN' THEN 1
        WHEN battle.judgement in ('LOSE','DRAW','DEEMED_LOSE') THEN 0
        ELSE
            NULL
        END AS result
    FROM
        battle
    WHERE
        battle.accountId = ? AND battle.'mode' != 'PRIVATE'
    ORDER BY
        battle.playedTime DESC
    LIMIT 500
"""

let coop_group_status_view = """
CREATE VIEW "coop_group_status_view" AS
SELECT
    coop.accountId,
    coop.GroupID,
    coop.'rule',
    coop.suppliedWeapon,
    stageId,
    MIN(coop.playedTime) AS startTime,
    MAX(coop.playedTime) AS endTime,
    AVG(coopPlayerResult.defeatEnemyCount) AS avg_defeatEnemyCount,
    AVG(coopPlayerResult.deliverCount) AS avg_deliverCount,
    AVG(coopPlayerResult.goldenAssistCount) AS avg_goldenAssistCount,
    AVG(coopPlayerResult.goldenDeliverCount) AS avg_goldenDeliverCount,
    AVG(coopPlayerResult.rescueCount) AS avg_rescueCount,
    AVG(coopPlayerResult.rescuedCount) AS avg_rescuedCount,
    COALESCE(SUM(coop.goldScale), 0) as goldScale,
    COALESCE(SUM(coop.silverScale), 0) as silverScale,
    COALESCE(SUM(coop.bronzeScale), 0) as bronzeScale,
    SUM(CASE WHEN coop.wave = 3 AND coop.'rule' <> 'TEAM_CONTEST' THEN 1 WHEN coop.wave = 5 AND coop.'rule' = 'TEAM_CONTEST' THEN 1 ELSE 0 END) as clear,
    SUM(CASE WHEN coop.wave < 0 THEN 1 ELSE 0 END) as disconnect,
    MAX(coop.afterGradePoint) as highestScore,
    MAX(coop.egg) as highestEgg,
    COUNT(*) AS count
FROM
    coop_view AS coop
JOIN coopPlayerResult ON coop.id = coopPlayerResult.coopId
WHERE
    coopPlayerResult.'order' = 0
GROUP BY
    coop.accountId,
    coop.GroupID
"""

public enum SplatDatabaseSQL {
    case enemy_status(accountId: Int, GroupID: Int)
    case weapon_status(accountId: Int, GroupID: Int)
    case coop_view
    case group_status(accountId: Int, GroupID: Int)
    case wave_result(accountId: Int, GroupID: Int)
    case last_500_coop(accountId: Int)
    case last_500_battle(accountId: Int)
    case coop_player_status(accountId: Int, GroupID: Int)
    case unknown

    public var request: SQLRequest<Row> {
        switch self {
        case .enemy_status(let accountId, let GroupID):
            return SQLRequest(sql: enemy_status_sql, arguments: [accountId, GroupID])
        case .weapon_status(let accountId, let GroupID):
            return SQLRequest(sql: weapon_status_sql, arguments: [accountId, GroupID])
        case .coop_view:
            return SQLRequest(sql: coop_view_sql)
        case .group_status(let accountId, let GroupID):
            return SQLRequest(sql: group_status_sql, arguments: [accountId, GroupID])
        case .wave_result(let accountId, let GroupID):
            return SQLRequest(sql: wave_result_sql, arguments: [accountId, GroupID])
        case .last_500_coop(let accountId):
            return SQLRequest(sql: last_500_coop_sql, arguments: [accountId])
        case .last_500_battle(let accountId):
            return SQLRequest(sql: last_500_battle_sql, arguments: [accountId])
        case .coop_player_status(let accountId, let GroupID):
            return SQLRequest(sql: coop_player_status_sql, arguments: [accountId, GroupID])
        case .unknown:
            return SQLRequest(sql: "")
        }
    }
}

