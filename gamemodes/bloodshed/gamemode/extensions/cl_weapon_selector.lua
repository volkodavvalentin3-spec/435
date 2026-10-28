local SOUND_SCROLL = "scroll_bar/scroll.ogg"
local SOUND_SELECT = "scroll_bar/select.ogg"
local SOUND_CANCEL = ""
local AUTO_CLOSE_DELAY = 3
local MAX_SLOTS = 6

local COLOR_HIGHLIGHT = Color(150, 0, 0)
local COLOR_BG = Color(50, 50, 50)
local COLOR_BG_TRANSPARENT = Color(50, 50, 50, 150)
local COLOR_BG_DARK = Color(30, 30, 30)

local UI_CONFIG = {
    cardWidth = 150,
    cardHeight = 30,
    cardMargin = 5
}

local isOpen = false
local animProgress = 0
local selectedSlot = 1
local selectedWeaponIndex = 1
local weaponSlots = {}

for i = 1, MAX_SLOTS do
    weaponSlots[i] = {}
end

local cv_drawhud = GetConVar("cl_drawhud")
local function UpdateWeaponList()
    for i = 1, MAX_SLOTS do
        weaponSlots[i] = {}
    end

    for _, weapon in ipairs(LocalPlayer():GetWeapons()) do
        local slot = weapon:GetSlot() + 1
        if slot <= MAX_SLOTS then
            table.insert(weaponSlots[slot], {
                entity = weapon,
                class = weapon:GetClass(),
                name = utf8.sub(language.GetPhrase(weapon:GetPrintName()), 1, 22),
                hoverAnimation = 0
            })
        end
    end

    for _, slotWeapons in ipairs(weaponSlots) do
        table.sort(slotWeapons, function(a, b)
            local posA = a.entity:GetSlotPos()
            local posB = b.entity:GetSlotPos()
            if posA ~= posB then
                return posA < posB
            end
            return a.entity:GetPrintName() < b.entity:GetPrintName()
        end)
    end
end
local function ShouldDraw()
    if not cv_drawhud:GetBool() then return true end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return true end
    if ply:InVehicle() and (not ply:GetAllowWeaponsInVehicle() or ply:GetVehicle():GetThirdPersonMode()) then return true end
    if #ply:GetWeapons() <= 0 then return true end
    return false
end

local function FindCurrentWeapon()
    local activeWeapon = LocalPlayer():GetActiveWeapon()
    if not IsValid(activeWeapon) then return 1, 1 end

    local class = activeWeapon:GetClass()
    local slot = activeWeapon:GetSlot() + 1

    if slot > MAX_SLOTS then slot = 1 end

    local index = 1
    for i, weaponData in ipairs(weaponSlots[slot]) do
        if weaponData.class == class then
            index = i
            break
        end
    end

    return slot, index
end
local function ToggleSelector(state)
    if state and ShouldDraw() then return end

    if state then
        timer.Create("dbgWeaponSelector.autoClose", AUTO_CLOSE_DELAY, 1, function()
            if not isOpen then return end
            ToggleSelector(false)
            LocalPlayer():EmitSound(SOUND_CANCEL, nil, nil, 0.15)
        end)
    else
        timer.Remove("dbgWeaponSelector.autoClose")
    end

    if isOpen == state then return end

    if state then
        UpdateWeaponList()
        selectedSlot, selectedWeaponIndex = FindCurrentWeapon()
    else
        isOpen = false
    end
    isOpen = state
end

local function GetNextSlot(direction)
    local nextSlot = ((selectedSlot + direction - 1) % MAX_SLOTS) + 1
    local loops = 0
    while #weaponSlots[nextSlot] == 0 and loops < MAX_SLOTS do
        nextSlot = ((nextSlot + direction - 1) % MAX_SLOTS) + 1
        loops = loops + 1
    end
    return nextSlot
end

local function CycleWeapon(direction)
    if not isOpen then return end

    selectedWeaponIndex = selectedWeaponIndex + direction

    if selectedWeaponIndex > #weaponSlots[selectedSlot] then
        selectedSlot = GetNextSlot(direction)
        selectedWeaponIndex = 1
    elseif selectedWeaponIndex < 1 then
        selectedSlot = GetNextSlot(direction)
        selectedWeaponIndex = #weaponSlots[selectedSlot]
    end

    LocalPlayer():EmitSound(SOUND_SCROLL, nil, math.random(95, 105), 0.15)
    timer.Adjust("dbgWeaponSelector.autoClose", AUTO_CLOSE_DELAY)
end

local function SelectSlot(slot)
    if not isOpen then return end

    if slot ~= selectedSlot then
        selectedSlot = slot
        selectedWeaponIndex = 1
    else
        selectedWeaponIndex = selectedWeaponIndex + 1
    end

    if not weaponSlots[selectedSlot] or #weaponSlots[selectedSlot] <= 0 then
        ToggleSelector(false)
        return
    end

    if selectedWeaponIndex > #weaponSlots[selectedSlot] then
        selectedWeaponIndex = 1
    end

    LocalPlayer():EmitSound(SOUND_SCROLL, nil, math.random(95, 105), 0.15)
    timer.Adjust("dbgWeaponSelector.autoClose", AUTO_CLOSE_DELAY)
end
local Binds = {
    ["invprev"] = function(ply)
        if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) then return end
        ToggleSelector(true)
        CycleWeapon(-1)
        return true
    end,
    ["invnext"] = function(ply)
        if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) then return end
        ToggleSelector(true)
        CycleWeapon(1)
        return true
    end,
    ["slot"] = function(ply, bind, slotIndex)
        ToggleSelector(true)
        SelectSlot(slotIndex)
        return true
    end,
    ["lastinv"] = function(ply)
        local prevWeapon = ply:GetPreviousWeapon()
        if IsValid(prevWeapon) and prevWeapon:IsWeapon() then
            input.SelectWeapon(prevWeapon)
        end
        return true
    end,
    ["cancelselect"] = function(ply)
        ToggleSelector(false)
        ply:EmitSound(SOUND_CANCEL, nil, nil, 0.15)
        return true
    end,
    ["+attack"] = function(ply)
        if not isOpen then return end

        local slotData = weaponSlots[selectedSlot]
        if not slotData then return end

        local weaponData = slotData[selectedWeaponIndex]
        if not weaponData or not IsValid(weaponData.entity) then return end

        input.SelectWeapon(weaponData.entity)
        weaponData.isSelected = true
        ply:EmitSound(SOUND_SELECT, nil, nil, 0.15)
        ToggleSelector(false)
        return true
    end,
    ["+attack2"] = function(ply)
        if not isOpen then return end
        ToggleSelector(false)
        ply:EmitSound(SOUND_CANCEL, nil, nil, 0.15)
        return true
    end
}

hook.Add("PlayerBindPress", "dbgWeaponSelector", function(ply, bind, pressed)
    if not pressed or not ply:Alive() or (ply:InVehicle() and not ply:GetAllowWeaponsInVehicle()) or vgui.CursorVisible() then
        return
    end

    bind = string.lower(bind)
    if string.sub(bind, 1, 4) == "slot" then
        local slotIndex = tonumber(string.sub(bind, 5))
        return Binds["slot"](ply, bind, slotIndex)
    else
        local func = Binds[bind]
        return func and func(ply) or nil
    end
end)

surface.CreateFont("dbgWeaponSelector.slot", {font = "Roboto Bold", extended = true, size = 18, weight = 300})
surface.CreateFont("dbgWeaponSelector.weapon", {font = "Roboto Regular", extended = true, size = 18, weight = 300})
local function DrawWeaponCard(x, y, data, isSelected)
    data.hoverAnimation = math.Approach(data.hoverAnimation, isSelected and 1 or 0, FrameTime() * (isSelected and 8 or 4))

    if data.hoverAnimation > 0 then
        local alpha = data.hoverAnimation * 255
        local highlightColor = Color(COLOR_HIGHLIGHT.r, COLOR_HIGHLIGHT.g, COLOR_HIGHLIGHT.b, alpha)
        draw.RoundedBox(4, x - 2, y - 2, UI_CONFIG.cardWidth + 4, UI_CONFIG.cardHeight + 4, highlightColor)
    end

    if isSelected then
        draw.RoundedBox(4, x, y, UI_CONFIG.cardWidth, UI_CONFIG.cardHeight, COLOR_HIGHLIGHT)
        if not data.isSelected then
            draw.RoundedBox(4, x + 1, y + 1, UI_CONFIG.cardWidth - 2, UI_CONFIG.cardHeight - 2, COLOR_BG_TRANSPARENT)
        end
    else
        draw.RoundedBox(4, x, y, UI_CONFIG.cardWidth, UI_CONFIG.cardHeight, COLOR_BG)
        draw.RoundedBox(4, x + 1, y + 1, UI_CONFIG.cardWidth - 2, UI_CONFIG.cardHeight - 2, COLOR_BG_DARK)
    end

    draw.SimpleText(
        data.name,
        "MuR_Font1",
        x + UI_CONFIG.cardWidth / 2,
        y + UI_CONFIG.cardHeight / 2,
        color_white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end
hook.Add("PostDrawHUD", "dbgWeaponSelector", function()
    animProgress = math.Approach(animProgress, isOpen and 1 or 0, FrameTime() * (isOpen and 8 or 4))

    if animProgress <= 0 then return end

    local ease = -animProgress * animProgress + 2 * animProgress
    local yOffset = math.ceil((1 - ease) * -30)

    surface.SetAlphaMultiplier(ease)

    local activeSlots = 0
    for _, slotWeapons in ipairs(weaponSlots) do
        if #slotWeapons > 0 then
            activeSlots = activeSlots + 1
        end
    end

    local totalWidth = (UI_CONFIG.cardWidth + UI_CONFIG.cardMargin) * activeSlots - UI_CONFIG.cardMargin
    local currentX = (ScrW() - totalWidth) / 2
    local startY = 30

    for slotIndex, slotWeapons in ipairs(weaponSlots) do
        if #slotWeapons > 0 then
            for i = #slotWeapons, 1, -1 do
                local weaponData = slotWeapons[i]
                local y = startY + (UI_CONFIG.cardHeight + UI_CONFIG.cardMargin) * (i - 1) + yOffset
                DrawWeaponCard(currentX, y, weaponData, slotIndex == selectedSlot and selectedWeaponIndex == i)
            end

            local slotX = currentX + UI_CONFIG.cardWidth / 2
            local slotY = 12
            draw.RoundedBox(4, slotX - 14, -8, 28, slotY + 21, COLOR_BG)
            draw.RoundedBox(4, slotX - 13, -8, 26, slotY + 20, COLOR_BG_DARK)
            draw.SimpleText(slotIndex, "dbgWeaponSelector.slot", slotX, slotY, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            currentX = currentX + UI_CONFIG.cardWidth + UI_CONFIG.cardMargin
        end
    end

    surface.SetAlphaMultiplier(1)
end)
hook.Add(
    "HUDShouldDraw",
    "dbgWeaponSelector",
    function(e)
        if e == "CHudWeaponSelection" then
            return false
        end
    end
)
