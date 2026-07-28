# SearchMaker

SearchMaker 是一个适用于《魔兽世界》正式服的轻量地图搜索与地点管理插件，支持
`enUS` 和 `zhCN`。它使用游戏原生路径点定位地点，并可在世界地图上显示自定义标记。

主要功能：

- 搜索当前地图或全部已保存地点，并可搜索地图名称。
- 保存、分组、修改、删除地点，可为单个地点选择自定义图标，并记录常用地点。
- 显示自定义地图标记、名称、颜色、大小和定位高亮。
- 识别坐标输入并直接创建游戏原生路径点。
- 使用 `SMK|` 文本导入、导出和备份地点。
- 可选读取 `HandyNotes_MapNotes` 的当前地图结果，并收藏到 SearchMaker 分组。

## 安装与依赖

将 `SearchMaker` 文件夹放入正式服的
`World of Warcraft/_retail_/Interface/AddOns/` 目录，然后进入游戏或执行 `/reload`。

插件不依赖第三方库。安装并启用 `HandyNotes` 与 `HandyNotes_MapNotes` 后，会自动提供
当前地图的外部地点搜索；未安装时其余功能不受影响。

## 功能支持与边界

符号说明：✅ 完整支持；⚠️ 有条件支持；— 不适用或不支持。

| 功能维度 | 当前地图搜索 | 全图搜索 | 自建地点 | 外部来源地点 | 功能边界 |
|---|---:|---:|---:|---:|---|
| 名称搜索 | ✅ | ✅ | ✅ | ⚠️ | 自建地点按名称搜索；外部地点仅来自当前地图的 `HandyNotes_MapNotes` 缓存 |
| 地图名称搜索 | ✅ | ✅ | — | — | 两种搜索模式都会查询地图索引；选择结果后打开对应地图，不创建地点 |
| 直接输入 X/Y 坐标 | ✅ | ⚠️ | — | — | 支持空格、英文逗号或中文逗号分隔；全图模式下仍使用当前上下文地图 |
| 搜索结果上限与排序 | ✅ | ✅ | ✅ | ✅ | 最多显示 20 条；按相关度、名称、地图名称、地图 ID 和坐标稳定排序 |
| 地图范围 | 当前浏览地图或角色当前地图 | 全部自建地点 | 仅 `mapID` 完全相同的地图 | 仅当前地图 | 不会把子地图地点自动投影到大陆或上层地图 |
| 原生路径点定位 | ✅ | ✅ | ✅ | ✅ | 坐标输入、自建地点和外部地点均使用游戏原生路径点；不支持路径点的地图会拒绝定位 |
| 定位高亮动画 | ⚠️ | ⚠️ | ✅ | ✅ | 仅在世界地图正显示目标地图时播放约 3 秒高亮；搜索结果悬停只显示动画，不显示额外标记 |
| 持久化地图标记 | ✅ | ⚠️ | ✅ | — | 只为自建地点创建；全图结果需切到其地图后显示，同时受全局设置和地点自身开关控制 |
| 地点名称、颜色与材质 | ✅ | ✅ | ✅ | — | 自建地点可设置名称显示、单独文字颜色、标记材质和自定义列表图标 |
| 添加、修改和删除 | ✅ | ✅ | ✅ | — | 自建地点可完整管理；地图标记可打开修改面板，坐标允许编辑 |
| 外部地点收藏 | ✅ | — | — | ✅ | 可右键收藏到动态分组；收藏后成为普通自建地点，后续可编辑、标记和分享 |
| 常用地点统计 | ✅ | ✅ | ✅ | — | 仅拥有内部地点 ID 的自建地点记录使用次数；临时坐标、地图结果和外部地点不记录 |
| 主面板展示 | ✅ | — | ✅ | — | 主面板只展示当前地图的自建地点，不直接列出外部来源地点 |
| 导入、导出与备份 | ✅ | ✅ | ✅ | — | 可导出当前地图或全部自建地点；每批支持 20、50、100、200 条，格式统一为 `SMK|` |
| 数据持久化 | ✅ | ✅ | ✅ | — | 自建地点、设置和使用次数保存在账号级 `SearchMakerDB`；外部缓存不写入存档 |
| 国际化 | ✅ | ✅ | ✅ | ⚠️ | UI 支持 `enUS`、`zhCN`；其他语言回退英文，外部文本由来源插件和客户端语言决定 |
| 第三方依赖 | ✅ | — | — | ⚠️ | 核心功能无第三方依赖；外部地点需要同时启用 `HandyNotes` 与 `HandyNotes_MapNotes` |

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
- “读取角色坐标”仅在编辑器目标地图与角色当前地图 ID 相同时可用。
- 主面板地点与常用地点的木牌左侧显示分组图标或该地点的自定义图标，并使用与搜索结果
  一致的图标边框。
- 新增或修改地点时，可勾选“自定义图标”并从 Atlas、完整材质路径两类图标中选择；
  不勾选时继续使用当前分组和现有回退图标。
- 勾选“显示标记材质”后，点击右侧当前材质图标可弹出独立的地图标记材质选择面板。
- 地点名称默认使用“标记设置”中的全局颜色；只有勾选“单独设置文字颜色”的地点才保存
  自己的颜色。
- “导出/导入”：备份、分享或导入地点；“从密语导入”读取本次登录或 `/reload` 后通过
  角色/战网密语收发的 `SMK|` 文本，并在文本框中显示原文和完整导入统计，不扫描其他频道。
- “更多”：批量删除地点或查看使用说明。
- “搜索设置”：调整搜索框缩放、透明度和快捷键。
- “标记设置”：调整地图标记图标与名称的显示、尺寸、颜色和偏移。
- 点击地图上的自建标记可直接修改；面板会根据点位到地图左右边缘的空间自动避让。
- HandyNotes_MapNotes 搜索结果可右键收藏，并动态选择目标分组。

## 导出 / 导入编码格式

当前导出格式统一使用 `SMK|` 前缀，坐标采用整数编码（×100），两个标记显示开关合并
为一个标志位，单地点颜色使用六位 RGB，类别、自定义图标和地图标记材质均使用稳定
数字 ID。自定义图标 ID 为正数时表示 Atlas，为负数时表示完整材质路径；地图标记材质
使用独立 `PinTextures.lua` 中的正数索引。未启用自定义图标时不保存图标 ID。导入只
接受当前 `SMK|` 记录，旧项目前缀和旧字段结构不会被识别。

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
| 地点分组图标（列表中） | `Config.lua` → `categories[*].atlas` |
| 可选 Atlas 自定义图标 | `Core/AtlasTextures.lua` |
| 可选完整路径自定义图标 | `Core/PathTextures.lua` |
| 地图标记材质 | `Core/PinTextures.lua` |
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
| 新增/修改面板布局 | `Config.lua` → `locationEditor` / `GetLocationEditorLayout()` |
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
| 密语 SMK 编码缓存 | `Core/WhisperInbox.lua` |
| 地点结构和验证 | `Core/LocationModel.lua` |
| 自定义图标索引和材质解析 | `Core/AtlasTextures.lua` / `Core/PathTextures.lua` / `Core/IconCatalog.lua` |
| 地图标记材质目录 | `Core/PinTextures.lua` |
| 图标单选网格 | `UI/IconGridPicker.lua` |
| 添加 / 编辑对话框 | `UI/LocationEditor.lua` |

---

导出的 `SMK|` 使用稳定类别 ID；项目尚未投产，不维护旧前缀兼容。

地图标记只显示 `mapID` 与当前地图完全一致的地点，不自动投影子地图地点到大陆地图。
HandyNotes_MapNotes 是按当前地图惰性建立的外部缓存，因此只参与当前地图搜索，不参与
全图搜索。主面板可分别控制是否显示地图标记及标记上方的地点名称，并可设置名称颜色
和字体大小。
坐标搜索结果仅调用游戏原生路径点，不写入地点或使用次数。
地点使用数字 ID，地点与使用次数保存在账号级 `SearchMakerDB` 中；材质目录里的
`note` 会按当前语言显示为图标的鼠标提示，但不会写入地点数据。进行批量修改前建议先导出备份。

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
