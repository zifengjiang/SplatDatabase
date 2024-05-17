import Foundation
import GRDB

extension SplatDatabase {
    public struct Filter {
        var accountId: Int64
        var modes: [String]?
        var rules: [String]?
        var stageIds: [Int]?
        var weaponIds: [Int]?
        var start: Date?
        var end: Date?
    }
}
