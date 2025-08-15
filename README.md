# SplatDatabase

一个用于管理喷射战士3游戏数据的Swift数据库库。

## 功能特性

- 支持从Conch Bay导入数据
- 支持从InkMe导入数据
- **新增：支持导入其他db.sqlite数据库文件并执行合并操作**

## 导入数据库功能

### 基本导入

```swift
let database = SplatDatabase.shared

// 导入其他db.sqlite文件
try database.importFromDatabase(sourceDbPath: "/path/to/other/database.sqlite") { progress in
    print("导入进度: \(progress * 100)%")
}
```

### 带约束处理的导入

```swift
// 导入并处理外键约束（推荐用于复杂数据库）
try database.importFromDatabaseWithConstraints(
    sourceDbPath: "/path/to/other/database.sqlite",
    progress: { progress in
        print("导入进度: \(progress * 100)%")
    },
    preserveIds: false // 是否保留原始ID，默认为false
)
```

### 功能说明

1. **自动表检测**: 自动检测源数据库中的所有表
2. **列匹配**: 只导入两个数据库都存在的列
3. **外键约束处理**: 按照正确的顺序导入表以避免外键约束错误
4. **进度回调**: 提供实时导入进度
5. **冲突处理**: 支持忽略重复记录或替换现有记录
6. **ID处理**: 可选择保留原始ID或使用新的自增ID

### 导入顺序

带约束处理的导入会按照以下顺序导入表：

1. `account` - 账户表
2. `imageMap` - 图片映射表
3. `i18n` - 国际化表
4. `schedule` - 日程表
5. `coop` - 合作模式表
6. `battle` - 对战表
7. `vsTeam` - 对战队伍表
8. `coopPlayerResult` - 合作玩家结果表
9. `coopWaveResult` - 合作波次结果表
10. `coopEnemyResult` - 合作敌人结果表
11. `weapon` - 武器表
12. `player` - 玩家表

### 注意事项

- 确保源数据库文件存在且可访问
- 导入过程中会跳过不存在的表
- 建议在导入前备份目标数据库
- 大量数据导入可能需要较长时间

