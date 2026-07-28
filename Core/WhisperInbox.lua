local _, SMK = ...

local Inbox = {
    events = {
        CHAT_MSG_WHISPER = true,
        CHAT_MSG_WHISPER_INFORM = true,
        CHAT_MSG_BN_WHISPER = true,
        CHAT_MSG_BN_WHISPER_INFORM = true,
    },
    codes = {},
}

function Inbox:Capture(message)
    if type(issecretvalue) == "function" and issecretvalue(message) then return false end
    if type(message) ~= "string" then return false end
    local code = SMK.ShareCodec:FindShareText(message)
    if not code then return false end
    local limit = math.max(1, tonumber(SMK.Config.share.whisperInboxMaxEntries) or 1)
    if #self.codes >= limit then table.remove(self.codes, 1) end
    self.codes[#self.codes + 1] = code
    return true
end

function Inbox:GetAll()
    return self.codes
end

function Inbox:GetImportText()
    if #self.codes == 0 then return nil end
    local prefix = SMK.Config.share.prefix
    local payloads = {}
    for _, code in ipairs(self.codes) do
        payloads[#payloads + 1] = code:sub(#prefix + 1)
    end
    return prefix .. table.concat(payloads, ";")
end

SMK.WhisperInbox = Inbox
