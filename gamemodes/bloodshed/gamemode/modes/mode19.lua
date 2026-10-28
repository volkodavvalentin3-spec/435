MuR.RegisterMode(19, {
    name = "Battle Royale",
    chance = 5,
    need_players = 2,
    win_condition = "survivor",
    kteam = "Soldier",
    dteam = "Soldier",
    iteam = "Soldier",
    disables_police = true,
    no_guilt = true,
    disables = true,
    disable_loot = true,
    no_default_roles = true,
    timer = 600,
    OnModeStarted = function(mode)
        if SERVER then
            MuR.Mode19 = {
                ZoneEntity = nil,
                StartTime = CurTime(),
                EndTime = CurTime() + 600,
                SpawnPoint = nil,
                PlayersAlive = 0,
                Winner = nil,
                WeaponSpawnMultiplier = 3,
                WeaponsBlocked = true,
                BlockEndTime = CurTime() + 42
            }

            timer.Simple(0.5, function()
                if not MuR.Mode19 then return end

                local allPlayers = player.GetAll()
                if #allPlayers == 0 then return end

                local spawnPly = allPlayers[math.random(1, #allPlayers)]
                local spawnPos = spawnPly:GetPos()
                MuR.Mode19.SpawnPoint = spawnPos

                for _, ply in ipairs(allPlayers) do
                    if ply:Alive() then
                        local offset = VectorRand() * 32
                        offset.z = 0
                        ply:SetPos(spawnPos + offset + Vector(0, 0, 4))
                    end
                end

                local zone = ents.Create("bloodshed_zone")
                if IsValid(zone) then
                    zone:SetPos(spawnPos)
                    zone.InitialRadius = 4000
                    zone.MinimumRadius = 50
                    zone.ShrinkDuration = 540
                    zone:Spawn()
                    MuR.Mode19.ZoneEntity = zone
                end

                MuR:SpawnBRWeapons()
            end)

            timer.Simple(12, function()
                MuR:GiveCountdown(30)
            end)

            for _, ply in player.Iterator() do
                ply:SetNW2String("Class", "Soldier")
                ply.ForceSpawn = true
                ply:Spawn()
            end
        end
    end,

    OnModeThink = function(mode)
        if SERVER and MuR.Mode19 then
            if MuR.Mode19.WeaponsBlocked and CurTime() >= MuR.Mode19.BlockEndTime then
                MuR.Mode19.WeaponsBlocked = false
            end

            if MuR.Mode19.WeaponsBlocked then
                for _, ply in player.Iterator() do
                    if ply:Alive() then
                        ply:SetActiveWeapon(nil)
                    end
                end
            end

            local alivePlayers = {}
            for _, ply in player.Iterator() do
                if ply:Alive() and ply:Team() == 1 then
                    table.insert(alivePlayers, ply)
                end
            end

            MuR.Mode19.PlayersAlive = #alivePlayers

            if #alivePlayers <= 1 and player.GetCount() > 0 then
                if not MuR.Mode19.GameEnded then
                    MuR.Mode19.GameEnded = true

                    if #alivePlayers == 1 then
                        local winner = alivePlayers[1]
                        MuR.Mode19.Winner = winner

                        net.Start("MuR.Mode19Winner")
                        net.WriteString(winner:Nick())
                        net.Broadcast()

                        timer.Simple(8, function()
                            MuR.Delay_Before_Lose = CurTime()
                        end)
                    else
                        timer.Simple(5, function()
                            MuR.Delay_Before_Lose = CurTime()
                        end)
                    end
                end
            end

            if CurTime() >= MuR.Mode19.EndTime and not MuR.Mode19.GameEnded then
                MuR.Mode19.GameEnded = true
                timer.Simple(5, function()
                    MuR.Delay_Before_Lose = CurTime()
                end)
            end
        end
    end,

    OnModeEnded = function(mode)
        if SERVER and MuR.Mode19 then
            if IsValid(MuR.Mode19.ZoneEntity) then
                MuR.Mode19.ZoneEntity:Remove()
            end
            MuR.Mode19 = nil
        end
        if CLIENT then
            hook.Remove("HUDPaint", "MuR.Mode19HUD")
        end
    end
})

if SERVER then
    util.AddNetworkString("MuR.Mode19Winner")

    function MuR:SpawnBRWeapons()
        if not MuR.Mode19 or not MuR.Mode19.SpawnPoint then return end

        local weaponClasses = {}

        for _, cat in pairs({"Civilian", "Killer", "Soldier"}) do
            if MuR.Shop[cat] then
                for _, item in ipairs(MuR.Shop[cat]) do
                    if item.func then
                        local funcStr = string.dump(item.func)
                        for class in string.gmatch(debug.getinfo(item.func, "S").source or "", "GiveWeapon%(['\"]([^'\"]+)['\"]") do
                            table.insert(weaponClasses, class)
                        end
                    end
                end
            end
        end

        local shopWeapons = {
            "mur_loot_bandage",
            "mur_loot_adrenaline",
            "mur_loot_medkit",
            "mur_f1",
            "mur_m67",
            "mur_ied",
            "mur_flashbang",
            "mur_gasoline",
            "mur_beartrap",
            "mur_taser",
            "tfa_bs_compactk",
            "tfa_bs_combk",
        }

        if MuR.WeaponsTable then
            if MuR.WeaponsTable["Primary"] then
                for _, wep in pairs(MuR.WeaponsTable["Primary"]) do
                    table.insert(shopWeapons, wep.class)
                end
            end
            if MuR.WeaponsTable["Secondary"] then
                for _, wep in pairs(MuR.WeaponsTable["Secondary"]) do
                    table.insert(shopWeapons, wep.class)
                end
            end
            if MuR.WeaponsTable["Melee"] then
                for _, wep in pairs(MuR.WeaponsTable["Melee"]) do
                    table.insert(shopWeapons, wep.class)
                end
            end
        end

        for _, ent in ipairs(ents.FindByClass("prop_*")) do
            if not istable(ent.Inventory) then
                ent.Inventory = {}
            end

            local add = math.random(0, 4)
            for i = 1, add do
                if math.random(1, 2) == 1 then
                    table.insert(ent.Inventory, shopWeapons[math.random(1, #shopWeapons)])
                else
                    local loot = MuR:GiveRandomTableWithChance(MuR.Loot)
                    if loot then
                        table.insert(ent.Inventory, loot.class)
                    end
                end
            end
        end
    end

    hook.Add("PlayerSpawn", "MuR_Mode19_Spawn", function(ply)
        if MuR.Gamemode == 19 and MuR.Mode19 then
            timer.Simple(0.1, function()
                if not IsValid(ply) then return end

                ply:StripWeapons()
                ply:StripAmmo()
                ply:GiveWeapon("mur_hands", true)
                ply:GiveWeapon("mur_loot_bandage")
                ply:SetTeam(1)
                ply:SetHealth(100)
                ply:SetMaxHealth(100)
                ply:SetArmor(0)
                ply:AllowFlashlight(false)

                if MuR.Mode19.SpawnPoint then
                    local offset = VectorRand() * 100
                    offset.z = 0
                    ply:SetPos(MuR.Mode19.SpawnPoint + offset + Vector(0, 0, 10))
                end
            end)
        end
    end)
end

if CLIENT then
    local playersAlive = 0
    local winnerName = ""
    local winnerShowTime = 0

    net.Receive("MuR.Mode19Winner", function()
        winnerName = net.ReadString()
        winnerShowTime = CurTime() + 8
    end)

    hook.Add("HUDPaint", "MuR.Mode19HUD", function()
        if MuR.GamemodeCount == 19 and MuR.DrawHUD and not MuR:GetClient("blsd_nohud") then
            local alive = 0
            for _, ply in player.Iterator() do
                if ply:Alive() and ply:Team() == 1 then
                    alive = alive + 1
                end
            end
            playersAlive = alive

            local w, h = ScrW(), ScrH()

            local playerText = "▲ " .. playersAlive
            draw.SimpleTextOutlined(playerText, "MuR_Font3", w / 2, h * 0.07, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))

            if winnerShowTime > CurTime() then
                local alpha = math.Clamp((winnerShowTime - CurTime()) / 3 * 255, 0, 255)
                draw.SimpleText(MuR.Language["mode19_winner"] or "WINNER", "MuR_Font5", w / 2, h / 2 - 50, Color(255, 215, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(winnerName, "MuR_Font6", w / 2, h / 2 + 20, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)
end
