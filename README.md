# SearchMaker

SearchMaker 是一个适用于《魔兽世界》正式服的轻量地图搜索与地点管理插件，支持
`enUS` 和 `zhCN`。它使用游戏原生路径点定位地点，并可在世界地图上显示自定义标记。

主要功能：

- 搜索当前地图或全部已保存地点，并可搜索地图名称。
- 保存、分组、修改、删除地点，可为单个地点选择自定义图标，并记录常用地点。
- 为地点保存备注，并在鼠标提示中使用可配置的绿色显示。
- 显示自定义地图标记、名称、颜色、大小和定位高亮。
- 识别坐标输入并直接创建游戏原生路径点。
- 使用 `SMK|` 文本导入、导出和备份地点，写入前显示导入预览。
- 将自建或外部地点加入路线队列，保存、搜索、分享和重复激活路线。
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
| 直接输入 X/Y 坐标 | ✅ | ⚠️ | — | — | 支持空格、英文逗号或中文逗号分隔；右键可复制、加入路线或添加临时标记；全图模式下仍使用当前上下文地图 |
| 搜索结果上限与排序 | ✅ | ✅ | ✅ | ✅ | 最多显示 20 条；按相关度、名称、地图名称、地图 ID 和坐标稳定排序 |
| 地图范围 | 当前浏览地图或角色当前地图 | 全部自建地点 | 仅 `mapID` 完全相同的地图 | 仅当前地图 | 不会把子地图地点自动投影到大陆或上层地图 |
| 原生路径点定位 | ✅ | ✅ | ✅ | ✅ | 坐标输入、自建地点和外部地点均使用游戏原生路径点；不支持路径点的地图会拒绝定位 |
| 定位高亮动画 | ⚠️ | ⚠️ | ✅ | ✅ | 仅在世界地图正显示目标地图时播放约 3 秒高亮；搜索结果悬停只显示动画，不显示额外标记 |
| 持久化地图标记 | ✅ | ⚠️ | ✅ | — | 只为自建地点创建；全图结果需切到其地图后显示，是否显示由地点自身选项控制 |
| 地点名称、颜色与材质 | ✅ | ✅ | ✅ | — | 自建地点可设置名称显示、单独文字颜色、标记材质和自定义列表图标 |
| 添加、修改和删除 | ✅ | ✅ | ✅ | — | 自建地点可完整管理；地图标记可打开修改面板，坐标允许编辑 |
| 外部地点收藏 | ✅ | — | — | ✅ | 右键“收藏坐标”默认保存到 `HandyNotes_MapNotes` 分组；收藏后成为普通自建地点 |
| 统一右键菜单 | ✅ | ✅ | ✅ | ✅ | 搜索结果、主面板地点和地图标记共用菜单；外部地点与自建地点显示各自可用操作 |
| 地点备注 | ✅ | ✅ | ✅ | — | 备注不参与搜索或重复判定；在地点和地图标记提示中以配置的绿色显示 |
| 路线规划 | ✅ | ✅ | ✅ | ✅ | 手动队列支持调整顺序、同地图最近距离自动排序、定位、完成并下一个和临时标记；路线定义可保存、导入、分享，当前执行状态只在本次会话有效 |
| 保存路线搜索 | ✅ | ✅ | — | — | 输入完整连续关键字“路线”显示最多 20 条；可继续输入路线名称筛选，单独“路”或“线”不触发 |
| 常用地点统计 | ✅ | ✅ | ✅ | — | 仅拥有内部地点 ID 的自建地点记录使用次数；临时坐标、地图结果和外部地点不记录 |
| 主面板展示 | ✅ | — | ✅ | — | 主面板只展示当前地图的自建地点，不直接列出外部来源地点 |
| 导入、导出与备份 | ✅ | ✅ | ✅ | — | 导入先预览新增、重复和无效数量；每批导出支持 20、50、100、200 条，格式统一为 `SMK|` |
| 数据持久化 | ✅ | ✅ | ✅ | — | 自建地点、保存路线、备注、设置和使用次数保存在账号级 `SearchMakerDB`；当前执行路线和外部缓存不写入存档 |
| 国际化 | ✅ | ✅ | ✅ | ⚠️ | UI 支持 `enUS`、`zhCN`；其他语言回退英文，外部文本由来源插件和客户端语言决定 |
| 第三方依赖 | ✅ | — | — | ⚠️ | 核心功能无第三方依赖；外部地点需要同时启用 `HandyNotes` 与 `HandyNotes_MapNotes` |

## 快捷键

- `Ctrl + Space`：呼出 / 隐藏搜索框（默认按键，可在“搜索设置”中修改）
- `Tab`：切换「当前地图」/「全图搜索」模式
- `Alt + 左键（世界地图上）`：在鼠标位置添加地点
- `右键搜索框`：打开地点主面板
- `中键搜索框`：打开 / 关闭世界地图
- 在搜索框输入 `12 34`、`12,34` 或 `12.3 34.56`：左键在当前地图定位，右键可复制、加入路线或添加临时标记
- `左键单击地图标记`：修改或删除该地点（坐标可编辑）
- `左键单击地点`：定位成功后在目标坐标显示约 3 秒的高亮提示
- `鼠标悬停地图标记`：查看地点名称和坐标
- `右键地点或地图标记`：打开复制、分享、修改、删除和加入路线等统一功能菜单
- 世界地图未打开时，右键自建地点搜索结果可直接打开对应地图并闪烁目标位置
- 在搜索框输入完整关键字“路线”：列出已保存路线；右键可打开、激活、分享或删除
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
- 主面板左上角的地点筛选可按分组，或只显示带地图标记、带备注、自定义图标的地点；
  筛选只影响当前面板和常用地点，不影响搜索、地图标记或存档。
- 新增或修改地点时，可勾选“自定义图标”并从 Atlas、完整材质路径两类图标中选择；
  不勾选时继续使用当前分组和现有回退图标。
- “备注”是地点的可选持久化字段，不参与搜索和重复判定；鼠标提示中使用
  `Config.colors.note` 的绿色显示。
- 勾选“显示标记材质”后，点击右侧当前材质图标可弹出独立的地图标记材质选择面板。
- 地点名称默认使用金色；勾选“单独设置文字颜色”的地点会保存自己的颜色。
- “导出/导入”：备份、分享或导入地点；“从密语导入”读取本次登录或 `/reload` 后通过
  角色/战网密语收发的 `SMK|` 文本，不扫描其他频道；所有导入均先预览再确认写入。
- “路线规划”：位于地点比例调整左侧。为当前队列输入名称后可保存，保存路线可通过
  `SMK|R|` 字符串分享和导入；搜索“路线”可重新打开或激活。“自动排序”只调整连续
  的同地图地点，角色所在地图从角色坐标开始，其他地图保留区段首个地点，不跨地图重排。
- “更多”：批量删除地点或查看使用说明。
- 路线中的每个地点可添加特殊临时标记。临时标记不进入地图标记材质池，不写入存档，
  清空或移除路线时仍保留，`/reload` 或退出游戏后消失；已有正式标记不会被覆盖或清除。
- “搜索设置”：调整搜索框缩放、透明度和快捷键。
- “标记设置”：调整地图标记材质大小、文字大小及水平/垂直偏移；是否显示材质和文字由
  每个地点新增/修改面板中的选项单独决定。
- 点击地图上的自建标记材质或地点名称可直接修改，二者悬停时均显示地点提示；面板会根据
  点位到地图左右边缘的空间自动避让。
- HandyNotes_MapNotes 搜索结果可通过统一右键菜单收藏，默认保存到同名分组。该分组使用
  `Interface/AddOns/HandyNotes_MapNotes/Images/MNL4.blp`，插件未加载时回退到“其他”图标。

## 导出 / 导入编码格式

当前导出格式统一使用 `SMK|` 前缀，坐标采用整数编码（×100），两个标记显示开关合并
为一个标志位，单地点颜色使用六位 RGB，类别、自定义图标和地图标记材质均使用稳定
数字 ID。自定义图标 ID 为正数时表示 Atlas，为负数时表示完整材质路径；地图标记材质
使用独立 `PinTextures.lua` 中的正数索引，备注作为经过转义的末尾字段。未启用自定义图标时不保存图标 ID。导入只
接受当前 `SMK|` 记录，旧项目前缀和旧字段结构不会被识别。

路线分享使用独立的 `SMK|R|` 类型标记，仅包含路线名称，以及每个点的地图 ID、名称和
X/Y 坐标，不包含地点 ID、分组、备注、图标或地图标记设置。保存的路线定义写入存档；
激活后的执行位置和完成进度只保存在内存中，退出游戏或 `/reload` 后清除。

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
| 面板滚动条右侧贴边位置 | `Config.lua` → `panel.layout.scrollFrameRightInset` |
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
| 全部面板背景内缩 | `Config.lua` → `panel.backgroundInset` / Backdrop `insets` |
| 全部插件面板边框 | `Config.lua` → `resultBackdrop` / `panelBackdrop`（`UI-Tooltip-Border`） |
| 数量限制：地点名最大输入字符/显示宽度 | `Config.lua` → `location.maxNameLength` / `maxNameWidth` |
| 备注长度和鼠标提示颜色 | `Config.lua` → `location.maxNoteLength/maxNoteWidth` / `colors.note` |
| 缩放范围 | `Config.lua` → `location.minScale` / `maxScale` / `scaleStep` |

### 功能行为

| 想修改什么 | 在哪里改 |
|---|---|
| 搜索结果最大条数 | `Config.lua` → `search.maxResults` |
| 路线名称限制和搜索图标路径 | `Config.lua` → `route.maxNameWidth` / `route.searchIcon` |
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
| 地点导入导出编码 | `Core/ShareCodec.lua` → `Codec:Encode()` / `Decode()` |
| 路线持久化与分享编码 | `Core/RouteStore.lua` / `Core/RouteCodec.lua` |
| HandyNotes_MapNotes 读取与缓存 | `Core/HandyNotesProvider.lua` |
| 当前地图上下文快照 | `Core/MapContextService.lua` |
| 地图标记绘制 | `Core/MapPinProvider.lua` |
| 地图标记池兼容边界 | `Core/MapPinPoolAdapter.lua` |
| 定位后的临时高亮样式与时长 | `Config.lua` → `mapPins.targetHighlight` |
| 路线临时标记材质与大小 | `Config.lua` → `mapPins.routeTemporary` |
| 地图显示/隐藏与 Alt 单击 | `Core/WorldMapController.lua` |
| 设置读写 | `Core/SettingsService.lua` |
| 刷新请求合并 | `Core/RefreshCoordinator.lua` / `Core/App.lua` |
| 导入与重复过滤 | `Core/ImportService.lua` |
| 当前执行路线（会话级） | `Core/RouteService.lua` |
| 密语 SMK 编码缓存 | `Core/WhisperInbox.lua` |
| 地点结构和验证 | `Core/LocationModel.lua` |
| 自定义图标索引和材质解析 | `Core/AtlasTextures.lua` / `Core/PathTextures.lua` / `Core/IconCatalog.lua` |
| 地图标记材质目录 | `Core/PinTextures.lua` |
| 图标单选网格 | `UI/IconGridPicker.lua` |
| 添加 / 编辑对话框 | `UI/LocationEditor.lua` |
| 统一地点右键菜单 | `UI/LocationContextMenu.lua` |
| 路线、路线导入和地点导入预览框 | `UI/RouteDialog.lua` / `UI/RouteImportDialog.lua` / `UI/ImportPreviewDialog.lua` |

---

导出的 `SMK|` 使用稳定类别 ID；项目尚未投产，不维护旧前缀兼容。

地图标记只显示 `mapID` 与当前地图完全一致的地点，不自动投影子地图地点到大陆地图。
HandyNotes_MapNotes 是按当前地图惰性建立的外部缓存，因此只参与当前地图搜索，不参与
全图搜索。每个地点单独控制是否显示地图标记材质、地点名称和独立文字颜色；标记设置
统一控制材质大小、文字大小及文字偏移，默认文字位于地点坐标中心且偏移为 0。
坐标搜索结果仅调用游戏原生路径点，不写入地点或使用次数。
地点使用数字 ID，地点、备注与使用次数保存在账号级 `SearchMakerDB` 中。地点字段
`note` 是用户备注；材质目录里的 `note` 是国际化提示键，两者用途不同。进行批量修改前建议先导出备份。

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
