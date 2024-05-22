import Foundation
import GRDB
import SwiftyJSON

extension SplatDatabase{

    public func importFromConchBay(dbPath: String, progress: ((Double) -> Void)? = nil) throws {
        let maxRetries = 6 // 最大重试次数
        var currentRetry = 0
        var offset = 0 // 初始偏移量为0

        while currentRetry < maxRetries {
            do {
                let db = try DatabasePool(path: dbPath)

                try db.read { db in
                        // 使用偏移量来查询数据库
                    let cursor = try Row.fetchCursor(db, sql: "SELECT mode, detail FROM result LIMIT -1 OFFSET \(offset)")

                        // 计算总行数以更新进度
                    let totalRows = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM result") ?? 0
                    var processedRows = offset

                    while let row = try cursor.next() {
                        if let mode = row["mode"] as String?, let detail = row["detail"] as String? {
                            if mode == "salmon_run" {
                                let json = JSON(parseJSON: detail)["coopHistoryDetail"]
                                if try self.isCoopExist(id: json["id"].stringValue) {
                                    continue
                                }
                                try self.insertCoop(json: json)
                            } else {
                                let json = JSON(parseJSON: detail)["vsHistoryDetail"]
                                try self.insertBattle(json: json)
                            }
                        }

                            // 更新进度
                        processedRows += 1
                        offset += 1
                        if let progress = progress {
                            let progressValue = Double(processedRows) / Double(totalRows)
                            progress(progressValue)
                        }
                    }
                        // 更新偏移量
                    offset += processedRows
                }

                    // 如果成功执行到这里，退出循环
                break
            } catch {
                    // 打印错误并尝试重试
                print("An error occurred: \(error)")
                currentRetry += 1
                if currentRetry < maxRetries {
                    print("Retrying...")
                } else {
                        // 达到最大重试次数时，抛出错误
                    throw error
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
