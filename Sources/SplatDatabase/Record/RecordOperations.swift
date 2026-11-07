import Foundation
import GRDB

/// 记录状态查询条件。
public enum RecordQueryState {
    /// 正常（未删除）的记录。
    case active
    /// 回收站中的记录。
    case deleted
    /// 已收藏且未删除的记录。
    case favorite
}

extension SplatDatabase {
    /// 批量写入时每批处理的 id 数量。
    public static let recordBatchSize = 50

    // MARK: - 软删除 / 恢复

    /// 批量设置记录的删除标记。
    public func setDeleted(_ isDeleted: Bool, kind: SplatRecordKind, ids: [Int64]) throws {
        try updateFlag("isDeleted", value: isDeleted, kind: kind, ids: ids)
    }

    /// 按 sp3PrincipalId 设置记录的删除标记。
    public func setDeleted(_ isDeleted: Bool, kind: SplatRecordKind, sp3PrincipalId: String) throws {
        try updateFlag("isDeleted", value: isDeleted, kind: kind, sp3PrincipalId: sp3PrincipalId)
    }

    // MARK: - 收藏

    /// 批量设置记录的收藏标记。
    public func setFavorite(_ isFavorite: Bool, kind: SplatRecordKind, ids: [Int64]) throws {
        try updateFlag("isFavorite", value: isFavorite, kind: kind, ids: ids)
    }

    /// 按 sp3PrincipalId 设置记录的收藏标记。
    public func setFavorite(_ isFavorite: Bool, kind: SplatRecordKind, sp3PrincipalId: String) throws {
        try updateFlag("isFavorite", value: isFavorite, kind: kind, sp3PrincipalId: sp3PrincipalId)
    }

    /// 批量翻转收藏状态（单事务、按批执行）。
    public func toggleFavorite(kind: SplatRecordKind, ids: [Int64]) throws {
        guard !ids.isEmpty else { return }

        try dbQueue.write { db in
            for batch in Self.batches(ids) {
                try db.execute(
                    sql: "UPDATE \(kind.table) SET isFavorite = NOT isFavorite WHERE id IN \(Self.placeholderList(count: batch.count))",
                    arguments: StatementArguments(batch)
                )
            }
        }
    }

    // MARK: - 永久删除

    /// 永久删除指定记录（含关联表数据）。
    public func deleteRecords(kind: SplatRecordKind, ids: [Int64]) throws {
        guard !ids.isEmpty else { return }

        try dbQueue.write { db in
            for id in ids {
                try deleteRecord(kind, id: id, db: db)
            }
        }
    }

    /// 永久删除某类记录中所有已软删除的数据（含关联表）。
    public func permanentlyDeleteSoftDeleted(_ kind: SplatRecordKind) throws {
        let ids = try dbQueue.read { db in
            try Int64.fetchAll(
                db,
                sql: "SELECT id FROM \(kind.table) WHERE isDeleted = ?",
                arguments: [true]
            )
        }
        try deleteRecords(kind: kind, ids: ids)
    }

    // MARK: - 查询

    /// 按状态查询记录，可选按账号过滤。
    public func fetchRecords<T: FetchableRecord & TableRecord>(
        _ type: T.Type,
        state: RecordQueryState,
        accountId: Int64? = nil
    ) async throws -> [T] {
        try await dbQueue.read { db in
            var request = T.all()

            switch state {
            case .active:
                request = request.filter(Column("isDeleted") == false)
            case .deleted:
                request = request.filter(Column("isDeleted") == true)
            case .favorite:
                request = request.filter(Column("isFavorite") == true && Column("isDeleted") == false)
            }

            if let accountId {
                request = request.filter(Column("accountId") == accountId)
            }

            return try request.fetchAll(db)
        }
    }

    /// 按 sp3PrincipalId 查询记录 id。
    public func recordIDs(kind: SplatRecordKind, sp3PrincipalId: String) throws -> [Int64] {
        try dbQueue.read { db in
            try Int64.fetchAll(
                db,
                sql: "SELECT id FROM \(kind.table) WHERE sp3PrincipalId = ?",
                arguments: [sp3PrincipalId]
            )
        }
    }

    // MARK: - 内部

    private func updateFlag(_ column: String, value: Bool, kind: SplatRecordKind, ids: [Int64]) throws {
        guard !ids.isEmpty else { return }

        try dbQueue.write { db in
            for batch in Self.batches(ids) {
                try db.execute(
                    sql: "UPDATE \(kind.table) SET \(column) = \(value ? 1 : 0) WHERE id IN \(Self.placeholderList(count: batch.count))",
                    arguments: StatementArguments(batch)
                )
            }
        }
    }

    private func updateFlag(_ column: String, value: Bool, kind: SplatRecordKind, sp3PrincipalId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE \(kind.table) SET \(column) = ? WHERE sp3PrincipalId = ?",
                arguments: [value, sp3PrincipalId]
            )
        }
    }

    private func deleteRecord(_ kind: SplatRecordKind, id: Int64, db: Database) throws {
        switch kind {
        case .battle:
            try deleteBattle(battleId: id, db: db)
        case .coop:
            try deleteCoop(coopId: id, db: db)
        }
    }

    /// 把 id 切分成若干批，避免单条 SQL 参数过多。
    public static func batches<ID>(_ ids: [ID], batchSize: Int = recordBatchSize) -> [[ID]] {
        guard batchSize > 0 else { return [] }
        return stride(from: 0, to: ids.count, by: batchSize).map { start in
            Array(ids[start..<min(start + batchSize, ids.count)])
        }
    }

    /// 生成 `(?, ?, ?)` 形式的占位符列表。
    static func placeholderList(count: Int) -> String {
        "(\(Array(repeating: "?", count: count).joined(separator: ",")))"
    }
}
