MuR.RegisterMode(20, {
    name = "Half-Life 2: Firefight",
    chance = 5,
    need_players = 4,
    disables = true,
    custom_spawning = true,
    no_guilt = true,
    disables_police = true,
    timer = 300,
    countdown_on_start = true,
    kteam = "CombineSoldier",
    dteam = "Rebel",

    spawn_type = "tdm",
    win_condition = "tdm",
    tdm_end_logic = true,
    win_screen_team1 = "combine_win",
    win_screen_team2 = "rebels_win",

    OnModeStarted = function(mode)
        if SERVER then
            local pos1, pos2 = MuR:FindTwoDistantSpawnLocations(2000, 50)

            MuR.Mode20 = {
                WeaponsBlocked = true,
                BlockEndTime = CurTime() + 22,
                SpawnTeam1 = pos1 or Vector(0, 0, 0),
                SpawnTeam2 = pos2 or Vector(0, 0, 0),
                RebelMedicSeed = tostring(math.random(100000, 999999))
            }
        end
    end,

    OnModeThink = function(mode)
        if SERVER and MuR.Mode20 then
            if MuR.Mode20.WeaponsBlocked and CurTime() >= MuR.Mode20.BlockEndTime then
                MuR.Mode20.WeaponsBlocked = false
            end

            if MuR.Mode20.WeaponsBlocked then
                for _, ply in player.Iterator() do
                    if ply:Alive() then
                        ply:SetActiveWeapon(nil)
                    end
                end
            end
        end
    end,

    OnModeEnded = function(mode)
        if SERVER then
            MuR.Mode20 = nil
        end
    end
})

if SERVER then
    hook.Add("PlayerSpawn", "MuR_Mode20_Spawn", function(ply)
        if MuR.Gamemode == 20 and MuR.Mode20 then
            timer.Simple(0.1, function()
                if not IsValid(ply) or not MuR.Mode20 then return end

                local class = ply:GetNW2String("Class", "")
                local spawnPos

                if class == "CombineSoldier" and MuR.Mode20.SpawnTeam1 then
                    spawnPos = MuR.Mode20.SpawnTeam1
                elseif class == "Rebel" and MuR.Mode20.SpawnTeam2 then
                    spawnPos = MuR.Mode20.SpawnTeam2
                end

                if spawnPos and spawnPos ~= Vector(0, 0, 0) then
                    local offset = VectorRand() * 100
                    offset.z = 0
                    ply:SetPos(spawnPos + offset + Vector(0, 0, 10))
                end
            end)
        end
    end)
end

if CLIENT then
    local scanlineOffset = 0

    hook.Add("RenderScreenspaceEffects", "MuR.Mode20CombineVision", function()
        if MuR.GamemodeCount ~= 20 then return end

        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local class = ply:GetNW2String("Class", "")
        if class ~= "CombineSoldier" then return end

        scanlineOffset = (scanlineOffset + FrameTime() * 50) % 4

        local tab = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0.02,
            ["$pp_colour_addb"] = 0.08,
            ["$pp_colour_brightness"] = 0.02,
            ["$pp_colour_contrast"] = 1.1,
            ["$pp_colour_colour"] = 0.3,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        }
        DrawColorModify(tab)

        DrawMotionBlur(0.1, 0.4, 0.001)

        local w, h = ScrW(), ScrH()
        local subclassName = ply:GetNW2String("Mode20CombineSubclassName", "")

        surface.SetDrawColor(0, 100, 200, 15)
        for y = math.floor(scanlineOffset), h, 4 do
            surface.DrawRect(0, y, w, 1)
        end

        surface.SetDrawColor(0, 150, 255, 30)
        surface.DrawOutlinedRect(50, 50, w - 100, h - 100, 2)

        surface.SetDrawColor(0, 100, 200, 20)
        surface.DrawRect(0, 0, w, 60)
        surface.DrawRect(0, h - 60, w, 60)
        surface.DrawRect(0, 60, 60, h - 120)
        surface.DrawRect(w - 60, 60, 60, h - 120)

        local cornerSize = 30
        surface.SetDrawColor(0, 200, 255, 80)
        surface.DrawLine(50, 50, 50 + cornerSize, 50)
        surface.DrawLine(50, 50, 50, 50 + cornerSize)
        surface.DrawLine(w - 50, 50, w - 50 - cornerSize, 50)
        surface.DrawLine(w - 50, 50, w - 50, 50 + cornerSize)
        surface.DrawLine(50, h - 50, 50 + cornerSize, h - 50)
        surface.DrawLine(50, h - 50, 50, h - 50 - cornerSize)
        surface.DrawLine(w - 50, h - 50, w - 50 - cornerSize, h - 50)
        surface.DrawLine(w - 50, h - 50, w - 50, h - 50 - cornerSize)

        draw.SimpleText("OVERWATCH ACTIVE", "MuR_FontDef", 70, 70, Color(0, 200, 255, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if subclassName ~= "" then
            draw.SimpleText("UNIT: " .. string.upper(subclassName), "MuR_FontDef", 70, 85, Color(0, 220, 255, 135), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        draw.SimpleText("SECTOR SCAN: " .. math.floor(CurTime() % 100), "MuR_FontDef", 70, subclassName ~= "" and 100 or 85, Color(0, 150, 200, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end)

    hook.Add("HUDPaint", "MuR.Mode20Targets", function()
        if MuR.GamemodeCount ~= 20 then return end

        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local class = ply:GetNW2String("Class", "")
        if class ~= "CombineSoldier" then return end

        local myPos = ply:GetShootPos()

        for _, target in player.Iterator() do
            if target == ply then continue end
            if not IsValid(target) then continue end

            local targetPos
            local isAlive = target:Alive()
            local targetColor

            if isAlive then
                targetPos = target:GetPos() + Vector(0, 0, 50)
                if target:Team() == ply:Team() then
                    targetColor = Color(0, 200, 255, 200)
                else
                    targetColor = Color(255, 50, 50, 200)
                end
            else
                local ragdoll = target:GetRagdollEntity()
                if not IsValid(ragdoll) then continue end
                targetPos = ragdoll:GetPos() + Vector(0, 0, 20)
                targetColor = Color(150, 150, 150, 150)
            end

            local dist = myPos:Distance(targetPos)
            if dist > 3000 then continue end

            local tr = util.TraceLine({
                start = myPos,
                endpos = targetPos,
                filter = ply,
                mask = MASK_SOLID_BRUSHONLY
            })
            if tr.Hit then continue end

            local screenPos = targetPos:ToScreen()
            if not screenPos.visible then continue end

            local size = math.Clamp(20 - (dist / 200), 6, 20)
            local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7

            local col = Color(targetColor.r, targetColor.g, targetColor.b, targetColor.a * pulse)

            surface.SetDrawColor(col)
            surface.DrawLine(screenPos.x - size, screenPos.y, screenPos.x - size/2, screenPos.y)
            surface.DrawLine(screenPos.x + size/2, screenPos.y, screenPos.x + size, screenPos.y)
            surface.DrawLine(screenPos.x, screenPos.y - size, screenPos.x, screenPos.y - size/2)
            surface.DrawLine(screenPos.x, screenPos.y + size/2, screenPos.x, screenPos.y + size)

            local distText = math.floor(dist / 52.49) .. "m"
            draw.SimpleText(distText, "MuR_FontDef", screenPos.x, screenPos.y + size + 5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            if not isAlive then
                draw.SimpleText("DECEASED", "MuR_FontDef", screenPos.x, screenPos.y - size - 15, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end
        end
    end)
end
