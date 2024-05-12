//
//  File.swift
//
//
//  Created by 姜锋 on 5/12/24.
//

import Foundation
import GRDB

struct PackableNumbers:Codable {
    var numbers: [UInt16]  // 使用 UInt16 存储，因为它足够容纳 0...4095 的值

    init(_ numbers: [UInt16]) {
        assert(numbers.count <= 5, "Must have less than five numbers")
        assert(numbers.allSatisfy { $0 < 4096 }, "All numbers must be less than 4096")
        self.numbers = numbers
    }

    /// 将 numbers 打包成一个 UInt64
    func pack() -> UInt64 {
        var packed: UInt64 = 0
        for number in numbers + Array(repeating: 0, count: 5 - numbers.count){
            packed = (packed << 12) | UInt64(number)
        }
        return packed
    }

    /// 从 UInt64 解包得到 PackableNumbers
    static func unpack(_ packed: UInt64) -> PackableNumbers {
        var numbers = [UInt16](repeating: 0, count: 5)
        for i in 0..<5 {
            numbers[4 - i] = UInt16((packed >> (UInt64(i) * 12)) & 0xFFF)
        }
        return PackableNumbers(numbers)
    }

    // 通过下标访问和设置数字
    subscript(index: Int) -> UInt16 {
        get {
            assert(index >= 0 && index < 5, "Index out of range")
            return numbers[index]
        }
        set {
            assert(index >= 0 && index < 5, "Index out of range")
            assert(newValue < 4096, "Number must be less than 4096")
            numbers[index] = newValue
        }
    }
}

@propertyWrapper
struct DatabasePackableNumbers:Codable {
    var wrappedValue: PackableNumbers

    init(wrappedValue: PackableNumbers) {
        self.wrappedValue = wrappedValue
    }
}

extension DatabasePackableNumbers: DatabaseValueConvertible {
    /// 将 PackableNumbers 转换为 DatabaseValue
    var databaseValue: DatabaseValue {
        let packedValue = wrappedValue.pack()
        let storedValue = Int64(bitPattern: packedValue)
        return storedValue.databaseValue
    }

    /// 从 DatabaseValue 解析出 DatabasePackableNumbers
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabasePackableNumbers? {
        guard let storedValue = Int64.fromDatabaseValue(dbValue) else {
            return nil
        }
        let packedValue = UInt64(bitPattern: storedValue)
        let numbers = PackableNumbers.unpack(packedValue)
        return DatabasePackableNumbers(wrappedValue: numbers)
    }


}

