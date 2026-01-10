util.AddNetworkString("gu_panorama_sync")
util.AddNetworkString("gu_panorama_login")
util.AddNetworkString("gu_panorama_register")
util.AddNetworkString("gu_panorama_save_char")
util.AddNetworkString("gu_panorama_select_char")
util.AddNetworkString("gu_panorama_request_sync")

local function readPlayerData(ply)
    if not IsValid(ply) then return {} end
    local path = GU_PANORAMA_CONFIG:GetDataPath(ply:SteamID64())
    if not file.Exists(path, "DATA") then return {} end

    local raw = file.Read(path, "DATA")
    local ok, data = pcall(util.JSONToTable, raw or "{}")
    if not ok or type(data) ~= "table" then
        return {}
    end

    return data
end

local function writePlayerData(ply, data)
    if not IsValid(ply) then return end
    data = data or {}
    data.characters = data.characters or {}

    file.CreateDir(GU_PANORAMA_CONFIG.DataFolder)
    local path = GU_PANORAMA_CONFIG:GetDataPath(ply:SteamID64())
    file.Write(path, util.TableToJSON(data, true))
end

local function sanitizeCharData(char)
    char = char or {}
    char.first_name = string.sub(tostring(char.first_name or ""), 1, 32)
    char.last_name = string.sub(tostring(char.last_name or ""), 1, 32)
    char.age = math.Clamp(tonumber(char.age) or 18, 16, 90)
    char.model = tostring(char.model or GU_PANORAMA_CONFIG.DefaultModel)
    char.bodygroups = char.bodygroups or {}
    char.money = tonumber(char.money) or 0
    char.last_played = tonumber(char.last_played) or os.time()
    if char.last_position and istable(char.last_position) then
        char.last_position = Vector(char.last_position.x or 0, char.last_position.y or 0, char.last_position.z or 0)
    else
        char.last_position = nil
    end

    return char
end

local function sendSync(ply)
    local data = readPlayerData(ply)

    net.Start("gu_panorama_sync")
        net.WriteBool(data.remember_me or false)
        net.WriteString(data.login or "")
        net.WriteString(data.email or "")

        net.WriteUInt(#(data.characters or {}), 3)
        for _, char in ipairs(data.characters or {}) do
            net.WriteUInt(char.slot or 1, 2)
            net.WriteString(char.first_name or "")
            net.WriteString(char.last_name or "")
            net.WriteUInt(math.Clamp(char.age or 18, 1, 120), 7)
            net.WriteString(char.model or GU_PANORAMA_CONFIG.DefaultModel)
            net.WriteUInt(table.Count(char.bodygroups or {}), 5)
            for k, v in pairs(char.bodygroups or {}) do
                net.WriteString(tostring(k))
                net.WriteInt(v, 8)
            end
            net.WriteInt(math.floor(char.money or 0), 32)
            net.WriteInt(char.last_played or 0, 32)
            local hasPos = char.last_position and char.last_position.x
            net.WriteBool(hasPos and true or false)
            if hasPos then
                net.WriteVector(char.last_position)
            end
        end
    net.Send(ply)
end

local function tryDarkRPSetup(ply, char)
    if not IsValid(ply) or not char then return end

    if DarkRP and ply.setDarkRPVar then
        local fullName = string.Trim(string.format("%s %s", char.first_name or "", char.last_name or ""))
        if fullName ~= "" then
            ply:setDarkRPVar("rpname", fullName)
        end

        if char.money then
            ply:setDarkRPVar("money", math.max(0, math.floor(char.money)))
        end
    end
end

local function applySpawnChoice(ply)
    if not IsValid(ply) then return end
    local pending = ply.gu_pendingCharacter
    if not pending then return end

    tryDarkRPSetup(ply, pending)

    local targetPos = pending.desired_pos
    ply.gu_pendingCharacter = nil

    if targetPos and isvector(targetPos) then
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            ply:SetPos(targetPos)
        end)
    end
end

hook.Add("PlayerInitialSpawn", "GU_Panorama_FirstSync", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        sendSync(ply)
    end)
end)

hook.Add("PlayerSpawn", "GU_Panorama_SpawnCharacter", function(ply)
    applySpawnChoice(ply)
end)

net.Receive("gu_panorama_request_sync", function(_, ply)
    sendSync(ply)
end)

net.Receive("gu_panorama_register", function(_, ply)
    local login = string.sub(net.ReadString(), 1, 32)
    local email = string.sub(net.ReadString(), 1, 64)
    local password = string.sub(net.ReadString(), 1, 64)
    local promo = string.sub(net.ReadString(), 1, 32)
    local remember = net.ReadBool()

    local data = readPlayerData(ply)
    data.login = login
    data.email = email
    data.password = password
    data.promo = promo
    data.remember_me = remember
    data.characters = data.characters or {}

    writePlayerData(ply, data)
    sendSync(ply)
end)

net.Receive("gu_panorama_login", function(_, ply)
    local login = string.sub(net.ReadString(), 1, 32)
    local password = string.sub(net.ReadString(), 1, 64)
    local remember = net.ReadBool()

    local data = readPlayerData(ply)
    if data.login ~= login or data.password ~= password then
        net.Start("gu_panorama_sync")
            net.WriteBool(data.remember_me or false)
            net.WriteString("")
            net.WriteString("")
            net.WriteUInt(0, 3)
        net.Send(ply)
        return
    end

    data.remember_me = remember
    writePlayerData(ply, data)
    sendSync(ply)
end)

net.Receive("gu_panorama_save_char", function(_, ply)
    local slot = net.ReadUInt(2)
    local first = net.ReadString()
    local last = net.ReadString()
    local age = net.ReadUInt(7)
    local model = net.ReadString()
    local bgCount = net.ReadUInt(5)
    local bodygroups = {}
    for _ = 1, bgCount do
        local key = net.ReadString()
        local val = net.ReadInt(8)
        bodygroups[key] = val
    end

    local data = readPlayerData(ply)
    data.characters = data.characters or {}

    local newChar = sanitizeCharData({
        slot = slot,
        first_name = first,
        last_name = last,
        age = age,
        model = model,
        bodygroups = bodygroups,
        last_played = os.time(),
    })

    local replaced = false
    for idx, char in ipairs(data.characters) do
        if char.slot == slot then
            data.characters[idx] = newChar
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(data.characters, newChar)
    end

    writePlayerData(ply, data)
    sendSync(ply)
end)

net.Receive("gu_panorama_select_char", function(_, ply)
    local slot = net.ReadUInt(2)
    local useLastPos = net.ReadBool()

    local data = readPlayerData(ply)
    local chosen
    for _, char in ipairs(data.characters or {}) do
        if char.slot == slot then
            chosen = sanitizeCharData(char)
            break
        end
    end

    if not chosen then return end

    chosen.last_played = os.time()
    data.characters = data.characters or {}
    for idx, char in ipairs(data.characters) do
        if char.slot == slot then
            data.characters[idx] = chosen
        end
    end

    local desiredPos
    if useLastPos and chosen.last_position then
        desiredPos = chosen.last_position
    end
    chosen.desired_pos = desiredPos

    writePlayerData(ply, data)

    ply.gu_pendingCharacter = chosen
    ply:Spawn()
end)

hook.Add("PlayerDisconnected", "GU_Panorama_SavePos", function(ply)
    local data = readPlayerData(ply)
    local lastSlot = ply.gu_pendingCharacter and ply.gu_pendingCharacter.slot
    if not lastSlot then return end

    for idx, char in ipairs(data.characters or {}) do
        if char.slot == lastSlot then
            char.last_position = ply:GetPos()
            char.money = DarkRP and ply.getDarkRPVar and ply:getDarkRPVar("money") or char.money or 0
            break
        end
    end

    writePlayerData(ply, data)
end)
