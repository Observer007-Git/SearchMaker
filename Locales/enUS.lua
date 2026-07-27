local _, SMK = ...

SMK.L = {
    SEARCH_BAR_SETTINGS = "Search Settings",
    SEARCH_BAR_SCALE = "Search Bar Scale",
    SEARCH_BAR_OPACITY = "Search Bar Opacity",
    SHORTCUT_KEY = "Shortcut Key",
    EXTERNAL_SOURCE = "External Source",
    SEARCH_CURRENT_MAP = "Search %s",
    SEARCH_ALL_MAPS = "Search All Maps",
    SHARE = "Share",
    FAVORITE_TO_FORMAT = "Add to %s",
    ADD = "Add Coordinate",
    SETTINGS = "Pin Settings",
    DISPLAY_SETTINGS = "Display Settings",
    MORE = "More",
    HELP = "How to Use",
    BULK_DELETE = "Bulk Delete",
    SHORTCUT = "Shortcut Key",
    CAPTURE_SHORTCUT = "Press a key...",
    MOVE_HINT = "Hold Shift to move",
    MOVE_HINT_SHORTCUT = "Hold Shift to move. Press %s to toggle.",
    NO_MATCH = "No matching locations",
    NO_LOCATIONS = "No locations on this map",
    FREQUENT = "Frequent",
    NO_FREQUENT = "No usage yet",
    LOCATION_COUNT = "Locations: %d/%d",
    PREFIX = "SearchMaker: ",
    BINDING_HEADER = "SearchMaker",
    BINDING_NAME = "Toggle Search",
    SHOW_PIN_TEXTURES = "Show Pin Textures",
    SHOW_MAP_PIN_NAMES = "Show Pin Names",
    PIN_TEXT_COLOR = "Show Pin Text",
    MAP_PIN_SETTINGS_LABEL = "Map Pin Settings:",
    PIN_TEXT_SIZE = "Pin Text Size",
    PIN_COLOR_LABEL = "Pin Color",
    CUSTOM_PIN_COLOR = "Show Pin Text Color",
    CUSTOM_ICON = "Custom Icon",
    CUSTOM_ICON_ATLAS = "Atlas Texture",
    CUSTOM_ICON_PATH = "Texture Path",
    PIN_NAME_OFFSET_X = "Name Offset X",
    PIN_NAME_OFFSET_Y = "Name Offset Y",
    PIN_TEXTURE_SIZE = "Pin Texture Size",
    LOCATION_SCALE = "Icon Scale",
    HELP_TITLE = "SearchMaker Guide",
    HELP_TEXT = [[
|cffffd100Search and access|r
• Left-click the search box to search, right-click it to open the main panel, and middle-click it to toggle the world map. Hold Shift and drag to move the search box.
• Press Tab to switch between Current Map and All Maps. With the map open, Current Map follows the viewed map; with it closed, it follows your character.
• Search by location name, or enter coordinates such as “45.2, 63.8” to create a native waypoint.

|cffffd100Locations and pins|r
• Alt+Left-click empty map space to add a location. Left-click a saved location to mark it, right-click to edit, or Shift+Right-click to delete.
• In the location editor, enable Custom Icon to override the group icon for that location.
• Pin Settings controls icon/name visibility, color, size, and offset. Search Settings controls the search box and shortcut key.
• HandyNotes_MapNotes results can be marked directly; right-click one to save it to a chosen group.

|cffffd100Sharing and data|r
• Import / Export copies or pastes SMK text. More can scan chat for SMK text or bulk-delete locations.
• Locations and settings are stored account-wide. Export a backup before making large changes.
]],

    -- Namespace
    ERROR_NO_CLIENT_SUPPORT = "Current client does not support built-in map markers.",
    ERROR_MAP_NOT_SUPPORTED = "This map does not support built-in markers.",
    ERROR_MAP_PINS_UNAVAILABLE = "Map pins are unavailable on this client.",
    LOAD_WORLD_MAP_FAILED = "Failed to load world map: %s",
    UNKNOWN_REASON = "Unknown reason",

    -- MapService
    UNKNOWN_MAP = "Unknown Map",
    MAP_FALLBACK = "Map %s",

    -- App chat messages
    ADD_SUCCESS = "Added %s (%.2f, %.2f).",
    EDIT_SUCCESS = "Modified %s (%.2f, %.2f).",
    EDIT_NOT_FOUND = "Original location no longer exists. Please reopen the editor.",
    DELETE_SUCCESS = "Deleted %s (%.2f, %.2f).",
    DELETE_INVALID = "Invalid delete request. No changes made.",
    DELETE_UNKNOWN_SOURCE = "Cannot identify the source. No changes made.",

    -- LocationEditor
    NAME_LABEL = "Name",
    X_LABEL = "X",
    Y_LABEL = "Y",
    CATEGORY_LABEL = "Category",
    READ_COORDINATES = "Get Character Coordinates",
    SAVE = "Save",
    DELETE = "Delete",
    CANCEL = "Cancel",
    EDIT_TITLE = "Edit Location",
    ADD_TITLE = "Add Location",
    MAP_FORMAT = "%s (Map ID: %d)",
    ERROR_NO_MAP_ID = "Cannot determine current map ID.",
    ERROR_INVALID_COORDINATES = "X and Y must be numbers between 0 and 100.",
    ERROR_INVALID_SETTING = "That setting value is invalid.",
    ERROR_EMPTY_NAME = "Please enter a location name.",
    ERROR_NAME_TOO_LONG = "Name supports up to 10 Chinese characters or 20 English letters.",

    -- BulkDeleteDialog
    BULK_DELETE_TITLE = "Bulk Delete",
    DELETE_BY_CATEGORY = "By Category",
    DELETE_CATEGORY_ACTION = "Delete Category",
    DELETE_BY_MAP_ID = "By Map ID",
    DELETE_MAP_ACTION = "Delete Map",
    CONFIRM_DELETE_ACTION = "Delete",
    CONFIRM_DELETE_FORMAT = "Are you sure you want to delete %s?\nThis removes %d locations.",
    BULK_DELETE_SUCCESS = "Deleted %s (%d total).",
    DELETE_CATEGORY_DESC = "all locations in category \"%s\"",
    DELETE_MAP_DESC = "all locations on map %d",

    -- ShareDialog
    CHAT_IMPORT = "Scan Chat",
    CHAT_IMPORT_NONE = "No SMK codes found in chat history.",
    CHAT_IMPORT_ALL_DUPLICATES = "Found SMK codes in chat, but all were duplicates.",
    CHAT_IMPORT_TRUNCATED = "(Some records were incomplete and were skipped.)",
    CHAT_IMPORT_SUCCESS = "Imported %d locations from chat.",
    SHARE_TITLE = "Import / Export",
    EXPORT_CURRENT_ONLY = "Current map only",
    EXPORT_BATCH_SIZE = "Maximum per Export",
    EXPORT_RANGE = "Export range",
    EXPORT_RANGE_SUCCESS = "Generated %d locations (range %d-%d). Press Ctrl+C to copy.",
    EXPORT_SUCCESS = "Generated %d locations. Press Ctrl+C to copy.",
    EXPORT_BUTTON = "Export",
    IMPORT_BUTTON = "Import",
    CLOSE = "Close",
    IMPORT_RESULT = "Imported %d, skipped %d duplicates, %d invalid.",
    EXPORT_NO_LOCATIONS = "No locations to export on this map.",
    EXPORT_NO_LOCATIONS_ALL = "No locations to export.",
    IMPORT_INVALID_FORMAT = "Invalid format: missing SMK prefix.",
    IMPORT_EMPTY = "No locations found in text.",
    DATABASE_READ_ONLY = "Saved data schema %d is newer than supported schema %d. SearchMaker is running read-only to protect it.",

    -- Widgets tooltip
    TOOLTIP_USAGE_COUNT = "Usage: %d",
    TOOLTIP_XY = "X %.2f · Y %.2f",
    ERROR_COORDS_READ_FAILED = "Cannot read coordinates on this map.",
    SAVE_FAILED = "Save failed.",
    ENTER_VALID_MAP_ID = "Please enter a valid map ID.",
    NO_LOCATIONS_TO_DELETE = "No locations found to delete.",

    -- Widgets tooltip
    TOOLTIP_INSTRUCTIONS = "Left-click: waypoint  ·  Right-click: edit  ·  Shift+Right-click: delete",

    -- SearchBar
    KEY_ALREADY_BOUND = "%s is already bound to \"%s\". Choose another key.",
    KEY_BIND_FAILED = "Failed to save shortcut key. Please try again.",
    KEY_BIND_UPDATED = "Shortcut key changed to %s.",
    KEY_BIND_IN_COMBAT = "Cannot change shortcut keys in combat.",
    SHORTCUT_TOOLTIP_TITLE = "Toggle search shortcut",
    SHORTCUT_TOOLTIP_CURRENT = "Current: %s",
    SHORTCUT_TOOLTIP_HINT = "Click, then press the new key.",
    SEARCH_RESULT_FORMAT = "%s: %s",
    COORDINATE_RESULT_FORMAT = "Coordinates: %s, %s",
    MAP_PORTAL_SUFFIX = " [Map]",
    HANDYNOTES_SOURCE_SUFFIX = "[From HandyNotes_MapNotes]",
    HANDYNOTES_PORTAL = "Portal",
    OPEN_MAP = "Click to open map",
    NO_KEY_BOUND = "Not set",

    -- FindDuplicate
    DUPLICATE_NAME = "A location with this name already exists on this map: %s",
    CAT_CITY_SERVICES = "City Services",
    CAT_CLASS = "Class",
    CAT_PROFESSION = "Profession",
    CAT_RAIDS = "Raids",
    CAT_DUNGEONS = "Dungeons",
    CAT_DELVES = "Delves",
    CAT_RARES = "Rare Creatures",
    CAT_TREASURES = "Treasures",
    CAT_PORTALS = "Portals",
    CAT_TELEPORT_BEACONS = "Teleport Beacons",
    CAT_MERCHANTS = "Merchants",
    CAT_NPC = "NPC",
    CAT_OTHER = "Other",

}
