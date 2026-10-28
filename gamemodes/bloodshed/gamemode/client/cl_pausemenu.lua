local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(y) return y * (ScrH() / 1080) end

MuR = MuR or {}

local THEME = {
    bg = Color(15, 15, 15, 240),
    accent = Color(220, 60, 60, 255),
    text = Color(240, 240, 240, 255),
    danger = Color(255, 70, 70, 255),
}

local blur = Material("pp/blurscreen")
local function DrawBlur(panel, strength)
    local x, y = panel:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(blur)
    for i = 1, 3 do
        blur:SetFloat("$blur", (i / 3) * (strength or 6))
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

local function RestoreScreenClicker()
    if MuR.PauseMenuPrevScreenClicker ~= nil then
        gui.EnableScreenClicker(MuR.PauseMenuPrevScreenClicker)
    else
        gui.EnableScreenClicker(false)
    end
end

local function ClosePauseMenu()
    if not IsValid(MuR.PauseMenu) then
        gui.EnableScreenClicker(false)
        return
    end

    local menu = MuR.PauseMenu
    MuR.PauseMenu = nil

    if IsValid(menu) then
        menu:AlphaTo(0, 0.15, 0, function()
            if IsValid(menu) then
                menu:Remove()
            end
        end)
    end

    RestoreScreenClicker()
end

local function CreatePauseButton(parent, text, onClick, opts)
    opts = opts or {}

    local btn = vgui.Create("DButton", parent)
    btn:SetTall(He(50))
    btn:SetText("")
    btn.HoverProgress = 0

    btn.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        self.HoverProgress = Lerp(FrameTime() * 12, self.HoverProgress, hovered and 1 or 0)

        local accent = opts.danger and THEME.danger or THEME.accent
        local r = Lerp(self.HoverProgress, THEME.text.r, accent.r)
        local g = Lerp(self.HoverProgress, THEME.text.g, accent.g)
        local b = Lerp(self.HoverProgress, THEME.text.b, accent.b)
        local textColor = Color(r, g, b, 255)

        if self.HoverProgress > 0.01 then
            surface.SetDrawColor(accent.r, accent.g, accent.b, self.HoverProgress * 255)
            surface.DrawRect(0, 0, We(4), h)
        end

        local textX = We(20) + (self.HoverProgress * We(10))
        draw.SimpleText(text, "MuR_Font3", textX, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        if onClick then
            onClick()
        end
    end

    return btn
end

local function RequestQuit()
    if gui.IsGameUIVisible() then
        RunConsoleCommand("gamemenucommand", "quit")
        RunConsoleCommand("gamemenucommand", "quitnoconfirm")
        return
    end

    gui.ActivateGameUI()
    timer.Simple(0.05, function()
        RunConsoleCommand("gamemenucommand", "quit")
        RunConsoleCommand("gamemenucommand", "quitnoconfirm")
    end)
end

local function OpenPauseMenu()
    if IsValid(MuR.PauseMenu) then
        MuR.PauseMenu:Remove()
    end

    MuR.PauseMenuPrevScreenClicker = vgui.CursorVisible()

    local frame = vgui.Create("DFrame")
    MuR.PauseMenu = frame
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.15, 0)

    gui.EnableScreenClicker(true)
    gui.HideGameUI()

    frame.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then
            ClosePauseMenu()
        end
    end

    frame.Paint = function(self, w, h)
        DrawBlur(self, 5)
        local leftW = We(1920)
        draw.RoundedBox(0, 0, 0, leftW, h, THEME.bg)
    end

    local logo = vgui.Create("DImage", frame)
    logo:SetImage("murdered/logo.png")
    logo:SetSize(We(550), He(290))
    logo:SetPos(We(250), He(150))

    local buttonPanel = vgui.Create("DPanel", frame)
    buttonPanel:SetSize(We(360), ScrH() - He(250))
    buttonPanel:SetPos(We(250), He(650))
    buttonPanel.Paint = nil

    local buttons = {
        {
            text = MuR.Language["pause_menu_resume"] or "Resume",
            action = ClosePauseMenu,
        },
        {
            text = MuR.Language["pause_menu_settings"] or "Bloodshed Settings",
            action = function()
                ClosePauseMenu()
                RunConsoleCommand("open_settings")
            end,
        },
        {
            text = MuR.Language["pause_menu_original"] or "Original Menu",
            action = function()
                ClosePauseMenu()
                gui.ActivateGameUI()
            end,
        },
        {
            text = MuR.Language["pause_menu_disconnect"] or "Disconnect",
            action = function()
                ClosePauseMenu()
                RunConsoleCommand("disconnect")
            end,
            danger = true,
        },
        {
            text = MuR.Language["pause_menu_quit"] or "Quit Game",
            action = function()
                ClosePauseMenu()
                RequestQuit()
            end,
            danger = true,
        },
    }

    local y = 0
    for _, data in ipairs(buttons) do
        local btn = CreatePauseButton(buttonPanel, data.text, data.action, { danger = data.danger })
        btn:SetPos(0, y)
        btn:SetWide(buttonPanel:GetWide())
        y = y + btn:GetTall() + He(8)
    end
end

hook.Add("OnPauseMenuShow", "MuR.CustomPauseMenu", function()
    if IsValid(MuR.PauseMenu) then
        ClosePauseMenu()
        return false
    end
    OpenPauseMenu()
    return false
end)

hook.Add("OnPauseMenuHide", "MuR.CustomPauseMenu", function()
    ClosePauseMenu()
end)

concommand.Add("mur_pausemenu", function()
    if IsValid(MuR.PauseMenu) then
        ClosePauseMenu()
    else
        OpenPauseMenu()
    end
end)
