local alpha = 0

local help_sounds = {
    "vo/npc/male01/gethellout.wav",
    "vo/npc/female01/gethellout.wav",
    "vo/npc/male01/runforyourlife01.wav",
    "vo/npc/male01/runforyourlife02.wav",
    "vo/npc/male01/runforyourlife03.wav",
    "vo/npc/female01/runforyourlife01.wav",
    "vo/npc/female01/runforyourlife02.wav",
    "vo/npc/male01/watchout.wav",
    "vo/npc/male01/behindyou01.wav",
    "vo/npc/male01/behindyou02.wav",
    "vo/npc/female01/watchout.wav",
    "vo/npc/female01/behindyou01.wav",
    "vo/npc/female01/behindyou02.wav",
    "vo/npc/male01/help01.wav",
    "vo/npc/female01/help01.wav",
}
net.Receive("MuR.WeaponryEffect", function()
    local ply = LocalPlayer()
    local num = net.ReadInt(32)
    local pos = ply:GetPos()
    pos = pos+Vector(math.random(-200,200), math.random(-200,200), 0)
    local pos2 = ply:GetPos()+VectorRand(-1000,1000)
    if num == 1 or num == 2 or num == 3 then
        ply:EmitSound(")murdered/weapons/grenade/m67_explode.wav", 120, math.random(80,120))
        util.ScreenShake(pos, 25, 25, 3, 2000)
        ParticleEffect("AC_grenade_explosion", pos, Angle(0,0,0))
        ParticleEffect("AC_grenade_explosion_air", pos, Angle(0,0,0))
        util.Decal("Scorch", pos, pos-Vector(0,0,8), ply)
        if math.random(1,4) >= 2 then
            RunConsoleCommand("mur_ragdoll")
        end
    elseif num == 4 or num == 5 or num == 6 then
        local snd = "murdered/weapons/melee/knife_bayonet_swing" .. math.random(1, 2) .. ".wav"
        local snd2 = "murdered/weapons/melee/knife_bayonet_hit" .. math.random(1, 2) .. ".wav"

        ply:EmitSound(snd)
        timer.Simple(0.2, function()
            ply:EmitSound(snd2)
            if math.random(1,3) == 1 then
                RunConsoleCommand("mur_ragdoll")
            end
        end)
    elseif num == 7 or num == 8 then
        if math.random(1,6) == 1 then
            ply:EmitSound(")murdered/player/other/jihad"..math.random(1,2)..".wav", 60)
        end
        timer.Simple(0.01, function()
            ply:EmitSound("murdered/weapons/grenade/ied.wav", 60)
        end)
        timer.Simple(0.7, function()
            ply:EmitSound(")murdered/weapons/grenade/m67_explode.wav", 120, math.random(80,120))
            util.ScreenShake(pos, 25, 25, 3, 2000)
            ParticleEffect("AC_grenade_explosion", pos, Angle(0,0,0))
            ParticleEffect("AC_grenade_explosion_air", pos, Angle(0,0,0))
            util.Decal("Scorch", pos, pos-Vector(0,0,8), ply)
            RunConsoleCommand("mur_ragdoll")
        end)
    elseif num == 9 or num == 10 then
        ply:ScreenFade(SCREENFADE.IN, color_black, 0.01, 3)
        ply:ConCommand("soundfade 100 3")
    elseif num == 11 or num == 12 or num == 13 then
        if math.random(1,5) >= 3 then
            sound.Play(table.Random(help_sounds), pos2, 90, math.random(90,110))
        end
        if math.random(1,5) >= 3 then
            timer.Simple(2, function()
                local snd = ")murdered/weapons/melee/knife_bayonet_swing" .. math.random(1, 2) .. ".wav"
                local snd2 = ")murdered/weapons/melee/knife_bayonet_hit" .. math.random(1, 2) .. ".wav"

                sound.Play(snd, pos2, 90, math.random(90,110))
                timer.Simple(0.2, function()
                    sound.Play(snd2, pos2, 90, math.random(90,110))
                end)
            end)
        end
        if math.random(1,5) >= 3 then
            timer.Simple(3, function()
                local snd = ")murdered/weapons/melee/knife_bayonet_swing" .. math.random(1, 2) .. ".wav"
                local snd2 = ")murdered/weapons/melee/knife_bayonet_hit" .. math.random(1, 2) .. ".wav"

                sound.Play(snd, pos2, 90, math.random(90,110))
                timer.Simple(0.2, function()
                    sound.Play(snd2, pos2, 90, math.random(90,110))
                end)
            end)
        end
    elseif num == 14 or num == 15 or num == 16 or num == 17 or num == 18 then
        local snd = "doors/door_latch3.wav"
        local snd2 = "doors/door_squeek1.wav"
        if math.random(1,4) == 1 then
            snd = "physics/wood/wood_box_impact_hard"..math.random(1,6)..".wav"
            snd2 = "physics/wood/wood_box_break"..math.random(1,2)..".wav"
        elseif math.random(1,4) == 1 then
            snd = "physics/wood/wood_box_impact_hard"..math.random(1,6)..".wav"
            snd2 = "ambient/materials/door_hit1.wav"
        elseif math.random(1,4) == 1 then
            snd = "ZippyGore3OnGib"
            snd2 = "ZippyGore3OnRootBoneGib"
        end

        sound.Play(snd, pos2, 90, math.random(90,110))
        timer.Simple(0.3, function()
            sound.Play(snd2, pos2, 90, math.random(90,110))
        end)
    end
end)

local adminvision = false
local showPlayerDots = true
local showTrapDots = true
local showPlayerInfo = true
local maxDrawDistance = 3000

local trapColor = Color(255, 50, 50, 255)
local deadPlayerColor = Color(100, 100, 100, 150)

hook.Add("HUDPaint", "MuR_ShowcaseRolesAdmin", function()
    if not MuR.DrawHUD or not adminvision then return end

    local localPlayer = LocalPlayer()
    local localPos = localPlayer:GetPos()

    if showPlayerDots then
        for _, ply in player.Iterator() do
            if ply != localPlayer and IsValid(ply) then
                DrawPlayerDot(ply, localPos, localPlayer)
            end
        end
    end

    if showTrapDots then
        DrawTraps(localPos, localPlayer)
    end

    if showPlayerInfo then
        DrawPlayerInfo(localPlayer)
    end
end)

function DrawPlayerDot(ply, localPos, localPlayer)
    local plyPos = ply:GetPos() + Vector(0, 0, 40)
    local distance = localPos:Distance(plyPos)

    if distance > maxDrawDistance then return end

    local tr = util.TraceLine({
        start = localPos + Vector(0, 0, 64),
        endpos = plyPos,
        filter = {localPlayer, ply},
        mask = MASK_SHOT
    })

    local isVisible = not tr.Hit or tr.Entity == ply
    local screenPos = plyPos:ToScreen()

    if not screenPos.visible then return end

    local dotColor = Color(255, 255, 255)

    if not ply:Alive() then
        dotColor = deadPlayerColor
    else
        local role = ply:GetNW2String("Class", "Unknown")
        local roleData = MuR:GetRole(role)
        if roleData and roleData.color then
            dotColor = Color(roleData.color.r, roleData.color.g, roleData.color.b, roleData.color.a)
        else
            dotColor = Color(150, 255, 150, 200)
        end
    end

    local dotSize = 8
    if not isVisible then
        dotSize = 6
        dotColor.a = 180
    end

    surface.SetDrawColor(dotColor)
    surface.DrawRect(screenPos.x - dotSize/2, screenPos.y - dotSize/2, dotSize, dotSize)

    surface.SetDrawColor(0, 0, 0, dotColor.a)
    surface.DrawOutlinedRect(screenPos.x - dotSize/2, screenPos.y - dotSize/2, dotSize, dotSize)
end

function DrawTraps(localPos, localPlayer)

    for _, ent in ents.Iterator() do
        if IsValid(ent) then
            local isTrap = false
            local trapType = "Unknown"

            if ent:GetClass() == "trap_entity" then
                isTrap = true
                trapType = "Floor Trap"
            elseif ent:GetClass() == "murwep_grenade" then
                isTrap = true
                trapType = "Tripwire"
            end

            if isTrap then
                DrawTrapDot(ent, trapType, localPos, localPlayer)
            end
        end
    end
end

function DrawTrapDot(trap, trapType, localPos, localPlayer)
    local trapPos = trap:GetPos() + Vector(0, 0, 10)
    local distance = localPos:Distance(trapPos)

    if distance > maxDrawDistance then return end

    local screenPos = trapPos:ToScreen()
    if not screenPos.visible then return end

    local dotSize = math.Clamp(12 - distance/200, 4, 12)

    surface.SetDrawColor(trapColor)
    surface.DrawRect(screenPos.x - dotSize/2, screenPos.y - dotSize/2, dotSize, dotSize)

    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawOutlinedRect(screenPos.x - dotSize/2, screenPos.y - dotSize/2, dotSize, dotSize)

    surface.SetDrawColor(255, 255, 255, 200)
    surface.DrawLine(screenPos.x - 2, screenPos.y - 2, screenPos.x + 2, screenPos.y + 2)
    surface.DrawLine(screenPos.x - 2, screenPos.y + 2, screenPos.x + 2, screenPos.y - 2)
end

function DrawPlayerInfo(localPlayer)
    local tr = localPlayer:GetEyeTrace()
    local ply = tr.Entity

    if not IsValid(ply) or not ply:IsPlayer() then return end

    local pos = (tr.HitPos - Vector(0,0,16)):ToScreen()
    local distance = localPlayer:GetPos():Distance(ply:GetPos())

    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(pos.x - 80, pos.y + 8, 160, 80)

    surface.SetDrawColor(100, 100, 100, 255)
    surface.DrawOutlinedRect(pos.x - 80, pos.y + 8, 160, 80)

    draw.SimpleText(ply:Nick(), "DermaDefault", pos.x, pos.y + 12, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)

    local role = ply:GetNW2String("Class", "Unknown")
    local roleData = MuR:GetRole(role)
    local roleColor = (roleData and roleData.color) or Color(255, 255, 255, 200)
    draw.SimpleText(role, "DermaDefault", pos.x, pos.y + 24, roleColor, TEXT_ALIGN_CENTER)

    if ply:Alive() then
        local healthColor = Color(255 - (ply:Health() * 2.55), ply:Health() * 2.55, 0)
        draw.SimpleText("HP: " .. ply:Health() .. "/" .. ply:GetMaxHealth(), "DermaDefault", pos.x, pos.y + 36, healthColor, TEXT_ALIGN_CENTER)

        if ply:Armor() > 0 then
            draw.SimpleText("Armor: " .. ply:Armor(), "DermaDefault", pos.x, pos.y + 48, Color(100, 150, 255), TEXT_ALIGN_CENTER)
        end
    end

    draw.SimpleText("Distance: " .. math.Round(distance) .. "u", "DermaDefault", pos.x, pos.y + 60, Color(200, 200, 200), TEXT_ALIGN_CENTER)

    local weapon = ply:GetActiveWeapon()
    if IsValid(weapon) then
        local weaponName = weapon:GetPrintName() or weapon:GetClass()
        draw.SimpleText("Weapon: " .. weaponName, "DermaDefault", pos.x, pos.y + 72, Color(255, 200, 100), TEXT_ALIGN_CENTER)
    end
end

concommand.Add("mur_visionadmin", function(ply)
    if not ply:IsSuperAdmin() then return end
    adminvision = not adminvision

    if adminvision then
        chat.AddText(Color(20, 200, 20), "[Admin Vision] ", Color(255, 255, 255), "Enabled")
    else
        chat.AddText(Color(200, 20, 20), "[Admin Vision] ", Color(255, 255, 255), "Disabled")
    end
end)

concommand.Add("mur_vision_distance", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end

    local newDistance = tonumber(args[1])
    if newDistance and newDistance > 0 and newDistance <= 10000 then
        maxDrawDistance = newDistance
        chat.AddText(Color(100, 150, 255), "[Admin Vision] ", Color(255, 255, 255), "Max distance set to " .. newDistance .. " units")
    else
        chat.AddText(Color(200, 20, 20), "[Admin Vision] ", Color(255, 255, 255), "Invalid distance. Use: mur_vision_distance [1-10000]")
    end
end)

local ICON_SNIPER = Material("murdered/sniper.png", "mips")
local ICON_HELI = Material("murdered/heli.png", "mips")

local animations = {
    sniper = {
        active = false,
        alpha = 0,
        scale = 1,
        rotation = 0
    },
    heli = {
        active = false,
        alpha = 0,
        scale = 1,
        rotation = 0
    }
}

local COLOR_TEXT = Color(255, 255, 255, 255)
local COLOR_ICON_SNIPER = Color(255, 255, 255)
local COLOR_ICON_HELI = Color(255, 255, 255)

local ANIM_SPEED = 3
local PULSE_SPEED = 2

hook.Add("HUDPaint", "MuR_NotificationIcons", function()
    if !MuR.DrawHUD or MuR:GetClient("blsd_nohud") then return end

    local currentTime = CurTime()
    local baseX, baseY = We(20), He(120)
    local iconSize = We(72)
    local spacing = We(10)

    if MuR.Data["SniperArrived"] ~= animations.sniper.active then
        animations.sniper.active = MuR.Data["SniperArrived"]
        if MuR.Data["SniperArrived"] then
            animations.sniper.alpha = 0
            animations.sniper.scale = 0.5
            animations.sniper.rotation = -45
        end
    end

    if MuR.Data["HeliArrived"] ~= animations.heli.active then
        animations.heli.active = MuR.Data["HeliArrived"]
        if MuR.Data["HeliArrived"] then
            animations.heli.alpha = 0
            animations.heli.scale = 0.5
            animations.heli.rotation = 45
        end
    end

    local deltaTime = FrameTime() * ANIM_SPEED

    if animations.sniper.active then
        animations.sniper.alpha = Lerp(deltaTime * 2, animations.sniper.alpha, 1)
        animations.sniper.scale = Lerp(deltaTime * 3, animations.sniper.scale, 1 + 0.1 * math.sin(currentTime * PULSE_SPEED))
        animations.sniper.rotation = Lerp(deltaTime * 3, animations.sniper.rotation, 0)
    else
        animations.sniper.alpha = Lerp(deltaTime, animations.sniper.alpha, 0)
    end

    if animations.heli.active then
        animations.heli.alpha = Lerp(deltaTime * 2, animations.heli.alpha, 1)
        animations.heli.scale = Lerp(deltaTime * 3, animations.heli.scale, 1 + 0.1 * math.sin(currentTime * PULSE_SPEED + 1))
        animations.heli.rotation = Lerp(deltaTime * 3, animations.heli.rotation, 0)
    else
        animations.heli.alpha = Lerp(deltaTime, animations.heli.alpha, 0)
    end

    local currentX = baseX
    local iconsVisible = 0

    if animations.sniper.alpha > 0.01 then
        local iconX = currentX + (iconSize / 2)
        local iconY = baseY + (iconSize / 2)

        surface.SetDrawColor(COLOR_ICON_SNIPER.r, COLOR_ICON_SNIPER.g, COLOR_ICON_SNIPER.b, COLOR_ICON_SNIPER.a * animations.sniper.alpha)
        surface.SetMaterial(ICON_SNIPER)

        local scaledSize = iconSize * animations.sniper.scale

        surface.DrawTexturedRectRotated(
            iconX,
            iconY,
            scaledSize,
            scaledSize,
            animations.sniper.rotation
        )

        currentX = currentX + iconSize + spacing
        iconsVisible = iconsVisible + 1
    end

    if animations.heli.alpha > 0.01 then
        local iconX = currentX + (iconSize / 2)
        local iconY = baseY + (iconSize / 2)

        surface.SetDrawColor(COLOR_ICON_HELI.r, COLOR_ICON_HELI.g, COLOR_ICON_HELI.b, COLOR_ICON_HELI.a * animations.heli.alpha)
        surface.SetMaterial(ICON_HELI)

        local scaledSize = iconSize * animations.heli.scale

        surface.DrawTexturedRectRotated(
            iconX,
            iconY,
            scaledSize,
            scaledSize,
            animations.heli.rotation
        )

        currentX = currentX + iconSize + spacing
        iconsVisible = iconsVisible + 1
    end

    if iconsVisible > 0 then
        local alertText = ""
        local textAlpha = 0

        if animations.sniper.active and animations.heli.active then
            alertText = MuR.Language["police_backup_helisniper"]
            textAlpha = math.max(animations.sniper.alpha, animations.heli.alpha)
        elseif animations.sniper.active then
            alertText = MuR.Language["police_backup_sniper"]
            textAlpha = animations.sniper.alpha
        elseif animations.heli.active then
            alertText = MuR.Language["police_backup_heli"]
            textAlpha = animations.heli.alpha
        end

        draw.SimpleText(
            alertText,
            "MuR_Font1",
            currentX,
            baseY + (iconSize / 2),
            Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, COLOR_TEXT.a * textAlpha),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end
end)
