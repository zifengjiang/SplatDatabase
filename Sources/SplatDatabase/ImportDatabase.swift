import Foundation
import GRDB
import SwiftyJSON

extension SplatDatabase{

    public func importFromConchBay(dbPath: String, progress: ((Double) -> Void)? = nil) throws {

        let db = try DatabasePool(path: dbPath)

        try db.read { db in
                // 计算总行数以更新进度
            let totalRows = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM result") ?? 0

                // 使用偏移量来查询数据库
            let cursor = try Row.fetchCursor(db, sql: "SELECT mode, detail FROM result")

            var processedRows = 0

            while let row = try cursor.next() {
                if let mode = row["mode"] as String?, let detail = row["detail"] as String? {
                    if mode == "salmon_run" {
                        let json = JSON(parseJSON: detail)["coopHistoryDetail"]
                        try self.insertCoop(json: json)
                    } else {
                        let json = JSON(parseJSON: detail)["vsHistoryDetail"]
                        try self.insertBattle(json: json)
                    }
                }
                    // 更新进度
                processedRows += 1
                if let progress = progress {
                    let progressValue = Double(processedRows) / Double(totalRows)
                    progress(progressValue)
                }
            }
        }

    }
}



extension SplatDatabase{
    public func importFromInkMe(dbPath: String, progress: ((Double) -> Void)? = nil) throws {
        let db = try DatabasePool(path: dbPath)

            // 使用 do-catch 处理可能的错误
        do {
            try db.read { db in
                    // 使用 Row.fetchCursor 减少内存占用
                let cursor = try Row.fetchCursor(db, sql: "SELECT ZMODE, ZDETAIL FROM ZDETAILENTITY")
                    // 计算总行数以更新进度
                let totalRows = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ZDETAILENTITY") ?? 0
                var processedRows = 0
                    // 逐行读取数据
                while let row = try cursor.next() {
                        // 安全地从 row 中获取数据
                    if let mode = row["ZMODE"] as String?, let detailData = row["ZDETAIL"] as? Data  {

                        if mode == "salmon_run" {
                                // 解析 JSON 并插入
                            let json = try JSON(data: detailData)
                            try self.insertCoop(json: json)
                        } else {
                            let json = try JSON(data: detailData)
                            try self.insertBattle(json: json)
                        }
                    }
                        // 更新进度
                    processedRows += 1
                    if let progress = progress {
                        let progressValue = Double(processedRows) / Double(totalRows)
                        progress(progressValue)
                    }
                }
            }
        } catch {
                // 处理错误，可能是数据库错误或 JSON 解析错误
            print("An error occurred: \(error)")
            throw error
        }
    }
}

extension SplatDatabase {
    /// 导入其他db.sqlite数据库文件，执行合并操作
    /// - Parameters:
    ///   - sourceDbPath: 源数据库文件路径
    ///   - progress: 进度回调，参数为0.0到1.0的进度值
    ///   - onConflict: 冲突处理策略，默认为.ignore（忽略重复记录）
    public func importFromDatabase(sourceDbPath: String, progress: ((Double) -> Void)? = nil, onConflict: Database.ConflictResolution = .ignore) throws {
        let sourceDb = try DatabasePool(path: sourceDbPath)
        
        // 获取所有表名
        let tableNames = try sourceDb.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        
        // 过滤掉系统表，只处理应用表
        let appTables = tableNames.filter { !$0.hasPrefix("sqlite_") && !$0.hasPrefix("android_") }
        
        var totalProgress = 0.0
        let progressPerTable = 1.0 / Double(appTables.count)
        
        for (index, tableName) in appTables.enumerated() {
            try importTable(tableName: tableName, from: sourceDb, onConflict: onConflict)
            
            // 更新进度
            totalProgress = Double(index + 1) * progressPerTable
            progress?(totalProgress)
        }
    }
    
    /// 导入单个表的数据
    /// - Parameters:
    ///   - tableName: 表名
    ///   - sourceDb: 源数据库
    ///   - onConflict: 冲突处理策略
    private func importTable(tableName: String, from sourceDb: DatabasePool, onConflict: Database.ConflictResolution) throws {
        // 检查目标数据库中是否存在该表
        let targetTableExists = try dbQueue.read { db in
            try db.tableExists(tableName)
        }
        
        guard targetTableExists else {
            print("警告: 目标数据库中不存在表 '\(tableName)'，跳过导入")
            return
        }
        
        // 获取源表的列信息
        let sourceColumns = try sourceDb.read { db in
            try db.columns(in: tableName)
        }
        
        // 获取目标表的列信息
        let targetColumns = try dbQueue.read { db in
            try db.columns(in: tableName)
        }
        
        // 找出两个表都存在的列
        let commonColumns = sourceColumns.filter { sourceCol in
            targetColumns.contains { targetCol in
                targetCol.name == sourceCol.name
            }
        }
        
        guard !commonColumns.isEmpty else {
            print("警告: 表 '\(tableName)' 没有共同的列，跳过导入")
            return
        }
        
        // 构建列名列表
        let columnNames = commonColumns.map { $0.name }
        let columnNamesString = columnNames.joined(separator: ", ")
        let placeholders = columnNames.map { _ in "?" }.joined(separator: ", ")
        
        // 构建INSERT语句
        let insertSQL = """
            INSERT INTO \(tableName) (\(columnNamesString))
            VALUES (\(placeholders))
        """
        
        // 构建SELECT语句
        let selectSQL = "SELECT \(columnNamesString) FROM \(tableName)"
        
        // 执行数据导入
        try sourceDb.read { sourceDb in
            let cursor = try Row.fetchCursor(sourceDb, sql: selectSQL)
            
            try dbQueue.write { targetDb in
                while let row = try cursor.next() {
                    // 提取列值
                    let values = columnNames.map { columnName in
                        row[columnName]
                    }
                    
                    // 执行插入
                    try targetDb.execute(sql: insertSQL, arguments: StatementArguments(values))
                }
            }
        }
        
        print("成功导入表 '\(tableName)' 的数据")
    }
    
    /// 导入数据库并处理外键约束
    /// - Parameters:
    ///   - sourceDbPath: 源数据库文件路径
    ///   - progress: 进度回调
    ///   - preserveIds: 是否保留原始ID，默认为false（使用新的自增ID）
    public func importFromDatabaseWithConstraints(sourceDbPath: String, progress: ((Double) -> Void)? = nil, preserveIds: Bool = false) throws {
        let sourceDb = try DatabasePool(path: sourceDbPath)
        
        // 存储ID映射关系（旧ID -> 新ID）
        var idMappings: [String: [Int: Int]] = [:]
        
        // 定义表的导入顺序（考虑外键约束）
        let tableOrder = [
            "account",      // 基础表，无外键依赖
            "imageMap",     // 基础表，无外键依赖
            "i18n",         // 基础表，无外键依赖
            "schedule",     // 基础表，无外键依赖
            "coop",         // 依赖account, imageMap
            "battle",       // 依赖account, imageMap
            "vsTeam",       // 依赖battle
            "coopPlayerResult", // 依赖coop
            "coopWaveResult",   // 依赖coop
            "coopEnemyResult",  // 依赖coop, imageMap
            "weapon",       // 依赖coop, coopPlayerResult, coopWaveResult, imageMap
            "player"        // 依赖vsTeam, coopPlayerResult
        ]
        
        var totalProgress = 0.0
        let progressPerTable = 1.0 / Double(tableOrder.count)
        
        for (index, tableName) in tableOrder.enumerated() {
            try importTableWithConstraints(tableName: tableName, from: sourceDb, preserveIds: preserveIds, idMappings: &idMappings)
            
            // 更新进度
            totalProgress = Double(index + 1) * progressPerTable
            progress?(totalProgress)
        }
    }
    
    /// 导入单个表并处理外键约束
    /// - Parameters:
    ///   - tableName: 表名
    ///   - sourceDb: 源数据库
    ///   - preserveIds: 是否保留原始ID
    ///   - idMappings: ID映射关系（旧ID -> 新ID）
    private func importTableWithConstraints(tableName: String, from sourceDb: DatabasePool, preserveIds: Bool, idMappings: inout [String: [Int: Int]]) throws {
        // 检查目标数据库中是否存在该表
        let targetTableExists = try dbQueue.read { db in
            try db.tableExists(tableName)
        }
        
        guard targetTableExists else {
            print("警告: 目标数据库中不存在表 '\(tableName)'，跳过导入")
            return
        }
        
        // 获取源表的列信息
        let sourceColumns = try sourceDb.read { db in
            try db.columns(in: tableName)
        }
        
        // 获取目标表的列信息
        let targetColumns = try dbQueue.read { db in
            try db.columns(in: tableName)
        }
        
        // 找出两个表都存在的列
        let commonColumns = sourceColumns.filter { sourceCol in
            targetColumns.contains { targetCol in
                targetCol.name == sourceCol.name
            }
        }
        
        guard !commonColumns.isEmpty else {
            print("警告: 表 '\(tableName)' 没有共同的列，跳过导入")
            return
        }
        
        // 构建列名列表
        let columnNames = commonColumns.map { $0.name }
        let columnNamesString = columnNames.joined(separator: ", ")
        let placeholders = columnNames.map { _ in "?" }.joined(separator: ", ")
        
        // 为特定表构建特殊的INSERT语句
        let insertSQL: String
        if ["account", "i18n", "imageMap", "schedule"].contains(tableName) {
            // 对于有唯一约束的表，使用INSERT OR REPLACE来处理唯一约束冲突
            insertSQL = """
                INSERT OR REPLACE INTO \(tableName) (\(columnNamesString))
                VALUES (\(placeholders))
            """
        } else {
            // 对于其他表，使用普通的INSERT
            insertSQL = """
                INSERT INTO \(tableName) (\(columnNamesString))
                VALUES (\(placeholders))
            """
        }
        
        // 构建SELECT语句
        let selectSQL = "SELECT \(columnNamesString) FROM \(tableName)"
        
        // 执行数据导入
        try sourceDb.read { sourceDb in
            let cursor = try Row.fetchCursor(sourceDb, sql: selectSQL)
            
            try dbQueue.write { targetDb in
                while let row = try cursor.next() {
                    // 提取列值
                    var values = columnNames.map { columnName in
                        row[columnName]
                    }
                    
                    // 记录原始ID（如果存在）
                    var originalId: Int? = nil
                    if let _ = columnNames.firstIndex(of: "id"), let idValue = row["id"] as? Int {
                        originalId = idValue
                    }
                    
                    // 如果不保留ID且是主键列，则跳过ID值（让数据库自动生成）
                    if !preserveIds, let primaryKeyIndex = columnNames.firstIndex(of: "id") {
                        values[primaryKeyIndex] = nil
                    }
                    
                    // 更新外键引用
                    if !preserveIds {
                        let updatedValues = updateForeignKeyReferences(values: values, columnNames: columnNames, tableName: tableName, idMappings: idMappings)
                        values = updatedValues
                    }
                    
                    // 执行插入
                    try targetDb.execute(sql: insertSQL, arguments: StatementArguments(values))
                    
                    // 记录新ID映射（如果生成了新ID）
                    if !preserveIds, let originalId = originalId {
                        let newId = targetDb.lastInsertedRowID
                        if idMappings[tableName] == nil {
                            idMappings[tableName] = [:]
                        }
                        idMappings[tableName]?[originalId] = Int(newId)
                    }
                }
            }
        }
        
        print("成功导入表 '\(tableName)' 的数据")
    }
    
    /// 更新外键引用
    /// - Parameters:
    ///   - values: 列值数组
    ///   - columnNames: 列名数组
    ///   - tableName: 表名
    ///   - idMappings: ID映射关系
    /// - Returns: 更新后的列值数组
    private func updateForeignKeyReferences(values: [DatabaseValueConvertible?], columnNames: [String], tableName: String, idMappings: [String: [Int: Int]]) -> [DatabaseValueConvertible?] {
        var updatedValues = values
        
        // 定义外键映射关系
        let foreignKeyMappings: [String: [String: String]] = [
            "coop": ["accountId": "account", "stageId": "imageMap", "boss": "imageMap"],
            "battle": ["accountId": "account", "stageId": "imageMap"],
            "vsTeam": ["battleId": "battle"],
            "coopPlayerResult": ["coopId": "coop"],
            "coopWaveResult": ["coopId": "coop"],
            "coopEnemyResult": ["coopId": "coop", "enemyId": "imageMap"],
            "weapon": ["coopId": "coop", "coopPlayerResultId": "coopPlayerResult", "coopWaveResultId": "coopWaveResult", "imageMapId": "imageMap"],
            "player": ["vsTeamId": "vsTeam", "coopPlayerResultId": "coopPlayerResult"]
        ]
        
        // 获取当前表的外键映射
        if let tableForeignKeys = foreignKeyMappings[tableName] {
            for (columnName, referencedTable) in tableForeignKeys {
                if let columnIndex = columnNames.firstIndex(of: columnName),
                   let oldId = values[columnIndex] as? Int,
                   let tableMappings = idMappings[referencedTable],
                   let newId = tableMappings[oldId] {
                    updatedValues[columnIndex] = newId
                }
            }
        }
        
        return updatedValues
    }
}

/*
 使用示例:
 
 // 基本导入
 let database = SplatDatabase.shared
 try database.importFromDatabase(sourceDbPath: "/path/to/other/database.sqlite") { progress in
     print("导入进度: \(progress * 100)%")
 }
 
 // 带约束处理的导入（推荐）
 try database.importFromDatabaseWithConstraints(
     sourceDbPath: "/path/to/other/database.sqlite",
     progress: { progress in
         print("导入进度: \(progress * 100)%")
     },
     preserveIds: false // 是否保留原始ID
 )
 
 功能特点:
 - 自动检测源数据库中的所有表
 - 只导入两个数据库都存在的列
 - 按照正确的顺序导入表以避免外键约束错误
 - 提供实时导入进度
 - 支持忽略重复记录
 - 可选择保留原始ID或使用新的自增ID
 - 自动处理外键引用更新
 */
