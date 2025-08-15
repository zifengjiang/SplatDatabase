import Foundation
import GRDB
import SwiftyJSON

// MARK: - JSONExporter使用示例
public class JSONExporterExample {
    
    /// 示例：导出Coop数据到JSON
    public static func exportCoopExample(dbPool: DatabasePool, coopId: Int64) throws -> String {
        let exporter = JSONExporter(dbPool: dbPool)
        
        do {
            let json = try exporter.exportCoopToJSON(coopId: coopId)
            
            // 将JSON转换为格式化的字符串
            let jsonData = try json.rawData()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            return jsonString
        } catch {
            throw error
        }
    }
    
    /// 示例：导出Battle数据到JSON
    public static func exportBattleExample(dbPool: DatabasePool, battleId: Int64) throws -> String {
        let exporter = JSONExporter(dbPool: dbPool)
        
        do {
            let json = try exporter.exportBattleToJSON(battleId: battleId)
            
            // 将JSON转换为格式化的字符串
            let jsonData = try json.rawData()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            return jsonString
        } catch {
            throw error
        }
    }
    
    /// 示例：批量导出Coop数据
    public static func exportMultipleCoopsExample(dbPool: DatabasePool, coopIds: [Int64]) throws -> [String] {
        let exporter = JSONExporter(dbPool: dbPool)
        var results: [String] = []
        
        for coopId in coopIds {
            do {
                let json = try exporter.exportCoopToJSON(coopId: coopId)
                let jsonData = try json.rawData()
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                results.append(jsonString)
            } catch {
                print("导出Coop ID \(coopId) 失败: \(error)")
                results.append("")
            }
        }
        
        return results
    }
    
    /// 示例：批量导出Battle数据
    public static func exportMultipleBattlesExample(dbPool: DatabasePool, battleIds: [Int64]) throws -> [String] {
        let exporter = JSONExporter(dbPool: dbPool)
        var results: [String] = []
        
        for battleId in battleIds {
            do {
                let json = try exporter.exportBattleToJSON(battleId: battleId)
                let jsonData = try json.rawData()
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                results.append(jsonString)
            } catch {
                print("导出Battle ID \(battleId) 失败: \(error)")
                results.append("")
            }
        }
        
        return results
    }
    
    /// 示例：将导出的JSON保存到文件
    public static func saveJSONToFile(jsonString: String, filename: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
        print("JSON已保存到: \(fileURL.path)")
    }
    
    /// 示例：获取所有Coop ID
    public static func getAllCoopIds(dbPool: DatabasePool) throws -> [Int64] {
        return try dbPool.read { db in
            return try Coop.fetchAll(db).compactMap { $0.id }
        }
    }
    
    /// 示例：获取所有Battle ID
    public static func getAllBattleIds(dbPool: DatabasePool) throws -> [Int64] {
        return try dbPool.read { db in
            return try Battle.fetchAll(db).compactMap { $0.id }
        }
    }
}

// MARK: - 使用说明
/*
 
 使用JSONExporter的步骤：
 
 1. 创建JSONExporter实例：
    let exporter = JSONExporter(dbQueue: yourDatabaseQueue)
 
 2. 导出Coop数据：
    let coopJson = try exporter.exportCoopToJSON(coopId: 123)
 
 3. 导出Battle数据：
    let battleJson = try exporter.exportBattleToJSON(battleId: 456)
 
 4. 将JSON转换为字符串：
    let jsonString = String(data: try coopJson.rawData(), encoding: .utf8) ?? ""
 
 5. 保存到文件：
    try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
 
 注意事项：
 - 确保数据库中有相应的数据
 - 导出的JSON格式与原始插入格式兼容
 - 图片URL包含正确的sha256值，可以重新插入数据库
 - 处理错误情况，某些记录可能不存在
 
 */
