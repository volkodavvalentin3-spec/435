MuR.RegisterMode(23, {
    name = "Prison Break",
    chance = 15,
    need_players = 4,
    disables = true,
    custom_spawning = true,
    custom_spawning_func = "Mode23SpawnPlayers",
    no_guilt = true,
    disables_police = true,
    disable_loot = true,
    timer = 420,
    no_default_roles = true,

    win_condition = "prison_break",
    tdm_end_logic = true,
    win_screen_team1 = "prisoners_win",
    win_screen_team2 = "guards_win",

    kteam = "Prisoner",
    dteam = "PrisonGuard",
    iteam = "PrisonGuard",

    OnModeStarted = function(mode)
        if SERVER then
            local pos1, pos2 = MuR:FindTwoDistantSpawnLocations(2500, 100)

            local guardSpawn = MuR:GetRandomPos(false, pos1, 2000, 5000, true)
            if not guardSpawn then
                guardSpawn = MuR:GetRandomPos(true, pos1, 2000, 5000, true)
            end
            if not guardSpawn then
                guardSpawn = pos2
            end

            MuR.Mode23 = {
                PrisonerLootSpawn = pos1 or Vector(0, 0, 0),
                GuardSpawn = guardSpawn or Vector(0, 0, 0),
                GuardsSpawned = false,
                GuardSpawnTime = CurTime() + 80,
                LootSpawned = false,
                CountdownIssuedBlyat = false
            }

            timer.Simple(0.5, function()
                if not MuR.Mode23 then return end
                MuR:SpawnPrisonBreakLoot()
            end)

            timer.Remove("MuR_Mode23_GuardCountdown")
            timer.Create("MuR_Mode23_GuardCountdown", 70, 1, function()
                if not MuR.Mode23 or MuR.Gamemode ~= 23 then return end
                if MuR.Mode23.CountdownIssuedBlyat then return end
                MuR.Mode23.CountdownIssuedBlyat = true
                MuR:GiveCountdown(10)
            end)
        end
    end,

    OnModeThink = function(mode)
        if SERVER and MuR.Mode23 then
            if not MuR.Mode23.GuardsSpawned and CurTime() >= MuR.Mode23.GuardSpawnTime then
                MuR.Mode23.GuardsSpawned = true
                MuR:SpawnPrisonGuards()
            end
        end
    end,

    OnModeEnded = function(mode)
        if SERVER then
            timer.Remove("MuR_Mode23_GuardCountdown")
            MuR.Mode23 = nil
        end
        if CLIENT then
            hook.Remove("HUDPaint", "MuR.Mode23HUD")
        end
    end
})

if SERVER then
    util.AddNetworkString("MuR.Mode23GuardsArriving")

    function MuR:Mode23SpawnPlayers()
        if MuR.Gamemode != 23 then return end

        local allPlayers = player.GetAll()
        table.Shuffle(allPlayers)

        local total = #allPlayers
        local guardCount = math.max(1, math.ceil(total * 0.5))
        if total <= 1 then guardCount = 0 end

        for i, ply in ipairs(allPlayers) do
            local roleClass = (i <= guardCount) and "PrisonGuard" or "Prisoner"
            local teamNum = (i <= guardCount) and 2 or 1

            ply:SetNW2String("Class", roleClass)
            ply:SetTeam(teamNum)

            ply.ForceSpawn = true
            ply:Spawn()
            ply:Freeze(true)
            ply:GodEnable()

            if roleClass == "Prisoner" then
                ply:SetNW2Float("ArrestState", 0)
            end

            timer.Simple(12, function()
                if IsValid(ply) then
                    ply:Freeze(false)
                    ply:GodDisable()
                end
            end)
        end
    end

    function MuR:SpawnPrisonGuards()
        if not MuR.Mode23 then return end

        MuR:PlaySoundOnClient("murdered/other/policearrive.wav")

        net.Start("MuR.Mode23GuardsArriving")
        net.Broadcast()

        for _, ply in player.Iterator() do
            if ply:GetNW2String("Class") == "PrisonGuard" then
                if not ply:Alive() then
                    ply.ForceSpawn = true
                    ply:Spawn()
                end

                if MuR.Mode23.GuardSpawn and MuR.Mode23.GuardSpawn ~= Vector(0, 0, 0) then
                    local offset = VectorRand() * 150
                    offset.z = 0
                    ply:SetPos(MuR.Mode23.GuardSpawn + offset + Vector(0, 0, 10))
                end

                ply:ScreenFade(SCREENFADE.IN, color_black, 1, 1)
            end
        end
    end

    function MuR:SpawnPrisonBreakLoot()
        if not MuR.Mode23 then return end

        local prisonLoot = {
            "mur_loot_bandage",
            "mur_loot_bandage",
            "mur_loot_bandage",
            "mur_loot_adrenaline",
            "mur_loot_medkit",
            "tfa_bs_combk",
            "tfa_bs_compactk",
            "tfa_bs_knife",
            "tfa_bs_machete",
            "tfa_bs_hammer",
            "tfa_bs_hammer",
            "tfa_bs_crowbar",
            "tfa_bs_crowbar",
            "tfa_bs_baton",
            "mur_flashbang",
            "mur_beartrap",
        }

        local lightWeapons = {}

        if MuR.WeaponsTable then
            if MuR.WeaponsTable["Secondary"] then
                for _, wep in pairs(MuR.WeaponsTable["Secondary"]) do
                    table.insert(lightWeapons, wep.class)
                end
            end
            if MuR.WeaponsTable["Melee"] then
                for _, wep in pairs(MuR.WeaponsTable["Melee"]) do
                    table.insert(lightWeapons, wep.class)
                end
            end
        end

        local spawnPos = MuR.Mode23.PrisonerLootSpawn
        if not spawnPos or spawnPos == Vector(0, 0, 0) then return end

        for i = 1, 40 do
            local pos = MuR:GetRandomPos(nil, spawnPos, 100, 1500, true)
            if not pos then continue end

            local class
            if math.random(1, 3) == 1 and #lightWeapons > 0 then
                class = lightWeapons[math.random(1, #lightWeapons)]
            else
                class = prisonLoot[math.random(1, #prisonLoot)]
            end

            local ent = ents.Create(class)
            if IsValid(ent) then
                ent:SetPos(pos + Vector(0, 0, 5))
                ent:Spawn()

                if ent:IsWeapon() and ent.ClipSize then
                    ent:SetClip1(math.random(0, math.floor(ent.ClipSize / 2)))
                end
            end
        end

        for _, ent in ipairs(ents.FindByClass("prop_*")) do
            if not istable(ent.Inventory) then
                ent.Inventory = {}
            end

            local add = math.random(0, 2)
            for i = 1, add do
                if math.random(1, 3) == 1 and #lightWeapons > 0 then
                    table.insert(ent.Inventory, lightWeapons[math.random(1, #lightWeapons)])
                else
                    table.insert(ent.Inventory, prisonLoot[math.random(1, #prisonLoot)])
                end
            end
        end

        MuR.Mode23.LootSpawned = true
    end

    hook.Add("PlayerSpawn", "MuR_Mode23_Spawn", function(ply)
        if MuR.Gamemode == 23 and MuR.Mode23 then
            timer.Simple(0.1, function()
                if not IsValid(ply) or not MuR.Mode23 then return end

                local class = ply:GetNW2String("Class", "")

                if class == "PrisonGuard" then
                    ply:SetTeam(2)

                    if not MuR.Mode23.GuardsSpawned then
                        ply:KillSilent()
                        ply.SpectateMode = 6
                        ply.SpectateIndex = 1
                        ply:Spectate(6)
                    else
                        if MuR.Mode23.GuardSpawn and MuR.Mode23.GuardSpawn ~= Vector(0, 0, 0) then
                            local offset = VectorRand() * 100
                            offset.z = 0
                            ply:SetPos(MuR.Mode23.GuardSpawn + offset + Vector(0, 0, 10))
                        end
                    end
                end
            end)
        end
    end)
end

if CLIENT then
    local guardsArrivingTime = 0

    net.Receive("MuR.Mode23GuardsArriving", function()
        guardsArrivingTime = CurTime() + 5
    end)

    hook.Add("HUDPaint", "MuR.Mode23HUD", function()
        if MuR.GamemodeCount ~= 23 then return end
        if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") then return end

        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local w, h = ScrW(), ScrH()
        local class = ply:GetNW2String("Class", "")

        if class == "Prisoner" then
            local timeLeft = 0
            if MuR.TimeCount and MuR.ModeTimer then
                local elapsed = CurTime() - MuR.TimeCount
                timeLeft = math.max(0, 60 - elapsed)
            end

            if timeLeft > 0 then
                draw.SimpleTextOutlined(string.format("%s: %d", MuR.Language["mode23_until_guards"] or "Until guards arrive", math.ceil(timeLeft)), "MuR_Font2", w / 2, h * 0.12, Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
            end
        end
    end)
end
