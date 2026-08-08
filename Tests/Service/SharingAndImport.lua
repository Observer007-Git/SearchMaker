local context = assert(...)
local SMK = context.SMK
local first = context.first

local shareEntry = assert(SMK.LocationModel:Normalize({
    mapID = first.mapID,
    x = first.x,
    y = first.y,
    name = first.name,
    categoryKey = first.categoryKey,
    showPinName = 1,
    showPinTexture = 1,
    pinTextureID = first.pinTextureID,
    pinColor = { r = 0.2, g = 0.4, b = 0.6 },
    customIconID = -3,
    note = "测试备注,绿色",
}))
local encoded = SMK.ShareCodec:Encode({ shareEntry })
assert(encoded:sub(1, 4) == "SMK|" and encoded:sub(1, 6) ~= "SMK|2|",
    "current share format does not use the unified SMK prefix")
local _, commaCount = encoded:gsub(",", "")
assert(commaCount == 9 and encoded:find("336699", 1, true),
    "share record was not packed into ten fields with one RGB value")
assert(encoded:find(",5,336699", 1, true)
    and not encoded:find("VignetteEvent-SuperTracked", 1, true),
    "share record did not encode the pin texture as a compact ID")
assert(SMK.ShareCodec:FindShareText("chat " .. encoded) == encoded,
    "share text was not found in chat")
local whisperEvents, whisperEventCount = SMK.WhisperInbox.events, 0
for _ in pairs(whisperEvents) do whisperEventCount = whisperEventCount + 1 end
assert(whisperEventCount == 4
    and whisperEvents.CHAT_MSG_WHISPER
    and whisperEvents.CHAT_MSG_WHISPER_INFORM
    and whisperEvents.CHAT_MSG_BN_WHISPER
    and whisperEvents.CHAT_MSG_BN_WHISPER_INFORM
    and not whisperEvents.CHAT_MSG_CHANNEL,
    "whisper inbox listens outside character or Battle.net whispers")
local originalWhisperLimit = SMK.Config.share.whisperInboxMaxEntries
SMK.Config.share.whisperInboxMaxEntries = 2
SMK.WhisperInbox.codes = {}
assert(not SMK.WhisperInbox:Capture("ordinary whisper")
    and SMK.WhisperInbox:Capture("prefix SMK|first")
    and SMK.WhisperInbox:Capture("SMK|second")
    and SMK.WhisperInbox:Capture("SMK|third")
    and #SMK.WhisperInbox:GetAll() == 2
    and SMK.WhisperInbox:GetAll()[1] == "SMK|second"
    and SMK.WhisperInbox:GetAll()[2] == "SMK|third"
    and SMK.WhisperInbox:GetImportText() == "SMK|second;third",
    "whisper inbox did not filter or bound captured SMK codes")
local originalIsSecretValue = issecretvalue
issecretvalue = function(value) return value == "SMK|secret" end
assert(not SMK.WhisperInbox:Capture("SMK|secret"),
    "whisper inbox attempted to inspect a secret message")
issecretvalue = originalIsSecretValue
SMK.Config.share.whisperInboxMaxEntries = originalWhisperLimit
SMK.WhisperInbox.codes = {}
local decoded, decodeError, invalid = SMK.ShareCodec:Decode(encoded)
assert(not decodeError and invalid == 0 and #decoded == 1, "current share round trip failed")
assert(decoded[1].categoryKey == "delves"
    and decoded[1].pinTextureID == 5
    and decoded[1].customIconID == -3
    and decoded[1].note == "测试备注,绿色"
    and math.abs(decoded[1].pinColor.r - 0.2) < 0.005
    and math.abs(decoded[1].pinColor.g - 0.4) < 0.005
    and math.abs(decoded[1].pinColor.b - 0.6) < 0.005,
    "share fields or per-location pin color were not preserved")
local emptyEntries, emptyError = SMK.ShareCodec:Decode("SMK|;;;;")
assert(not emptyEntries and emptyError == SMK.L.IMPORT_EMPTY,
    "separator-only share text was accepted as an empty preview")
local previewEntry = assert(SMK.LocationModel:Normalize({
    mapID = 777, x = 12.5, y = 34.5, name = "预览地点",
    categoryKey = "other", note = "导入前不写入",
}))
local previewText = SMK.ShareCodec:Encode({ previewEntry, previewEntry })
local preview = assert(SMK.Import:PreviewText(previewText))
assert(preview.importable == 1 and preview.duplicates == 1
    and preview.invalid == 0 and not SMK.Store:FindDuplicate(previewEntry),
    "import preview wrote data or misclassified batch duplicates")
local previewCommit = assert(SMK.Import:CommitPreview(preview))
assert(previewCommit.imported == 1 and previewCommit.duplicates == 1,
    "confirmed import did not match its preview")
assert(SMK.Store:Delete(SMK.Store:FindDuplicate(previewEntry)) == 1,
    "import preview fixture could not be removed")
local noColorDecoded, noColorError, noColorInvalid = SMK.ShareCodec:Decode(
    SMK.ShareCodec:Encode({ assert(SMK.LocationModel:Normalize({
        mapID = 100, x = 1, y = 2, name = "无颜色", categoryKey = "other",
    })) }))
assert(not noColorError and noColorInvalid == 0 and #noColorDecoded == 1
    and noColorDecoded[1].pinColor == nil,
    "share records without a per-location color did not round trip")
local originalNormalizeLocation = SMK.LocationModel.Normalize
local importNormalizeCalls = 0
SMK.LocationModel.Normalize = function(self, values)
    importNormalizeCalls = importNormalizeCalls + 1
    return originalNormalizeLocation(self, values)
end
local importResult = assert(SMK.Import:ImportText(encoded))
SMK.LocationModel.Normalize = originalNormalizeLocation
assert(importResult.imported == 0 and importResult.duplicates == 1,
    "shared import service did not filter duplicates")
assert(importNormalizeCalls == 1,
    "decoded share entries were normalized again during storage")
local dialogText = encoded
SMK.ImportPreviewDialog = {
    Open = function(_, _, onConfirm) onConfirm() end,
}
SMK.ShareDialog.textBox = {
    GetText = function() return dialogText end,
    SetText = function(_, value) dialogText = value end,
}
SMK.ShareDialog.status = {
    SetText = function(self, value) self.text = value end,
    SetTextColor = function(self, ...) self.color = { ... } end,
}
SMK.ShareDialog:Import()
assert(dialogText == "", "successful share import retained the pasted text")
local reportedWhisperText = "SMK|2393,6169,5147,13,打撒放大1,3,8,00FF0A,20,;"
    .. "2393,4170,4442,13,放大顺丰1,3,1,2FFF24,19,;"
    .. "2395,5359,7011,13,森林测试点,0,1,,29,"
local reportedEntries, reportedError, reportedInvalid =
    SMK.ShareCodec:Decode(reportedWhisperText)
assert(not reportedError and reportedInvalid == 0 and #reportedEntries == 3,
    "reported whisper text did not decode all three complete records")
local knownWhisperDuplicate = assert(SMK.Store:Add(reportedEntries[3]))
SMK.WhisperInbox.codes = { reportedWhisperText }
local reportedPreview = assert(SMK.ShareDialog:ImportWhispers())
assert(reportedPreview.importable == 2
    and reportedPreview.duplicates == 1
    and reportedPreview.invalid == 0
    and dialogText == reportedWhisperText
    and SMK.ShareDialog.status.text == string.format(SMK.L.IMPORT_RESULT, 2, 1, 0),
    "whisper import did not retain the source text or show complete import statistics")
local importedWhisperFirst = SMK.Store:FindDuplicate(reportedEntries[1])
local importedWhisperSecond = SMK.Store:FindDuplicate(reportedEntries[2])
assert(importedWhisperFirst and importedWhisperSecond,
    "reported complete whisper locations were not both imported")
assert(SMK.Store:DeleteMany({
    importedWhisperFirst, importedWhisperSecond, knownWhisperDuplicate,
}) == 3, "whisper import regression fixtures were not removed")
SMK.WhisperInbox.codes = {}
local invalidImport = assert(SMK.Import:ImportEntries({ {} }))
assert(invalidImport.invalid == 1 and invalidImport.imported == 0,
    "shared import service did not validate entries")

for _, sample in ipairs({ "SMK3|x", "SMK2|x", "MLL2|x", "MLL1|x" }) do
    local entries = SMK.ShareCodec:Decode(sample)
    assert(not entries, "legacy share prefix was accepted: " .. sample)
end
local oldEntries, _, oldInvalid = SMK.ShareCodec:Decode(
    "SMK|100,100,200,8,old,0,1,0,0,,,,")
assert(oldEntries and #oldEntries == 0 and oldInvalid == 1,
    "obsolete field-count share records were accepted")
local previousEntries, _, previousInvalid = SMK.ShareCodec:Decode(
    "SMK|100,100,200,8,old,0,1")
assert(previousEntries and #previousEntries == 0 and previousInvalid == 1,
    "pre-custom-icon SMK record was accepted")
local invalidIconEntries, _, invalidIconCount = SMK.ShareCodec:Decode(
    "SMK|100,100,200,8,bad,0,1,,-999,")
assert(invalidIconEntries and #invalidIconEntries == 0 and invalidIconCount == 1,
    "unknown custom icon ID was accepted")
local invalidPinEntries, _, invalidPinCount = SMK.ShareCodec:Decode(
    "SMK|100,100,200,8,bad,0,999,,,")
assert(invalidPinEntries and #invalidPinEntries == 0 and invalidPinCount == 1,
    "unknown pin texture ID was accepted")

local duplicateA = { mapID = 100, x = 1.234, y = 5.678, name = " Test Name " }
local duplicateB = { mapID = 100, x = 1.2341, y = 5.6781, name = "testname" }
assert(SMK.LocationModel:GetDuplicateKey(duplicateA) == SMK.LocationModel:GetDuplicateKey(duplicateB),
    "duplicate normalization failed")

local ranges501 = SMK.ShareDialog:GetExportRanges(501)
local ranges1000 = SMK.ShareDialog:GetExportRanges(1000)
assert(#ranges501 == 3 and ranges501[3].first == 401 and ranges501[3].last == 501,
    "501-entry export pagination failed")
assert(#ranges1000 == 5 and ranges1000[5].first == 801 and ranges1000[5].last == 1000,
    "1000-entry export pagination failed")
assert(SMK.Settings:Set("exportBatchSize", 50))
local ranges120 = SMK.ShareDialog:GetExportRanges(120)
assert(#ranges120 == 3 and ranges120[2].first == 51 and ranges120[2].last == 100
    and ranges120[3].first == 101 and ranges120[3].last == 120,
    "selected export batch size did not control pagination")
assert(not SMK.Settings:Set("exportBatchSize", 75)
    and SMK.Settings:Get("exportBatchSize") == 50,
    "unsupported export batch size was accepted")
local originalExport = SMK.ShareDialog.Export
local exportRefreshes = 0
SMK.ShareDialog.exportEntries = {}
SMK.ShareDialog.Export = function() exportRefreshes = exportRefreshes + 1 end
SMK.ShareDialog:SetBatchSize(100)
SMK.ShareDialog.Export = originalExport
SMK.ShareDialog.exportEntries = nil
assert(exportRefreshes == 1,
    "changing export batch size did not refresh the filtered export entries")
local rangeLabelHidden, rangeDropdownHidden = false, false
SMK.ShareDialog.exportEntries = { shareEntry }
SMK.ShareDialog.exportRanges = { { first = 1, last = 1 } }
SMK.ShareDialog.currentRangeStart, SMK.ShareDialog.currentRangeEnd = 1, 1
SMK.ShareDialog.rangeLabel = { Hide = function() rangeLabelHidden = true end }
SMK.ShareDialog.rangeDropdown = { Hide = function() rangeDropdownHidden = true end }
SMK.ShareDialog:ReleaseExportState()
assert(not SMK.ShareDialog.exportEntries and not SMK.ShareDialog.exportRanges
    and SMK.ShareDialog.currentRangeStart == 1
    and SMK.ShareDialog.currentRangeEnd == 0
    and rangeLabelHidden and rangeDropdownHidden,
    "closing the share dialog did not release export state")
