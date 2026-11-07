import Foundation

/// 数据库中存储的两类「可软删除 / 可收藏」的记录。
///
/// 两类记录在表结构上共享 `id` / `accountId` / `sp3PrincipalId` /
/// `isDeleted` / `isFavorite` 这些列，因此删除、恢复、收藏等操作可以共用一份实现。
public enum SplatRecordKind: String, CaseIterable, Sendable {
    case battle
    case coop

    /// 记录所在的表名（表名与枚举名保持一致）。
    public var table: String { rawValue }

    /// 记录上用于展示的 id 列表（供批量操作使用）。
    var idColumn: String { "id" }
}
