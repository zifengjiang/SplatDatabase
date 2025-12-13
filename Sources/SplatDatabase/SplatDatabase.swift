import Foundation
import GRDB
import SwiftyJSON

public class SplatDatabase {
    public static let shared = try! SplatDatabase()

    public var dbQueue: DatabasePool!


    public init() throws{
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        self.dbQueue = try DatabasePool(path: databaseURL.path)

        try migrator.migrate(dbQueue)
    }

        /// test use
    public init(path:String) {
        do {
            try createDatabase(path: path)
        }catch{
            print(#file,#line,error.localizedDescription)
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createDatabase") { db in
            try self.setupSchema(db: db)
        }

        migrator.registerMigration("insertI18nForVersion800") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion800") { db in
            try self.updateImageMap(db: db) // 你可能需要类似修改 updateImageMap 方法
        }

        migrator.registerMigration("coop_group_status_view") { db in
            try db.execute(sql: coop_group_status_view)
        }

        migrator.registerMigration("createIndexes") { db in
            try db.execute(sql: """
                    CREATE INDEX idx_coop_accountId ON coop (accountId);
                    CREATE INDEX idx_coop_playedTime ON coop (playedTime);
                    CREATE INDEX idx_coopEnemyResult_coopId ON coopEnemyResult (coopId);
                    CREATE INDEX idx_imageMap_id ON imageMap (id);
                    CREATE INDEX idx_coopPlayerResult_coopId ON coopPlayerResult(coopId);
                    CREATE INDEX idx_coopPlayerResult_order ON coopPlayerResult('order');
                    CREATE INDEX idx_weapon_coopPlayerResultId ON weapon(coopPlayerResultId);
                    CREATE INDEX idx_coopWaveResult_coopId ON coopWaveResult(coopId);
                    CREATE INDEX idx_player_coopPlayerResultId ON player(coopPlayerResultId);
                    CREATE INDEX idx_coop_boss ON coop(boss);
                    CREATE INDEX idx_coop_stageId ON coop(stageId);
                """)
        }


        migrator.registerMigration("insertI18nForVersion810") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion810") { db in
            try self.updateImageMap(db: db)
        }

        migrator.registerMigration("insertI18nForVersion900") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion900") { db in
            try self.updateImageMap(db: db)
        }

        migrator.registerMigration("insertI18nForVersion910") { db in
            try self.updateI18n(db: db)
        }

        migrator.registerMigration("insertImageMapForVersion910") { db in
            try self.updateImageMap(db: db)
        }

        migrator.registerMigration("addIsBossColumnToCoopEnemyResult") { db in
                // Check if the column already exists
            let columns = try db.columns(in: "coopEnemyResult")
            if !columns.contains(where: { $0.name == "isBoss" }) {
                try db.alter(table: "coopEnemyResult") { t in
                    t.add(column: "isBoss", .boolean).notNull().defaults(to: false)
                }
            }
        }

        migrator.registerMigration("alterPlayerTableColumnWeaponId2Weapon") { db in
            let columns = try db.columns(in: "player")
            if columns.contains(where: { $0.name == "weaponId" }) {
                try db.alter(table: "player") { t in
                    t.rename(column: "weaponId", to: "weapon")
                }
            }
        }

        migrator.registerMigration("removeForeignKeyConstraint") { db in
            try db.create(table: "new_player",ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("isCoop",.boolean).notNull() // true for coop, false for battle

                    /// Common Attributes
                t.column("sp3PrincipalId", .text).notNull()
                t.column("byname", .text).notNull()
                t.column("name", .text).notNull()
                t.column("nameId", .text).notNull()
                t.column("species", .boolean).notNull() // true for octoling, false for inkling
                t.column("nameplate", .integer).notNull()
                t.column("nameplateTextColor", .integer).notNull()

                    /// Coop Attributes
                t.column("uniformId", .integer).references("imageMap",column: "id")

                    /// Battle Attributes
                t.column("paint", .integer)
                t.column("weapon", .integer)
                t.column("headGear", .integer)
                t.column("clothingGear", .integer)
                t.column("shoesGear", .integer)
                t.column("crown", .boolean)
                t.column("festDragonCert", .text)
                t.column("festGrade", .text)
                t.column("isMyself", .boolean)

                    /// Battle Result Attributes
                t.column("kill", .integer)
                t.column("death", .integer)
                t.column("assist", .integer)
                t.column("special", .integer)
                t.column("noroshiTry", .integer)

                t.column("vsTeamId", .integer).references("vsTeam", column: "id")
                t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id")
            }

            try db.execute(sql: """
                    INSERT INTO new_player
                    SELECT id,isCoop,sp3PrincipalId,byname,name,nameId,species,nameplate,nameplateTextColor,uniformId,paint,weapon,headGear,clothingGear,shoesGear,crown,festDragonCert,festGrade,isMyself,kill,death,assist,special,noroshiTry,vsTeamId,coopPlayerResultId
                    FROM player;
                """)
            try db.drop(table: "player")
            try db.rename(table: "new_player", to: "player")

        }
        // CREATE INDEX idx_player_coopPlayerResultId ON player(coopPlayerResultId)
        migrator.registerMigration("createIdx_player_coopPlayerResultId") { db in
            try db.execute(sql: "CREATE INDEX idx_player_coopPlayerResultId ON player(coopPlayerResultId);")
        }

        migrator.registerMigration("fixTriumvirateIssue1") { db in
            try I18n(key: "Q29vcEVuZW15LTMw", translations: ["zhCN": "头目联合", "zhTW": "頭目聯合", "en": "Triumvirate", "ja": "トリアムバレイト", "ko": "트리엄버레이트", "ru": "Триумвирейт", "fr": "Triumvirat", "de": "Triumvirat", "es": "Triunvirato", "it": "Triumvirato", "nl": "Triumviraat"]).insert(db, onConflict: .ignore)
            // Update
            try db.execute(sql: """
                UPDATE coopWaveResult
                SET eventWave = (
                SELECT i18n.id FROM i18n
                WHERE i18n.'key' = 'Q29vcEVuZW15LTMw'
                )
                WHERE eventWave IS NULL 
                AND waveNumber = 4
                AND coopId IN (
                SELECT id FROM coop 
                WHERE rule != 'TEAM_CONTEST'
                );
            """)
        }

        migrator.registerMigration("create_battle_view") { db in
            let sql = """
        
            CREATE VIEW battle_view AS
        WITH OrderedBattle AS (
        SELECT
        b.*,
        DATE(b.playedTime, 'localtime') AS dayKey_local,
        LAG(b.mode) OVER (
            PARTITION BY b.accountId
            ORDER BY b.playedTime, b.id
        ) AS prev_mode,
        LAG(DATE(b.playedTime, 'localtime')) OVER (
            PARTITION BY b.accountId
            ORDER BY b.playedTime, b.id
        ) AS prev_dayKey_local
        FROM battle AS b
        ),
        GroupingBattle AS (
        SELECT
        *,
        CASE
            WHEN mode = prev_mode AND dayKey_local = prev_dayKey_local THEN 0
            ELSE 1
        END AS is_new_group
        FROM OrderedBattle
        )
        SELECT
        *,
        SUM(is_new_group) OVER (
        PARTITION BY accountId
        ORDER BY playedTime, id
        ) AS GroupID
        FROM GroupingBattle;
        """
            try db.execute(sql: sql)
        }

        migrator.registerMigration("create_battle_group_status_view") { db in
            let sql = """
        CREATE VIEW battle_group_status_view AS
        WITH base AS (
        SELECT
        bv.accountId,
        bv.GroupID,
        bv.dayKey_local,
        bv.mode,
        MIN(bv.playedTime) AS startTime, 
        MAX(bv.playedTime) AS endTime,
        COUNT(*) AS count,
        SUM(CASE WHEN bv.judgement = 'WIN'  THEN 1 ELSE 0 END) AS winCount,
        SUM(CASE WHEN bv.judgement like '%LOSE%' THEN 1 ELSE 0 END) AS loseCount,
        SUM(CASE WHEN bv.judgement LIKE '%DRAW%' THEN 1 ELSE 0 END) AS drawCount,
        SUM(CASE WHEN bv.judgement LIKE '%DEEMED_LOSE%' THEN 1 ELSE 0 END) as disconnectCount,
        SUM(CASE
                WHEN bv.judgement = 'WIN'
                 AND bv.knockout IS NOT NULL
                 AND bv.knockout = 'WIN'
                THEN 1 ELSE 0
            END) AS koWinCount,
        SUM(CASE
                WHEN bv.judgement like '%LOSE%'
                 AND bv.knockout IS NOT NULL
                 AND bv.knockout = 'LOSE'
                THEN 1 ELSE 0
            END) AS koLoseCount,
        AVG(bv.duration)      AS avgDuration,
        MAX(bv.myLeaguePower) AS maxMyLeaguePower,
        MAX(bv.lastXPower)    AS maxLastXPower,
        MAX(bv.entireXPower)  AS maxEntireXPower,
        SUM(COALESCE(bv.festContribution, 0)) AS festContribution,
        SUM(COALESCE(bv.festJewel, 0))        AS festJewel,
        AVG(bv.myFestPower)                   AS avgMyFestPower
        FROM battle_view AS bv
        GROUP BY bv.accountId, bv.GroupID
        ),
        mystats AS (
        SELECT
        bv.accountId,
        bv.GroupID,
        SUM(COALESCE(p.kill,0))   AS 'kill',
        SUM(COALESCE(p.death,0))   AS death,
        SUM(COALESCE(p.assist,0))  AS assist,
        SUM(COALESCE(p.special,0)) AS special
        FROM battle_view AS bv
        JOIN vsTeam AS t ON t.battleId = bv.id
        JOIN player AS p ON p.vsTeamId = t.id
                    AND p.isMyself = 1
                    AND p.isCoop   = 0
        GROUP BY bv.accountId, bv.GroupID
        )
        SELECT
        base.accountId,
        base.GroupID,
        base.mode,
        base.startTime,
        base.endTime,
        base.count,
        base.winCount,
        base.loseCount,
        base.drawCount,
        base.disconnectCount,
        base.koWinCount,
        base.koLoseCount,
        base.avgDuration,
        base.maxMyLeaguePower,
        base.maxLastXPower,
        base.maxEntireXPower,
        base.festContribution,
        base.festJewel,
        base.avgMyFestPower,
        mystats.kill,
        mystats.death,
        mystats.assist,
        mystats.special
        FROM base
        LEFT JOIN mystats
        ON mystats.accountId = base.accountId
        AND mystats.GroupID   = base.GroupID;
        """
            try db.execute(sql: sql)
        }

    migrator.registerMigration("insertI18nForVersion920") { db in
        try self.updateI18n(db: db)
    }

    migrator.registerMigration("insertImageMapForVersion920") { db in
        try self.updateImageMap(db: db)
    }
    
    migrator.registerMigration("insertI18nForVersion1000") { db in
        try self.updateI18n(db: db)
    }

    migrator.registerMigration("insertImageMapForVersion1000") { db in
        try self.updateImageMap(db: db)
    }
    
    migrator.registerMigration("addSoftDeleteAndFavoriteColumns") { db in
        // 为coop表添加软删除和喜爱标记列
        let coopColumns = try db.columns(in: "coop")
        if !coopColumns.contains(where: { $0.name == "isDeleted" }) {
            try db.alter(table: "coop") { t in
                t.add(column: "isDeleted", .boolean).notNull().defaults(to: false)
            }
        }
        if !coopColumns.contains(where: { $0.name == "isFavorite" }) {
            try db.alter(table: "coop") { t in
                t.add(column: "isFavorite", .boolean).notNull().defaults(to: false)
            }
        }
        
        // 为battle表添加软删除和喜爱标记列
        let battleColumns = try db.columns(in: "battle")
        if !battleColumns.contains(where: { $0.name == "isDeleted" }) {
            try db.alter(table: "battle") { t in
                t.add(column: "isDeleted", .boolean).notNull().defaults(to: false)
            }
        }
        if !battleColumns.contains(where: { $0.name == "isFavorite" }) {
            try db.alter(table: "battle") { t in
                t.add(column: "isFavorite", .boolean).notNull().defaults(to: false)
            }
        }
        
        // 为软删除列创建索引以提高查询性能
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_coop_isDeleted ON coop (isDeleted)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_coop_isFavorite ON coop (isFavorite)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_battle_isDeleted ON battle (isDeleted)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_battle_isFavorite ON battle (isFavorite)")
    }
    
    migrator.registerMigration("updateViewsWithIsDeletedFilter2") { db in
        // 删除现有的视图
        try db.execute(sql: "DROP VIEW IF EXISTS battle_view")
        try db.execute(sql: "DROP VIEW IF EXISTS coop_view")
        
        // 重新创建 battle_view isDeleted 过滤条件
        let battle_view = """
        CREATE VIEW battle_view AS
        WITH OrderedBattle AS (
        SELECT
        b.*,
        DATE(b.playedTime, 'localtime') AS dayKey_local,
        LAG(b.mode) OVER (
            PARTITION BY b.accountId
            ORDER BY b.playedTime, b.id
        ) AS prev_mode,
        LAG(DATE(b.playedTime, 'localtime')) OVER (
            PARTITION BY b.accountId
            ORDER BY b.playedTime, b.id
        ) AS prev_dayKey_local
        FROM battle AS b
        WHERE b.isDeleted = 0
        ),
        GroupingBattle AS (
        SELECT
        *,
        CASE
            WHEN mode = prev_mode AND dayKey_local = prev_dayKey_local THEN 0
            ELSE 1
        END AS is_new_group
        FROM OrderedBattle

        )
        SELECT
        *,
        SUM(is_new_group) OVER (
        PARTITION BY accountId
        ORDER BY playedTime, id
        ) AS GroupID
        FROM GroupingBattle
        """
        try db.execute(sql: battle_view)
        
        // 重新创建 coop_group_status_view，添加 isDeleted 过滤条件
        let coop_view = """
        CREATE VIEW coop_view AS
        WITH OrderedCoop AS (
            SELECT *,
                LAG(rule) OVER (PARTITION BY accountId ORDER BY playedTime) AS prev_rule,
                LAG(stageId) OVER (PARTITION BY accountId ORDER BY playedTime) AS prev_stageId,
                LAG(suppliedWeapon) OVER (PARTITION BY accountId ORDER BY playedTime) AS prev_suppliedWeapon
            FROM coop
            WHERE isDeleted = 0
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
        try db.execute(sql: coop_view)
    }

    migrator.registerMigration("createIndexForIsDeleted") { db in
        let sql = """
        CREATE INDEX IF NOT EXISTS idx_battle_acc_time_id__alive
        ON "battle"("accountId", "playedTime", "id")
        WHERE "isDeleted" = 0;

        CREATE INDEX IF NOT EXISTS idx_coop_acc_rule_stage_weapon_time__alive
        ON "coop"("accountId", "rule", "stageId", "suppliedWeapon", "playedTime")
        WHERE "isDeleted" = 0;

        CREATE INDEX IF NOT EXISTS idx_vsteam_battleId
        ON "vsTeam"("battleId");

        CREATE INDEX IF NOT EXISTS idx_player_vsTeam_self_vs
        ON "player"("vsTeamId", "isMyself", "isCoop");

        CREATE INDEX IF NOT EXISTS idx_coopPlayerResult_coop_order
        ON "coopPlayerResult"("coopId", "order");
        """
        try db.execute(sql: sql)
    }
    
    migrator.registerMigration("updateIsMyselfLogic") { db in
        // 更新合作模式下的 isMyself 字段逻辑
        // 对于合作模式（isCoop = 1）的玩家，如果 order = 0 则 isMyself = 1，否则为 0
        try db.execute(sql: """
            UPDATE player 
            SET isMyself = (
                CASE 
                    WHEN isCoop = 1 AND coopPlayerResultId IS NOT NULL THEN
                        (SELECT CASE WHEN cpr.'order' = 0 THEN 1 ELSE 0 END 
                         FROM coopPlayerResult cpr 
                         WHERE cpr.id = player.coopPlayerResultId)
                    WHEN isCoop = 0 THEN isMyself
                    ELSE 0
                END
            )
            WHERE isCoop = 1 AND coopPlayerResultId IS NOT NULL
        """)
    }

    migrator.registerMigration("updateCoopView") { db in
        let sql = """
        DROP VIEW IF EXISTS coop_view;

        CREATE VIEW coop_view AS
        WITH RECURSIVE
        ranked AS (
        SELECT
            c.*,
            ROW_NUMBER() OVER (
            PARTITION BY c.accountId
            ORDER BY c.playedTime, c.id
            ) AS rn
        FROM coop c
        WHERE c.isDeleted = 0
        ),
        /* 递归推进：同时维护
        - last_team_time  : 最近一次 TEAM_CONTEST 的时间
        - last_team_gid   : 最近一次 TEAM_CONTEST 所属组号
        - last_reg_time/last_reg_stage/last_reg_weapon/last_reg_gid : 最近一次 REGULAR 的锚点
        - gid             : “下一次新组”将使用的编号
        - last_valid_gid  : 最近一次有效(非 -1)组号，供其它模式继承
        */
        walk AS (
        -- 基线
        SELECT
            r.*,
            1 AS group_id,
            1 AS gid,
            1 AS last_valid_gid,

            CASE WHEN r.rule = 'TEAM_CONTEST' THEN r.playedTime END AS last_team_time,
            CASE WHEN r.rule = 'TEAM_CONTEST' THEN 1               END AS last_team_gid,

            CASE WHEN r.rule = 'REGULAR' THEN r.playedTime     END AS last_reg_time,
            CASE WHEN r.rule = 'REGULAR' THEN r.stageId        END AS last_reg_stage,
            CASE WHEN r.rule = 'REGULAR' THEN r.suppliedWeapon END AS last_reg_weapon,
            CASE WHEN r.rule = 'REGULAR' THEN 1                END AS last_reg_gid
        FROM ranked r
        WHERE r.rn = 1

        UNION ALL

        -- 递推
        SELECT
            r.*,

            /* 组号：TEAM_CONTEST/REGULAR 走 48h 规则，BIG_RUN 总是新开，其它继承 */
            /* 注意：这里我们不把 “-1/1” 写进 GroupID，避免影响聚合；-1/1 会单独写入 reg_flag */
            CASE
            WHEN r.rule = 'TEAM_CONTEST' THEN
                CASE
                WHEN w.last_team_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                THEN w.last_team_gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'REGULAR' THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND r.stageId = w.last_reg_stage
                AND r.suppliedWeapon = w.last_reg_weapon
                THEN w.last_reg_gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'BIG_RUN' THEN w.gid + 1
            ELSE w.last_valid_gid
            END AS group_id,

            /* 下一次新组编号是否自增 */
            CASE
            WHEN r.rule = 'TEAM_CONTEST' THEN
                CASE
                WHEN w.last_team_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                THEN w.gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'REGULAR' THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND r.stageId = w.last_reg_stage
                AND r.suppliedWeapon = w.last_reg_weapon
                THEN w.gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'BIG_RUN' THEN w.gid + 1
            ELSE w.gid
            END AS gid,

            /* 最近一次有效组号：当前 group_id 非 -1（我们没把 -1 写入组号）则更新为本次 */
            CASE
            WHEN
                CASE
                WHEN r.rule = 'TEAM_CONTEST' THEN
                    CASE
                    WHEN w.last_team_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                    THEN w.last_team_gid ELSE w.gid + 1 END
                WHEN r.rule = 'REGULAR' THEN
                    CASE
                    WHEN w.last_reg_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                    AND r.stageId = w.last_reg_stage
                    AND r.suppliedWeapon = w.last_reg_weapon
                    THEN w.last_reg_gid ELSE w.gid + 1 END
                WHEN r.rule = 'BIG_RUN' THEN w.gid + 1
                ELSE w.last_valid_gid
                END <> -1
            THEN
                CASE
                WHEN r.rule = 'TEAM_CONTEST' THEN
                    CASE
                    WHEN w.last_team_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                    THEN w.last_team_gid ELSE w.gid + 1 END
                WHEN r.rule = 'REGULAR' THEN
                    CASE
                    WHEN w.last_reg_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                    AND r.stageId = w.last_reg_stage
                    AND r.suppliedWeapon = w.last_reg_weapon
                    THEN w.last_reg_gid ELSE w.gid + 1 END
                WHEN r.rule = 'BIG_RUN' THEN w.gid + 1
                ELSE w.last_valid_gid
                END
            ELSE w.last_valid_gid
            END AS last_valid_gid,

            /* 刷新 TEAM_CONTEST 锚点 */
            CASE WHEN r.rule = 'TEAM_CONTEST' THEN r.playedTime ELSE w.last_team_time END AS last_team_time,
            CASE
            WHEN r.rule = 'TEAM_CONTEST' THEN
                CASE
                WHEN w.last_team_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                THEN w.last_team_gid
                ELSE w.gid + 1
                END
            ELSE w.last_team_gid
            END AS last_team_gid,

            /* 刷新 REGULAR 锚点 */
            CASE WHEN r.rule = 'REGULAR' THEN r.playedTime     ELSE w.last_reg_time   END AS last_reg_time,
            CASE WHEN r.rule = 'REGULAR' THEN r.stageId        ELSE w.last_reg_stage  END AS last_reg_stage,
            CASE WHEN r.rule = 'REGULAR' THEN r.suppliedWeapon ELSE w.last_reg_weapon END AS last_reg_weapon,
            CASE
            WHEN r.rule = 'REGULAR' THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND r.stageId = w.last_reg_stage
                AND r.suppliedWeapon = w.last_reg_weapon
                THEN w.last_reg_gid
                ELSE w.gid + 1
                END
            ELSE w.last_reg_gid
            END AS last_reg_gid

        FROM walk w
        JOIN ranked r
            ON r.accountId = w.accountId
        AND r.rn       = w.rn + 1
        ),
        /* 在递归结果上计算你要的“反之亦然”标记：
        若当前 REGULAR 落在 TEAM_CONTEST 窗口内（距最近 TEAM_CONTEST ≤ 48h）：
            - 若它与上一次 REGULAR 本应属同一组（≤48h 且同 stage/weapon） → reg_flag = -1
            - 否则 → reg_flag = 1
        其余情况 → reg_flag = 0
        */
        labeled AS (
        SELECT
            w.*,
            CASE
            WHEN w.rule = 'REGULAR'
            AND w.last_team_time IS NOT NULL
            AND (julianday(w.playedTime) - julianday(w.last_team_time)) <= 2.0
            THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(w.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND w.stageId = w.last_reg_stage
                AND w.suppliedWeapon = w.last_reg_weapon
                THEN -1
                ELSE 1
                END
            ELSE 0
            END AS reg_flag
        FROM walk w
        )
        SELECT
        id, rule, sp3PrincipalId, boss, suppliedWeapon, egg, powerEgg, bossDefeated,
        wave, stageId, afterGrade, afterGradePoint, afterGradeDiff, preDetailId,
        goldScale, silverScale, bronzeScale, jobPoint, jobScore, jobRate, jobBonus,
        playedTime, dangerRate, smellMeter, accountId, isDeleted, isFavorite,
        group_id AS GroupID,
        reg_flag
        FROM labeled;
        """
        try db.execute(sql: sql)
    }
    
    migrator.registerMigration("fixBigRunGrouping") { db in
        let sql = """
        DROP VIEW IF EXISTS coop_view;

        CREATE VIEW coop_view AS
        WITH RECURSIVE
        ranked AS (
        SELECT
            c.*,
            ROW_NUMBER() OVER (
            PARTITION BY c.accountId
            ORDER BY c.playedTime, c.id
            ) AS rn
        FROM coop c
        WHERE c.isDeleted = 0
        ),
        /* 递归推进：同时维护
        - last_team_time  : 最近一次 TEAM_CONTEST 的时间
        - last_team_gid   : 最近一次 TEAM_CONTEST 所属组号
        - last_reg_time/last_reg_stage/last_reg_weapon/last_reg_gid : 最近一次 REGULAR 的锚点
        - last_bigrun_weapon/last_bigrun_gid : 最近一次 BIG_RUN 的锚点
        - gid             : "下一次新组"将使用的编号
        - last_valid_gid  : 最近一次有效(非 -1)组号，供其它模式继承
        */
        walk AS (
        -- 基线
        SELECT
            r.*,
            1 AS group_id,
            1 AS gid,
            1 AS last_valid_gid,

            CASE WHEN r.rule = 'TEAM_CONTEST' THEN r.playedTime END AS last_team_time,
            CASE WHEN r.rule = 'TEAM_CONTEST' THEN 1               END AS last_team_gid,

            CASE WHEN r.rule = 'REGULAR' THEN r.playedTime     END AS last_reg_time,
            CASE WHEN r.rule = 'REGULAR' THEN r.stageId        END AS last_reg_stage,
            CASE WHEN r.rule = 'REGULAR' THEN r.suppliedWeapon END AS last_reg_weapon,
            CASE WHEN r.rule = 'REGULAR' THEN 1                END AS last_reg_gid,

            CASE WHEN r.rule = 'BIG_RUN' THEN r.suppliedWeapon END AS last_bigrun_weapon,
            CASE WHEN r.rule = 'BIG_RUN' THEN 1                END AS last_bigrun_gid
        FROM ranked r
        WHERE r.rn = 1

        UNION ALL

        -- 递推
        SELECT
            r.*,

            /* 组号：TEAM_CONTEST/REGULAR 走 48h 规则，BIG_RUN 同 weapon 同组，其它继承 */
            /* 注意：这里我们不把 "-1/1" 写进 GroupID，避免影响聚合；-1/1 会单独写入 reg_flag */
            CASE
            WHEN r.rule = 'TEAM_CONTEST' THEN
                CASE
                WHEN w.last_team_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                THEN w.last_team_gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'REGULAR' THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND r.stageId = w.last_reg_stage
                AND r.suppliedWeapon = w.last_reg_weapon
                THEN w.last_reg_gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'BIG_RUN' THEN
                CASE
                WHEN w.last_bigrun_weapon IS NOT NULL
                AND r.suppliedWeapon = w.last_bigrun_weapon
                THEN w.last_bigrun_gid
                ELSE w.gid + 1
                END
            ELSE w.last_valid_gid
            END AS group_id,

            /* 下一次新组编号是否自增 */
            CASE
            WHEN r.rule = 'TEAM_CONTEST' THEN
                CASE
                WHEN w.last_team_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                THEN w.gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'REGULAR' THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND r.stageId = w.last_reg_stage
                AND r.suppliedWeapon = w.last_reg_weapon
                THEN w.gid
                ELSE w.gid + 1
                END
            WHEN r.rule = 'BIG_RUN' THEN
                CASE
                WHEN w.last_bigrun_weapon IS NOT NULL
                AND r.suppliedWeapon = w.last_bigrun_weapon
                THEN w.gid
                ELSE w.gid + 1
                END
            ELSE w.gid
            END AS gid,

            /* 最近一次有效组号：当前 group_id 非 -1（我们没把 -1 写入组号）则更新为本次 */
            CASE
            WHEN
                CASE
                WHEN r.rule = 'TEAM_CONTEST' THEN
                    CASE
                    WHEN w.last_team_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                    THEN w.last_team_gid ELSE w.gid + 1 END
                WHEN r.rule = 'REGULAR' THEN
                    CASE
                    WHEN w.last_reg_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                    AND r.stageId = w.last_reg_stage
                    AND r.suppliedWeapon = w.last_reg_weapon
                    THEN w.last_reg_gid ELSE w.gid + 1 END
                WHEN r.rule = 'BIG_RUN' THEN
                    CASE
                    WHEN w.last_bigrun_weapon IS NOT NULL
                    AND r.suppliedWeapon = w.last_bigrun_weapon
                    THEN w.last_bigrun_gid ELSE w.gid + 1 END
                ELSE w.last_valid_gid
                END <> -1
            THEN
                CASE
                WHEN r.rule = 'TEAM_CONTEST' THEN
                    CASE
                    WHEN w.last_team_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                    THEN w.last_team_gid ELSE w.gid + 1 END
                WHEN r.rule = 'REGULAR' THEN
                    CASE
                    WHEN w.last_reg_time IS NOT NULL
                    AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                    AND r.stageId = w.last_reg_stage
                    AND r.suppliedWeapon = w.last_reg_weapon
                    THEN w.last_reg_gid ELSE w.gid + 1 END
                WHEN r.rule = 'BIG_RUN' THEN
                    CASE
                    WHEN w.last_bigrun_weapon IS NOT NULL
                    AND r.suppliedWeapon = w.last_bigrun_weapon
                    THEN w.last_bigrun_gid ELSE w.gid + 1 END
                ELSE w.last_valid_gid
                END
            ELSE w.last_valid_gid
            END AS last_valid_gid,

            /* 刷新 TEAM_CONTEST 锚点 */
            CASE WHEN r.rule = 'TEAM_CONTEST' THEN r.playedTime ELSE w.last_team_time END AS last_team_time,
            CASE
            WHEN r.rule = 'TEAM_CONTEST' THEN
                CASE
                WHEN w.last_team_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_team_time)) <= 2.0
                THEN w.last_team_gid
                ELSE w.gid + 1
                END
            ELSE w.last_team_gid
            END AS last_team_gid,

            /* 刷新 REGULAR 锚点 */
            CASE WHEN r.rule = 'REGULAR' THEN r.playedTime     ELSE w.last_reg_time   END AS last_reg_time,
            CASE WHEN r.rule = 'REGULAR' THEN r.stageId        ELSE w.last_reg_stage  END AS last_reg_stage,
            CASE WHEN r.rule = 'REGULAR' THEN r.suppliedWeapon ELSE w.last_reg_weapon END AS last_reg_weapon,
            CASE
            WHEN r.rule = 'REGULAR' THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(r.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND r.stageId = w.last_reg_stage
                AND r.suppliedWeapon = w.last_reg_weapon
                THEN w.last_reg_gid
                ELSE w.gid + 1
                END
            ELSE w.last_reg_gid
            END AS last_reg_gid,

            /* 刷新 BIG_RUN 锚点 */
            CASE WHEN r.rule = 'BIG_RUN' THEN r.suppliedWeapon ELSE w.last_bigrun_weapon END AS last_bigrun_weapon,
            CASE
            WHEN r.rule = 'BIG_RUN' THEN
                CASE
                WHEN w.last_bigrun_weapon IS NOT NULL
                AND r.suppliedWeapon = w.last_bigrun_weapon
                THEN w.last_bigrun_gid
                ELSE w.gid + 1
                END
            ELSE w.last_bigrun_gid
            END AS last_bigrun_gid

        FROM walk w
        JOIN ranked r
            ON r.accountId = w.accountId
        AND r.rn       = w.rn + 1
        ),
        /* 在递归结果上计算你要的"反之亦然"标记：
        若当前 REGULAR 落在 TEAM_CONTEST 窗口内（距最近 TEAM_CONTEST ≤ 48h）：
            - 若它与上一次 REGULAR 本应属同一组（≤48h 且同 stage/weapon） → reg_flag = -1
            - 否则 → reg_flag = 1
        其余情况 → reg_flag = 0
        */
        labeled AS (
        SELECT
            w.*,
            CASE
            WHEN w.rule = 'REGULAR'
            AND w.last_team_time IS NOT NULL
            AND (julianday(w.playedTime) - julianday(w.last_team_time)) <= 2.0
            THEN
                CASE
                WHEN w.last_reg_time IS NOT NULL
                AND (julianday(w.playedTime) - julianday(w.last_reg_time)) <= 2.0
                AND w.stageId = w.last_reg_stage
                AND w.suppliedWeapon = w.last_reg_weapon
                THEN -1
                ELSE 1
                END
            ELSE 0
            END AS reg_flag
        FROM walk w
        )
        SELECT
        id, rule, sp3PrincipalId, boss, suppliedWeapon, egg, powerEgg, bossDefeated,
        wave, stageId, afterGrade, afterGradePoint, afterGradeDiff, preDetailId,
        goldScale, silverScale, bronzeScale, jobPoint, jobScore, jobRate, jobBonus,
        playedTime, dangerRate, smellMeter, accountId, isDeleted, isFavorite,
        group_id AS GroupID,
        reg_flag
        FROM labeled;
        """
        try db.execute(sql: sql)
    }
    
    
    
    migrator.registerMigration("insertI18nForVersion1010") { db in
        try self.updateI18n(db: db)
    }

    migrator.registerMigration("insertImageMapForVersion1010") { db in
        try self.updateImageMap(db: db)
    }
    return migrator
    
    
    



    }



        /// Function to export the current database to a specified location
    public func exportDatabase(to destinationPath: URL? = nil) throws -> URL {
        guard let dbQueue = dbQueue else {
            throw NSError(domain: "DatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])
        }

            // Get the path to the current database file
        let dbPath = dbQueue.path

            // Determine the destination path
        let fileManager = FileManager.default
        let destinationFileName = "Splat3Database_copy.sqlite"
        var destinationURL = destinationPath ?? fileManager.temporaryDirectory.appendingPathComponent(destinationFileName)

            // Check if destinationPath is a directory and append the default file name if it is
        var isDir: ObjCBool = false
        if let path = destinationPath?.path, fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            destinationURL = destinationPath!.appendingPathComponent(destinationFileName)
        }

            // Perform the export by copying the file
        try fileManager.copyItem(atPath: dbPath, toPath: destinationURL.path)

        return destinationURL
    }

    public func createDatabase(path: String) throws {

        self.dbQueue = try DatabasePool(path: path)

        try self.migrator.migrate(dbQueue)
    }


    private func setupSchema(db: Database) throws {
        try db.create(table: "i18n", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("key", .text).notNull().unique()
            t.column("zhCN", .text) // 中文简体
            t.column("zhTW", .text) // 中文繁体
            t.column("en", .text) // 英文
            t.column("ja", .text) // 日文
            t.column("ko", .text) // 韩文
            t.column("ru", .text) // 俄文
            t.column("fr", .text) // 法文
            t.column("de", .text) // 德文
            t.column("es", .text) // 西班牙文
            t.column("it", .text) // 意大利文
            t.column("nl", .text) // 荷兰文
        }

        try I18n(key: "Q29vcEVuZW15LTMw", translations: ["zhCN": "头目联合", "zhTW": "頭目聯合", "en": "Triumvirate", "ja": "トリアムバレイト", "ko": "트리엄버레이트", "ru": "Триумвирейт", "fr": "Triumvirat", "de": "Triumvirat", "es": "Triunvirato", "it": "Triumvirato", "nl": "Triumviraat"]).insert(db, onConflict: .ignore)

        try db.create(table: "coop",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("rule", .text).notNull()
            t.column("sp3PrincipalId", .text).notNull()
            t.column("boss", .integer).references("imageMap",column: "id")
            t.column("suppliedWeapon",.integer).notNull()
            t.column("egg",.integer).notNull()
            t.column("powerEgg", .integer).notNull()
            t.column("bossDefeated", .boolean)
            t.column("wave", .integer).notNull()
            t.column("stageId", .integer).notNull().references("imageMap", column: "id")
            t.column("afterGrade", .integer)
            t.column("afterGradePoint", .integer)
            t.column("afterGradeDiff", .integer)
            t.column("preDetailId", .text)
            t.column("goldScale", .integer)
            t.column("silverScale", .integer)
            t.column("bronzeScale", .integer)
            t.column("jobPoint", .integer)
            t.column("jobScore", .integer)
            t.column("jobRate", .double)
            t.column("jobBonus", .integer)
            t.column("playedTime", .datetime).notNull()
            t.column("dangerRate", .double).notNull()
            t.column("smellMeter", .integer)
            t.column("accountId", .integer).notNull().references("account", column: "id")

            t.uniqueKey(["sp3PrincipalId","playedTime", "accountId"], onConflict: .ignore)
        }

        try db.create(table: "battle",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("sp3PrincipalId", .text).notNull()
            t.column("mode", .text).notNull()
            t.column("rule", .text).notNull()
            t.column("stageId", .integer).notNull().references("imageMap", column: "id")
            t.column("playedTime", .datetime).notNull()
            t.column("duration", .integer).notNull()
            t.column("judgement", .text).notNull()
            t.column("knockout", .text)
            t.column("udemae", .text)
            t.column("preDetailId", .text)

                /// BankaraMatch Attributes
            t.column("earnedUdemaePoint",.integer)
            t.column("bankaraMode", .text)
            t.column("bankaraPower", .blob)

                /// LeagueMatch Attributes
            t.column("leagueMatchEventId", .text)
            t.column("myLeaguePower", .integer)

                /// XMatch Attributes
            t.column("lastXPower", .double)
            t.column("entireXPower", .double)

                /// FestMatch Attributes
            t.column("festDragonMatchType", .text)
            t.column("festContribution", .integer)
            t.column("festJewel", .integer)
            t.column("myFestPower", .integer)

            t.column("awards",.text)
            t.column("accountId", .integer).notNull().references("account", column: "id")

            t.uniqueKey(["sp3PrincipalId","playedTime", "accountId"], onConflict: .ignore)
        }

        try db.create(table: "weapon",ifNotExists: true) { t in
            t.column("imageMapId", .integer).notNull().references("imageMap", column: "id")
            t.column("order", .integer).notNull().defaults(to: 0)
            t.column("coopId", .integer).references("coop", column: "id") // shift weapons
            t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id") // player weapons
            t.column("coopWaveResultId", .integer).references("coopWaveResult", column: "id")
        }

        try db.create(table: "coopPlayerResult",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("order",.integer).notNull()
            t.column("specialWeaponId", .integer).references("imageMap", column: "id")
            t.column("defeatEnemyCount", .integer).notNull()
            t.column("deliverCount", .integer).notNull()
            t.column("goldenAssistCount", .integer).notNull()
            t.column("goldenDeliverCount", .integer).notNull()
            t.column("rescueCount", .integer).notNull()
            t.column("rescuedCount", .integer).notNull()

            t.column("coopId", .integer).references("coop", column: "id")
        }

        try db.create(table: "coopWaveResult",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")

            t.column("waveNumber", .integer).notNull()
            t.column("waterLevel", .integer).notNull()
            t.column("eventWave", .integer).references("i18n", column: "id")
            t.column("deliverNorm", .integer)
            t.column("goldenPopCount", .integer).notNull()
            t.column("teamDeliverCount", .integer)

            t.column("coopId", .integer).references("coop", column: "id")
        }

        try db.create(table: "coopEnemyResult",ifNotExists: true) { t in
            t.column("enemyId", .integer).references("imageMap", column: "id")
            t.column("teamDefeatCount", .text).notNull()
            t.column("defeatCount", .integer).notNull()
            t.column("popCount", .integer).notNull()

            t.column("coopId", .integer).references("coop", column: "id")
        }

        try db.create(table: "player",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("isCoop",.boolean).notNull() // true for coop, false for battle

                /// Common Attributes
            t.column("sp3PrincipalId", .text).notNull()
            t.column("byname", .text).notNull()
            t.column("name", .text).notNull()
            t.column("nameId", .text).notNull()
            t.column("species", .boolean).notNull() // true for octoling, false for inkling
            t.column("nameplate", .integer).notNull()
            t.column("nameplateTextColor", .integer).notNull()
            t.column("bynameFormatted", .integer) // PackableNumbers: [adjective_id, subject_id, male_flag]

                /// Coop Attributes
            t.column("uniformId", .integer).references("imageMap",column: "id")

                /// Battle Attributes
            t.column("paint", .integer)
            t.column("weapon", .integer)
            t.column("headGear", .integer)
            t.column("clothingGear", .integer)
            t.column("shoesGear", .integer)
            t.column("crown", .boolean)
            t.column("festDragonCert", .text)
            t.column("festGrade", .text)
            t.column("isMyself", .boolean)

                /// Battle Result Attributes
            t.column("kill", .integer)
            t.column("death", .integer)
            t.column("assist", .integer)
            t.column("special", .integer)
            t.column("noroshiTry", .integer)

            t.column("vsTeamId", .integer).references("vsTeam", column: "id")
            t.column("coopPlayerResultId", .integer).references("coopPlayerResult", column: "id")
        }

        try db.create(table: "vsTeam",ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("order", .integer).notNull() // 0 is my team
            t.column("color", .integer).notNull()
            t.column("judgement", .text)

                /// Team Result Attributes
            t.column("paintPoint", .integer)
            t.column("paintRatio", .double)
            t.column("score", .integer)
            t.column("noroshi", .integer)

            t.column("tricolorRole",.text)
            t.column("festTeamName", .text)
            t.column("festUniformName",.text)
            t.column("festUniformBonusRate", .double)
            t.column("festStreakWinCount", .integer)

            t.column("battleId", .integer).references("battle", column: "id")
        }

        try db.create(table: "imageMap", ifNotExists: true) { t in
                /// badge, brand, coopEnemy, coopSkin, gear, nameplate, skill, stage, weapon, subspecial
            t.autoIncrementedPrimaryKey("id")
            t.column("nameId", .text).notNull().unique()
            t.column("hash", .text).notNull()
            t.column("name",.text).notNull()
        }

        try db.create(table: "account", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("sp3Id", .text).unique()
            t.column("avatar", .blob)
            t.column("name",.text)
            t.column("code",.text).unique()
            t.column("sessionToken",.text)
            t.column("lastRefresh", .datetime)
        }

        try db.create(table: "schedule", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("startTime", .datetime).notNull()
            t.column("endTime", .datetime).notNull()
            t.column("mode", .integer).notNull()
            t.column("rule1", .integer)
            t.column("rule2", .integer)
            t.column("stage", .integer).notNull()
            t.column("weapons", .integer)
            t.column("boss", .integer)
            t.column("event", .text)

            t.uniqueKey(["startTime","endTime", "mode"], onConflict: .replace)
        }

        try db.execute(sql: coop_view_sql)
    }

}


extension SplatDatabase {
    /// 便捷的数据库导入方法，通过SplatDatabase.shared调用
    /// - Parameters:
    ///   - sourceDbPath: 源数据库文件路径
    ///   - progress: 进度回调，参数为0.0到1.0的进度值
    ///   - preserveIds: 是否保留原始ID，默认为false（使用新的自增ID）
    public static func importDatabase(sourceDbPath: String, progress: ((Double) -> Void)? = nil, preserveIds: Bool = false) throws {
        try shared.importFromDatabaseWithConstraints(sourceDbPath: sourceDbPath, progress: progress, preserveIds: preserveIds)
    }
    
    /// 完全替换数据库的方法，通过SplatDatabase.shared调用
    /// - Parameters:
    ///   - sourceDbPath: 源数据库文件路径
    ///   - progress: 进度回调，参数为0.0到1.0的进度值
    public static func replaceDatabase(sourceDbPath: String, progress: ((Double) -> Void)? = nil) throws {
        try shared.replaceDatabaseWithSource(sourceDbPath: sourceDbPath, progress: progress)
    }
    
    public enum Mode:String{
        case battle = "battle"
        case coop = "coop"
    }

    public func filterNotExists(in kind: Mode, ids: [String]) throws -> [String] {
            // 1) 预解析 & 校验，建议把 playedTime 统一成 Int64 时间戳或标准化字符串
        struct Key: Hashable { let p: String; let t: Date; let u: String } // principal, time, sp3Id

        var tuples: [Key] = []
        tuples.reserveCapacity(ids.count)

            // 映射表：三元组 -> 原始 id，便于 O(1) 回表
        var keyToOriginal: [Key: String] = [:]
        keyToOriginal.reserveCapacity(ids.count)

        for id in ids {
            guard
                  let date = id.base64DecodedString.extractedDate
            else {
                    // 这里可选择跳过或抛错；我选择抛错更安全
                throw NSError(domain: "FilterNotExists", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid id: \(id)"])
            }
            let p = id.getDetailUUID()
            let u = id.extractUserId()
            let t = date
            let key = Key(p: p, t: t, u: u)
            tuples.append(key)
            keyToOriginal[key] = id
        }

        if tuples.isEmpty { return [] }

            // 2) 分片，避免超出 SQLite 占位符上限（每行 3 个占位符）
        let maxVars = 900 // 留些余量，避免恰好 999
        let perChunk = max(1, maxVars / 3)
        var missing: Set<Key> = []

        let tableName = kind  // 确保从枚举白名单映射得到安全表名
                                           // 可选：如果需要 account 过滤，这里决定是否保留 JOIN account
        let baseSQLPrefix = """
        WITH input(sp3PrincipalId, playedTime, sp3Id) AS (VALUES
        """

        let baseSQLSuffix = """
            )
            SELECT i.sp3PrincipalId, i.playedTime, i.sp3Id
            FROM input i
            LEFT JOIN \(tableName) t
              ON  t.sp3PrincipalId = i.sp3PrincipalId
              AND t.playedTime     = i.playedTime
            LEFT JOIN account a
              ON  t.accountId = a.id
              AND a.sp3Id     = i.sp3Id
            WHERE t.sp3PrincipalId IS NULL
            """

        try dbQueue.read { db in
            var start = 0
            while start < tuples.count {
                let end = min(start + perChunk, tuples.count)
                let chunk = tuples[start..<end]

                    // 构造 VALUES (?,?,?),(?,?,?),...
                let valuesPlaceholders = Array(repeating: "(?,?,?)", count: chunk.count).joined(separator: ",")
                let sql = baseSQLPrefix + valuesPlaceholders + "\n" + baseSQLSuffix

                    // 组装参数，注意 playedTime 用与库中一致的类型（这里用 Int64）
                var args: [DatabaseValueConvertible] = []
                args.reserveCapacity(chunk.count * 3)
                for k in chunk {
                    args.append(k.p)
                    args.append(k.t)
                    args.append(k.u)
                }

                let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
                for row in rows {
                    let p: String = row["sp3PrincipalId"]
                    let t: Date  = row["playedTime"]
                    let u: String = row["sp3Id"]
                    missing.insert(Key(p: p, t: t, u: u))
                }
                start = end
            }
        }

            // 3) 将缺失三元组映射回原始 ids
        var notExistIds: [String] = []
        notExistIds.reserveCapacity(missing.count)
        for key in missing {
            if let original = keyToOriginal[key] {
                notExistIds.append(original)
            }
        }
        return notExistIds
    }

}



