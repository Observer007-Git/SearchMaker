# SearchMaker

SearchMaker 是一个适用于《魔兽世界》正式服的轻量地图搜索与地点管理插件，支持
`enUS` 和 `zhCN`。它使用游戏原生路径点定位地点，并可在世界地图上显示自定义标记。

主要功能：

- 搜索当前地图或全部已保存地点，并可搜索地图名称。
- 保存、分组、修改、删除地点，记录常用地点。
- 显示自定义地图标记、名称、颜色、大小和定位高亮。
- 识别坐标输入并直接创建游戏原生路径点。
- 使用 `SMK|` 文本导入、导出和备份地点。
- 可选读取 `HandyNotes_MapNotes` 的当前地图结果，并收藏到 SearchMaker 分组。

## 安装与依赖

将 `SearchMaker` 文件夹放入正式服的
`World of Warcraft/_retail_/Interface/AddOns/` 目录，然后进入游戏或执行 `/reload`。

插件不依赖第三方库。安装并启用 `HandyNotes` 与 `HandyNotes_MapNotes` 后，会自动提供
当前地图的外部地点搜索；未安装时其余功能不受影响。

## 快捷键

- `Ctrl + Space`：呼出 / 隐藏搜索框（默认按键，可在“搜索设置”中修改）
- `Tab`：切换「当前地图」/「全图搜索」模式
- `Alt + 左键（世界地图上）`：在鼠标位置添加地点
- `右键搜索框`：打开地点主面板
- `中键搜索框`：打开 / 关闭世界地图
- 在搜索框输入 `12 34`、`12,34` 或 `12.3 34.56`：在当前地图设置临时坐标
- `左键单击地图标记`：修改或删除该地点（坐标可编辑）
- `左键单击地点`：定位成功后在目标坐标显示约 3 秒的高亮提示
- `鼠标悬停地图标记`：查看地点名称和坐标
- `Shift + 拖动搜索框`：移动搜索框

当前地图模式会在世界地图打开时搜索正在浏览的地图；地图关闭时，搜索框获得焦点或被
点击会重新读取角色当前地图。世界地图打开时，将鼠标移到当前地图的搜索结果上会短暂
预览定位动画。

## 主面板

右键搜索框打开主面板；点击面板外区域、按 `Esc` 或点击右上角关闭按钮可关闭。

- “新增坐标”：手动添加地点，也可读取角色坐标。
- “导出/导入”：备份、分享或导入地点。
- “更多”：扫描近期聊天中的 `SMK|` 文本、批量删除地点或查看使用说明。
- “搜索设置”：调整搜索框缩放、透明度和快捷键。
- “标记设置”：调整地图标记图标与名称的显示、尺寸、颜色和偏移。
- HandyNotes_MapNotes 搜索结果可右键收藏，并动态选择目标分组。

## 导出 / 导入编码格式

当前导出格式统一使用 `SMK|` 前缀，坐标采用整数编码（×100），类别使用稳定数字 ID，
并保留单地点标记文字颜色。导入只接受当前 `SMK|` 记录，旧项目前缀和旧字段结构不会
被识别。

导出时可选择“只导出当前地图”，并将最大单次导出数量设为 `20`、`50`、`100` 或
`200`。超过该数量时，可在“导出范围”中选择分页；切换地图范围或批次大小会立即重新
计算当前导出内容。

---

## 快速修改指引

修改插件外观、尺寸、行为时，按以下路径找到对应代码：

### 外观 / 尺寸

| 想修改什么 | 在哪里改 |
|---|---|
| 搜索栏宽度/高度 | `Config.lua` → `search.barWidth` / `search.barHeight` |
| 搜索输入框宽度/高度 | `Config.lua` → `search.boxWidth` / `search.boxHeight` |
| 搜索结果边框、背景内缩和垂直间距 | `Config.lua` → `search.resultFrameInset` / `resultBackdropInset` / `resultGap` |
| 面板宽度/高度 | `Config.lua` → `panel.layout` / `GetPanelLayout()` / `panel.height` |
| 地点按钮大小 | `Config.lua` → `location.baseWidth` / `location.baseHeight` |
| 主面板木牌水平间距 | `Config.lua` → `location.horizontalGap` |
| 主面板目标列数/内容边距/滚动条预留 | `Config.lua` → `panel.layout` |
| 主面板滚动条水平偏移 | `Config.lua` → `panel.layout.scrollbarOffsetX` |
| 主面板顶部高度与内容间距 | `Config.lua` → `panel.layout.headerHeight` / `contentTopGap` |
| 主面板功能按钮 Atlas、尺寸和边距 | `Config.lua` → `panel.controls` |
| 地点木牌背景 Atlas | `Config.lua` → `art.locationSign` |
| 地点图标（列表中） | `Config.lua` → `categories[*].atlas` |
| 当前地图搜索图标 | `Config.lua` → `art.searchIcon` |
| 全图搜索图标 | `Config.lua` → `art.searchAllMapsIcon` |
| 搜索结果图标边框及扩展 | `Config.lua` → `art.searchResultIconFrame` / `searchResultIconFrameExpand` |
| 颜色（文字/边框/背景） | `Config.lua` → `colors.*` |
| 面板底图 Atlas | `Config.lua` → `panel.backgroundAtlas` |
| 数量限制：地点名最大输入字符/显示宽度 | `Config.lua` → `location.maxNameLength` / `maxNameWidth` |
| 缩放范围 | `Config.lua` → `location.minScale` / `maxScale` / `scaleStep` |

### 功能行为

| 想修改什么 | 在哪里改 |
|---|---|
| 搜索结果最大条数 | `Config.lua` → `search.maxResults` |
| 常用地点最大显示数 | `Config.lua` → `location.maxFrequent` |
| 导出分页可选数量与默认值 | `Config.lua` → `export.batchSizes/defaultBatchSize` |
| 默认类别 | `Config.lua` → `defaultCategoryKey` |
| 类别列表（名称/图标/顺序） | `Config.lua` → `categories[...]` |
| 编辑器中列表顺序 | `Config.lua` → `categories[...]`（遍历顺序即为显示顺序） |
| 新增/修改面板布局 | `UI/LocationEditor.lua` → `Editor:Create()` |
| 搜索框布局 | `UI/SearchBar.lua` → `SearchBar:Create()` + `ApplyArt()` |
| 搜索结果列表 | `UI/SearchResults.lua` |
| 主面板开关、外部点击与搜索结果生命周期 | `UI/PanelController.lua` |
| 弹窗显示与下拉菜单生命周期 | `UI/ModalManager.lua` |
| 主面板显示设置 | `UI/PanelSettings.lua` |
| 搜索栏位置 | `UI/SearchBarPosition.lua` |
| 快捷键录入 | `UI/ShortcutController.lua` |
| 使用说明框 | `UI/HelpDialog.lua` |

### 语言 / 本地化

| 想修改什么 | 在哪里改 |
|---|---|
| 中文字符串 | `Locales/zhCN.lua`（直接改键值） |
| 英文字符串 | `Locales/enUS.lua`（同上） |
| 非中文客户端默认语言 | `Locales/enUS.lua`（默认表） |
| 在地图搜索中出现的「地图」后缀 | `Locales/zhCN.lua` → `MAP_PORTAL_SUFFIX` |

### 核心逻辑

| 想修改什么 | 在哪里改 |
|---|---|
| 地点搜索算法 | `Core/SearchService.lua` → `Search:GetScore()` |
| 数据库初始化 / 存档字段 | `Core/Database.lua` → `DB:Initialize()` |
| 设置字段验证规则 | `Core/SettingsSchema.lua` |
| 地点数据操作（增删改查） | `Core/LocationStore.lua` → `Store:*()` |
| 导入导出编码 | `Core/ShareCodec.lua` → `Codec:Encode()` / `Decode()` |
| HandyNotes_MapNotes 读取与缓存 | `Core/HandyNotesProvider.lua` |
| 当前地图上下文快照 | `Core/MapContextService.lua` |
| 地图标记绘制 | `Core/MapPinProvider.lua` |
| 地图标记池兼容边界 | `Core/MapPinPoolAdapter.lua` |
| 定位后的临时高亮样式与时长 | `Config.lua` → `mapPins.targetHighlight` |
| 地图显示/隐藏与 Alt 单击 | `Core/WorldMapController.lua` |
| 设置读写 | `Core/SettingsService.lua` |
| 刷新请求合并 | `Core/RefreshCoordinator.lua` / `Core/App.lua` |
| 导入与重复过滤 | `Core/ImportService.lua` |
| 地点结构和验证 | `Core/LocationModel.lua` |
| 添加 / 编辑对话框 | `UI/LocationEditor.lua` |

---

导出的 `SMK|` 使用稳定类别 ID；项目尚未投产，不维护旧前缀兼容。

地图标记只显示 `mapID` 与当前地图完全一致的地点，不自动投影子地图地点到大陆地图。
主面板可分别控制是否显示地图标记及标记上方的地点名称，并可设置名称颜色和字体大小。
坐标搜索结果仅调用游戏原生路径点，不写入地点或使用次数。
地点和设置保存在账号级 `SearchMakerDB` 中；进行批量修改前建议先导出备份。

## 开发验证

核心服务测试及 TOC/XML/Lua 静态检查位于 `Tests/`，运行：

```sh
Tests/run.sh
```

相同检查也会由 `.github/workflows/test.yml` 在 GitHub push 和 pull request 时执行。

将源码同步到本机正式服插件目录：

```sh
./sync_to_wow.sh
```
