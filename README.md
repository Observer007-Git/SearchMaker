# SearchMaker

在世界地图上搜索并标记地点，使用游戏内置路径点功能。

## 快捷键

- `Ctrl + Space`：呼出 / 隐藏搜索框
- `Tab`：切换「当前地图」/「全图搜索」模式
- `Alt + 左键（世界地图上）」：在鼠标位置添加地点
- `Shift + 拖动搜索框」：移动搜索框

## 导出 / 导入编码格式

当前导出格式为 `SMK|2|`，坐标采用整数编码（×100），类别使用稳定数字 ID。
导入仍兼容未显式标版本的 `SMK|` 文本。

---

## 快速修改指引

修改插件外观、尺寸、行为时，按以下路径找到对应代码：

### 外观 / 尺寸

| 想修改什么 | 在哪里改 |
|---|---|
| 搜索栏宽度/高度 | `Config.lua` → `search.barWidth` / `search.barHeight` |
| 搜索输入框宽度/高度 | `Config.lua` → `search.boxWidth` / `search.boxHeight` |
| 面板宽度/高度 | `Config.lua` → `panel.width` / `panel.height` |
| 地点按钮大小 | `Config.lua` → `location.baseWidth` / `location.baseHeight` |
| 按钮背景贴图 | `Config.lua` → `art.button`（接口路径） |
| 地点图标（列表中） | `Config.lua` → `art.defaultLocationIcon` |
| 颜色（文字/边框/背景） | `Config.lua` → `colors.*` |
| 面板底图 Atlas | `Config.lua` → `panel.backgroundAtlas` |
| 数量限制：地点名最大字符 | `Config.lua` → `location.maxNameLength` |
| 缩放范围 | `Config.lua` → `location.minScale` / `maxScale` / `scaleStep` |

### 功能行为

| 想修改什么 | 在哪里改 |
|---|---|
| 搜索结果最大条数 | `Config.lua` → `search.maxResults` |
| 常用地点最大显示数 | `Config.lua` → `location.maxFrequent` |
| 批量导出每批条数 | `Config.lua` → `export.maxPerBatch` |
| 默认类别 | `Config.lua` → `defaultCategoryKey` |
| 类别列表（名称/图标/顺序） | `Config.lua` → `categories[...]` |
| 编辑器中列表顺序 | `Config.lua` → `categories[...]`（遍历顺序即为显示顺序） |
| 新增/修改面板布局 | `UI/LocationEditor.lua` → `Editor:Create()` |
| 搜索框布局 | `UI/SearchBar.lua` → `SearchBar:Create()` + `ApplyArt()` |

### 语言 / 本地化

| 想修改什么 | 在哪里改 |
|---|---|
| 中文字符串 | `Locales/zhCN.lua`（直接改键值） |
| 英文字符串 | `Locales/enUS.lua`（同上） |
| 非中文客户端默认语言 | `Locales/init.lua`（决定加载 zhCN 还是 enUS） |
| 在地图搜索中出现的「地图」后缀 | `Locales/zhCN.lua` → `MAP_PORTAL_SUFFIX` |

### 核心逻辑

| 想修改什么 | 在哪里改 |
|---|---|
| 地点搜索算法 | `Core/SearchService.lua` → `Search:GetScore()` |
| 数据库初始化 / 存档字段 | `Core/Database.lua` → `DB:Initialize()` |
| 地点数据操作（增删改查） | `Core/LocationStore.lua` → `Store:*()` |
| 导入导出编码 | `Core/ShareCodec.lua` → `Codec:Encode()` / `Decode()` |
| 地图标记绘制 | `UI/Widgets.lua` → `Widgets:RefreshMapPins()` |
| 添加 / 编辑对话框 | `UI/LocationEditor.lua` |

---

导出的 `SMK|2|` 使用稳定类别 ID，并兼容导入旧版 `SMK|` / `SMK3|` / `SMK2|` / `MLL2|` / `MLL1|`。

## 开发验证

核心服务测试及 TOC/XML/Lua 静态检查位于 `Tests/`，运行：

```sh
Tests/run.sh
```
