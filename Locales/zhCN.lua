local _, SMK = ...

if SMK.locale ~= "zhCN" then return end

local translations = {
    SEARCH_BAR_SETTINGS = "搜索设置",
    SEARCH_BAR_SCALE = "搜索框缩放",
    SEARCH_BAR_OPACITY = "搜索框透明度",
    SHORTCUT_KEY = "呼出快捷键",
    EXTERNAL_SOURCE = "外部来源",
    SEARCH_CURRENT_MAP = "搜索 %s",
    SEARCH_ALL_MAPS = "搜索 所有地图",
    SHARE = "导出/导入",
    ADD = "新增坐标",
    SETTINGS = "标记设置",
    DISPLAY_SETTINGS = "显示设置",
    MORE = "更多",
    HELP = "使用说明",
    BULK_DELETE = "批量删除",
    ROUTE_TITLE = "路线规划",
    SHORTCUT = "呼出快捷键",
    CAPTURE_SHORTCUT = "请按快捷键",
    MOVE_HINT = "按住 shift 可以移动",
    MOVE_HINT_SHORTCUT = "按住 shift 可以移动，按 %s 键呼出和关闭",
    NO_MATCH = "无匹配地点",
    NO_LOCATIONS = "当前地图没有维护地点",
    FREQUENT = "常用",
    NO_FREQUENT = "暂无使用记录",
    LOCATION_COUNT = "坐标数量：%d/%d",
    SHOW_PIN_TEXTURES = "显示标记材质",
    PIN_TEXT_COLOR = "显示标记文字",
    MAP_PIN_SETTINGS_LABEL = "地图标记设置：",
    PIN_TEXT_SIZE = "标记文字大小",
    CUSTOM_PIN_COLOR = "显示标记文字颜色",
    CUSTOM_ICON = "自定义图标",
    CUSTOM_ICON_ATLAS = "Atlas 材质",
    CUSTOM_ICON_PATH = "路径材质",
    ICON_NOTES = {
        alliance = "联盟",
        horde = "部落",
        great_vault = "宝库",
        horde_icon = "部落图标",
        alliance_icon = "联盟图标",
        bank = "银行",
        auction_house = "拍卖",
        mailbox = "邮箱",
        innkeeper = "旅店",
        flight_master = "飞行管理员",
        stable_master = "兽栏管理员",
        barber = "理发师",
        transmogrifier = "幻化师",
        trading_post = "商栈",
        merchant = "商人",
        class_trainer = "职业训练师",
        profession_trainer = "专业训练师",
        other = "其他",
        crafting_orders = "订单",
        timewalking_vendor = "漫游商人",
        item_upgrade = "物品升级",
        alliance_portal = "联盟传送门",
        horde_portal = "部落传送门",
        chromie = "克罗米",
        alliance_portal_alt = "联盟传送门2",
        horde_portal_alt = "部落传送门2",
        quest = "任务",
        alliance_pvp = "联盟PVP",
        horde_pvp = "部落PVP",
        coordinate_selected = "坐标选中",
        coordinate_unselected = "坐标未选中",
        class = "职业",
        profession = "专业",
        raid = "团队副本",
        dungeon = "地下城",
        delve = "地下堡",
        rare_creature = "稀有怪物",
        treasure = "宝箱",
        portal = "传送门",
        teleport_beacon = "传送道标",
        cave_entrance = "山洞进",
        cave_exit = "山洞出",
        alchemy = "炼金",
        blacksmithing = "锻造",
        cooking = "烹饪",
        enchanting = "附魔",
        engineering = "工程",
        fishing = "钓鱼",
        herbalism = "草药",
        inscription = "铭文",
        jewelcrafting = "珠宝",
        leatherworking = "皮革",
        mining = "采矿",
        skinning = "剥皮",
        tailoring = "裁缝",
        archaeology = "考古",
        mount = "马",
    },
    PIN_NAME_OFFSET_X = "名称水平偏移",
    PIN_NAME_OFFSET_Y = "名称垂直偏移",
    PIN_TEXTURE_SIZE = "标记材质大小",
    LOCATION_SCALE = "地点缩放",
    HELP_TITLE = "SearchMaker 使用说明",
    HELP_TEXT = [[
 快捷键 ctrl+空格呼出搜索框（支持更改快捷键），搜索框锚定位置分打开和关闭世界地图时两类，可按 shift点搜索框移动位置。右键点击搜索框打开插件面板，鼠标中键点击搜索框打开世界地图，该插件主要功能支持坐标自定义增删改查，坐标输入智能检测，图钉功能对地图打标记，地图区域和副本地图搜索跳转，当前地图`HandyNotes_MapNotes`插件坐标定位。

|cffffd100坐标新增，地图标记|r
• 点击插件面板中的新增按钮。
• 在任意支持标记的地图上，alt+左键点击地图进行标记，标记支持常显材质、文字，支持调整标记大小和文字颜色。
• 搜索结果中外部来源坐标，右键收藏。
• 从私聊接收的分享消息中导入。
• 地点备注会以绿色显示在鼠标提示中；导入前会先预览新增、重复和无效地点。
• 搜索结果、主面板地点和地图标记统一使用右键功能菜单；外部地点默认收藏到“HandyNotes_MapNotes”。
• 可将多个地点加入路线，按顺序定位，并使用“完成并下一个”继续。
• 路线地点可添加本次运行有效的临时标记；已有正式标记不会被覆盖或清除。

|cffffd100坐标查询及定位，地图区域和副本地图定位，坐标输入智能匹配|r
• 搜索当前地图时，搜索范围是已经新增、标记、收藏和导入过的当前地图坐标，和来自外部来源如`HandyNotes_MapNotes`插件在地图上标记的坐标。
• 搜索所有地图时，搜索范围是所有地图已收录的坐标。但不包括外部来源坐标。
• 打开世界地图时，当前地图和全图搜索，都支持搜索地图区域，且地图和坐标结果都支持点击跳转到对应地图。
• 不打开世界地图时，地图区域结果支持直接自动打开世界地图并跳转，坐标结果仅标记，不会打开世界地图。
• 当搜索框输入 22 22，或 22,22 等符合坐标格式的数据时，会自动识别并展示结果；左键定位，右键可复制、加入路线或添加临时标记。

|cffffd100坐标修改|r
• 右键点击搜索结果、插件主面板坐标或地图标记，在统一功能菜单中选择“修改坐标”。
• 外部来源`HandyNotes_MapNotes`坐标不支持直接修改，可先收藏为自建坐标。

|cffffd100坐标删除|r
• 右键点击自建坐标，在统一功能菜单中选择“删除坐标”。
• 外部来源`HandyNotes_MapNotes`坐标不写入本插件，因此不提供删除。

]],

    -- Namespace
    BINDING_HEADER = "SearchMaker",
    BINDING_NAME = "呼出搜索框",
    PREFIX = "SearchMaker：",
    LOAD_WORLD_MAP_FAILED = "无法加载世界地图组件：%s",
    UNKNOWN_REASON = "未知原因",
    ERROR_NO_CLIENT_SUPPORT = "当前客户端不支持内置地图标记。",
    ERROR_MAP_NOT_SUPPORTED = "当前地图不支持内置路径点。",
    ERROR_MAP_PINS_UNAVAILABLE = "当前客户端无法加载地图标记。",

    -- MapService
    UNKNOWN_MAP = "未知地图",
    MAP_FALLBACK = "地图 %s",

    -- App chat messages
    ADD_SUCCESS = "已新增 %s（%.2f, %.2f）。",
    EDIT_SUCCESS = "已修改 %s（%.2f, %.2f）。",
    EDIT_NOT_FOUND = "原始地点已不存在，请重新打开修改窗口。",
    DELETE_SUCCESS = "已删除 %s（%.2f, %.2f）。",
    DELETE_INVALID = "删除信息无效，未执行删除。",
    DELETE_UNKNOWN_SOURCE = "无法识别该地点的来源，未执行删除。",

    -- LocationEditor
    NAME_LABEL = "名字",
    NOTE_LABEL = "备注",
    X_LABEL = "X坐标",
    Y_LABEL = "Y坐标",
    CATEGORY_LABEL = "类别",
    READ_COORDINATES = "读取角色坐标",
    SAVE = "保存",
    DELETE = "删除",
    CANCEL = "取消",
    EDIT_TITLE = "修改地点",
    ADD_TITLE = "添加地点",
    MAP_FORMAT = "%s（地图 ID：%d）",
    ERROR_NO_MAP_ID = "无法取得当前地图 ID。",
    ERROR_INVALID_COORDINATES = "X、Y 坐标必须是 0 到 100 之间的数字。",
    ERROR_INVALID_SETTING = "该设置值无效。",
    ERROR_EMPTY_NAME = "请输入地点名字。",
    ERROR_NAME_TOO_LONG = "地点名字过长，最多支持 10 个宽字符或 20 个窄字符。",
    ERROR_NOTE_TOO_LONG = "备注过长，最多支持 60 个宽字符或 120 个窄字符。",

    -- BulkDeleteDialog
    BULK_DELETE_TITLE = "批量删除",
    DELETE_BY_CATEGORY = "按类别",
    DELETE_CATEGORY_ACTION = "删除该类别",
    DELETE_BY_MAP_ID = "按地图 ID",
    DELETE_MAP_ACTION = "删除该地图",
    CONFIRM_DELETE_ACTION = "删除",
    CONFIRM_DELETE_FORMAT = "确定删除%s吗？\n将删除 %d 个地点。",
    BULK_DELETE_SUCCESS = "已删除%s，共 %d 个地点。",
    DELETE_CATEGORY_DESC = "类别“%s”的全部地点",
    DELETE_MAP_DESC = "地图 ID %d 的全部地点",

    -- ShareDialog
    CHAT_IMPORT = "从密语导入",
    CHAT_IMPORT_NONE = "本次登录或 /reload 后的密语中没有 SMK 编码。",
    SHARE_TITLE = "导入 / 导出",
    EXPORT_CURRENT_ONLY = "只导出当前地图",
    EXPORT_BATCH_SIZE = "最大单次导出数量",
    EXPORT_RANGE = "导出范围",
    EXPORT_RANGE_SUCCESS = "已生成 %d 个地点（第%d-%d条）。按 Ctrl+C 复制。",
    EXPORT_SUCCESS = "已生成 %d 个地点，按 Ctrl+C 复制。",
    EXPORT_BUTTON = "生成导出文本",
    IMPORT_BUTTON = "导入粘贴文本",
    CLOSE = "关闭",
    IMPORT_RESULT = "已导入 %d 个，跳过重复 %d 个，无效 %d 个。",
    EXPORT_NO_LOCATIONS = "该地图没有可导出的地点。",
    EXPORT_NO_LOCATIONS_ALL = "没有可导出的地点。",
    IMPORT_INVALID_FORMAT = "文本格式无效：缺少 SMK 前缀。",
    IMPORT_EMPTY = "文本中没有可导入的地点。",
    IMPORT_PREVIEW_TITLE = "导入前预览",
    IMPORT_PREVIEW_SUMMARY = "可导入 %d 个 · 重复 %d 个 · 无效 %d 个",
    IMPORT_PREVIEW_NEW = "[新增]",
    IMPORT_PREVIEW_DUPLICATE = "[重复]",
    IMPORT_PREVIEW_MORE = "……另有 %d 个",
    IMPORT_CONFIRM = "确认导入",
    DATABASE_READ_ONLY = "存档版本 %d 高于当前支持的版本 %d，SearchMaker 已进入只读模式以保护数据。",

    -- Widgets tooltip
    TOOLTIP_USAGE_COUNT = "使用次数：%d",
    TOOLTIP_XY = "X：%.2f  ·  Y：%.2f",
    ERROR_COORDS_READ_FAILED = "当前地图无法读取角色坐标。",
    SAVE_FAILED = "保存失败。",
    ENTER_VALID_MAP_ID = "请输入有效的整数地图 ID。",
    NO_LOCATIONS_TO_DELETE = "没有找到可删除的地点。",

    -- Widgets tooltip
    TOOLTIP_INSTRUCTIONS = "左键标记  ·  右键功能菜单",
    TOOLTIP_PIN_INSTRUCTIONS = "左键修改  ·  右键功能菜单",

    -- 地点右键菜单和路线
    MENU_FAVORITE = "收藏坐标",
    MENU_COPY_COORDINATES = "复制坐标",
    MENU_SHARE_COORDINATE = "分享坐标",
    MENU_EDIT_COORDINATE = "修改坐标",
    MENU_DELETE_COORDINATE = "删除坐标",
    MENU_ADD_ROUTE = "加入路线",
    MENU_ADD_TEMP_PIN = "添加临时标记",
    COPY_COORDINATES_TITLE = "复制坐标",
    SHARE_COORDINATE_TITLE = "分享坐标",
    COPY_HINT = "按 Ctrl+C 复制。",
    ROUTE_COUNT = "路线地点：%d/%d",
    ROUTE_EMPTY = "路线中暂无地点。",
    ROUTE_LOCATE = "定位",
    ROUTE_TEMP_PIN = "临时标记",
    ROUTE_TEMP_PIN_ACTIVE = "已临时标记",
    ROUTE_TEMP_PIN_PERSISTENT_STATE = "已有永久标记",
    ROUTE_START = "开始路线",
    ROUTE_COMPLETE_NEXT = "完成并下一个",
    ROUTE_CLEAR = "清空",
    ROUTE_ADDED = "已将 %s 加入路线。",
    ROUTE_DUPLICATE = "该地点已在路线中。",
    ROUTE_FULL = "路线最多支持 %d 个地点。",
    ROUTE_TEMP_PIN_ADDED = "已为 %s 添加临时地图标记。",
    ROUTE_TEMP_PIN_PERSISTENT = "该地点已有正式地图标记，未覆盖或清除。",
    ROUTE_TEMP_PIN_EXISTS = "该地点已有临时地图标记。",

    -- SearchBar
    KEY_ALREADY_BOUND = "%s 已被“%s”占用，请选择其他按键。",
    KEY_BIND_FAILED = "快捷键保存失败，请稍后重试。",
    KEY_BIND_UPDATED = "呼出快捷键已修改为 %s。",
    KEY_BIND_IN_COMBAT = "战斗中不能修改快捷键。",
    SHORTCUT_TOOLTIP_TITLE = "呼出搜索框快捷键",
    SHORTCUT_TOOLTIP_CURRENT = "当前：%s",
    SHORTCUT_TOOLTIP_HINT = "点击后按下新的组合键。",
    SEARCH_RESULT_FORMAT = "%s：%s",
    COORDINATE_RESULT_FORMAT = "坐标：%s，%s",
    MAP_PORTAL_SUFFIX = " [地图]",
    HANDYNOTES_SOURCE_SUFFIX = "[HandyNotes_MapNotes]",
    HANDYNOTES_PORTAL = "传送门",
    OPEN_MAP = "点击打开地图",
    NO_KEY_BOUND = "未设置",

    -- FindDuplicate
    DUPLICATE_NAME = "此地图已有同名地点：%s",
    -- Categories
    CAT_CITY_SERVICES = "主城功能区域",
    CAT_CLASS = "职业",
    CAT_PROFESSION = "专业",
    CAT_RAIDS = "团队副本",
    CAT_DUNGEONS = "地下城",
    CAT_DELVES = "地下堡",
    CAT_RARES = "稀有怪物",
    CAT_TREASURES = "宝箱",
    CAT_PORTALS = "传送门",
    CAT_TELEPORT_BEACONS = "传送道标",
    CAT_MERCHANTS = "商人",
    CAT_NPC = "NPC",
    CAT_HANDYNOTES_MAPNOTES = "HandyNotes_MapNotes",
    CAT_OTHER = "其他",

}

for key, value in pairs(translations) do
    SMK.L[key] = value
end
