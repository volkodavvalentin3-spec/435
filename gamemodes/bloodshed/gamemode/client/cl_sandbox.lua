hook.Add("ContextMenuOpen", "MuR.BlockContext", function()
    return MuR.EnableDebug
end)

hook.Add("OnSpawnMenuClose", "SpawnMenuWhitelist", function()
	LocalPlayer().CanOpenSpawnmenu = false
end)

--
-- Обычному игроку spawnmenu открывается только из Q-меню, которое выставляет
-- CanOpenSpawnmenu на один раз.
--
-- Мёртвому админу этот путь закрыт целиком: само Q-меню живёт под проверкой
-- LocalPlayer():Alive() (cl_q_menu.lua), то есть до кнопки он не доходит — а
-- нужен spawnmenu администратору как раз тогда, когда он уже не играет и
-- разбирается с картой. Поэтому для суперадмина открываем напрямую.
--
hook.Add("SpawnMenuOpen", "SpawnMenuWhitelist", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end

	if ply:IsSuperAdmin() and not ply:Alive() then return true end

	return ply.CanOpenSpawnmenu == true
end)

hook.Add("PlayerNoClip", "BlockNoclip", function(ply, desiredState)
    return desiredState == true and false
end)

net.Receive("MuR.NoNodes", function()
    hook.Add("HUDPaint", "MuRNoNodes", function()
        --
        -- В отладке карту гоняют без навмеша намеренно (правят сетку, смотрят
        -- геометрию), и закрывать весь экран чёрным на это время незачем —
        -- хватает строчки сверху.
        --
        -- Проверка внутри отрисовки, а НЕ при получении сообщения: EnableDebug
        -- приезжает с сервера отдельно и может прийти позже, чем NoNodes, плюс
        -- его переключают прямо на живой карте.
        --
        if MuR.EnableDebug then
            draw.SimpleTextOutlined(MuR.Language["gui_nonodes1"], "MuR_Font1",
                ScrW()/2, He(6), Color(220,60,60), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP,
                1, Color(0,0,0,220))
            return
        end

        surface.SetDrawColor(0,0,0,250)
        surface.DrawRect(0,0,ScrW(),ScrH())
        draw.SimpleText(MuR.Language["gui_nonodes1"], "MuR_Font5", ScrW()/2, ScrH()/2-He(25), Color(200,20,20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(MuR.Language["gui_nonodes2"], "MuR_Font2", ScrW()/2, ScrH()/2+He(10), Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end)

local ICON_SIZE    = 60
local HOLD_TIME    = 0.3
local circMat = Material("hud/bammo/circle.png")
local AmmoSprites = {
    ["Pistol"]                  = "Pistol",
    ["Buckshot"]                = "buckshot",
    ["357"]                = "Pistol",
    ["SMG1"]                    = "Pistol",
    ["AR2"]                     = "rifle",
    ["SniperRound"]             = "rifle",
    ["SniperPenetratedRound"]   = "rifle",
    ["RPG_Round"]               = "rpground",
    ["SMG1_Grenade"]            = "buckshot",
    ["Grenade"]                 = "grenade",
}
local isHolding = false

hook.Add("Think", "AmmoHud_KeyHold", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if input.IsKeyDown(KEY_E) then
        if not isHolding then
            isHolding = true
            ply._AmmoHoldStart = CurTime()
        elseif CurTime() - ply._AmmoHoldStart >= HOLD_TIME then
            ply._ShowAmmo      = true
            if ply._ShowAmmoStart == 0 then
                ply._ShowAmmoStart = CurTime()
            end
        end
    else
        isHolding     = false
        ply._ShowAmmo = false
        ply._ShowAmmoStart = 0
    end
end)

hook.Add("HUDPaint", "AmmoHud_Drawing", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply._ShowAmmo then return end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return end

    local clip      = weapon:Clip1()
    if clip < 0 then return end
    local maxClip   = weapon:GetMaxClip1()
    local ammoName  = game.GetAmmoName(weapon:GetPrimaryAmmoType())
    local spriteKey = AmmoSprites[ammoName]
    if not spriteKey then return end

    local progress = math.min((CurTime() - ply._ShowAmmoStart) / 0.5, 1)
    local alpha    = 255*progress

    local vm   = ply:GetViewModel()
    local att  = vm:GetAttachment(1)
    if not att then return end
    local pos3D = att.Pos - att.Ang:Forward() * 5
    local pos2D = pos3D:ToScreen()

    surface.SetDrawColor(255, 255, 255, alpha * 0.5)
    surface.SetMaterial(circMat)
    surface.DrawTexturedRect(pos2D.x - ICON_SIZE-4, pos2D.y-4, ICON_SIZE+8, ICON_SIZE+8)

    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(Material("hud/bammo/" .. spriteKey .. "Cont.png"))
    surface.DrawTexturedRect(pos2D.x - ICON_SIZE, pos2D.y, ICON_SIZE, ICON_SIZE)

    local fillH = ICON_SIZE * (clip / maxClip)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(Material("hud/bammo/" .. spriteKey .. ".png"))
    surface.DrawTexturedRectUV(pos2D.x - ICON_SIZE, pos2D.y + ICON_SIZE - fillH, ICON_SIZE, fillH, 0, (maxClip - clip) / maxClip, 1, 1)

    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(Material("hud/bammo/" .. spriteKey .. ".png"))
    surface.DrawTexturedRect(ScrW() - 200, ScrH() - 100, ICON_SIZE, ICON_SIZE)

    local reserve = weapon.ShotgunReload and weapon:Ammo1() or math.ceil(weapon:Ammo1() / maxClip)
    draw.SimpleText("~ " .. reserve, "MuR_Font3", ScrW() - 200 + ICON_SIZE + 10, ScrH() - 100 + ICON_SIZE / 2, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local mode = weapon.GetFireModeName and weapon:GetFireModeName() or "Semi-Auto"
    draw.SimpleText(mode, "MuR_Font2", pos2D.x - ICON_SIZE/2, pos2D.y, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end)
