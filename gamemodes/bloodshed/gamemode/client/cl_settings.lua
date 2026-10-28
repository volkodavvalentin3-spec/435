local Settings = {
    Character = {},
    Settings = {},
    Admin = {}
}

local UI = MuR.UI

local THEME = {
    background = UI.Colors.bg,
    accent     = UI.Colors.accent,
    panel      = UI.Colors.panel,
    text       = UI.Colors.text,
    textDark   = UI.Colors.textDim
}

function AddSetting(category, settingType, name, convar, min, max, options)
    table.insert(Settings[category], {
        type = settingType,
        name = name,
        convar = convar,
        min = min,
        max = max,
        options = options
    })
end

local function CreateControl(parent, setting)
    local row = UI.Row(parent, setting.name)

    local function dockRight(control, width)
        control:Dock(RIGHT)
        control:DockMargin(0, He(10), We(UI.PAD), He(10))
        if width then control:SetWide(width) end
    end

    if setting.type == "checkbox" then
        local box = UI.Checkbox(row, setting.convar)
        box:Dock(RIGHT)
        box:DockMargin(0, He(13), We(UI.PAD), He(13))
        box:SetWide(He(20))

    elseif setting.type == "slider" then
        dockRight(UI.Slider(row, setting.convar, setting.min, setting.max, 0), We(280))

    elseif setting.type == "textentry" then
        dockRight(UI.TextEntry(row, setting.convar), We(220))

    elseif setting.type == "combobox" then
        dockRight(UI.ComboBox(row, setting.options or {}, setting.convar), We(220))
    end

    return row
end

local FRAME_W, FRAME_H = 860, 640

local function L(key, fallback)
    return (MuR.Language and MuR.Language[key]) or fallback or key
end

local CARD_H = 92

local SANITY_TIERS = {
    veryhigh = "killerclass_sanity_veryhigh",
    high     = "killerclass_sanity_high",
    medium   = "killerclass_sanity_medium",
    low      = "killerclass_sanity_low",
    verylow  = "killerclass_sanity_verylow"
}

local function classCard(parent, def, convar)
    local c = UI.Colors

    local card = vgui.Create("DButton", parent)
    card:Dock(TOP)
    card:DockMargin(We(UI.PAD), 0, We(UI.PAD), He(6))
    card:SetTall(He(CARD_H))
    card:SetText("")

    card.DoClick = function()
        surface.PlaySound("murdered/vgui/ui_click.wav")
        RunConsoleCommand(convar, def.id)
    end

    card.Paint = function(self, w, h)
        local selected = GetConVar(convar):GetString() == def.id

        UI.Rect(0, 0, w, h, self:IsHovered() and c.panelHov or c.panel)
        UI.Outline(0, 0, w, h, selected and c.accent or c.line)

        if selected then UI.Rect(0, 0, We(3), h, c.accent) end

        local x = We(UI.PAD)
        local right = w - We(UI.PAD)

        draw.SimpleText(L("killerclass_" .. def.id, def.id), "MuR_Font2", x, He(14),
            selected and c.accent or c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local reserve = We(210)
        local lines = UI.WrapText(L("killerclass_" .. def.id .. "_desc", ""), "MuR_Font0",
            right - x - reserve)

        for i = 1, math.min(#lines, 3) do
            draw.SimpleText(lines[i], "MuR_Font0", x, He(40 + (i - 1) * 15), c.textDim,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        if def.minutes then
            local minutes = MuR.KillerSanityMinutes(def)

            draw.SimpleText(L("killerclass_sanity", "Sanity"), "MuR_Font0", right, He(16),
                c.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText(L(SANITY_TIERS[def.tier or "medium"], ""), "MuR_Font1", right, He(32),
                c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("~%s %s",
                    minutes % 1 == 0 and tostring(math.floor(minutes)) or tostring(minutes),
                    L("killerclass_minutes", "min")),
                "MuR_Font0", right, He(54), c.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            UI.Meter(right - We(160), He(74), We(160), He(6),
                math.Clamp(minutes / MuR.KILLER_SANITY_MAX_MINUTES, 0.06, 1), c.accent, 16)

        elseif def.ability then
            draw.SimpleText(L("killerclass_ability", "Ability"), "MuR_Font0", right, He(16),
                c.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText(L("killerclass_ability_" .. def.ability, def.ability), "MuR_Font1",
                right, He(32), c.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end

    return card
end

local function BuildKillerClassTab(panel)
    local c = UI.Colors

    for _, mode in ipairs({1, 4, 3}) do
        local set = MuR.KillerClassSets[mode]

        if set then
            local convar = MuR.KillerClassConVar(mode)

            local header = vgui.Create("DPanel", panel)
            header:Dock(TOP)
            header:DockMargin(We(UI.PAD), He(14), We(UI.PAD), He(8))
            header:SetTall(He(26))
            local names = {}
            for _, m in ipairs(set.modes or {mode}) do
                names[#names + 1] = MuR.Language["gamename" .. m] or ("Mode " .. m)
            end
            local title = table.concat(names, "  /  ")

            header.Paint = function(self, w, h)
                draw.SimpleText(title, "MuR_Font1", 0, h / 2, c.text,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                UI.HLine(0, h - 1, w, c.lineSoft)
            end

            for _, id in ipairs(set.order) do
                local def = MuR.KillerClasses[id]
                if def then classCard(panel, def, convar) end
            end
        end
    end
end

function OpenSettingsMenu()
    local frame = UI.Frame(We(FRAME_W), He(FRAME_H), {KEY_ESCAPE, KEY_F1})
    frame:Center()

    function frame:Paint(w, h)
        UI.Chrome(w, h, L("settings_main", "Settings"), nil, L("settings_close_key", "[F1]"))
    end

    local tabStrip = vgui.Create("DPanel", frame)
    tabStrip:SetPos(0, He(UI.HEADER))
    tabStrip:SetSize(We(FRAME_W), He(UI.TAB))
    tabStrip.Paint = function(self, w, h) UI.HLine(0, h - 1, w, UI.Colors.line) end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(0, He(UI.HEADER + UI.TAB))
    content:SetSize(We(FRAME_W), He(FRAME_H - UI.HEADER - UI.TAB))
    content.Paint = function() end

    local noop = function() end
    local sheetItems = {}

    local sheet = {}
    function sheet:AddSheet(label, panel)
        panel:SetParent(content)
        panel:Dock(FILL)
        panel:DockMargin(0, He(8), 0, He(8))
        panel:SetVisible(#sheetItems == 0)

        sheetItems[#sheetItems + 1] = {label = label, panel = panel}

        return {Tab = {SetFont = noop, Paint = noop, UpdateColours = noop}}
    end
    function sheet:GetItems() return {} end

    local characterPanel = vgui.Create("DScrollPanel")
    characterPanel.Paint = function() end

    UI.Scrollbar(characterPanel)

    local settingsPanel = vgui.Create("DScrollPanel")
    settingsPanel.Paint = function() end

    UI.Scrollbar(settingsPanel)

    local killerPanel = vgui.Create("DScrollPanel")
    killerPanel.Paint = function() end

    UI.Scrollbar(killerPanel)
    BuildKillerClassTab(killerPanel)

    local characterSheet = sheet:AddSheet(MuR.Language["settings_main_char"], characterPanel)
    local killerSheet = sheet:AddSheet(L("settings_main_killer", "Killer"), killerPanel)
    local settingsSheet = sheet:AddSheet(MuR.Language["settings_main_set"], settingsPanel)

    local bindsPanel = vgui.Create("DScrollPanel")
    bindsPanel.Paint = function() end

    UI.Scrollbar(bindsPanel)

    local bindsSheet = sheet:AddSheet(MuR.Language["binds_tab_name"], bindsPanel)
    bindsSheet.Tab:SetFont("MuR_Font1")

    local bindsData = {
        {name = "bind_ragdoll", command = "mur_ragdoll"},
        {name = "bind_kick", command = "mur_legkick"},
        {name = "bind_armor", command = "mur_armor_panel"},
        {name = "bind_voice", command = "mur_voicepanel"},
        {name = "bind_drop", command = "mur_wep_drop"},
        {name = "bind_unload", command = "mur_wep_unload"},
        {name = "bind_shout", command = "mur_shout"},
        {name = "bind_hostage_capture", command = "mur_hostage_capture"},
        {name = "bind_hostage_execute", command = "mur_hostage_execute"},
        {name = "bind_ron_briefing", command = "mur_ron_briefing"},
    }

    for _, bind in ipairs(bindsData) do
        local row = UI.Row(bindsPanel, MuR.Language[bind.name] or bind.name)
        local command = bind.command

        local binder = UI.Binder(row, MuR:GetBind(command), function(num)
            if num then MuR:SetBind(command, num) end
        end)
        binder:Dock(RIGHT)
        binder:DockMargin(0, He(10), We(UI.PAD), He(10))
        binder:SetWide(We(180))
    end

    local adminPanel
    local adminSheet
    local adminItems = {}
    if LocalPlayer():IsSuperAdmin() then
        adminPanel = vgui.Create("DScrollPanel")
        adminPanel.Paint = function() end
        UI.Scrollbar(adminPanel)
        adminSheet = sheet:AddSheet(MuR.Language["settings_main_admin"] or "Admin", adminPanel)
        adminSheet.Tab:SetFont("MuR_Font1")

        local function addAdminRow(name, rightWidgetBuilder)
            local row = UI.Row(adminPanel, name)
            rightWidgetBuilder(row)
            return row
        end

        local modeCheckboxes = {}
        local modeIds = {}
        for id, _ in pairs(MuR.Modes or {}) do table.insert(modeIds, id) end
        table.sort(modeIds, function(a,b) return a<b end)

        local restartRow = addAdminRow(MuR.Language["settings_admin_restart"] or "Restart round", function(parent)
            local btn = vgui.Create("DButton", parent)
            btn:Dock(RIGHT)
            btn:SetWide(We(220))
            btn:DockMargin(0, He(10), We(20), He(10))
            btn:SetText("")
            function btn:Paint(w, h)
                local hovered = self:IsHovered()
                local color = hovered and THEME.accent or THEME.background
                UI.Rect(0, 0, w, h, color)
                draw.SimpleText(MuR.Language["settings_admin_select"] or "Select mode", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            function btn:DoClick()
                surface.PlaySound("murdered/vgui/ui_click.wav")
                local menu = UI.Menu()
                menu:AddOption(MuR.EnableDebug and "Disable Sandbox" or "Enable Sandbox", function()
                    RunConsoleCommand("mur_sandboxtoggle")
                end)
                menu:AddOption(MuR.Language["settings_admin_random"] or "Random", function()
                    RunConsoleCommand("mur_nextgamemode", "0")
                    RunConsoleCommand("mur_restartround")
                end)
                for _, id in ipairs(modeIds) do
                    local solo = MuR.Modes[id].need_players and MuR.Modes[id].need_players == 1
                    if !solo and player.GetCount() == 1 then continue end
                    local txt = MuR.Language["gamename" .. tostring(id)] or ("Mode " .. tostring(id))
                    menu:AddOption(txt, function()
                        RunConsoleCommand("mur_nextgamemode", tostring(id))
                        RunConsoleCommand("mur_restartround")
                    end)
                end
                menu:Open()
            end
        end)
        table.insert(adminItems, restartRow)

        local nextTraitorRow = addAdminRow(MuR.Language["settings_admin_nexttraitor"] or "Next traitor", function(parent)
            local btn = UI.Button(parent, MuR.Language["settings_admin_select_player"] or "Select player", nil)
            btn:Dock(RIGHT)
            btn:DockMargin(0, He(10), We(UI.PAD), He(10))
            btn:SetWide(We(220))

            btn.DoClick = function()
                surface.PlaySound("murdered/vgui/ui_click.wav")

                local plys = player.GetAll()
                local rowH, headH, footH = 34, UI.HEADER, 58
                local listH = math.Clamp(#plys * rowH, rowH, 360)

                local win = UI.Frame(We(460), He(headH + listH + footH), {KEY_ESCAPE})
                win:Center()

                win.Paint = function(self, w, h)
                    UI.Chrome(w, h, MuR.Language["settings_admin_nexttraitor"] or "Next traitor",
                        MuR.Language["settings_admin_pick_hint"] or "")
                end

                local chosen = {}

                local scroll = vgui.Create("DScrollPanel", win)
                scroll:SetPos(0, He(headH))
                scroll:SetSize(We(460), He(listH))
                UI.Scrollbar(scroll)

                for _, target in ipairs(plys) do
                    local row = vgui.Create("DButton", scroll)
                    row:Dock(TOP)
                    row:SetTall(He(rowH))
                    row:SetText("")

                    row.Paint = function(self, w, h)
                        local on = chosen[target] ~= nil
                        if self:IsHovered() then UI.Rect(0, 0, w, h, UI.Colors.lineSoft) end
                        UI.HLine(0, h - 1, w, UI.Colors.lineSoft)

                        local box = He(14)
                        local bx, by = We(UI.PAD), h / 2 - box / 2
                        UI.Outline(bx, by, box, box, on and UI.Colors.accent or UI.Colors.line)
                        if on then UI.Rect(bx + 3, by + 3, box - 6, box - 6, UI.Colors.accent) end

                        local name = IsValid(target) and target:Nick() or "?"
                        draw.SimpleText(name, "MuR_Font1", bx + box + We(10), h / 2,
                            on and UI.Colors.text or UI.Colors.textDim,
                            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                        if on then
                            draw.SimpleText("#" .. chosen[target], "MuR_Font0", w - We(UI.PAD), h / 2,
                                UI.Colors.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        end
                    end

                    row.DoClick = function()
                        surface.PlaySound("buttons/lightswitch2.wav")

                        if chosen[target] then
                            local removed = chosen[target]
                            chosen[target] = nil
                            for other, order in pairs(chosen) do
                                if order > removed then chosen[other] = order - 1 end
                            end
                        else
                            local count = 0
                            for _ in pairs(chosen) do count = count + 1 end
                            chosen[target] = count + 1
                        end
                    end
                end

                local apply = UI.Button(win, MuR.Language["settings_admin_apply"] or "Apply", function()
                    local ordered = {}
                    for target, order in pairs(chosen) do
                        if IsValid(target) then ordered[order] = target:Nick() end
                    end

                    local args = {}
                    for i = 1, #ordered do args[#args + 1] = ordered[i] end

                    if #args == 0 then
                        RunConsoleCommand("mur_nexttraitor", "")
                    else
                        RunConsoleCommand("mur_nexttraitor", unpack(args))
                    end

                    win:Remove()
                end)
                apply:SetPos(We(UI.PAD), He(headH + listH + 12))
                apply:SetSize(We(200), He(34))

                local cancel = UI.Button(win, MuR.Language["settings_admin_cancel"] or "Cancel", function()
                    win:Remove()
                end)
                cancel:SetPos(We(240), He(headH + listH + 12))
                cancel:SetSize(We(200), He(34))
            end
        end)
        table.insert(adminItems, nextTraitorRow)

        local respawnRow = addAdminRow(MuR.Language["settings_admin_respawn"] or "Respawn player", function(parent)
            local btn = vgui.Create("DButton", parent)
            btn:Dock(RIGHT)
            btn:SetWide(We(220))
            btn:DockMargin(0, He(10), We(20), He(10))
            btn:SetText("")
            function btn:Paint(w, h)
                local hovered = self:IsHovered()
                local color = hovered and THEME.accent or THEME.background
                UI.Rect(0, 0, w, h, color)
                draw.SimpleText(MuR.Language["settings_admin_select_player"] or "Select player", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            function btn:DoClick()
                surface.PlaySound("murdered/vgui/ui_click.wav")
                local win = vgui.Create("DFrame")
                win:SetTitle("")
                win:SetSize(We(520), He(280))
                win:Center()
                win:MakePopup()
                function win:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.background)
                    UI.Rect(0, 0, w, He(50), THEME.panel)
                    draw.SimpleText(MuR.Language["settings_admin_respawn"] or "Respawn player", "MuR_Font3", We(16), He(25), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local plyBox = vgui.Create("DComboBox", win)
                plyBox:SetPos(We(16), He(70))
                plyBox:SetSize(We(488), He(36))
                plyBox:SetValue(MuR.Language["settings_admin_select_player"] or "Select player")
                for _, ply in player.Iterator() do
                    plyBox:AddChoice(ply:Nick())
                end

                local useCurrent = vgui.Create("DCheckBoxLabel", win)
                useCurrent:SetPos(We(16), He(120))
                useCurrent:SetText(MuR.Language["settings_admin_use_current_role"] or "Use current role")
                useCurrent:SetTextColor(THEME.text)
                useCurrent:SetChecked(true)

                local roleBox = vgui.Create("DComboBox", win)
                roleBox:SetPos(We(16), He(170))
                roleBox:SetSize(We(488), He(36))
                roleBox:SetValue(MuR.Language["settings_admin_choose_role"] or "Choose role")
                roleBox:SetEnabled(false)

                local function fillRoles()
                    local added = {}
                    local function addRole(c)
                        if not isstring(c) or added[c] then return end
                        added[c] = true
                        local map = {
                            Killer = "murderer", Traitor = "traitor", Innocent = "innocent", Defender = "defender",
                            Medic = "medic", Builder = "builder", HeadHunter = "headhunter", Criminal = "criminal",
                            Security = "security", Witness = "witness", Officer = "officer", ArmoredOfficer = "riotpolice",
                            FBI = "fbiagent", Zombie = "zombie", SWAT = "swat", Riot = "riotpolice",
                            Terrorist = "terrorist", Shooter = "shooter", Soldier = "soldier", GangGreen = "ganggreen", GangRed = "gangred",
                            Tony = "tony", Mafia = "mafia"
                        }
                        local key = map[c] or string.lower(c)
                        local label = MuR.Language[key] or c
                        roleBox:AddChoice(label, c)
                    end
                    for id, def in pairs(MuR.Modes or {}) do
                        if isstring(def.kteam) then addRole(def.kteam) end
                        if isstring(def.dteam) then addRole(def.dteam) end
                        if isstring(def.iteam) then addRole(def.iteam) end
                        if istable(def.roles) then
                            for _, r in ipairs(def.roles) do
                                addRole(r.class or r.name)
                            end
                        end
                    end
                end
                fillRoles()

                function useCurrent:OnChange(val)
                    roleBox:SetEnabled(not val)
                end

                local apply = vgui.Create("DButton", win)
                apply:SetPos(We(16), He(220))
                apply:SetSize(We(240), He(36))
                apply:SetText("")
                function apply:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.accent)
                    draw.SimpleText(MuR.Language["settings_admin_apply"] or "Apply", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                function apply:DoClick()
                    local plname = plyBox:GetSelected()
                    if not plname then return end
                    if useCurrent:GetChecked() then
                        RunConsoleCommand("mur_forcespawn", plname)
                    else
                        local _, class = roleBox:GetSelected()
                        if class then
                            RunConsoleCommand("mur_forcespawn", plname, class)
                        else
                            RunConsoleCommand("mur_forcespawn", plname)
                        end
                    end
                    win:Close()
                end

                local cancel = vgui.Create("DButton", win)
                cancel:SetPos(We(264), He(220))
                cancel:SetSize(We(240), He(36))
                cancel:SetText("")
                function cancel:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.panel)
                    draw.SimpleText(MuR.Language["settings_admin_cancel"] or "Cancel", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                function cancel:DoClick()
                    win:Close()
                end
            end
        end)
        table.insert(adminItems, respawnRow)

        local manageRow = addAdminRow(MuR.Language["settings_admin_modes"] or "Manage modes", function(parent)
            local btn = vgui.Create("DButton", parent)
            btn:Dock(RIGHT)
            btn:SetWide(We(220))
            btn:DockMargin(0, He(10), We(20), He(10))
            btn:SetText("")
            function btn:Paint(w, h)
                local hovered = self:IsHovered()
                local color = hovered and THEME.accent or THEME.background
                UI.Rect(0, 0, w, h, color)
                draw.SimpleText(MuR.Language["settings_admin_open"] or "Open", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            function btn:DoClick()
                surface.PlaySound("murdered/vgui/ui_click.wav")
                local win = vgui.Create("DFrame")
                win:SetTitle("")
                win:SetSize(We(720), He(380))
                win:Center()
                win:MakePopup()
                function win:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.background)
                    UI.Rect(0, 0, w, He(50), THEME.panel)
                    draw.SimpleText(MuR.Language["settings_admin_modes"] or "Manage modes", "MuR_Font3", We(16), He(25), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local left = vgui.Create("DListView", win)
                left:SetPos(We(16), He(66))
                left:SetSize(We(320), He(240))
                left:AddColumn(MuR.Language["settings_admin_enabled"] or "Enabled")

                local mid = vgui.Create("DPanel", win)
                mid:SetPos(We(344), He(66))
                mid:SetSize(We(32), He(240))
                function mid:Paint(w,h) end

                local toRight = vgui.Create("DButton", mid)
                toRight:SetText(">>")
                toRight:SetSize(We(32), He(36))
                toRight:SetPos(0, He(70))
                function toRight:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.accent)
                    draw.SimpleText(">>", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                local toLeft = vgui.Create("DButton", mid)
                toLeft:SetText("<<")
                toLeft:SetSize(We(32), He(36))
                toLeft:SetPos(0, He(130))
                function toLeft:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.panel)
                    draw.SimpleText("<<", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                local right = vgui.Create("DListView", win)
                right:SetPos(We(392), He(66))
                right:SetSize(We(312), He(240))
                right:AddColumn(MuR.Language["settings_admin_disabled"] or "Disabled")

                local function syncLists(disabled)
                    left:Clear()
                    right:Clear()
                    local set = {}
                    for k,v in pairs(disabled or {}) do if v then set[tonumber(k)] = true end end
                    for _, id in ipairs(modeIds) do
                        local name = MuR.Language["gamename"..id] or ("Mode "..id)
                        if set[id] then
                            right:AddLine(name).mode_id = id
                        else
                            left:AddLine(name).mode_id = id
                        end
                    end
                end

                local currentDisabled = {}
                local function requestState()
                    net.Start("MuR.ModesStateReq"); net.SendToServer()
                end
                net.Receive("MuR.ModesState", function()
                    currentDisabled = net.ReadTable() or {}
                    syncLists(currentDisabled)
                end)
                requestState()

                function toRight:DoClick()
                    local sel = left:GetSelected()
                    for _, line in ipairs(sel or {}) do
                        if line.mode_id then currentDisabled[line.mode_id] = true end
                    end
                    syncLists(currentDisabled)
                end
                function toLeft:DoClick()
                    local sel = right:GetSelected()
                    for _, line in ipairs(sel or {}) do
                        if line.mode_id then currentDisabled[line.mode_id] = nil end
                    end
                    syncLists(currentDisabled)
                end

                local save = vgui.Create("DButton", win)
                save:SetPos(We(16), He(320))
                save:SetSize(We(340), He(36))
                save:SetText("")
                function save:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.accent)
                    draw.SimpleText(MuR.Language["settings_admin_save"] or "Save", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                function save:DoClick()
                    local payload = {_asSet = {}}
                    for k,v in pairs(currentDisabled or {}) do if v then payload._asSet[tostring(k)] = true end end
                    net.Start("MuR.ModesStateSave")
                    net.WriteTable(payload)
                    net.SendToServer()
                    surface.PlaySound("buttons/button9.wav")
                end

                local close = vgui.Create("DButton", win)
                close:SetPos(We(364), He(320))
                close:SetSize(We(340), He(36))
                close:SetText("")
                function close:Paint(w,h)
                    UI.Rect(0, 0, w, h, THEME.panel)
                    draw.SimpleText(MuR.Language["settings_admin_close"] or "Close", "MuR_Font1", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                function close:DoClick()
                    win:Close()
                end
            end
        end)
        table.insert(adminItems, manageRow)

        do
            net.Start("MuR.ModesStateReq")
            net.SendToServer()
            net.Receive("MuR.ModesState", function()
                local disabled = net.ReadTable() or {}
                for id, cb in pairs(modeCheckboxes) do
                    if IsValid(cb) then
                        cb:SetValue(disabled[id] and 1 or 0)
                    end
                end
            end)
        end
    end

    characterSheet.Tab:SetFont("MuR_Font1")
    killerSheet.Tab:SetFont("MuR_Font1")
    settingsSheet.Tab:SetFont("MuR_Font1")

    for _, setting in ipairs(Settings.Character) do
        CreateControl(characterPanel, setting)
    end

    for _, setting in ipairs(Settings.Settings) do
        CreateControl(settingsPanel, setting)
    end

    local tabButtons = {}
    local tabW = We(FRAME_W) / math.max(#sheetItems, 1)

    local function selectTab(index)
        for i, entry in ipairs(sheetItems) do
            entry.panel:SetVisible(i == index)
            tabButtons[i].Active = (i == index)
        end
    end

    for i, entry in ipairs(sheetItems) do
        local tab = UI.Tab(tabStrip, entry.label, function() selectTab(i) end)
        tab:SetPos((i - 1) * tabW, 0)
        tab:SetSize(tabW, He(UI.TAB))
        tabButtons[i] = tab

        if i > 1 then
            local sep = vgui.Create("DPanel", tabStrip)
            sep:SetPos((i - 1) * tabW, He(8))
            sep:SetSize(1, He(UI.TAB - 16))
            sep.Paint = function(self, w, h) UI.Rect(0, 0, w, h, UI.Colors.line) end
        end
    end

    selectTab(1)

    return frame
end

concommand.Add("open_settings", function()
    OpenSettingsMenu()
end)

hook.Add("PlayerBindPress", "OpenSettingsMenuF1", function(ply, bind, pressed)
    if bind == "gm_showhelp" and pressed then
        OpenSettingsMenu()
        return true
    end
end)

AddSetting("Settings", "slider", MuR.Language["settings_settings_view"], "blsd_viewperson", 0, 2)
AddSetting("Settings", "checkbox", MuR.Language["settings_settings_exec"], "blsd_execution_3rd_person")
AddSetting("Settings", "checkbox", MuR.Language["settings_settings_holdrag"], "blsd_ragdoll_hold_grab")

AddSetting("Settings", "checkbox", MuR.Language["settings_settings_hud"], "blsd_nohud")
AddSetting("Settings", "checkbox", MuR.Language["settings_settings_crossrag"], "blsd_crosshair_ragdoll")
AddSetting("Settings", "checkbox", MuR.Language["settings_settings_chands"], "blsd_chands")
AddSetting("Settings", "checkbox", MuR.Language["settings_settings_tpik"], "blsd_tpik")
AddSetting("Settings", "checkbox", MuR.Language["settings_settings_viewbob"], "blsd_viewbob")

AddSetting("Character", "textentry", MuR.Language["settings_character_namem"], "blsd_character_name_male")
AddSetting("Character", "textentry", MuR.Language["settings_character_namef"], "blsd_character_name_female")
AddSetting("Character", "checkbox", MuR.Language["settings_character_female"], "blsd_character_female")
AddSetting("Character", "slider", MuR.Language["settings_character_tone"], "blsd_character_pitch", 86, 114)
AddSetting("Character", "combobox", MuR.Language["settings_character_exec"], "blsd_character_executionstyle", nil, nil, {
    ["default"] = MuR.Language["settings_character_exec1"],
    ["long_gib"] = MuR.Language["settings_character_exec2"],
    ["long_choke"] = MuR.Language["settings_character_exec3"],
    ["default_knife"] = MuR.Language["settings_character_exec4"],
})
