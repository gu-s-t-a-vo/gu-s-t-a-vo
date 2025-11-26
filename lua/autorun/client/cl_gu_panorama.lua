local CONFIG = GU_PANORAMA_CONFIG

GU_Panorama = GU_Panorama or {}
GU_Panorama.State = "panorama"
GU_Panorama.Characters = {}
GU_Panorama.AutoLogin = false
GU_Panorama.Account = {
    login = "",
    email = "",
    remember = false
}

local showCharacters
local showAuth

surface.CreateFont("GU_Panorama_Title", {
    font = "Roboto",
    size = 42,
    weight = 600
})

surface.CreateFont("GU_Panorama_Subtle", {
    font = "Roboto",
    size = 20,
    weight = 500
})

surface.CreateFont("GU_Panorama_Small", {
    font = "Roboto",
    size = 16,
    weight = 500
})

local function blurBackground(panel)
    local blur = Material("pp/blurscreen")
    local x, y = panel:LocalToScreen(0, 0)
    local scrW, scrH = ScrW(), ScrH()

    surface.SetMaterial(blur)
    surface.SetDrawColor(255, 255, 255, 255)

    for i = 1, 3 do
        blur:SetFloat("$blur", (i / 3) * 5)
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, scrW, scrH)
    end
end

local function makeBackground()
    local frame = vgui.Create("EditablePanel")
    frame:SetSize(ScrW(), ScrH())
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    frame:SetMouseInputEnabled(true)
    frame:SetDrawOnTop(true)
    frame:SetZPos(32700)

    frame.logo = Material(CONFIG.LogoMaterial)
    frame.background = Material(CONFIG.BackgroundMaterial)

    local function continueFlow()
        if not GU_Panorama.InputReady then return end
        if GU_Panorama.State ~= "panorama" then return end

        hook.Remove("PlayerButtonDown", "GU_Panorama_AnyKey")

        GU_Panorama.State = "auth"

        if GU_Panorama.AutoLogin then
            showCharacters()
        else
            showAuth()
        end

        if IsValid(GU_Panorama.Panorama) then
            GU_Panorama.Panorama:Remove()
        end
    end

    frame.Think = function(self)
        if not IsValid(self) then return end
        self:MakePopup()
        gui.EnableScreenClicker(true)
    end

    frame.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)

        -- surface.SetMaterial(self.background)
        -- surface.DrawTexturedRect(0, 0, w, h)

        -- local logoW, logoH = 900, 400
        -- surface.SetMaterial(self.logo)
        -- surface.DrawTexturedRect((w - logoW) / 2, (h - logoH) / 2, logoW, logoH)

        local pulse = 127 + math.sin(CurTime() * 3) * 128
        draw.SimpleText("Нажмите любую кнопку чтобы продолжить", "GU_Panorama_Subtle", w - 40, h - 40, Color(255, 255, 255, pulse), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        draw.SimpleText("🖱", "GU_Panorama_Title", w - 48, h - 80, Color(255, 255, 255, pulse), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end

    frame.OnMousePressed = continueFlow
    frame.OnKeyCodePressed = continueFlow

    return frame
end

local function sendSyncRequest()
    net.Start("gu_panorama_request_sync")
    net.SendToServer()
end

local function requestLogin(login, password, remember)
    net.Start("gu_panorama_login")
        net.WriteString(login)
        net.WriteString(password)
        net.WriteBool(remember)
    net.SendToServer()
end

local function requestRegister(login, email, password, promo, remember)
    net.Start("gu_panorama_register")
        net.WriteString(login)
        net.WriteString(email)
        net.WriteString(password)
        net.WriteString(promo)
        net.WriteBool(remember)
    net.SendToServer()
end

local function requestSaveChar(slot, data)
    net.Start("gu_panorama_save_char")
        net.WriteUInt(slot, 2)
        net.WriteString(data.first)
        net.WriteString(data.last)
        net.WriteUInt(data.age, 7)
        net.WriteString(data.model)
        net.WriteUInt(table.Count(data.bodygroups or {}), 5)
        for k, v in pairs(data.bodygroups or {}) do
            net.WriteString(k)
            net.WriteInt(v, 8)
        end
    net.SendToServer()
end

local function requestSelectChar(slot, useLastPos)
    net.Start("gu_panorama_select_char")
        net.WriteUInt(slot, 2)
        net.WriteBool(useLastPos)
    net.SendToServer()
end

local function buildLoginForm(parent)
    local container = vgui.Create("DPanel", parent)
    container:Dock(FILL)
    container:DockMargin(24, 24, 24, 24)

    local form = vgui.Create("DForm", container)
    form:Dock(LEFT)
    form:SetWide(math.min(ScrW() * 0.4, 420))
    form:SetName("Авторизация")

    local loginEntry = vgui.Create("DTextEntry", form)
    loginEntry:SetPlaceholderText("Логин")
    loginEntry:SetText(GU_Panorama.Account.login or "")
    form:AddItem(loginEntry)

    local passwordEntry = vgui.Create("DTextEntry", form)
    passwordEntry:SetPlaceholderText("Пароль")
    passwordEntry:SetEnterAllowed(false)
    passwordEntry:SetValue("")
    passwordEntry:SetText("")
    form:AddItem(passwordEntry)

    local remember = vgui.Create("DCheckBoxLabel", form)
    remember:SetText("Запомнить меня")
    remember:SetValue(GU_Panorama.Account.remember and 1 or 0)
    form:AddItem(remember)

    local submit = vgui.Create("DButton", form)
    submit:SetText("Войти")
    form:AddItem(submit)

    submit.DoClick = function()
        requestLogin(loginEntry:GetText(), passwordEntry:GetText(), remember:GetChecked())
    end

    return container
end

local function buildRegisterForm(parent)
    local container = vgui.Create("DPanel", parent)
    container:Dock(FILL)
    container:DockMargin(24, 24, 24, 24)

    local form = vgui.Create("DForm", container)
    form:Dock(LEFT)
    form:SetWide(math.min(ScrW() * 0.4, 420))
    form:SetName("Регистрация")

    local loginEntry = vgui.Create("DTextEntry", form)
    loginEntry:SetPlaceholderText("Логин")
    form:AddItem(loginEntry)

    local emailEntry = vgui.Create("DTextEntry", form)
    emailEntry:SetPlaceholderText("Email")
    form:AddItem(emailEntry)

    local passwordEntry = vgui.Create("DTextEntry", form)
    passwordEntry:SetPlaceholderText("Пароль")
    form:AddItem(passwordEntry)

    local promoEntry = vgui.Create("DTextEntry", form)
    promoEntry:SetPlaceholderText("Промокод")
    form:AddItem(promoEntry)

    local remember = vgui.Create("DCheckBoxLabel", form)
    remember:SetText("Запомнить меня")
    remember:SetValue(1)
    form:AddItem(remember)

    local submit = vgui.Create("DButton", form)
    submit:SetText("Создать аккаунт")
    form:AddItem(submit)

    submit.DoClick = function()
        requestRegister(loginEntry:GetText(), emailEntry:GetText(), passwordEntry:GetText(), promoEntry:GetText(), remember:GetChecked())
    end

    return container
end

local function buildCharacterCreator(slot)
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(900, ScrW() * 0.9), math.min(640, ScrH() * 0.9))
    frame:Center()
    frame:SetTitle("Создание персонажа: слот " .. slot)
    frame:MakePopup()

    local modelPanel = vgui.Create("DModelPanel", frame)
    modelPanel:Dock(LEFT)
    modelPanel:SetWide(frame:GetWide() * 0.45)
    modelPanel:SetModel(CONFIG.DefaultModel)
    modelPanel:SetFOV(36)
    modelPanel:SetCamPos(Vector(80, 0, 65))
    modelPanel:SetLookAt(Vector(0, 0, 62))

    local metaPanel = vgui.Create("DScrollPanel", frame)
    metaPanel:Dock(FILL)
    metaPanel:DockMargin(16, 8, 8, 8)

    local first = vgui.Create("DTextEntry", metaPanel)
    first:SetPlaceholderText("Имя")
    metaPanel:AddItem(first)

    local last = vgui.Create("DTextEntry", metaPanel)
    last:SetPlaceholderText("Фамилия")
    metaPanel:AddItem(last)

    local age = vgui.Create("DNumSlider", metaPanel)
    age:SetText("Возраст")
    age:SetMin(16)
    age:SetMax(90)
    age:SetValue(24)
    age:SetDecimals(0)
    metaPanel:AddItem(age)

    local modelEntry = vgui.Create("DTextEntry", metaPanel)
    modelEntry:SetPlaceholderText("Модель игрока")
    modelEntry:SetText(CONFIG.DefaultModel)
    metaPanel:AddItem(modelEntry)

    local bodygroupList = vgui.Create("DPanelList", metaPanel)
    bodygroupList:SetSpacing(6)
    bodygroupList:EnableVerticalScrollbar(true)
    metaPanel:AddItem(bodygroupList)

    local function refreshBodygroups()
        bodygroupList:Clear()
        local ent = modelPanel.Entity
        if not IsValid(ent) then return end

        for _, group in ipairs(ent:GetBodyGroups()) do
            if CONFIG.BodygroupIgnore[group.name] then continue end
            local slider = vgui.Create("DNumSlider")
            slider:SetText(group.name)
            slider:SetMin(0)
            slider:SetMax(group.num - 1)
            slider:SetDecimals(0)
            slider:SetValue(ent:GetBodygroup(group.id))
            slider.OnValueChanged = function(_, val)
                ent:SetBodygroup(group.id, math.floor(val))
            end
            bodygroupList:AddItem(slider)
        end
    end

    modelEntry.OnEnter = function(self)
        modelPanel:SetModel(self:GetText())
        timer.Simple(0, refreshBodygroups)
    end

    modelPanel.PostDrawModel = function(self, ent)
        self:SetModel(modelEntry:GetText())
    end

    refreshBodygroups()

    local save = vgui.Create("DButton", metaPanel)
    save:SetText("Сохранить персонажа")
    metaPanel:AddItem(save)

    save.DoClick = function()
        if not IsValid(modelPanel.Entity) then return end
        local bgTable = {}
        for _, group in ipairs(modelPanel.Entity:GetBodyGroups()) do
            if CONFIG.BodygroupIgnore[group.name] then continue end
            bgTable[tostring(group.id)] = modelPanel.Entity:GetBodygroup(group.id)
        end

        requestSaveChar(slot, {
            first = first:GetText(),
            last = last:GetText(),
            age = math.floor(age:GetValue()),
            model = modelEntry:GetText(),
            bodygroups = bgTable
        })

        frame:Close()
    end

    return frame
end

local function buildCharacterCard(parent, char, slot)
    local panel = vgui.Create("DPanel", parent)
    panel:SetTall(140)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, 12)

    panel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 25, 200))
        draw.SimpleText(char.first_name .. " " .. char.last_name, "GU_Panorama_Title", 16, 16, color_white, TEXT_ALIGN_LEFT)
        draw.SimpleText("Возраст: " .. char.age, "GU_Panorama_Subtle", 16, 60, color_white, TEXT_ALIGN_LEFT)
        draw.SimpleText("Последний визит: " .. os.date("%d.%m.%Y %H:%M", char.last_played or os.time()), "GU_Panorama_Small", 16, 90, Color(200, 200, 200), TEXT_ALIGN_LEFT)
        draw.SimpleText("Деньги: " .. tostring(char.money or 0), "GU_Panorama_Small", 16, 110, Color(200, 200, 200), TEXT_ALIGN_LEFT)
    end

    local choose = vgui.Create("DButton", panel)
    choose:SetText("Играть")
    choose:SetSize(120, 32)
    choose:SetPos(panel:GetWide() - 140, panel:GetTall() - 44)
    choose:Dock(RIGHT)
    choose:DockMargin(12, 12, 12, 12)

    choose.DoClick = function()
        local spawnMenu = vgui.Create("DFrame")
        spawnMenu:SetSize(300, 160)
        spawnMenu:Center()
        spawnMenu:SetTitle("Выбор точки появления")
        spawnMenu:MakePopup()

        local lastPos = vgui.Create("DCheckBoxLabel", spawnMenu)
        lastPos:SetText("Последнее место выхода")
        lastPos:SetPos(16, 40)
        lastPos:SetValue(1)

        local defaultPos = vgui.Create("DCheckBoxLabel", spawnMenu)
        defaultPos:SetText("Стандартный спавн")
        defaultPos:SetPos(16, 70)
        defaultPos:SetValue(0)

        lastPos.OnChange = function(_, val)
            defaultPos:SetValue(not val and 1 or 0)
        end
        defaultPos.OnChange = function(_, val)
            lastPos:SetValue(not val and 1 or 0)
        end

        local confirm = vgui.Create("DButton", spawnMenu)
        confirm:SetText("Продолжить")
        confirm:SetSize(120, 28)
        confirm:SetPos(150, 110)
        confirm.DoClick = function()
            requestSelectChar(slot, lastPos:GetChecked())
            spawnMenu:Close()
        end
    end

    local edit = vgui.Create("DButton", panel)
    edit:SetText("Редактировать")
    edit:SetSize(120, 32)
    edit:Dock(RIGHT)
    edit:DockMargin(12, 12, 12, 12)

    edit.DoClick = function()
        local creator = buildCharacterCreator(slot)
        if IsValid(creator) then
            creator:MakePopup()
        end
    end

    return panel
end

local function buildCharacterSlots()
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(960, ScrW() * 0.9), math.min(720, ScrH() * 0.9))
    frame:Center()
    frame:SetTitle("Персонажи")
    frame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(16, 16, 16, 16)

    local usedSlots = {}
    for _, char in ipairs(GU_Panorama.Characters) do
        usedSlots[char.slot] = char
        buildCharacterCard(scroll, char, char.slot)
    end

    for slot = 1, 3 do
        if usedSlots[slot] then continue end
        local empty = vgui.Create("DPanel", scroll)
        empty:SetTall(120)
        empty:Dock(TOP)
        empty:DockMargin(0, 0, 0, 12)
        empty.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 25, 200))
            draw.SimpleText("Свободный слот #" .. slot, "GU_Panorama_Title", 16, 16, color_white, TEXT_ALIGN_LEFT)
            draw.SimpleText("Создайте нового героя", "GU_Panorama_Subtle", 16, 60, color_white, TEXT_ALIGN_LEFT)
        end

        local create = vgui.Create("DButton", empty)
        create:SetText("Создать")
        create:SetSize(120, 32)
        create:Dock(RIGHT)
        create:DockMargin(12, 12, 12, 12)
        create.DoClick = function()
            local creator = buildCharacterCreator(slot)
            if IsValid(creator) then creator:MakePopup() end
        end
    end

    return frame
end

local function buildAuth()
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(860, ScrW() * 0.8), math.min(540, ScrH() * 0.8))
    frame:Center()
    frame:SetTitle("Вход / Регистрация")
    frame:MakePopup()

    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)

    sheet:AddSheet("Авторизация", buildLoginForm(sheet), "icon16/user.png")
    sheet:AddSheet("Регистрация", buildRegisterForm(sheet), "icon16/add.png")

    return frame
end

local function closeAll()
    if IsValid(GU_Panorama.Panorama) then GU_Panorama.Panorama:Remove() end
    if IsValid(GU_Panorama.AuthFrame) then GU_Panorama.AuthFrame:Remove() end
    if IsValid(GU_Panorama.CharacterFrame) then GU_Panorama.CharacterFrame:Remove() end
end

local function showCharacters()
    if IsValid(GU_Panorama.AuthFrame) then GU_Panorama.AuthFrame:Close() end
    GU_Panorama.CharacterFrame = buildCharacterSlots()
end

local function showAuth()
    if IsValid(GU_Panorama.CharacterFrame) then GU_Panorama.CharacterFrame:Close() end
    GU_Panorama.AuthFrame = buildAuth()
end

local function showPanorama()
    GU_Panorama.Panorama = makeBackground()
    GU_Panorama.State = "panorama"
    GU_Panorama.InputReady = false

    timer.Simple(0.5, function()
        if not IsValid(GU_Panorama.Panorama) then return end
        GU_Panorama.InputReady = true
    end)

    hook.Add("PlayerButtonDown", "GU_Panorama_AnyKey", function(ply)
        if not GU_Panorama.InputReady then return end
        if ply ~= LocalPlayer() then return end
        hook.Remove("PlayerButtonDown", "GU_Panorama_AnyKey")

        if GU_Panorama.AutoLogin then
            showCharacters()
        else
            showAuth()
        end

        if IsValid(GU_Panorama.Panorama) then
            GU_Panorama.Panorama:Remove()
        end
    end)
end

net.Receive("gu_panorama_sync", function()
    GU_Panorama.Characters = {}
    GU_Panorama.Account = {
        remember = net.ReadBool(),
        login = net.ReadString(),
        email = net.ReadString()
    }

    local count = net.ReadUInt(3)
    for _ = 1, count do
        local char = {
            slot = net.ReadUInt(2),
            first_name = net.ReadString(),
            last_name = net.ReadString(),
            age = net.ReadUInt(7),
            model = net.ReadString(),
            bodygroups = {},
            money = net.ReadInt(32),
            last_played = net.ReadInt(32)
        }

        local bgCount = net.ReadUInt(5)
        for _ = 1, bgCount do
            local key = net.ReadString()
            local val = net.ReadInt(8)
            char.bodygroups[key] = val
        end

        local hasPos = net.ReadBool()
        if hasPos then
            char.last_position = net.ReadVector()
        end

        table.insert(GU_Panorama.Characters, char)
    end

    GU_Panorama.AutoLogin = GU_Panorama.Account.remember and GU_Panorama.Account.login ~= ""

    if not GU_Panorama.Initialized then
        GU_Panorama.Initialized = true
        showPanorama()
    end
end)

hook.Add("InitPostEntity", "GU_Panorama_Sync", function()
    sendSyncRequest()
end)

concommand.Add("gu_panorama_reload", function()
    sendSyncRequest()
    showPanorama()
end)
