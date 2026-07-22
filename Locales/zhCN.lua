local _, SMK = ...

if SMK.locale ~= "zhCN" then return end

local translations = {
    SEARCH_CURRENT_MAP = "搜索 %s",
    SEARCH_ALL_MAPS = "搜索 宇宙",
    SHARE = "导出/导入",
    ADD = "新增",
    BULK_DELETE = "批量删除",
    SHORTCUT = "呼出快捷键",
    CAPTURE_SHORTCUT = "请按快捷键",
    MOVE_HINT = "按住 shift 可以移动",
    MOVE_HINT_SHORTCUT = "按住 shift 可以移动，按 %s 键呼出和关闭",
    NO_MATCH = "无匹配地点",
    NO_LOCATIONS = "当前地图没有维护地点",
    FREQUENT = "常用",
    NO_FREQUENT = "暂无使用记录",
    LOCATION_COUNT = "坐标数量：%d/%d",
    SHOW_MAP_PINS = "显示地图标记",
    SHOW_MAP_PIN_NAMES = "显示标记名称",
    PIN_TEXT_COLOR = "标记文字颜色",
    PIN_TEXT_SIZE = "标记文字大小",
    PIN_TEXTURE_LABEL = "标记材质",
    LOCATION_SCALE = "地点缩放",

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
    X_LABEL = "X坐标",
    Y_LABEL = "Y坐标",
    CATEGORY_LABEL = "类别",
    READ_COORDINATES = "读取当前坐标",
    SAVE = "保存",
    DELETE = "删除",
    CANCEL = "取消",
    EDIT_TITLE = "修改地点",
    ADD_TITLE = "添加地点",
    MAP_FORMAT = "%s（地图 ID：%d）",
    ERROR_NO_MAP_ID = "无法取得当前地图 ID。",
    ERROR_INVALID_COORDINATES = "X、Y 坐标必须是 0 到 100 之间的数字。",
    ERROR_EMPTY_NAME = "请输入地点名字。",
    ERROR_NAME_TOO_LONG = "地点名字最多支持 10 个汉字或 20 个英文字母。",

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
    
    CHAT_IMPORT = "密语导入",
    CHAT_IMPORT_NONE = "未在聊天记录中发现 SMK 编码。",
    CHAT_IMPORT_ALL_DUPLICATES = "聊天中发现 SMK 编码，但都已存在。",
    CHAT_IMPORT_TRUNCATED = "（部分坐标记录不完整，已跳过。）",
    CHAT_IMPORT_SUCCESS = "从聊天中成功导入 %d 个地点。",
    SHARE_TITLE = "导入 / 导出",
    EXPORT_CURRENT_ONLY = "只导出当前地图",
        EXPORT_RANGE = "导出范围",
    EXPORT_RANGE_SUCCESS = "已生成 %d 个地点（第%d-%d条）。按 Ctrl+C 复制。",
    EXPORT_SUCCESS = "已生成 %d 个地点，按 Ctrl+C 复制。",
    EXPORT_BUTTON = "生成导出文本",
    IMPORT_BUTTON = "导入粘贴文本",
    CLOSE = "关闭",
    IMPORT_RESULT = "已导入 %d 个，跳过重复 %d 个，无效 %d 个。",
    EXPORT_NO_LOCATIONS = "该地图没有可导出的地点。",
    EXPORT_NO_LOCATIONS_ALL = "没有可导出的地点。",
    IMPORT_INVALID_FORMAT = "文本格式无效：缺少 SMK 版本标记。",
    IMPORT_NEWER_FORMAT = "该共享文本使用了尚不支持的格式版本 %d。",
    IMPORT_EMPTY = "文本中没有可导入的地点。",
    DATABASE_READ_ONLY = "存档版本 %d 高于当前支持的版本 %d，SearchMaker 已进入只读模式以保护数据。",

    -- Widgets tooltip
    TOOLTIP_USAGE_COUNT = "使用次数：%d",
    TOOLTIP_XY = "X：%.2f  ·  Y：%.2f",
    ERROR_COORDS_READ_FAILED = "当前地图无法读取角色坐标。",
    SAVE_FAILED = "保存失败。",
    ENTER_VALID_MAP_ID = "请输入有效的整数地图 ID。",
    NO_LOCATIONS_TO_DELETE = "没有找到可删除的地点。",

    -- Widgets tooltip
    TOOLTIP_INSTRUCTIONS = "左键标记  ·  右键修改  ·  Shift+右键删除",

    -- SearchBar
    KEY_ALREADY_BOUND = "%s 已被“%s”占用，请选择其他按键。",
    KEY_BIND_FAILED = "快捷键保存失败，请稍后重试。",
    KEY_BIND_UPDATED = "呼出快捷键已修改为 %s。",
    KEY_BIND_IN_COMBAT = "战斗中不能修改快捷键。",
    SHORTCUT_TOOLTIP_TITLE = "呼出搜索框快捷键",
    SHORTCUT_TOOLTIP_CURRENT = "当前：%s",
    SHORTCUT_TOOLTIP_HINT = "点击后按下新的组合键。",
    SEARCH_RESULT_FORMAT = "%s：%s",
            MAP_PORTAL_SUFFIX = " [地图]",
    OPEN_MAP = "点击打开地图",
    NO_KEY_BOUND = "未设置",

    -- FindDuplicate
    DUPLICATE_NAME = "此地图已有同名地点：%s",
    -- Categories
    CAT_DELVES = "地下堡",
    CAT_DUNGEONS = "地下城",
    CAT_RAIDS = "团队副本",
    CAT_TELEPORT = "传送点",
    CAT_FLIGHT = "飞行点",
    CAT_PROFESSIONS = "专业",
    CAT_NPC = "NPC",
    CAT_OTHER = "其他",

}

for key, value in pairs(translations) do
    SMK.L[key] = value
end
