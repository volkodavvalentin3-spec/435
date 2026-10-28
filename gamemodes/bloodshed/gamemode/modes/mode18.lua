MuR.RegisterMode(18, {
    name = "Last Stand - Zombies",
    chance = 1,
    need_players = 1,
    soldier_spawning = true,
    no_win_screen = true,
    kteam = "Survivors",
    dteam = "Zombies",
    iteam = "Spectators",
    disables_police = true,
    no_guilt = true,
    no_friendly_fire = true,
    OnModeStarted = function(mode)
        if SERVER then
            MuR.Mode18 = {
                Wave = 0,
                ZombiesAlive = 0,
                ZombiesToSpawn = 0,
                ZombiesSpawned = 0,
                State = "intermission",
                NextWaveTime = CurTime() + 30,
                SpawnPoints = {},
                ActiveZombies = {},
                CurrentMusic = math.random(1,4),
                SoundConfig = {
                    SpecialWaveStart = "murdered/nz/special_start.mp3",
                    SpecialWaveEnd = "murdered/nz/special_end.mp3",
                    SpecialWaveMusic = "murdered/nz/special_round_music.ogg",
                    Laugh = {"murdered/nz/announce_laugh1.mp3", "murdered/nz/announce_laugh2.mp3", "murdered/nz/announce_laugh3.mp3", "murdered/nz/announce_laugh4.mp3", "murdered/nz/announce_laugh5.mp3"},

                    [1] = {
                        FirstWaveStart = "murdered/nz/1/start_init.mp3",
                        WaveStart = {"murdered/nz/1/start1.mp3", "murdered/nz/1/start2.mp3", "murdered/nz/1/start3.mp3"},
                        WaveEnd = {"murdered/nz/1/end1.mp3", "murdered/nz/1/end2.mp3", "murdered/nz/1/end3.mp3"},
                        GameOver = "murdered/nz/1/gameover.mp3"
                    },
                    [2] = {
                        FirstWaveStart = "murdered/nz/2/start_init.mp3",
                        WaveStart = {"murdered/nz/2/start1.mp3", "murdered/nz/2/start2.mp3", "murdered/nz/2/start3.mp3"},
                        WaveEnd = {"murdered/nz/2/end1.mp3", "murdered/nz/2/end2.mp3", "murdered/nz/2/end3.mp3"},
                        GameOver = "murdered/nz/2/gameover.mp3"
                    },
                    [3] = {
                        FirstWaveStart = "murdered/nz/3/start_init.mp3",
                        WaveStart = {"murdered/nz/3/start1.mp3", "murdered/nz/3/start2.mp3", "murdered/nz/3/start3.mp3"},
                        WaveEnd = {"murdered/nz/3/end1.mp3", "murdered/nz/3/end2.mp3", "murdered/nz/3/end3.mp3"},
                        GameOver = "murdered/nz/3/gameover.mp3"
                    },
                    [4] = {
                        FirstWaveStart = "murdered/nz/3/start_init.mp3",
                        WaveStart = {"murdered/nz/3/start1.mp3", "murdered/nz/3/start2.mp3", "murdered/nz/3/start3.mp3"},
                        WaveEnd = {"murdered/nz/3/end1.mp3", "murdered/nz/3/end2.mp3", "murdered/nz/3/end3.mp3"},
                        GameOver = "murdered/nz/3/gameover.mp3"
                    },
                }
            }

            -- Только свои NPC: классы npc_vj_smod_* и npc_vj_psyonic_* были
            -- контентом сторонних аддонов на VJ Base и здесь больше не нужны.
            MuR.Mode18.ZombieConfig = {
                {class = "npc_bs_zombie", chance = 100, wave = 1},
                {class = "npc_bs_nz_vermin", chance = 15, wave = 6},
                {class = "npc_bs_nz_mangler", chance = 10, wave = 8},
                {class = "npc_bs_nz_amalgam", chance = 5, wave = 11},
                {class = "npc_bs_nz_mimic", chance = 8, wave = 13},
            }

            -- Спец-волна — только вермины: их много, они быстрые, и волна
            -- читается как отдельное событие, а не как обычная с добавками.
            MuR.Mode18.SpecialZombieConfig = {
                {class = "npc_bs_nz_vermin", chance = 100, wave = 5},
            }

            -- Скорость по волне: 60 на первой, 360 к тридцатой, линейно.
            MuR.Mode18.SpeedFirstWave = 60
            MuR.Mode18.SpeedLastWave = 360
            MuR.Mode18.SpeedMaxWave = 30
            -- От чего считается множитель для особых: бег рядового зомби.
            MuR.Mode18.SpeedBaseline = 220

            function MuR.Mode18.WaveSpeed(wave)
                local last = MuR.Mode18.SpeedMaxWave
                local f = math.Clamp(((wave or 1) - 1) / (last - 1), 0, 1)

                return Lerp(f, MuR.Mode18.SpeedFirstWave, MuR.Mode18.SpeedLastWave)
            end

            util.AddNetworkString("MuR.Mode18Update")
            util.AddNetworkString("MuR.Mode18Points")
            util.AddNetworkString("MuR.Mode18Fog")
            util.AddNetworkString("MuR.Mode18Music")
            util.AddNetworkString("MuR.Mode18Hit")
            util.AddNetworkString("MuR.Mode18NukeEffect")
            util.AddNetworkString("MuR.Mode18Powerup")
            util.AddNetworkString("MuR.Mode18Killstreak")
            util.AddNetworkString("MuR.Mode18Reset")
            util.AddNetworkString("MuR.Mode18WallBuy")
            util.AddNetworkString("MuR.Mode18AshEffect")

            hook.Add("CreateEntityRagdoll", "MuR.Mode18.TagZombieRagdoll", function(ent, rag)
                if MuR.Gamemode ~= 18 then return end
                if not IsValid(ent) or not IsValid(rag) then return end
                if ent.IsMode18Zombie or ent:GetNWBool("IsMode18Zombie", false) then
                    rag:SetNW2Bool("MuR.IsMode18ZombieRag", true)

                    timer.Simple(0, function()
                        if not IsValid(rag) then return end
                        rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                        rag:SetVelocity(vector_origin)
                        local physCount = rag:GetPhysicsObjectCount()
                        for i = 0, physCount - 1 do
                            local phys = rag:GetPhysicsObjectNum(i)
                            if IsValid(phys) then
                                phys:SetVelocity(vector_origin)
                                phys:AddAngleVelocity(-phys:GetAngleVelocity())
                                phys:SetDamping(0.8, 0.8)
                                phys:Wake()
                            end
                        end
                    end)
                end
            end)

            MuR.Mode18.DoublePointsEnd = 0
            MuR.Mode18.InstaKillEnd = 0
            MuR.Mode18.ActiveZombies = {}

            net.Start("MuR.Mode18Reset")
            net.Broadcast()

            concommand.Add("mur_zombiepoints", function(ply, cmd, args)
                if not IsValid(ply) or not ply:IsAdmin() then return end
                if not IsValid(ply) or not ply:IsAdmin() then return end
                if MuR.Gamemode ~= 18 then
                    ply:ChatPrint("[Zombie] This command only works in Zombie mode!")
                    return
                end

                local target = args[1]
                local amount = tonumber(args[2]) or 1000

                if not target then

                    local current = ply:GetNWInt("MuR_ZombiesPoints", 0)
                    ply:SetNWInt("MuR_ZombiesPoints", current + amount)
                    ply:ChatPrint("[Zombie] Added " .. amount .. " points to yourself. Total: " .. (current + amount))
                else
                    local targetPly = nil
                    for _, p in player.Iterator() do
                        if string.find(string.lower(p:Nick()), string.lower(target)) then
                            targetPly = p
                            break
                        end
                    end

                    if targetPly then
                        local current = targetPly:GetNWInt("MuR_ZombiesPoints", 0)
                        targetPly:SetNWInt("MuR_ZombiesPoints", current + amount)
                        ply:ChatPrint("[Zombie] Added " .. amount .. " points to " .. targetPly:Nick() .. ". Total: " .. (current + amount))
                    else
                        ply:ChatPrint("[Zombie] Player not found: " .. target)
                    end
                end
            end)
        end
    end,

    OnModeThink = function(mode)
        if SERVER and MuR.Mode18 then
            MuR.Mode18.NextThinkTime = MuR.Mode18.NextThinkTime or 0
            if CurTime() < MuR.Mode18.NextThinkTime then return end
            MuR.Mode18.NextThinkTime = CurTime() + 0.1

            local alivePlayers = 0
            for _, ply in player.Iterator() do
                if ply:Alive() and ply:Team() == 1 then
                    alivePlayers = alivePlayers + 1
                end
            end

            if alivePlayers == 0 and player.GetCount() > 0 then
                if not MuR.Mode18.RoundEnded then
                    MuR.Mode18.RoundEnded = true
                    MuR.Delay_Before_Lose = CurTime() + 15
                    timer.Simple(10, function()
                        MuR:PlaySoundOnClient(MuR.Mode18.SoundConfig[MuR.Mode18.CurrentMusic].GameOver)
                    end)
                    timer.Simple(15, function()
                        MuR.Delay_Before_Lose = CurTime() - 1
                    end)
                end
                return
            end

            if MuR.Mode18.State == "intermission" then
                if CurTime() >= MuR.Mode18.NextWaveTime then
                    MuR.Mode18.State = "wave"
                    MuR.Mode18.Wave = MuR.Mode18.Wave + 1

                    for _, ent in ents.Iterator() do
                        if ent:GetClass() == "mode18_perkmachine" or ent:GetClass() == "mode18_packapunch" then
                            ent:Remove()
                        end
                    end
                    net.Start("MuR.Mode18CloseUI")
                    net.Broadcast()

                    local isSpecial = (MuR.Mode18.Wave % 5 == 0)
                    MuR.Mode18.IsSpecialWave = isSpecial

                    if isSpecial then
                        MuR:PlaySoundOnClient(MuR.Mode18.SoundConfig.SpecialWaveStart)
                        timer.Simple(5, function()
                            if MuR.Mode18 and MuR.Mode18.State == "wave" then
                                net.Start("MuR.Mode18Music")
                                net.WriteBool(true)
                                net.WriteString(MuR.Mode18.SoundConfig.SpecialWaveMusic)
                                net.Broadcast()
                            end
                        end)

                        net.Start("MuR.Mode18Fog")
                        net.WriteBool(true)
                        net.Broadcast()
                    else
                        local soundList = MuR.Mode18.SoundConfig[MuR.Mode18.CurrentMusic].WaveStart
                        local snd = soundList[math.random(1, #soundList)]
                        if MuR.Mode18.Wave == 1 then
                            snd = MuR.Mode18.SoundConfig[MuR.Mode18.CurrentMusic].FirstWaveStart
                        end
                        MuR:PlaySoundOnClient(snd)

                        net.Start("MuR.Mode18Fog")
                        net.WriteBool(false)
                        net.Broadcast()
                    end

                    local playerCount = player.GetCount()
                    local totalZombies = math.floor(playerCount/3 * (4 + MuR.Mode18.Wave * 2))
                    if totalZombies > 128 then totalZombies = 128 end
                    if totalZombies < 6 then totalZombies = 6 end

                    MuR.Mode18.ZombiesToSpawn = totalZombies
                    MuR.Mode18.ZombiesSpawned = 0
                    MuR.Mode18.ZombiesAlive = 0
                    MuR.Mode18.NextSpawnTime = CurTime()

                    for _, ply in player.Iterator() do
                        if ply:Alive() then
                            ply:SetHealth(math.min(ply:Health() + 20, 100))
                        end
                    end

                    MuR:SendMode18Data()
                end
            elseif MuR.Mode18.State == "wave" then
                local actualAlive = 0
                for _, z in pairs(MuR.Mode18.ActiveZombies) do
                    if IsValid(z) and z:Health() > 0 then
                        actualAlive = actualAlive + 1
                    end
                end
                MuR.Mode18.ZombiesAlive = actualAlive

                if not MuR.Mode18.LastZombieUpdate or CurTime() > MuR.Mode18.LastZombieUpdate + 1 then
                    MuR.Mode18.LastZombieUpdate = CurTime()
                    MuR:SendMode18Data()
                end

                if MuR.Mode18.ZombiesSpawned >= MuR.Mode18.ZombiesToSpawn and MuR.Mode18.ZombiesAlive <= 0 then
                    MuR.Mode18.State = "intermission"
                    MuR.Mode18.NextWaveTime = CurTime() + 20

                    for _, ply in player.Iterator() do
                        if ply:Team() == 1 then
                            ply:AddMoney(50)
                        end
                        if not ply:Alive() and ply:Team() == 1 then
                            ply.ForceSpawn = true
                            ply:Spawn()
                            ply:AddMoney(25)
                        end

                        if ply:Alive() and ply.Mode18Perks and ply.Mode18Perks["bandolier"] then
                            for _, wep in pairs(ply:GetWeapons()) do
                                if IsValid(wep) then
                                    local ammoType = wep:GetPrimaryAmmoType()
                                    local clipSize = wep:GetMaxClip1()
                                    if ammoType > 0 and clipSize > 0 then
                                        ply:GiveAmmo(clipSize * 2, ammoType)
                                    end
                                end
                            end
                        end
                    end

                    local ragdolls = {}
                    for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
                        if IsValid(rag) and not rag.isRDRag then
                            table.insert(ragdolls, rag)
                        end
                    end

                    for i, rag in ipairs(ragdolls) do
                        timer.Simple(0.15 * (i - 1), function()
                            if IsValid(rag) then
                                net.Start("MuR.Mode18AshEffect")
                                net.WriteEntity(rag)
                                net.WriteFloat(2.5)
                                net.Broadcast()

                                timer.Simple(2.5, function()
                                    if IsValid(rag) then
                                        rag:Remove()
                                    end
                                end)
                            end
                        end)
                    end

                    if MuR.Mode18.IsSpecialWave then
                        MuR:PlaySoundOnClient(MuR.Mode18.SoundConfig.SpecialWaveEnd)

                        net.Start("MuR.Mode18Music")
                        net.WriteBool(false)
                        net.WriteString("")
                        net.Broadcast()

                        net.Start("MuR.Mode18Fog")
                        net.WriteBool(false)
                        net.Broadcast()
                    else
                        local soundList = MuR.Mode18.SoundConfig[MuR.Mode18.CurrentMusic].WaveEnd
                        local snd = soundList[math.random(1, #soundList)]
                        MuR:PlaySoundOnClient(snd)
                    end

                    MuR:SendMode18Data()

                    MuR:SpawnMode18Machines()

                    return
                end

                -- Потолок живых считается от онлайна и номера волны, а не
                -- зашит числом: см. MuR:GetMaxNPCs.
                if MuR.Mode18.ZombiesSpawned < MuR.Mode18.ZombiesToSpawn and MuR.Mode18.ZombiesAlive < MuR:GetMaxNPCs(MuR.Mode18.Wave) and CurTime() >= (MuR.Mode18.NextSpawnTime or 0) then
                    MuR.Mode18.NextSpawnTime = CurTime() + 1

                    local allPlayers = player.GetAll()
                    if #allPlayers == 0 then return end
                    local rply = allPlayers[math.random(1, #allPlayers)]
                    local spawnPos = MuR:GetRandomPos(nil, rply:GetPos(), 500, 2000)
                    if spawnPos then
                        local availableClasses = {}
                        local config = MuR.Mode18.IsSpecialWave and MuR.Mode18.SpecialZombieConfig or MuR.Mode18.ZombieConfig

                        for _, z in ipairs(config) do
                            if MuR.Mode18.Wave >= z.wave then
                                table.insert(availableClasses, z)
                            end
                        end

                        if #availableClasses > 0 then
                            local totalChance = 0
                            for _, z in ipairs(availableClasses) do
                                totalChance = totalChance + z.chance
                            end

                            local randomVal = math.random(0, totalChance)
                            local zType = availableClasses[1]
                            local currentSum = 0

                            for _, z in ipairs(availableClasses) do
                                currentSum = currentSum + z.chance
                                if randomVal <= currentSum then
                                    zType = z
                                    break
                                end
                            end

                            local zombie = ents.Create(zType.class)
                            if IsValid(zombie) then
                                zombie:SetPos(spawnPos + Vector(0,0,2))
                                zombie:Spawn()
                                zombie:Activate()
                                local max = zombie:GetMaxHealth()
                                local newhp = max + (max / 100 * (MuR.Mode18.Wave * 25))
                                zombie:SetHealth(newhp)
                                zombie.EnemyXRayDetection = true
                                zombie.IsMode18Zombie = true

                                -- Скорость волны — про обычного зомби: у него
                                -- одна величина и на шаг, и на бег, анимацию
                                -- база выбирает сама.
                                --
                                -- Особым плоская подстановка не годится: она
                                -- стирала их собственные скорости, и манглер с
                                -- его бегом на 260 полз наравне с рядовым
                                -- зомби. Им та же волна даёт множитель, и то
                                -- лишь на ускорение — замедлять босса волна
                                -- не должна.
                                local waveSpeed = MuR.Mode18.WaveSpeed(MuR.Mode18.Wave)

                                if zombie:GetClass() == "npc_bs_zombie" then
                                    zombie.WalkSpeed = waveSpeed
                                    zombie.RunSpeed = waveSpeed
                                else
                                    zombie.SpeedScale = math.max(1, waveSpeed / MuR.Mode18.SpeedBaseline)
                                end
                                zombie:SetNWBool("IsMode18Zombie", true)
                                zombie.DisableMuRGibs = true
                                zombie.Mode18_SpawnTime = CurTime()
                                zombie.Mode18_LastProgressTime = CurTime()
                                zombie.Mode18_LastPos = spawnPos
                                if zType.init then
                                    zType.init(zombie)
                                end

                                table.insert(MuR.Mode18.ActiveZombies, zombie)
                                MuR.Mode18.ZombiesSpawned = MuR.Mode18.ZombiesSpawned + (MuR.Mode18.IsSpecialWave and 2 or 1)
                                MuR.Mode18.ZombiesAlive = MuR.Mode18.ZombiesAlive + 1
                            end
                        end
                    end
                end

                MuR.Mode18.NextStuckCheck = MuR.Mode18.NextStuckCheck or CurTime()
                if CurTime() >= MuR.Mode18.NextStuckCheck then
                    MuR.Mode18.NextStuckCheck = CurTime() + 2

                    for i = #MuR.Mode18.ActiveZombies, 1, -1 do
                        local z = MuR.Mode18.ActiveZombies[i]
                        if not IsValid(z) or z:Health() <= 0 then
                            table.remove(MuR.Mode18.ActiveZombies, i)
                        else
                            local closestPly = nil
                            local closestDist = math.huge
                            for _, ply in player.Iterator() do
                                if ply:Alive() and ply:Team() == 1 then
                                    local d = ply:GetPos():DistToSqr(z:GetPos())
                                    if d < closestDist then
                                        closestDist = d
                                        closestPly = ply
                                    end
                                end
                            end

                            if closestPly then
                                local maxDistSqr = 4000 * 4000
                                if closestDist > maxDistSqr then
                                    local newPos = MuR:GetRandomPos(nil, closestPly:GetPos(), 400, 1000)
                                    if newPos then
                                        z:SetPos(newPos + Vector(0,0,10))
                                        z.Mode18_LastProgressTime = CurTime()
                                        z.Mode18_LastPos = newPos
                                    end
                                else
                                    local lastPos = z.Mode18_LastPos or z:GetPos()
                                    local moved = z:GetPos():DistToSqr(lastPos)

                                    if moved > 2500 then
                                        z.Mode18_LastProgressTime = CurTime()
                                        z.Mode18_LastPos = z:GetPos()
                                    elseif CurTime() - (z.Mode18_LastProgressTime or CurTime()) > 15 then
                                        local newPos = MuR:GetRandomPos(nil, closestPly:GetPos(), 300, 800)
                                        if newPos then
                                            z:SetPos(newPos + Vector(0,0,10))
                                            z.Mode18_LastProgressTime = CurTime()
                                            z.Mode18_LastPos = newPos
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end,

    OnModeEnded = function(mode)
        if SERVER and MuR.Mode18 then
            hook.Remove("CreateEntityRagdoll", "MuR.Mode18.TagZombieRagdoll")
            for _, ent in ents.Iterator() do
                if ent.IsMode18Zombie then
                    ent:Remove()
                end
            end
            MuR.Mode18 = nil
        end
        if CLIENT then
            hook.Remove("HUDPaint", "MuR.Mode18HUD")
        end
    end
})

if SERVER then
    hook.Add("OnNPCKilled", "MuR_Mode18_Points", function(npc, attacker, inflictor)
        if MuR.Gamemode == 18 and MuR.Mode18 and npc.IsMode18Zombie then
            MuR.Mode18.ZombiesAlive = MuR.Mode18.ZombiesAlive - 1

            if MuR.Mode18.ZombiesToSpawn == MuR.Mode18.ZombiesSpawned and MuR.Mode18.ZombiesAlive <= 0 and MuR.Mode18.IsSpecialWave then
                local powerup = ents.Create("mode18_powerup")
                if IsValid(powerup) then
                    powerup:SetPos(npc:GetPos() + Vector(0,0,30))
                    powerup:Spawn()
                    powerup:SetPowerupType("Max Ammo")
                end
            end

            if math.random() < 0.03 then
                local powerup = ents.Create("mode18_powerup")
                if IsValid(powerup) then
                    powerup:SetPos(npc:GetPos() + Vector(0,0,30))
                    powerup:Spawn()
                    local types = {"Max Ammo", "Nuke", "Double Points", "Insta-Kill", "Bonus Points", "Full Power", "Fire Sale", "Max Armor"}
                    powerup:SetPowerupType(types[math.random(1, #types)])
                end
            end

            if IsValid(attacker) and attacker:IsPlayer() then
                local points = attacker:GetNWInt("MuR_ZombiesPoints", 0)
                local reward = 75
                if MuR.Mode18.DoublePointsEnd > CurTime() then
                    reward = reward * 2
                end

                local lastKill = attacker.Mode18_LastKillTime or 0
                local streak = attacker.Mode18_KillStreak or 0

                if CurTime() - lastKill < 2.5 then
                    streak = streak + 1
                else
                    streak = 1
                end
                attacker.Mode18_LastKillTime = CurTime()
                attacker.Mode18_KillStreak = streak

                local bonus = 0
                local streakKey = ""

                if streak == 2 then bonus = 5; streakKey = "mode18_kill_2"
                elseif streak == 3 then bonus = 10; streakKey = "mode18_kill_3"
                elseif streak == 4 then bonus = 15; streakKey = "mode18_kill_4"
                elseif streak >= 5 then bonus = 20; streakKey = "mode18_kill_5"
                end

                if MuR.Mode18.DoublePointsEnd > CurTime() then
                    bonus = bonus * 2
                end

                points = points + reward + bonus
                attacker:SetNWInt("MuR_ZombiesPoints", points)

                if bonus > 0 then
                    net.Start("MuR.Mode18Killstreak")
                    net.WriteString(streakKey)
                    net.WriteInt(bonus, 16)
                    net.Send(attacker)
                end
            end
        end
    end)

    MuR.LastLaugh = 0
    hook.Add("PlayerDeath", "MuR_Mode18_Death", function(victim, inflictor, attacker)
        if MuR.Gamemode == 18 and MuR.LastLaugh < CurTime() then
            MuR.LastLaugh = CurTime() + 3
            local laughSounds = MuR.Mode18.SoundConfig.Laugh
            local snd = laughSounds[math.random(1, #laughSounds)]
            MuR:PlaySoundOnClient(snd)
        end
    end)

    function MuR:SendMode18Data()
        if MuR.Mode18 then
            net.Start("MuR.Mode18Update")
            net.WriteInt(MuR.Mode18.Wave, 16)
            net.WriteString(MuR.Mode18.State)
            net.WriteFloat(MuR.Mode18.NextWaveTime)
            net.WriteInt(MuR.Mode18.ZombiesAlive + (MuR.Mode18.ZombiesToSpawn - MuR.Mode18.ZombiesSpawned), 16)
            net.Broadcast()
        end
    end

    local function FindWallPos(startPos, radius)
        local directions = {
            Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0),
            Vector(0.7,0.7,0), Vector(0.7,-0.7,0), Vector(-0.7,0.7,0), Vector(-0.7,-0.7,0)
        }

        local bestPos = nil
        local bestNormal = nil
        local minDist = radius

        for _, dir in ipairs(directions) do
            local tr = util.TraceLine({
                start = startPos + Vector(0,0,30),
                endpos = startPos + Vector(0,0,30) + dir * radius,
                mask = MASK_SOLID_BRUSHONLY
            })

            if tr.Hit and tr.Fraction < 1 then
                local dist = tr.StartPos:Distance(tr.HitPos)
                if dist < minDist then
                    minDist = dist
                    bestPos = tr.HitPos
                    bestNormal = tr.HitNormal
                end
            end
        end

        if bestPos then

            return bestPos + bestNormal * 25, bestNormal
        end
        return nil, nil
    end

    function MuR:SpawnMode18Machines()
        if not MuR.Mode18 then return end

        local players = {}
        for _, ply in player.Iterator() do
            if ply:Alive() then
                table.insert(players, ply)
            end
        end

        if #players == 0 then return end

        local perkPly = players[math.random(1, #players)]
        local perkPos = MuR:GetRandomPos(nil, perkPly:GetPos(), 200, 800)

        if perkPos then
            local wallPos, wallNormal = FindWallPos(perkPos, 300)
            local spawnPos = wallPos or perkPos
            local spawnAng = Angle(0, math.random(0, 360), 0)

            if wallNormal then
                spawnAng = wallNormal:Angle()
                spawnAng.p = 0
                spawnAng.r = 0
            end

            local perkMachine = ents.Create("mode18_perkmachine")
            if IsValid(perkMachine) then
                perkMachine:SetPos(spawnPos + Vector(0, 0, 10))
                perkMachine:SetAngles(spawnAng)
                perkMachine:Spawn()
                perkMachine:Activate()

                local tr = util.TraceLine({
                    start = spawnPos + Vector(0, 0, 50),
                    endpos = spawnPos - Vector(0, 0, 100),
                    mask = MASK_SOLID_BRUSHONLY
                })
                if tr.Hit then
                    perkMachine:SetPos(tr.HitPos)
                end
            end
        end
    end

    hook.Add("EntityTakeDamage", "MuR_Mode18_Hitmarker", function(target, dmginfo)
        if MuR.Gamemode == 18 and target.IsMode18Zombie then
            local attacker = dmginfo:GetAttacker()
            if IsValid(attacker) and attacker:IsPlayer() then
                if MuR.Mode18.InstaKillEnd > CurTime() then
                    dmginfo:SetDamage(target:Health() + 100)
                end

                local dmg = dmginfo:GetDamage()
                if dmg > 10 then
                    local currentPoints = attacker:GetNWInt("MuR_ZombiesPoints", 0)
                    local bonus = 5
                    if MuR.Mode18.DoublePointsEnd > CurTime() then
                        bonus = bonus * 2
                    end
                    attacker:SetNWInt("MuR_ZombiesPoints", currentPoints + bonus)
                end

                net.Start("MuR.Mode18Hit")
                net.Send(attacker)
            end
        end

        if MuR.Gamemode == 18 then
            local attacker = dmginfo:GetAttacker()
            if IsValid(attacker) and MuR.IsAI(attacker) and attacker.IsMode18Zombie then
                local class = target:GetClass()
                if class == "prop_physics" or class == "prop_physics_multiplayer" or string.find(class, "door") then
                    dmginfo:ScaleDamage(10)
                end
            end
        end
    end)
end

if CLIENT then
    local function We(x) return x / 1920 * ScrW() end
    local function He(y) return y / 1080 * ScrH() end

    MuR.Mode18Client = MuR.Mode18Client or {Wave = 0, State = "intermission", NextWaveTime = 0, Powerups = {}}
    local displayedPoints = 0
    local waveAlpha = 0
    local musicChannel = nil
    local lastHitTime = 0
    local nukeFlash = 0

    local floatingPoints = {}
    local killstreaks = {}
    local lastPoints = 0
    local waveAnim = 0
    local lastWave = 0
    local fireParticles = {}
    local waveFlash = 0
    local powerupDisplayState = {}

    local waveEndAnim = {
        active = false,
        startTime = 0,
        phase = "none",
        displayWave = 0,
        posX = 0,
        posY = 0,
        scale = 1,
        finalWave = nil
    }
    local objectivesState = {
        waveAlpha = 0,
        intermissionAlpha = 1,
        displayedZombies = 0
    }
    local radarBlips = {}
    local nextRadarScan = 0
    local radarSweepAngle = 0
    local radarSweepActive = false
    local radarGlitchTime = 0
    local objGlitchTime = 0

    local gradMat = Material("murdered/nz/gradient.png", "noclamp smooth")
    local fireMat = Material("sprites/flamelet1")
    local powerupIcons = {
        ["Double Points"] = Material("murdered/nz/2x.png", "noclamp smooth"),
        ["Insta-Kill"] = Material("murdered/nz/instakill.png", "noclamp smooth"),
        ["Max Ammo"] = Material("murdered/nz/ammo.png", "noclamp smooth"),
        ["Nuke"] = Material("murdered/nz/nuke.png", "noclamp smooth"),
        ["Bonus Points"] = Material("murdered/nz/bonus.png", "noclamp smooth"),
        ["Full Power"] = Material("murdered/nz/power.png", "noclamp smooth"),
        ["Fire Sale"] = Material("murdered/nz/firesale.png", "noclamp smooth"),
        ["Max Armor"] = Material("murdered/nz/armor.png", "noclamp smooth")
    }

    local function ResetMode18Client()
        MuR.Mode18Client = {Wave = 0, State = "intermission", NextWaveTime = 0, Powerups = {}, ZombiesRemaining = 0}
        displayedPoints = 0
        waveAlpha = 0
        lastHitTime = 0
        nukeFlash = 0
        floatingPoints = {}
        killstreaks = {}
        lastPoints = 0
        waveAnim = 0
        lastWave = 0
        fireParticles = {}
        waveFlash = 0
        if IsValid(musicChannel) then
            musicChannel:Stop()
            musicChannel = nil
        end

        if skyboxMeteors and worldMeteors then
            for _, m in ipairs(worldMeteors) do
                if m.emitter then m.emitter:Finish() end
            end
            for _, fc in ipairs(fireColumns) do
                if fc.emitter then fc.emitter:Finish() end
            end
        end
        skyboxMeteors = {}
        worldMeteors = {}
        curseEffects = {}
        fireColumns = {}
        groundCracks = {}
        curseIntensity = 0
    end

    local function SpawnFireParticles(posX, posY)
        local cx, cy = posX or We(100), posY or (ScrH() - He(100))
        for i = 1, 20 do
            table.insert(fireParticles, {
                x = cx + math.random(-40, 40),
                y = cy + math.random(-20, 20),
                vx = math.random(-50, 50),
                vy = math.random(-150, -50),
                size = math.random(15, 35),
                life = CurTime() + math.random() * 1.5 + 0.5,
                color = math.random() > 0.5 and Color(255, 100, 0) or Color(255, 200, 50)
            })
        end
    end

    net.Receive("MuR.Mode18Reset", function()
        ResetMode18Client()
    end)

    net.Receive("MuR.Mode18Update", function()
        local oldState = MuR.Mode18Client.State
        local oldWave = MuR.Mode18Client.Wave
        MuR.Mode18Client.Wave = net.ReadInt(16)
        MuR.Mode18Client.State = net.ReadString()
        MuR.Mode18Client.NextWaveTime = net.ReadFloat()
        MuR.Mode18Client.ZombiesRemaining = net.ReadInt(16)

        if MuR.Mode18Client.State == "intermission" and oldState == "wave" and oldWave > 0 then
            waveEndAnim.active = true
            waveEndAnim.startTime = CurTime()
            waveEndAnim.phase = "move_up"
            waveEndAnim.displayWave = oldWave
            waveEndAnim.posX = We(100)
            waveEndAnim.posY = ScrH() - He(100)
            waveEndAnim.scale = 1
        end
    end)

    net.Receive("MuR.Mode18Powerup", function()
        local ptype = net.ReadString()
        local endTime = net.ReadFloat()

        local isNew = not MuR.Mode18Client.Powerups[ptype] or CurTime() > MuR.Mode18Client.Powerups[ptype]
        MuR.Mode18Client.Powerups[ptype] = endTime

        if isNew then
            powerupDisplayState[ptype] = {
                spawnTime = CurTime(),
                alpha = 0,
                textAlpha = 255,
                scale = 1.5
            }
        end
    end)

    net.Receive("MuR.Mode18NukeEffect", function()
        nukeFlash = 2
        util.ScreenShake(EyePos(), 4, 8, 6, 720, true)
    end)

    net.Receive("MuR.Mode18Music", function()
        local play = net.ReadBool()
        local path = net.ReadString()

        if play then
            if IsValid(musicChannel) then musicChannel:Stop() end

            sound.PlayFile("sound/" .. path, "noplay noblock", function(station, errCode, errStr)
                if IsValid(station) then
                    station:EnableLooping(true)
                    station:Play()
                    musicChannel = station
                end
            end)
        else
            if IsValid(musicChannel) then
                musicChannel:Stop()
                musicChannel = nil
            end
        end
    end)

    net.Receive("MuR.Mode18Hit", function()
        lastHitTime = CurTime()
        surface.PlaySound("player/headshot1.wav")
    end)

    net.Receive("MuR.Mode18Killstreak", function()
        local nameKey = net.ReadString()
        local bonus = net.ReadInt(16)
        local name = MuR.Language[nameKey] or nameKey
        table.insert(killstreaks, {name = name, bonus = bonus, time = CurTime() + 3, alpha = 255})
    end)

    hook.Add("HUDPaint", "MuR.Mode18HUD", function()
        if MuR.GamemodeCount == 18 and MuR.DrawHUD and not MuR:GetClient("blsd_nohud") and not MuR.CutsceneActive then
            local ply = LocalPlayer()
            local isAlive = ply:Alive()
            local points = ply:GetNWInt("MuR_ZombiesPoints", 0)

            if isAlive then
                if points > lastPoints then
                    local diff = points - lastPoints
                    table.insert(floatingPoints, {amount = diff, time = CurTime() + 1.5, x = ScrW() - We(50), y = He(780), alpha = 255})
                end
                lastPoints = points

                displayedPoints = Lerp(FrameTime() * 10, displayedPoints, points)

                local ptsColor = Color(255, 200, 50)
                if MuR.Mode18Client.Powerups["Double Points"] and CurTime() < MuR.Mode18Client.Powerups["Double Points"] then
                    ptsColor = Color(255, 255, 0)
                end

                draw.SimpleText(string.format("%d", math.Round(displayedPoints)), "MuR_Font_NZ3", ScrW() - We(50), He(800), ptsColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                for i = #floatingPoints, 1, -1 do
                    local fp = floatingPoints[i]
                    if CurTime() < fp.time then
                        fp.y = fp.y - FrameTime() * 30
                        fp.alpha = math.Remap(fp.time - CurTime(), 0, 1.5, 0, 255)
                        draw.SimpleText("+" .. fp.amount, "MuR_Font_NZ3", fp.x, fp.y, Color(255, 255, 100, fp.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    else
                        table.remove(floatingPoints, i)
                    end
                end
            end

            if MuR.Mode18Client.Wave > 0 or waveEndAnim.active then
                local baseX, baseY = We(100), ScrH() - He(100)
                local centerX, centerY = ScrW() / 2, ScrH() / 2 - He(50)

                local wave = MuR.Mode18Client.Wave
                local cx, cy = baseX, baseY
                local col = Color(180, 20, 20, 255)
                local scale = 1
                local rotation = 0
                local displayWave = wave

                if waveEndAnim.active then
                    local elapsed = CurTime() - waveEndAnim.startTime
                    local nextWave = waveEndAnim.displayWave + 1

                    if waveEndAnim.phase == "move_up" then
                        local t = math.Clamp(elapsed / 1, 0, 1)
                        t = t * t * (3 - 2 * t)
                        cx = Lerp(t, baseX, centerX)
                        cy = Lerp(t, baseY, centerY)
                        scale = Lerp(t, 1, 1.5)
                        displayWave = waveEndAnim.displayWave
                        col = Color(255, 200, 100, 255)

                        if elapsed >= 1 then
                            waveEndAnim.phase = "hold"
                            waveEndAnim.startTime = CurTime()
                            surface.PlaySound("murdered/nz/counterfire.mp3")
                            waveFlash = 1
                            SpawnFireParticles(centerX, centerY)
                        end
                    elseif waveEndAnim.phase == "hold" then
                        cx, cy = centerX, centerY
                        scale = 1.5
                        displayWave = nextWave
                        local pulse = math.sin(CurTime() * 4) * 0.1 + 1
                        scale = 1.5 * pulse
                        col = Color(255, 255, 150, 255)

                        if elapsed >= 3 then
                            waveEndAnim.phase = "move_down"
                            waveEndAnim.startTime = CurTime()
                        end
                    elseif waveEndAnim.phase == "move_down" then
                        local t = math.Clamp(elapsed / 1, 0, 1)
                        t = t * t * (3 - 2 * t)
                        cx = Lerp(t, centerX, baseX)
                        cy = Lerp(t, centerY, baseY)
                        scale = Lerp(t, 1.5, 1)
                        displayWave = nextWave
                        col = Color(Lerp(t, 255, 180), Lerp(t, 255, 20), Lerp(t, 150, 20), 255)

                        if elapsed >= 1 then
                            waveEndAnim.active = false
                            waveEndAnim.phase = "none"
                            waveEndAnim.finalWave = nextWave
                        end
                    end
                else
                    if waveEndAnim.finalWave and waveEndAnim.finalWave > wave then
                        displayWave = waveEndAnim.finalWave
                    else
                        displayWave = wave
                        waveEndAnim.finalWave = nil
                    end
                    col = Color(180, 20, 20, 255)
                end

                for i = #fireParticles, 1, -1 do
                    local p = fireParticles[i]
                    if CurTime() < p.life then
                        p.x = p.x + p.vx * FrameTime()
                        p.y = p.y + p.vy * FrameTime()
                        p.vy = p.vy - 100 * FrameTime()
                        local alpha = math.Remap(p.life - CurTime(), 0, 1, 0, 255)
                        local size = p.size * (1 - (1 - (p.life - CurTime()) / 2) * 0.5)

                        surface.SetMaterial(fireMat)
                        surface.SetDrawColor(p.color.r, p.color.g, p.color.b, alpha)
                        surface.DrawTexturedRect(p.x - size/2, p.y - size/2, size, size)
                    else
                        table.remove(fireParticles, i)
                    end
                end

                if waveFlash > 0.01 then
                    waveFlash = Lerp(FrameTime() * 3, waveFlash, 0)
                    surface.SetDrawColor(255, 100, 0, 100 * waveFlash)
                    draw.NoTexture()
                    local glowSize = (80 + waveFlash * 60) * scale
                    for j = 1, 3 do
                        surface.DrawCircle(cx, cy, glowSize * j * 0.4, 255, 100, 0, 30 * waveFlash / j)
                    end
                end

                local matrix = Matrix()
                matrix:Translate(Vector(cx, cy, 0))
                matrix:Rotate(Angle(0, rotation, 0))
                matrix:Scale(Vector(scale, scale, 1))
                matrix:Translate(Vector(-cx, -cy, 0))

                cam.PushModelMatrix(matrix)
                    draw.SimpleText(displayWave, "MuR_Font_NZ_Big", cx, cy, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.PopModelMatrix()
            end

            if nukeFlash > 0.01 then
                nukeFlash = Lerp(FrameTime() * 2, nukeFlash, 0)
                surface.SetDrawColor(255, 255, 255, 255 * nukeFlash)
                surface.DrawRect(0, 0, ScrW(), ScrH())
            end

            local activePowerups = {}
            for ptype, endTime in pairs(MuR.Mode18Client.Powerups) do
                if CurTime() < endTime then
                    table.insert(activePowerups, {type = ptype, endTime = endTime})
                else
                    if powerupDisplayState[ptype] then
                        powerupDisplayState[ptype].dying = true
                        powerupDisplayState[ptype].deathTime = CurTime()
                    end
                    MuR.Mode18Client.Powerups[ptype] = nil
                end
            end

            for ptype, state in pairs(powerupDisplayState) do
                if state.dying and CurTime() > state.deathTime + 0.5 then
                    powerupDisplayState[ptype] = nil
                end
            end

            table.sort(activePowerups, function(a, b) return a.type < b.type end)

            local iconSize = He(72)
            local spacing = We(15)
            local totalWidth = #activePowerups * iconSize + (#activePowerups - 1) * spacing
            local startX = (ScrW() - totalWidth) / 2
            local baseY = ScrH() - He(350)

            local powerupNames = {
                ["Double Points"] = MuR.Language["mode18_powerup_doublepoints"] or "DOUBLE POINTS",
                ["Insta-Kill"] = MuR.Language["mode18_powerup_instakill"] or "INSTA-KILL",
                ["Max Ammo"] = MuR.Language["mode18_powerup_maxammo"] or "MAX AMMO",
                ["Nuke"] = MuR.Language["mode18_powerup_nuke"] or "NUKE",
                ["Bonus Points"] = MuR.Language["mode18_powerup_bonus"] or "BONUS POINTS",
                ["Full Power"] = MuR.Language["mode18_powerup_fullpower"] or "FULL POWER",
                ["Fire Sale"] = MuR.Language["mode18_powerup_firesale"] or "FIRE SALE",
                ["Max Armor"] = MuR.Language["mode18_powerup_carpenter"] or "MAX ARMOR"
            }

            for i, p in ipairs(activePowerups) do
                local ptype = p.type
                local endTime = p.endTime
                local timeLeft = endTime - CurTime()

                local state = powerupDisplayState[ptype]
                if not state then
                    state = {spawnTime = CurTime(), alpha = 255, textAlpha = 0, scale = 1}
                    powerupDisplayState[ptype] = state
                end

                local timeSinceSpawn = CurTime() - state.spawnTime
                state.alpha = Lerp(FrameTime() * 8, state.alpha, state.dying and 0 or 255)
                state.scale = Lerp(FrameTime() * 10, state.scale, 1)

                if timeSinceSpawn < 3 then
                    state.textAlpha = math.Remap(timeSinceSpawn, 0, 3, 255, 0)
                else
                    state.textAlpha = 0
                end

                local icon = powerupIcons[ptype]
                local x = startX + (i-1) * (iconSize + spacing)
                local y = baseY

                local drawAlpha = state.alpha
                if timeLeft < 5 then
                    local blink = math.sin(CurTime() * 10) * 0.5 + 0.5
                    drawAlpha = drawAlpha * (0.4 + blink * 0.6)
                end

                if icon and drawAlpha > 1 then
                    local scaledSize = iconSize * state.scale
                    local offset = (scaledSize - iconSize) / 2

                    surface.SetMaterial(icon)
                    surface.SetDrawColor(255, 255, 255, drawAlpha)
                    surface.DrawTexturedRect(x - offset, y - offset, scaledSize, scaledSize)

                    if state.textAlpha > 1 then
                        local textY = y - He(25) - (1 - timeSinceSpawn / 3) * He(20)
                        local pName = powerupNames[ptype] or ptype
                        draw.SimpleText(pName, "MuR_Font_NZ2", x + iconSize/2, textY, Color(255, 220, 50, state.textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    end

                    local timerText = string.format("%.0f", math.max(0, timeLeft))
                    local timerAlpha = drawAlpha * (timeLeft < 10 and 1 or 0.7)
                    local timerCol = Color(255, 255, 255, timerAlpha)
                    draw.SimpleText(timerText, "MuR_Font_NZ2", x + iconSize/2, y + iconSize + He(5), timerCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end
            end

            local wep = ply:GetActiveWeapon()
            if isAlive and IsValid(wep) then
                local name = string.upper(wep:GetPrintName())
                local clip = wep:Clip1()
                local reserve = ply:GetAmmoCount(wep:GetPrimaryAmmoType())

                local x, y = ScrW() - We(50), ScrH() - He(50)

                surface.SetMaterial(gradMat)
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRectRotated(x - We(140), y - He(30), We(300), He(120), 180)

                if clip >= 0 then
                    draw.SimpleText(clip, "MuR_Font_NZ5", x - We(50), y + He(15), Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
                    draw.SimpleText((reserve <= 999 and reserve or "∞"), "MuR_Font_NZ2", x - We(45), y + He(5), Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
                    draw.SimpleText(name, "MuR_Font_NZ3", x, y - He(40), Color(200, 50, 50), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
                else
                    draw.SimpleText(name, "MuR_Font_NZ3", x, y - He(40), Color(200, 50, 50), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
                end
            end

            local cx, cy = ScrW() / 2, ScrH() / 2
            local totalBonus = 0
            local activeStreaks = 0
            local maxAlpha = 0

            for i = #killstreaks, 1, -1 do
                local ks = killstreaks[i]
                if CurTime() < ks.time then
                    ks.alpha = math.Remap(ks.time - CurTime(), 0, 0.5, 0, 255)
                    totalBonus = totalBonus + ks.bonus
                    activeStreaks = activeStreaks + 1
                    if ks.alpha > maxAlpha then maxAlpha = ks.alpha end
                else
                    table.remove(killstreaks, i)
                end
            end

            local ky = cy - He(60)

            for i, ks in ipairs(killstreaks) do
                if CurTime() < ks.time then
                    draw.SimpleText(ks.name, "MuR_Font_NZ2", cx + We(120), ky, Color(255, 255, 255, ks.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("+" .. ks.bonus, "MuR_Font_NZ2", cx + We(80), ky, Color(255, 220, 50, ks.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    ky = ky + He(28)
                end
            end

            if activeStreaks > 0 then
                draw.SimpleText(totalBonus, "MuR_Font_NZ1", cx + We(80), ky + He(5), Color(255, 220, 50, maxAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            if CurTime() - lastHitTime < 0.2 then
                local alpha = math.Remap(CurTime() - lastHitTime, 0, 0.2, 255, 0)
                surface.SetDrawColor(255, 255, 255, alpha)

                local cx, cy = ScrW() / 2, ScrH() / 2
                local size = 6
                local gap = 4

                surface.DrawLine(cx - size - gap, cy - size - gap, cx - gap, cy - gap)
                surface.DrawLine(cx + size + gap, cy - size - gap, cx + gap, cy - gap)
                surface.DrawLine(cx - size - gap, cy + size + gap, cx - gap, cy + gap)
                surface.DrawLine(cx + size + gap, cy + size + gap, cx + gap, cy + gap)
            end

            local objX, objY = We(25), He(25)
            local objAlpha = 200

            local isSpecialNow = MuR.Mode18Client.Wave > 0 and MuR.Mode18Client.Wave % 5 == 0 and MuR.Mode18Client.State == "wave"
            local objGlitchOffset = Vector(0, 0, 0)
            local objGlitchAlpha = 0

            if isSpecialNow then
                if math.random() < 0.03 then
                    objGlitchTime = CurTime() + 0.1
                end

                if CurTime() < objGlitchTime then
                    objGlitchOffset = Vector(math.random(-8, 8), math.random(-3, 3), 0)
                    objGlitchAlpha = math.random(-50, 50)
                end
            end

            local gx, gy = objX + objGlitchOffset.x, objY + objGlitchOffset.y
            local ga = math.Clamp(objAlpha + objGlitchAlpha, 50, 255)

            local objText = MuR.Language["mode18_objectives"] or "OBJECTIVES"
            if isSpecialNow and CurTime() < objGlitchTime then
                draw.SimpleText(objText, "MuR_Font3", gx + 2, gy, Color(255, 0, 0, ga * 0.5), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(objText, "MuR_Font3", gx - 2, gy, Color(0, 255, 255, ga * 0.5), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            draw.SimpleText(objText, "MuR_Font3", gx, gy, Color(255, 255, 255, ga), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            surface.SetDrawColor(255, 255, 255, ga * 0.6)
            surface.DrawRect(gx, gy + He(32), We(160), 2)

            local taskY = gy + He(40)

            local isWave = MuR.Mode18Client.State == "wave"
            local targetWave = isWave and 1 or 0
            local targetInter = isWave and 0 or 1

            objectivesState.waveAlpha = Lerp(FrameTime() * 5, objectivesState.waveAlpha, targetWave)
            objectivesState.intermissionAlpha = Lerp(FrameTime() * 5, objectivesState.intermissionAlpha, targetInter)

            local remaining = MuR.Mode18Client.ZombiesRemaining or 0
            objectivesState.displayedZombies = Lerp(FrameTime() * 8, objectivesState.displayedZombies, remaining)

            if objectivesState.waveAlpha > 0.01 then
                local a = objectivesState.waveAlpha * ga
                local tx = gx + We(5) + (isSpecialNow and CurTime() < objGlitchTime and math.random(-3, 3) or 0)
                local surText = MuR.Language["mode18_obj_survive"] or "• Survive the wave"
                local zombText = (MuR.Language["mode18_zombies"] or "Zombies") .. ": " .. math.Round(objectivesState.displayedZombies)
                draw.SimpleText(surText, "MuR_Font2", tx, taskY, Color(255, 255, 255, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(zombText, "MuR_Font2", tx, taskY + He(25), Color(180, 180, 180, a * 0.8), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            if objectivesState.intermissionAlpha > 0.01 then
                local a = objectivesState.intermissionAlpha * ga
                local timeLeft = math.max(0, math.ceil(MuR.Mode18Client.NextWaveTime - CurTime()))
                local prepText = MuR.Language["mode18_obj_prepare"] or "• Prepare for next wave"
                draw.SimpleText(prepText, "MuR_Font2", gx + We(5), taskY, Color(255, 255, 255, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                if timeLeft > 0 then
                    local timeLabel = MuR.Language["mode18_time"] or "Time"
                    local secLabel = MuR.Language["mode18_seconds_short"] or "s"
                    draw.SimpleText(timeLabel .. ": " .. timeLeft .. secLabel, "MuR_Font2", gx + We(5), taskY + He(25), Color(180, 180, 180, a * 0.8), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end

            if isAlive then
            local radarSize = He(180)
            local radarX = ScrW() - radarSize - We(20)
            local radarY = He(20)
            local radarCX = radarX + radarSize / 2
            local radarCY = radarY + radarSize / 2
            local radarRange = 800
            local radarAlpha = 200

            local isSpecialNow = MuR.Mode18Client.Wave > 0 and MuR.Mode18Client.Wave % 5 == 0 and MuR.Mode18Client.State == "wave"
            local glitchActive = false
            local glitchOffsetX, glitchOffsetY = 0, 0

            if isSpecialNow then
                if math.random() < 0.05 then
                    radarGlitchTime = CurTime() + math.random() * 0.15
                end
                if CurTime() < radarGlitchTime then
                    glitchActive = true
                    glitchOffsetX = math.random(-6, 6)
                    glitchOffsetY = math.random(-4, 4)
                end
            end

            local rcx = radarCX + glitchOffsetX
            local rcy = radarCY + glitchOffsetY

            surface.SetDrawColor(10, 15, 20, radarAlpha * 0.9)
            draw.NoTexture()
            local segments = 48
            local verts = {}
            for i = 0, segments do
                local ang = (i / segments) * math.pi * 2
                table.insert(verts, {x = rcx + math.cos(ang) * radarSize / 2, y = rcy + math.sin(ang) * radarSize / 2})
            end
            surface.DrawPoly(verts)

            for i = 1, 3 do
                local ringSize = (radarSize / 2) * (i / 3)
                local ringAlpha = radarAlpha * 0.25
                if glitchActive and math.random() < 0.3 then ringAlpha = ringAlpha * math.random() end
                surface.DrawCircle(rcx, rcy, ringSize, 200, 200, 200, ringAlpha)
            end

            surface.SetDrawColor(200, 200, 200, radarAlpha * 0.15)
            surface.DrawLine(rcx, radarY + glitchOffsetY + 5, rcx, radarY + glitchOffsetY + radarSize - 5)
            surface.DrawLine(radarX + glitchOffsetX + 5, rcy, radarX + glitchOffsetX + radarSize - 5, rcy)

            if radarSweepActive then
                radarSweepAngle = radarSweepAngle + FrameTime() * 720
                if radarSweepAngle >= 360 then
                    radarSweepAngle = 0
                    radarSweepActive = false
                end

                local sweepRad = math.rad(-radarSweepAngle + 90)
                local sweepEndX = rcx + math.cos(sweepRad) * (radarSize / 2 - 3)
                local sweepEndY = rcy - math.sin(sweepRad) * (radarSize / 2 - 3)

                surface.SetDrawColor(255, 100, 100, 200)
                surface.DrawLine(rcx, rcy, sweepEndX, sweepEndY)

                for j = 1, 15 do
                    local fadeAng = math.rad(-(radarSweepAngle - j * 3) + 90)
                    local fadeAlpha = 200 * (1 - j / 15)
                    local fadeX = rcx + math.cos(fadeAng) * (radarSize / 2 - 3)
                    local fadeY = rcy - math.sin(fadeAng) * (radarSize / 2 - 3)
                    surface.SetDrawColor(255, 100, 100, fadeAlpha * 0.3)
                    surface.DrawLine(rcx, rcy, fadeX, fadeY)
                end
            end

            if glitchActive then
                for i = 1, math.random(2, 5) do
                    local gy = rcy - radarSize/2 + math.random() * radarSize
                    local gw = math.random(20, 60)
                    local gh = math.random(1, 3)
                    surface.SetDrawColor(200, 200, 200, math.random(30, 80))
                    surface.DrawRect(rcx - radarSize/2 + math.random(-10, 10), gy, gw, gh)
                end
            end

            local plyPos = ply:GetPos()
            local plyAng = ply:EyeAngles().y

            local zombieClasses = {
                ["npc_bs_zombie"] = true,
                ["npc_bs_nz_vermin"] = true,
                ["npc_bs_nz_mangler"] = true,
                ["npc_bs_nz_amalgam"] = true,
                ["npc_bs_nz_mimic"] = true,
            }

            if CurTime() > nextRadarScan then
                nextRadarScan = CurTime() + 5
                radarBlips = {}
                radarSweepActive = true
                radarSweepAngle = 0

                for _, ent in ipairs(ents.FindInSphere(plyPos, radarRange)) do
                    local isZombie = MuR.IsAI(ent) and zombieClasses[ent:GetClass()]

                    if isZombie and IsValid(ent) and ent:Health() > 0 then
                        local entPos = ent:GetPos()

                        table.insert(radarBlips, {
                            pos = entPos,
                            spawnTime = CurTime(),
                            fadeTime = 4
                        })
                    end
                end
            end

            for i = #radarBlips, 1, -1 do
                local blip = radarBlips[i]
                local age = CurTime() - blip.spawnTime

                if age > blip.fadeTime then
                    table.remove(radarBlips, i)
                else
                    local alpha = 1 - (age / blip.fadeTime)
                    alpha = alpha * alpha

                    local diff = blip.pos - plyPos
                    local dist = diff:Length2D()
                    local worldAng = math.deg(math.atan2(diff.y, diff.x))

                    local relAng = math.rad(worldAng - plyAng + 90)
                    local normalizedDist = math.Clamp(dist / radarRange, 0, 1)

                    local dotX = math.cos(relAng) * normalizedDist * (radarSize / 2 - 8)
                    local dotY = -math.sin(relAng) * normalizedDist * (radarSize / 2 - 8)

                    local screenX = rcx + dotX
                    local screenY = rcy + dotY

                    if glitchActive and math.random() < 0.2 then
                        screenX = screenX + math.random(-5, 5)
                        screenY = screenY + math.random(-5, 5)
                    end

                    local dotSize = 5

                    surface.SetDrawColor(255, 60, 60, 255 * alpha)
                    draw.NoTexture()
                    surface.DrawRect(screenX - dotSize/2, screenY - dotSize/2, dotSize, dotSize)

                    surface.DrawCircle(screenX, screenY, dotSize + 2, 255, 60, 60, 80 * alpha)
                end
            end

            local arrowSize = 8
            surface.SetDrawColor(100, 255, 100, 255)
            local arrow = {
                {x = rcx, y = rcy - arrowSize},
                {x = rcx - arrowSize * 0.6, y = rcy + arrowSize * 0.5},
                {x = rcx, y = rcy + arrowSize * 0.1},
                {x = rcx + arrowSize * 0.6, y = rcy + arrowSize * 0.5}
            }
            draw.NoTexture()
            surface.DrawPoly(arrow)

            surface.SetDrawColor(220, 220, 220, radarAlpha)
            surface.DrawCircle(rcx, rcy, radarSize / 2, 220, 220, 220, radarAlpha)

            if glitchActive then
                surface.SetDrawColor(255, 0, 0, 100)
                surface.DrawCircle(rcx + 2, rcy, radarSize / 2, 255, 0, 0, 50)
                surface.SetDrawColor(0, 255, 255, 100)
                surface.DrawCircle(rcx - 2, rcy, radarSize / 2, 0, 255, 255, 50)
            end
            end
        end
    end)

    local fogEnabled = false
    local fogDensity = 0
    local isSpecialWave = false
    local waveActive = false
    local atmosphereIntensity = 0
    local stormIntensity = 0
    local nextLightning = 0
    local lightningFlash = 0
    local emberParticles = {}
    local ashParticles = {}
    local nextEmber = 0
    local nextAsh = 0
    local heatDistortion = 0
    local bloodDrips = {}
    local nextBloodDrip = 0
    local screenShakeOffset = Vector(0, 0, 0)
    local windSway = 0
    local pulseEffect = 0

    local emberMat = Material("sprites/light_glow02_add")
    local smokeMat = Material("particle/smokesprites_0001")
    local bloodMat = Material("decals/blood1")

    local skyboxMeteors = {}
    local nextSkyboxMeteor = 0
    local worldMeteors = {}
    local nextWorldMeteor = 0
    local curseEffects = {}
    local nextCurseEffect = 0
    local fireColumns = {}
    local groundCracks = {}
    local curseIntensity = 0

    local ambientSmoke = {}
    local nextAmbientSmoke = 0
    local groundFog = {}
    local nextGroundFog = 0
    local activeFieSounds = {}

    local meteorMat = Material("sprites/light_glow02_add")
    local trailMat = Material("trails/smoke")
    local fireMat3D = Material("sprites/flamelet1")
    local smokeMat = Material("sprites/light_glow02_add")
    local fogMat = Material("sprites/heatwave")
    local smokeCloudMat = Material("particle/particle_smokegrenade")

    local crackEffectModels = {
        "models/murdered/nz/hell lava crack 01.mdl",
        "models/murdered/nz/hell lava crack 02.mdl",
        "models/murdered/nz/hell lava crack 03.mdl",
        "models/murdered/nz/hell lava crack 04.mdl",
        "models/murdered/nz/hell lava crack 05.mdl",
        "models/murdered/nz/hell lava crack preset 01.mdl",
        "models/murdered/nz/hell lava crack preset 02.mdl",
        "models/murdered/nz/hell lava crack preset 03.mdl",
        "models/murdered/nz/hell lava crack preset 04.mdl",
        "models/murdered/nz/hell lava crack preset 05.mdl",
        "models/murdered/nz/hell lava cracks 01.mdl",
    }

    local function GetWaveIntensity()
        local wave = MuR.Mode18Client.Wave or 0
        return math.Clamp(wave / 10, 0, 1)
    end

    net.Receive("MuR.Mode18Fog", function()
        isSpecialWave = net.ReadBool()
    end)

    hook.Add("Think", "MuR.Mode18Atmosphere", function()
        if MuR.GamemodeCount ~= 18 then return end

        local ply = LocalPlayer()
        if IsValid(ply) and not ply:Alive() and IsValid(musicChannel) then
            musicChannel:Stop()
            musicChannel = nil
        end

        waveActive = MuR.Mode18Client.State == "wave"
        local waveIntensity = GetWaveIntensity()
        local targetCurse = waveActive and waveIntensity or (waveIntensity * 0.25)
        curseIntensity = Lerp(FrameTime() * 0.5, curseIntensity, targetCurse)

        local targetAtmo = waveActive and 1 or 0.2
        atmosphereIntensity = Lerp(FrameTime() * 0.5, atmosphereIntensity, targetAtmo)

        local targetStorm = (waveActive and isSpecialWave) and 1 or 0
        stormIntensity = Lerp(FrameTime() * 0.3, stormIntensity, targetStorm)

        local targetFog = 0
        if waveActive then
            targetFog = isSpecialWave and 1 or 0.5
        else
            targetFog = waveIntensity * 0.15
        end
        fogDensity = Lerp(FrameTime() * 0.3, fogDensity, targetFog)

        heatDistortion = math.sin(CurTime() * 2) * 0.5 + 0.5
        windSway = math.sin(CurTime() * 0.5) * stormIntensity
        pulseEffect = math.sin(CurTime() * 3) * 0.5 + 0.5

        if curseIntensity > 0.05 and CurTime() > nextSkyboxMeteor then
            local spawnRate = Lerp(curseIntensity, 3, 0.3)
            nextSkyboxMeteor = CurTime() + spawnRate + math.random() * spawnRate * 0.3

            local plyPos = ply:GetPos()
            local skyDist = 8000
            local angle = math.random() * math.pi * 2
            local startPos = plyPos + Vector(math.cos(angle) * skyDist, math.sin(angle) * skyDist, 3000 + math.random() * 2000)
            local endAngle = angle + math.pi + (math.random() - 0.5) * 0.5
            local endPos = plyPos + Vector(math.cos(endAngle) * skyDist * 0.3, math.sin(endAngle) * skyDist * 0.3, -500)

            table.insert(skyboxMeteors, {
                pos = startPos,
                vel = (endPos - startPos):GetNormalized() * (1500 + math.random() * 1000),
                size = 30 + math.random() * 50 * curseIntensity,
                life = CurTime() + 8,
                trail = {},
                trailTime = 0,
                color = Color(255, math.random(30, 100), 0)
            })
        end

        if curseIntensity > 0.3 and CurTime() > nextWorldMeteor then
            local spawnRate = Lerp(curseIntensity, 25, 8)
            nextWorldMeteor = CurTime() + spawnRate + math.random() * spawnRate * 0.5

            local plyPos = ply:GetPos()
            local spawnDist = 1000 + math.random() * 2000
            local angle = math.random() * math.pi * 2
            local startPos = plyPos + Vector(math.cos(angle) * spawnDist, math.sin(angle) * spawnDist, 1500 + math.random() * 1000)

            local targetOffset = Vector((math.random() - 0.5) * 500, (math.random() - 0.5) * 500, 0)
            local targetPos = plyPos + targetOffset

            local tr = util.TraceLine({
                start = targetPos + Vector(0, 0, 500),
                endpos = targetPos - Vector(0, 0, 2000),
                mask = MASK_SOLID_BRUSHONLY
            })

            if tr.Hit then
                targetPos = tr.HitPos
            end

            table.insert(worldMeteors, {
                pos = startPos,
                targetPos = targetPos,
                vel = Vector(0, 0, -800 - math.random() * 400),
                size = 15 + math.random() * 25 * curseIntensity,
                life = CurTime() + 10,
                trail = {},
                trailTime = 0,
                color = Color(255, math.random(20, 80), 0),
                emitter = ParticleEmitter(startPos, false),
                nextParticle = 0,
                impacted = false
            })
        end

        if curseIntensity > 0.1 and CurTime() > nextCurseEffect then
            local spawnRate = Lerp(curseIntensity, 5, 0.8)
            nextCurseEffect = CurTime() + spawnRate + math.random() * spawnRate * 0.5

            local plyPos = ply:GetPos()
            local dist = 200 + math.random() * 800
            local angle = math.random() * math.pi * 2
            local effectPos = plyPos + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)

            local tr = util.TraceLine({
                start = effectPos + Vector(0, 0, 200),
                endpos = effectPos - Vector(0, 0, 500),
                mask = MASK_SOLID_BRUSHONLY
            })

            if tr.Hit then
                effectPos = tr.HitPos

                local effectType = math.random(1, 3)
                if effectType == 1 and curseIntensity > 0.4 then
                    local fireLife = CurTime() + 3 + math.random() * 2
                    table.insert(fireColumns, {
                        pos = effectPos,
                        height = 100 + math.random() * 150 * curseIntensity,
                        width = 20 + math.random() * 30,
                        life = fireLife,
                        startTime = CurTime(),
                        emitter = ParticleEmitter(effectPos, false),
                        nextParticle = 0
                    })

                    for k = #activeFieSounds, 1, -1 do
                        if CurTime() > activeFieSounds[k] then
                            table.remove(activeFieSounds, k)
                        end
                    end

                    if #activeFieSounds < 3 then
                        sound.Play("ambient/fire/fire_small1.wav", effectPos, 50, math.random(90, 110))
                        table.insert(activeFieSounds, fireLife)
                    end
                elseif effectType == 2 or effectType == 3 then
                    local modelPath = crackEffectModels[math.random(#crackEffectModels)]
                    local targetScale = 0.8 + math.random() * 1.2 * curseIntensity

                    local csEnt = ClientsideModel(modelPath, RENDERGROUP_OPAQUE)
                    if IsValid(csEnt) then
                        csEnt:SetPos(effectPos - Vector(0, 0, 0))
                        csEnt:SetAngles(Angle(0, math.random(0, 360), 0))
                        csEnt:SetModelScale(0.01, 0)
                        csEnt:SetColor(Color(80, 40, 30))

                        table.insert(groundCracks, {
                            ent = csEnt,
                            pos = effectPos,
                            targetScale = targetScale,
                            currentScale = 0.01,
                            life = CurTime() + 6 + math.random() * 4,
                            startTime = CurTime(),
                            emitter = ParticleEmitter(effectPos, false),
                            nextParticle = 0,
                            glowIntensity = 0
                        })

                        sound.Play("physics/concrete/concrete_break2.wav", effectPos, 65, math.random(80, 100))
                    end
                end
            end
        end

        if stormIntensity > 0.5 and CurTime() > nextLightning then
            nextLightning = CurTime() + math.random(2, 8) / stormIntensity
            lightningFlash = 1

            if math.random() > 0.3 then
                timer.Simple(0.05 + math.random() * 0.1, function()
                    surface.PlaySound("ambient/weather/thunder" .. math.random(1, 4) .. ".wav")
                end)
            end
        end

        if lightningFlash > 0 then
            lightningFlash = lightningFlash - FrameTime() * 8
            if lightningFlash < 0 then lightningFlash = 0 end
        end

        if atmosphereIntensity > 0.1 and CurTime() > nextEmber then
            nextEmber = CurTime() + 0.05 / atmosphereIntensity
            local intensity = isSpecialWave and 2 or 1
            for i = 1, math.random(1, 3) * intensity do
                table.insert(emberParticles, {
                    x = math.random(0, ScrW()),
                    y = ScrH() + 20,
                    vx = math.random(-100, 100) + windSway * 200,
                    vy = math.random(-200, -80),
                    size = math.random(2, 6),
                    life = CurTime() + math.random(2, 5),
                    color = math.random() > 0.3 and Color(255, math.random(50, 150), 0) or Color(255, 200, 100),
                    flicker = math.random() * math.pi * 2
                })
            end
        end

        if stormIntensity > 0.3 and CurTime() > nextAsh then
            nextAsh = CurTime() + 0.02
            for i = 1, math.random(2, 5) do
                table.insert(ashParticles, {
                    x = math.random(-50, ScrW() + 50),
                    y = -20,
                    vx = math.random(50, 200) * stormIntensity + windSway * 300,
                    vy = math.random(100, 300),
                    size = math.random(1, 4),
                    life = CurTime() + math.random(3, 6),
                    rotation = math.random() * 360,
                    rotSpeed = math.random(-180, 180)
                })
            end
        end

        if isSpecialWave and stormIntensity > 0.5 and CurTime() > nextBloodDrip then
            nextBloodDrip = CurTime() + math.random(1, 3)
            table.insert(bloodDrips, {
                x = math.random(0, ScrW()),
                y = 0,
                vy = 0,
                length = math.random(50, 150),
                life = CurTime() + 4,
                alpha = 200
            })
        end

        if stormIntensity > 0.3 then
            local shake = stormIntensity * 2
            screenShakeOffset = Vector(
                math.sin(CurTime() * 15) * shake,
                math.cos(CurTime() * 12) * shake,
                0
            )

            if math.random() < 0.02 * stormIntensity then
                util.ScreenShake(LocalPlayer():GetPos(), stormIntensity * 3, 5, 0.3, 500, true)
            end
        else
            screenShakeOffset = Lerp(FrameTime() * 5, screenShakeOffset, Vector(0,0,0))
        end

        if curseIntensity > 0.15 and CurTime() > nextAmbientSmoke and IsValid(ply) then
            local spawnRate = Lerp(curseIntensity, 2, 0.4)
            nextAmbientSmoke = CurTime() + spawnRate

            local plyPos = ply:GetPos()
            local dist = 300 + math.random() * 600
            local angle = math.random() * math.pi * 2
            local smokePos = plyPos + Vector(math.cos(angle) * dist, math.sin(angle) * dist, math.random(50, 200))

            table.insert(ambientSmoke, {
                pos = smokePos,
                vel = Vector((math.random() - 0.5) * 30, (math.random() - 0.5) * 30, math.random(5, 20)),
                size = 80 + math.random() * 120 * curseIntensity,
                life = CurTime() + 4 + math.random() * 3,
                startTime = CurTime(),
                rotation = math.random() * 360,
                rotSpeed = (math.random() - 0.5) * 20,
                alpha = 30 + curseIntensity * 40
            })
        end

        if curseIntensity > 0.2 and CurTime() > nextGroundFog and IsValid(ply) then
            local spawnRate = Lerp(curseIntensity, 3, 0.6)
            nextGroundFog = CurTime() + spawnRate

            local plyPos = ply:GetPos()
            local dist = 200 + math.random() * 500
            local angle = math.random() * math.pi * 2
            local fogPos = plyPos + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)

            local tr = util.TraceLine({
                start = fogPos + Vector(0, 0, 100),
                endpos = fogPos - Vector(0, 0, 300),
                mask = MASK_SOLID_BRUSHONLY
            })

            if tr.Hit then
                fogPos = tr.HitPos + Vector(0, 0, 5)
                table.insert(groundFog, {
                    pos = fogPos,
                    vel = Vector((math.random() - 0.5) * 20, (math.random() - 0.5) * 20, 0),
                    size = 150 + math.random() * 200,
                    life = CurTime() + 6 + math.random() * 4,
                    startTime = CurTime(),
                    alpha = 20 + curseIntensity * 30
                })
            end
        end
    end)

    hook.Add("SetupWorldFog", "MuR.Mode18Fog", function()
        if MuR.GamemodeCount == 18 and fogDensity > 0.01 then
            render.FogMode(MATERIAL_FOG_LINEAR)

            if isSpecialWave then
                render.FogStart(50 * (1 - fogDensity))
                render.FogEnd(350 + 200 * (1 - fogDensity))
                render.FogMaxDensity(0.98 * fogDensity)
                local flicker = math.sin(CurTime() * 8) * 10
                render.FogColor(50 + flicker, 0, 5)
            else
                render.FogStart(100 + 100 * (1 - fogDensity))
                render.FogEnd(500 + 300 * (1 - fogDensity))
                render.FogMaxDensity(0.85 * fogDensity)
                render.FogColor(80, 15, 5)
            end
            return true
        end
    end)

    hook.Add("RenderScreenspaceEffects", "MuR.Mode18CC", function()
        if MuR.GamemodeCount ~= 18 then return end

        if lightningFlash > 0.01 then
            local tab = {
                ["$pp_colour_addr"] = 0.5 * lightningFlash,
                ["$pp_colour_addg"] = 0.5 * lightningFlash,
                ["$pp_colour_addb"] = 0.6 * lightningFlash,
                ["$pp_colour_brightness"] = 0.3 * lightningFlash,
                ["$pp_colour_contrast"] = 1 + lightningFlash * 0.5,
                ["$pp_colour_colour"] = 1,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(tab)
        end

        if atmosphereIntensity > 0.01 then
            local hellIntensity = atmosphereIntensity
            local specialMult = isSpecialWave and 1.5 or 1
            local pulse = pulseEffect * 0.05 * hellIntensity

            local tab = {
                ["$pp_colour_addr"] = (0.15 + pulse) * hellIntensity * specialMult,
                ["$pp_colour_addg"] = 0.02 * hellIntensity,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = -0.1 * hellIntensity * specialMult,
                ["$pp_colour_contrast"] = 1 + (0.3 * hellIntensity * specialMult),
                ["$pp_colour_colour"] = 1 - (0.4 * hellIntensity * specialMult),
                ["$pp_colour_mulr"] = 0.05 * hellIntensity,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(tab)

            if isSpecialWave and stormIntensity > 0.3 then
                DrawSharpen(1 + stormIntensity * 0.5, 0.5 * stormIntensity)
            end
        end
    end)

    hook.Add("HUDPaint", "MuR.Mode18Particles", function()
        if MuR.GamemodeCount ~= 18 or MuR.CutsceneActive then return end

        local dt = FrameTime()

        for i = #emberParticles, 1, -1 do
            local p = emberParticles[i]
            if CurTime() < p.life then
                p.x = p.x + p.vx * dt + windSway * 50 * dt
                p.y = p.y + p.vy * dt
                p.vy = p.vy - 30 * dt

                local alpha = math.Remap(p.life - CurTime(), 0, 2, 0, 255)
                local flicker = math.sin(CurTime() * 20 + p.flicker) * 0.3 + 0.7

                surface.SetMaterial(emberMat)
                surface.SetDrawColor(p.color.r, p.color.g, p.color.b, alpha * flicker)
                local size = p.size * (1 + math.sin(CurTime() * 10 + p.flicker) * 0.2)
                surface.DrawTexturedRect(p.x - size, p.y - size, size * 2, size * 2)
            else
                table.remove(emberParticles, i)
            end
        end

        for i = #ashParticles, 1, -1 do
            local p = ashParticles[i]
            if CurTime() < p.life then
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.rotation = p.rotation + p.rotSpeed * dt

                local alpha = math.Remap(p.life - CurTime(), 0, 1, 0, 150)

                surface.SetDrawColor(30, 30, 30, alpha)
                local matrix = Matrix()
                matrix:Translate(Vector(p.x, p.y, 0))
                matrix:Rotate(Angle(0, p.rotation, 0))
                matrix:Translate(Vector(-p.x, -p.y, 0))

                cam.PushModelMatrix(matrix)
                    surface.DrawRect(p.x - p.size/2, p.y - p.size/2, p.size, p.size)
                cam.PopModelMatrix()
            else
                table.remove(ashParticles, i)
            end
        end

        for i = #bloodDrips, 1, -1 do
            local p = bloodDrips[i]
            if CurTime() < p.life then
                p.vy = p.vy + 500 * dt
                p.y = p.y + p.vy * dt

                if p.y > ScrH() + p.length then
                    p.life = 0
                else
                    local alpha = math.min(p.alpha, math.Remap(p.life - CurTime(), 0, 1, 0, p.alpha))
                    surface.SetDrawColor(100, 0, 0, alpha)
                    surface.DrawRect(p.x, p.y - p.length, 3, p.length)
                    surface.SetDrawColor(150, 0, 0, alpha * 0.7)
                    surface.DrawRect(p.x + 1, p.y - p.length * 0.8, 1, p.length * 0.8)
                end
            else
                table.remove(bloodDrips, i)
            end
        end

        if stormIntensity > 0.3 then
            local lineCount = math.floor(50 * stormIntensity)
            surface.SetDrawColor(80, 80, 90, 30 * stormIntensity)

            local angle = 15 + windSway * 10
            local len = 30 + stormIntensity * 20

            for i = 1, lineCount do
                local x = (i / lineCount * ScrW() + CurTime() * 500) % (ScrW() + 200) - 100
                local y = math.random(0, ScrH())
                local rad = math.rad(angle)
                surface.DrawLine(x, y, x + math.cos(rad) * len, y + math.sin(rad) * len)
            end
        end

        if isSpecialWave and stormIntensity > 0.5 then
            local pulse = math.sin(CurTime() * 4) * 0.5 + 0.5
            surface.SetDrawColor(100, 0, 0, 20 * pulse * stormIntensity)
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end
    end)

    local dissolvingRagdolls = {}

    net.Receive("MuR.Mode18AshEffect", function()
        local rag = net.ReadEntity()
        local duration = net.ReadFloat()

        if IsValid(rag) then
            table.insert(dissolvingRagdolls, {
                ent = rag,
                startTime = CurTime(),
                duration = duration,
                emitter = ParticleEmitter(rag:GetPos(), false),
                nextParticle = 0
            })

            sound.Play("ambient/fire/mtov_flame2.wav", rag:GetPos(), 55, math.random(120, 150))
        end
    end)

    hook.Add("PreDrawOpaqueRenderables", "MuR.Mode18DissolveRagdolls", function()
        if MuR.GamemodeCount ~= 18 then return end

        for i = #dissolvingRagdolls, 1, -1 do
            local data = dissolvingRagdolls[i]
            local rag = data.ent

            if not IsValid(rag) then
                if data.emitter then data.emitter:Finish() end
                table.remove(dissolvingRagdolls, i)
                continue
            end

            local elapsed = CurTime() - data.startTime
            local progress = math.Clamp(elapsed / data.duration, 0, 1)

            if progress >= 1 then
                if data.emitter then data.emitter:Finish() end
                table.remove(dissolvingRagdolls, i)
                continue
            end

            rag.Mode18DissolveProgress = progress

            if data.emitter and CurTime() > data.nextParticle then
                data.nextParticle = CurTime() + 0.05

                local pos = rag:GetPos() + VectorRand() * 30
                local boneCount = rag:GetBoneCount()
                if boneCount and boneCount > 0 then
                    local bonePos = rag:GetBonePosition(math.random(0, boneCount - 1))
                    if bonePos then pos = bonePos + VectorRand() * 10 end
                end

                local particleCount = math.floor(2 + progress * 5)
                for j = 1, particleCount do
                    local particle = data.emitter:Add("particle/smokesprites_000" .. math.random(1, 9), pos)
                    if particle then
                        particle:SetVelocity(VectorRand() * 30 + Vector(0, 0, 30 + progress * 50))
                        particle:SetDieTime(1.5 + math.random() * 1)
                        particle:SetStartAlpha(100 + progress * 100)
                        particle:SetEndAlpha(0)
                        particle:SetStartSize(2 + progress * 4)
                        particle:SetEndSize(1)
                        particle:SetRoll(math.random(0, 360))
                        particle:SetRollDelta(math.random(-2, 2))
                        particle:SetColor(50, 45, 40)
                        particle:SetGravity(Vector(0, 0, -20))
                        particle:SetAirResistance(80)
                    end
                end

                if math.random() < 0.3 + progress * 0.4 then
                    local ember = data.emitter:Add("effects/ember_swirling001", pos)
                    if ember then
                        ember:SetVelocity(VectorRand() * 50 + Vector(0, 0, 50 + progress * 100))
                        ember:SetDieTime(1 + math.random())
                        ember:SetStartAlpha(255)
                        ember:SetEndAlpha(0)
                        ember:SetStartSize(2 + math.random() * 2)
                        ember:SetEndSize(0)
                        ember:SetColor(255, math.random(80, 150), 0)
                        ember:SetGravity(Vector(0, 0, 20))
                    end
                end
            end
        end
    end)

    hook.Add("PreDrawTranslucentRenderables", "MuR.Mode18RenderDissolve", function()
        if MuR.GamemodeCount ~= 18 then return end

        for _, data in ipairs(dissolvingRagdolls) do
            local rag = data.ent
            if not IsValid(rag) then continue end

            local progress = data.ent.Mode18DissolveProgress or 0

            render.SetBlend(1 - progress)
            render.SetColorModulation(1 - progress * 0.5, 1 - progress * 0.7, 1 - progress * 0.7)

            rag:DrawModel()

            render.SetBlend(1)
            render.SetColorModulation(1, 1, 1)
        end
    end)

    hook.Add("PreDrawOpaqueRenderables", "MuR.Mode18HideDissolving", function()
        if MuR.GamemodeCount ~= 18 then return end

        for _, data in ipairs(dissolvingRagdolls) do
            if IsValid(data.ent) then
                data.ent:SetNoDraw(true)
            end
        end
    end)

    hook.Add("PostDrawOpaqueRenderables", "MuR.Mode18RestoreDissolving", function()
        if MuR.GamemodeCount ~= 18 then return end

        for _, data in ipairs(dissolvingRagdolls) do
            if IsValid(data.ent) then
                data.ent:SetNoDraw(false)
            end
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", "MuR.Mode18CurseEffects3D", function(depth, sky)
        if MuR.GamemodeCount ~= 18 then return end
        if sky then return end

        local dt = FrameTime()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local plyPos = ply:GetPos()

        for i = #skyboxMeteors, 1, -1 do
            local m = skyboxMeteors[i]
            if CurTime() < m.life then
                m.pos = m.pos + m.vel * dt

                if CurTime() > m.trailTime then
                    m.trailTime = CurTime() + 0.02
                    table.insert(m.trail, {pos = m.pos, life = CurTime() + 0.5, size = m.size})
                    if #m.trail > 30 then table.remove(m.trail, 1) end
                end

                render.SetMaterial(meteorMat)
                local dist = m.pos:Distance(plyPos)
                local alpha = math.Clamp(1 - (dist / 15000), 0.2, 1) * 255

                render.DrawSprite(m.pos, m.size * 2, m.size * 2, Color(m.color.r, m.color.g, m.color.b, alpha))
                render.DrawSprite(m.pos, m.size * 4, m.size * 4, Color(m.color.r, m.color.g * 0.5, 0, alpha * 0.3))

                for j, t in ipairs(m.trail) do
                    if CurTime() < t.life then
                        local trailAlpha = math.Remap(t.life - CurTime(), 0, 0.5, 0, alpha * 0.6)
                        local trailSize = t.size * (j / #m.trail)
                        render.DrawSprite(t.pos, trailSize, trailSize, Color(255, 100, 0, trailAlpha))
                    end
                end
            else
                table.remove(skyboxMeteors, i)
            end
        end

        for i = #worldMeteors, 1, -1 do
            local m = worldMeteors[i]
            if CurTime() < m.life and not m.impacted then
                local dir = (m.targetPos - m.pos):GetNormalized()
                local speed = 600 + curseIntensity * 400
                m.vel = dir * speed
                m.pos = m.pos + m.vel * dt

                if m.emitter and CurTime() > m.nextParticle then
                    m.nextParticle = CurTime() + 0.02
                    local p = m.emitter:Add("particles/smokey", m.pos)
                    if p then
                        p:SetVelocity(-m.vel * 0.1 + VectorRand() * 30)
                        p:SetDieTime(0.5 + math.random() * 0.3)
                        p:SetStartAlpha(200)
                        p:SetEndAlpha(0)
                        p:SetStartSize(m.size * 0.5)
                        p:SetEndSize(m.size * 2)
                        p:SetRoll(math.random(0, 360))
                        p:SetRollDelta(math.random(-2, 2))
                        p:SetColor(255, math.random(50, 100), 0)
                    end

                    local ember = m.emitter:Add("effects/ember_swirling001", m.pos + VectorRand() * m.size * 0.3)
                    if ember then
                        ember:SetVelocity(-m.vel * 0.05 + VectorRand() * 50)
                        ember:SetDieTime(0.3 + math.random() * 0.2)
                        ember:SetStartAlpha(255)
                        ember:SetEndAlpha(0)
                        ember:SetStartSize(3)
                        ember:SetEndSize(0)
                        ember:SetColor(255, math.random(100, 200), 0)
                    end
                end

                render.SetMaterial(meteorMat)
                render.DrawSprite(m.pos, m.size * 2.5, m.size * 2.5, Color(255, 80, 0, 255))
                render.DrawSprite(m.pos, m.size * 5, m.size * 5, Color(255, 30, 0, 100))
                render.DrawSprite(m.pos, m.size, m.size, Color(255, 255, 200, 255))

                if m.pos:Distance(m.targetPos) < 50 or m.pos.z < m.targetPos.z then
                    m.impacted = true

                    local effectdata = EffectData()
                    effectdata:SetOrigin(m.targetPos)
                    effectdata:SetScale(m.size * 0.3)
                    util.Effect("Explosion", effectdata)

                    util.ScreenShake(m.targetPos, 2 + curseIntensity * 3, 5, 0.5, 500)

                    if m.emitter then
                        for j = 1, 30 do
                            local p = m.emitter:Add("effects/ember_swirling001", m.targetPos + Vector(0, 0, 10))
                            if p then
                                p:SetVelocity(VectorRand() * 200 + Vector(0, 0, 150))
                                p:SetDieTime(1 + math.random())
                                p:SetStartAlpha(255)
                                p:SetEndAlpha(0)
                                p:SetStartSize(5 + math.random() * 5)
                                p:SetEndSize(0)
                                p:SetColor(255, math.random(50, 150), 0)
                                p:SetGravity(Vector(0, 0, -300))
                            end
                        end

                        for j = 1, 15 do
                            local p = m.emitter:Add("particles/smokey", m.targetPos + Vector(0, 0, 20))
                            if p then
                                p:SetVelocity(VectorRand() * 100 + Vector(0, 0, 100))
                                p:SetDieTime(2 + math.random())
                                p:SetStartAlpha(150)
                                p:SetEndAlpha(0)
                                p:SetStartSize(20)
                                p:SetEndSize(80)
                                p:SetRoll(math.random(0, 360))
                                p:SetRollDelta(math.random(-1, 1))
                                p:SetColor(50, 40, 30)
                            end
                        end

                        m.emitter:Finish()
                        m.emitter = nil
                    end

                    sound.Play("ambient/explosions/explode_" .. math.random(1, 4) .. ".wav", m.targetPos, 40, math.random(90, 110))
                end
            elseif m.impacted or CurTime() >= m.life then
                if m.emitter then m.emitter:Finish() end
                table.remove(worldMeteors, i)
            end
        end

        for i = #fireColumns, 1, -1 do
            local fc = fireColumns[i]
            if CurTime() < fc.life then
                local elapsed = CurTime() - fc.startTime
                local fadeIn = math.Clamp(elapsed * 2, 0, 1)
                local fadeOut = math.Clamp((fc.life - CurTime()) * 2, 0, 1)
                local alpha = fadeIn * fadeOut * 255

                local heightMod = 1 + math.sin(CurTime() * 5) * 0.2
                local currentHeight = fc.height * heightMod * fadeIn

                render.SetMaterial(fireMat3D)

                local segments = 8
                for j = 0, segments do
                    local t = j / segments
                    local segPos = fc.pos + Vector(0, 0, currentHeight * t)
                    local segSize = fc.width * (1 - t * 0.7) * (1 + math.sin(CurTime() * 10 + t * 5) * 0.3)
                    local segAlpha = alpha * (1 - t * 0.5)

                    local r = 255
                    local g = math.Remap(t, 0, 1, 200, 50)
                    local b = math.Remap(t, 0, 1, 50, 0)

                    render.DrawSprite(segPos, segSize, segSize, Color(r, g, b, segAlpha))
                    render.DrawSprite(segPos, segSize * 1.5, segSize * 1.5, Color(r, g * 0.5, 0, segAlpha * 0.3))
                end

                if fc.emitter and CurTime() > fc.nextParticle then
                    fc.nextParticle = CurTime() + 0.05
                    local p = fc.emitter:Add("effects/ember_swirling001", fc.pos + Vector(math.random(-10, 10), math.random(-10, 10), currentHeight * 0.8))
                    if p then
                        p:SetVelocity(Vector(math.random(-30, 30), math.random(-30, 30), 100 + math.random() * 50))
                        p:SetDieTime(0.8 + math.random() * 0.5)
                        p:SetStartAlpha(255)
                        p:SetEndAlpha(0)
                        p:SetStartSize(3)
                        p:SetEndSize(0)
                        p:SetColor(255, math.random(100, 200), 0)
                        p:SetGravity(Vector(0, 0, 50))
                    end
                end
            else
                if fc.emitter then fc.emitter:Finish() end
                table.remove(fireColumns, i)
            end
        end

        for i = #groundCracks, 1, -1 do
            local gc = groundCracks[i]
            if CurTime() < gc.life and IsValid(gc.ent) then
                local elapsed = CurTime() - gc.startTime
                local growTime = 1.5
                local fadeOutStart = gc.life - 2

                if elapsed < growTime then
                    local growProgress = elapsed / growTime
                    growProgress = growProgress * growProgress * (3 - 2 * growProgress)
                    gc.currentScale = Lerp(growProgress, 0.01, gc.targetScale)
                    gc.glowIntensity = growProgress
                else
                    gc.currentScale = gc.targetScale
                    gc.glowIntensity = 1
                end

                if CurTime() > fadeOutStart then
                    local fadeProgress = (CurTime() - fadeOutStart) / 2
                    gc.glowIntensity = 1 - fadeProgress
                    gc.currentScale = Lerp(fadeProgress, gc.targetScale, 0.01)
                end

                gc.ent:SetModelScale(gc.currentScale, 0)

                local pulse = math.sin(CurTime() * 5 + gc.pos.x * 0.1) * 0.2 + 0.8
                local lavaGlow = gc.glowIntensity * pulse

                local colorVal = math.floor(60 + lavaGlow * 40)
                gc.ent:SetColor(Color(colorVal + 20, colorVal - 20, colorVal - 30))

                render.SetMaterial(meteorMat)
                local glowSize = 30 + gc.currentScale * 50
                render.DrawSprite(gc.pos, glowSize * lavaGlow, glowSize * lavaGlow, Color(255, 80, 20, 120 * lavaGlow))
                render.DrawSprite(gc.pos, glowSize * 1.5 * lavaGlow, glowSize * 1.5 * lavaGlow, Color(255, 40, 0, 50 * lavaGlow))
                render.DrawSprite(gc.pos + Vector(0, 0, gc.currentScale * 20), glowSize * 0.6 * lavaGlow, glowSize * 0.6 * lavaGlow, Color(255, 150, 50, 80 * lavaGlow))

                if gc.emitter and CurTime() > gc.nextParticle and gc.glowIntensity > 0.3 then
                    gc.nextParticle = CurTime() + 0.08

                    local emberCount = math.floor(1 + gc.glowIntensity * 3)
                    for j = 1, emberCount do
                        local offset = VectorRand() * gc.currentScale * 15
                        offset.z = math.abs(offset.z)
                        local ember = gc.emitter:Add("effects/ember_swirling001", gc.pos + offset)
                        if ember then
                            ember:SetVelocity(Vector(math.random(-30, 30), math.random(-30, 30), 50 + math.random() * 80))
                            ember:SetDieTime(0.8 + math.random() * 0.6)
                            ember:SetStartAlpha(255 * gc.glowIntensity)
                            ember:SetEndAlpha(0)
                            ember:SetStartSize(3 + math.random() * 3)
                            ember:SetEndSize(0)
                            ember:SetColor(255, math.random(80, 180), 0)
                            ember:SetGravity(Vector(0, 0, 30))
                        end
                    end

                    if math.random() < 0.3 then
                        local smoke = gc.emitter:Add("particle/particle_smokegrenade", gc.pos + Vector(0, 0, gc.currentScale * 10))
                        if smoke then
                            smoke:SetVelocity(Vector(math.random(-10, 10), math.random(-10, 10), 20 + math.random() * 30))
                            smoke:SetDieTime(1.5 + math.random())
                            smoke:SetStartAlpha(50 * gc.glowIntensity)
                            smoke:SetEndAlpha(0)
                            smoke:SetStartSize(10 + gc.currentScale * 10)
                            smoke:SetEndSize(30 + gc.currentScale * 20)
                            smoke:SetRoll(math.random(0, 360))
                            smoke:SetRollDelta(math.random(-1, 1))
                            smoke:SetColor(60, 30, 20)
                        end
                    end
                end
            else
                if gc.emitter then gc.emitter:Finish() end
                if IsValid(gc.ent) then gc.ent:Remove() end
                table.remove(groundCracks, i)
            end
        end

        render.SetMaterial(smokeCloudMat)
        for i = #ambientSmoke, 1, -1 do
            local s = ambientSmoke[i]
            if CurTime() < s.life then
                s.pos = s.pos + s.vel * dt
                s.rotation = s.rotation + s.rotSpeed * dt

                local elapsed = CurTime() - s.startTime
                local fadeIn = math.Clamp(elapsed * 0.5, 0, 1)
                local fadeOut = math.Clamp((s.life - CurTime()) * 0.5, 0, 1)
                local alpha = s.alpha * fadeIn * fadeOut

                local sway = math.sin(CurTime() * 0.5 + i) * 10
                local drawPos = s.pos + Vector(sway, 0, 0)
                local size = s.size * 2

                render.DrawSprite(drawPos, size, size, Color(40, 15, 8, alpha * 3))
                render.DrawSprite(drawPos + Vector(0, 0, 20), size * 0.8, size * 0.8, Color(60, 25, 12, alpha * 2))
                render.SetMaterial(meteorMat)
                render.DrawSprite(drawPos, size * 0.4, size * 0.4, Color(255, 80, 30, alpha * 0.8))
            else
                table.remove(ambientSmoke, i)
            end
        end

        for i = #groundFog, 1, -1 do
            local f = groundFog[i]
            if CurTime() < f.life then
                f.pos = f.pos + f.vel * dt

                local elapsed = CurTime() - f.startTime
                local fadeIn = math.Clamp(elapsed * 0.3, 0, 1)
                local fadeOut = math.Clamp((f.life - CurTime()) * 0.3, 0, 1)
                local alpha = f.alpha * fadeIn * fadeOut

                local pulse = math.sin(CurTime() * 2 + i * 0.5) * 0.2 + 1
                local size = f.size * pulse * 1.5

                render.SetMaterial(smokeCloudMat)
                render.DrawSprite(f.pos, size, size * 0.4, Color(35, 15, 8, alpha * 4))
                render.DrawSprite(f.pos + Vector(size * 0.2, size * 0.1, 3), size * 0.8, size * 0.3, Color(45, 20, 10, alpha * 3))
                render.DrawSprite(f.pos - Vector(size * 0.15, size * 0.2, -2), size * 0.6, size * 0.25, Color(30, 12, 6, alpha * 3))
                render.SetMaterial(meteorMat)
                render.DrawSprite(f.pos + Vector(0, 0, 5), size * 0.2, size * 0.2, Color(255, 60, 20, alpha * 0.5))
            else
                table.remove(groundFog, i)
            end
        end
    end)

    hook.Add("PreDrawSkyBox", "MuR.Mode18SkyMeteors", function()
        if MuR.GamemodeCount ~= 18 then return end
        if curseIntensity < 0.05 then return end
    end)

    hook.Add("PostDrawSkyBox", "MuR.Mode18SkyEffects", function()
        if MuR.GamemodeCount ~= 18 then return end
        if curseIntensity < 0.05 then return end

        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local eyePos = EyePos()
        local eyeAng = EyeAngles()
        local forward = eyeAng:Forward()

        local redTint = curseIntensity * 0.8
        local pulse = math.sin(CurTime() * 1.5) * 0.15 + 0.85

        render.SetMaterial(smokeCloudMat)
        for i = 1, 16 do
            local ang = (i / 16) * math.pi * 2 + CurTime() * 0.01
            local skyPos = eyePos + Vector(math.cos(ang) * 120, math.sin(ang) * 120, 50 + math.sin(CurTime() * 0.3 + i) * 20)
            local size = 80 + math.sin(CurTime() * 0.2 + i * 0.5) * 25
            render.DrawSprite(skyPos, size, size, Color(80, 20, 5, 60 * redTint * pulse))
        end

        render.SetMaterial(meteorMat)

        for i = #skyboxMeteors, 1, -1 do
            local m = skyboxMeteors[i]
            if CurTime() < m.life then
                local relPos = m.pos - ply:GetPos()
                local dir = relPos:GetNormalized()
                local skyDist = 150
                local skyPos = eyePos + dir * skyDist

                local meteorSize = 8 + m.size * 0.15

                render.DrawSprite(skyPos, meteorSize, meteorSize, Color(255, 255, 220, 255))
                render.DrawSprite(skyPos, meteorSize * 2, meteorSize * 2, Color(255, 150, 50, 200))
                render.DrawSprite(skyPos, meteorSize * 4, meteorSize * 4, Color(255, 80, 20, 100))
                render.DrawSprite(skyPos, meteorSize * 6, meteorSize * 6, Color(255, 40, 0, 40))

                if #m.trail > 0 then
                    local prevPos = skyPos
                    for j = #m.trail, 1, -1 do
                        local t = m.trail[j]
                        if CurTime() < t.life then
                            local trailRel = t.pos - ply:GetPos()
                            local trailDir = trailRel:GetNormalized()
                            local trailSkyPos = eyePos + trailDir * skyDist

                            local trailProgress = j / #m.trail
                            local trailAlpha = math.Remap(t.life - CurTime(), 0, 0.5, 0, 200) * trailProgress
                            local trailSize = meteorSize * trailProgress * 0.8

                            render.DrawSprite(trailSkyPos, trailSize * 1.5, trailSize * 1.5, Color(255, 120, 30, trailAlpha))
                            render.DrawSprite(trailSkyPos, trailSize * 3, trailSize * 3, Color(255, 60, 10, trailAlpha * 0.4))

                            prevPos = trailSkyPos
                        end
                    end
                end
            end
        end

        local horizonGlow = curseIntensity * pulse
        for i = 1, 20 do
            local hAng = (i / 20) * math.pi * 2
            local hPos = eyePos + Vector(math.cos(hAng) * 130, math.sin(hAng) * 130, -30)
            local hSize = 50 + math.sin(CurTime() * 0.6 + i * 0.4) * 15
            render.DrawSprite(hPos, hSize, hSize * 0.5, Color(255, 50, 10, 70 * horizonGlow))
        end

        render.SetMaterial(fogMat)
        local waveCount = math.floor(5 + curseIntensity * 8)
        for i = 1, waveCount do
            local waveTime = CurTime() * 0.3 + i * 0.8
            local waveAng = (i / waveCount) * math.pi * 2 + math.sin(waveTime) * 0.5
            local waveDist = 100 + math.sin(waveTime * 0.5) * 30
            local wavePos = eyePos + Vector(math.cos(waveAng) * waveDist, math.sin(waveAng) * waveDist, 30 + math.sin(waveTime * 1.2) * 20)
            local waveSize = 40 + math.sin(waveTime * 1.5) * 15
            render.DrawSprite(wavePos, waveSize, waveSize, Color(255, 100, 40, 40 * curseIntensity))
        end

        if curseIntensity > 0.4 then
            local flashChance = (curseIntensity - 0.4) * 0.03
            if math.random() < flashChance then
                for i = 1, math.random(2, 4) do
                    local lAng = math.random() * math.pi * 2
                    local lDist = 80 + math.random() * 40
                    local lPos = eyePos + Vector(math.cos(lAng) * lDist, math.sin(lAng) * lDist, 60 + math.random() * 30)
                    render.SetMaterial(meteorMat)
                    render.DrawSprite(lPos, 20, 20, Color(255, 220, 180, 255))
                    render.DrawSprite(lPos, 50, 50, Color(255, 150, 80, 120))
                    render.DrawSprite(lPos, 100, 100, Color(255, 80, 30, 40))
                end
            end
        end
    end)
end
