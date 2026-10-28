local SNIPER_WARN_SOUND = ")murdered/weapons/m40a1/bolt.mp3"
local SNIPER_SHOOT_SOUND = ")murdered/weapons/m40a1/m40a1_suppressed_fp.wav"
local SNIPER_DAMAGE = 100
local SNIPER_DAMAGE_LEG = 25
local REACTION_TIME = 1.5
local MIN_DELAY = 3
local MAX_DELAY = 5
local ESCAPE_DISTANCE = 180
local SNIPER_POINTS_COUNT = 16
local SNIPER_POINT_DISTANCE_MIN = 768
local SNIPER_POINT_DISTANCE_MAX = 2048
local SNIPER_POINT_HEIGHT_MIN = 256
local SNIPER_POINT_HEIGHT_MAX = 768
local SNIPER_UPDATE_TIME = 1
local LASER_COLOR = Color(255, 0, 0, 10)
local LASER_WIDTH = 0.5
local MAX_SHOTS_PER_TARGET = 3
local SHOT_INTERVAL = 0.8
local AIM_SMOOTHING = 0.4
local HELI_SOUND_INTERVAL = 8

local targetedPlayers = {}
local activeLasers = {}
local ragdollStates = {}

if CLIENT then
    local laserData = {}

    net.Receive("MuR_LaserEffect", function()
        local plyIndex = net.ReadUInt(16)
        local active = net.ReadBool()

        if active then
            local startPos = net.ReadVector()
            local endPos = net.ReadVector()

            laserData[plyIndex] = {
                startPos = startPos,
                endPos = endPos,
                lastUpdate = CurTime()
            }
        else
            laserData[plyIndex] = nil
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", "MuR_DrawLasers", function()
        local curTime = CurTime()

        for plyIndex, data in pairs(laserData) do
            if curTime - data.lastUpdate < 0.1 then
                render.SetMaterial(Material("cable/redlaser"))
                render.DrawBeam(data.startPos, data.endPos, LASER_WIDTH, 0, 1, LASER_COLOR)

                local glowSize = math.sin(curTime * 10) * 1 + 3
                render.SetMaterial(Material("sprites/light_glow02_add"))
                render.DrawSprite(data.endPos, glowSize, glowSize, Color(255, 0, 0, 15))
            else
                laserData[plyIndex] = nil
            end
        end
    end)
end

if SERVER then
    util.AddNetworkString("MuR_LaserEffect")

    local function GetHeadPosition(ply)
        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then
            local pos = ply:GetBonePosition(headBone)
            if pos then
                return pos
            end
        end
        return ply:EyePos()
    end

    local function GetLegPosition(ply, isLeft)
        local boneName = isLeft and "ValveBiped.Bip01_L_Calf" or "ValveBiped.Bip01_R_Calf"
        local bone = ply:LookupBone(boneName)
        if bone then
            local pos = ply:GetBonePosition(bone)
            if pos then
                return pos + Vector(0, 0, 20)
            end
        end
        return ply:GetPos() + Vector(math.random(-20, 20), math.random(-20, 20), 30)
    end

    local function GetTargetPosition(ply, data)
        local arrestState = ply:GetNW2Float("ArrestState")
        local ragdoll = ply:GetRD()

        if IsValid(ragdoll) then
            local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
            if headBone then
                local pos = ragdoll:GetBonePosition(headBone)
                if pos then
                    return pos
                end
            end
            return ragdoll:GetPos() + Vector(0, 0, 30)
        end

        if arrestState == 1 then
            if !data.targetLeg then
                data.targetLeg = math.random(0, 1) == 1
            end
            return GetLegPosition(ply, data.targetLeg)
        end

        return GetHeadPosition(ply)
    end

    local function PredictPlayerPosition(ply, time)
        local vel = ply:GetVelocity()
        local headPos = GetHeadPosition(ply)
        return headPos + vel * time
    end

    local function IsVisibleFrom(point, ply)
        local targetPos = GetTargetPosition(ply, targetedPlayers[ply] or {})

        local traceData = {
            start = point,
            endpos = targetPos,
            filter = function(ent)
                return ent:GetClass() != "prop_ragdoll" and ent != ply
            end,
            mask = MASK_VISIBLE_AND_NPCS
        }

        local trace = util.TraceLine(traceData)
        return !trace.Hit or trace.Entity == ply, targetPos
    end

    local function UpdateLaser(ply, startPos, data)
        if !IsValid(ply) then return end

        local targetPos = GetTargetPosition(ply, data)
        local visible, newTargetPos = IsVisibleFrom(startPos, ply)

        if visible then
            data.lastKnownTargetPos = newTargetPos
            data.currentAimPos = data.currentAimPos or newTargetPos
        end

        if data.lastKnownTargetPos then
            data.currentAimPos = data.currentAimPos or data.lastKnownTargetPos
            data.currentAimPos = LerpVector(AIM_SMOOTHING, data.currentAimPos, data.lastKnownTargetPos)
        end

        local aimPos = data.currentAimPos or targetPos

        if !visible then
            local wallTrace = util.TraceLine({
                start = startPos,
                endpos = startPos + (aimPos - startPos):GetNormalized() * 4000,
                filter = function(ent)
                    return ent:GetClass() != "prop_ragdoll" and ent != ply
                end,
                mask = MASK_VISIBLE_AND_NPCS
            })
            aimPos = wallTrace.HitPos
        end

        net.Start("MuR_LaserEffect")
        net.WriteUInt(ply:EntIndex(), 16)
        net.WriteBool(true)
        net.WriteVector(startPos)
        net.WriteVector(aimPos)
        net.Send(ply)

        local otherPlayers = {}
        for _, p in player.Iterator() do
            if p != ply and p:GetPos():Distance(ply:GetPos()) < 1000 then
                table.insert(otherPlayers, p)
            end
        end

        if #otherPlayers > 0 then
            net.Start("MuR_LaserEffect")
            net.WriteUInt(ply:EntIndex(), 16)
            net.WriteBool(true)
            net.WriteVector(startPos)
            net.WriteVector(aimPos)
            net.Send(otherPlayers)
        end
    end

    local function CreateLaserEffect(startPos, ply, data)
        activeLasers[ply] = {
            startPos = startPos,
            timer = "MuR_Laser_" .. ply:EntIndex(),
            data = data
        }

        timer.Create(activeLasers[ply].timer, 0.05, 0, function()
            if !IsValid(ply) or !activeLasers[ply] then
                timer.Remove("MuR_Laser_" .. ply:EntIndex())
                return
            end

            UpdateLaser(ply, startPos, data)
        end)
    end

    local function RemoveLaser(ply)
        if activeLasers[ply] then
            timer.Remove(activeLasers[ply].timer)

            net.Start("MuR_LaserEffect")
            net.WriteUInt(ply:EntIndex(), 16)
            net.WriteBool(false)
            net.Broadcast()

            activeLasers[ply] = nil
        end
    end

    local function PlayHeliSounds(shootPoint, ply)
        local soundFile = ")murdered/pheli/chopper" .. math.random(1, 20) .. ".wav"
        sound.Play(soundFile, shootPoint, 100, math.random(90, 110))

        timer.Create("MuR_HeliSounds_" .. ply:EntIndex(), HELI_SOUND_INTERVAL, 0, function()
            if !IsValid(ply) or (!IsValid(ply:GetRD()) and ply:GetNW2Float("ArrestState") != 1) then
                timer.Remove("MuR_HeliSounds_" .. ply:EntIndex())
                return
            end

            local soundFile = ")murdered/pheli/chopper" .. math.random(1, 20) .. ".wav"
            sound.Play(soundFile, shootPoint, 100, math.random(90, 110))
        end)
    end

    local function FindSniperPoints(ply)
        local playerPos = ply:GetPos()
        local points = {}

        for i = 1, SNIPER_POINTS_COUNT do
            local angle = math.random() * math.pi * 2
            local distance = math.random(SNIPER_POINT_DISTANCE_MIN, SNIPER_POINT_DISTANCE_MAX)
            local height = math.random(SNIPER_POINT_HEIGHT_MIN, SNIPER_POINT_HEIGHT_MAX)

            local potentialPoint = playerPos + Vector(
                math.cos(angle) * distance,
                math.sin(angle) * distance,
                height
            )

            local skyTrace = util.TraceLine({
                start = potentialPoint,
                endpos = potentialPoint + Vector(0, 0, 5000),
                mask = MASK_SOLID
            })

            if skyTrace.HitSky and IsVisibleFrom(potentialPoint, ply) then
                table.insert(points, potentialPoint)
            end
        end

        table.sort(points, function(a, b)
            local distA = a:Distance(playerPos)
            local distB = b:Distance(playerPos)
            return distA < distB
        end)

        return points
    end

    local function FireShot(ply, data, shotNumber)
        if !IsValid(ply) then
            targetedPlayers[ply] = nil
            RemoveLaser(ply)
            return
        end

        local ragdoll = ply:GetRD()
        local arrestState = ply:GetNW2Float("ArrestState")

        if IsValid(ragdoll) and arrestState == 1 then
            RemoveLaser(ply)
            PlayHeliSounds(data.shootPoint, ply)
            targetedPlayers[ply] = nil
            ragdollStates[ply] = true
            return
        end

        if arrestState == 1 and data.targetLeg then
            data.targetLeg = nil
        end

        local targetPos = GetTargetPosition(ply, data)
        local newVisible, newTargetPos = IsVisibleFrom(data.shootPoint, ply)

        if newVisible then
            data.lastKnownTargetPos = newTargetPos
        end

        local finalTargetPos = data.currentAimPos or targetPos
        local direction = (finalTargetPos - data.shootPoint):GetNormalized()
        local escaped = ply:GetPos():Distance(data.initialPos) > ESCAPE_DISTANCE
        local spread = escaped and Vector(0.05, 0.05, 0) or Vector(0.01, 0.01, 0)

        sound.Play(SNIPER_SHOOT_SOUND, data.shootPoint, 120, math.random(90, 110))

        local ent = ents.Create("info_target")
        ent:SetPos(data.shootPoint)
        ent:Spawn()
        ent.IsPolice = true

        local damage = (data.targetLeg and !IsValid(ragdoll)) and SNIPER_DAMAGE_LEG or SNIPER_DAMAGE

        local bullet = {
            Src = data.shootPoint,
            Dir = direction,
            Spread = spread,
            Force = 5,
            Damage = damage,
            Attacker = game.GetWorld(),
            IgnoreEntity = ent,
            Callback = function(attacker, tr, dmginfo)
                dmginfo:SetDamageType(DMG_BULLET)

                if tr.Hit and !tr.HitSky then
                    local effectdata = EffectData()
                    effectdata:SetOrigin(tr.HitPos)
                    effectdata:SetNormal(tr.HitNormal)
                    util.Effect("Impact", effectdata)
                end

                return {true, true}
            end
        }

        ent:FireBullets(bullet)
        SafeRemoveEntityDelayed(ent, 1)

        if shotNumber < MAX_SHOTS_PER_TARGET and !escaped and IsValid(ply) and !IsValid(ply:GetRD()) then
            timer.Simple(SHOT_INTERVAL, function()
                FireShot(ply, data, shotNumber + 1)
            end)
        else
            RemoveLaser(ply)
            local delay = math.Rand(MIN_DELAY, MAX_DELAY)
            timer.Simple(delay, function()
                if !IsValid(ply) then return end
                targetedPlayers[ply] = nil
            end)
        end
    end

    local function TargetPlayer(ply)
        if targetedPlayers[ply] then return end

        local arrestState = ply:GetNW2Float("ArrestState")
        local ragdoll = ply:GetRD()

        if arrestState == 1 and IsValid(ragdoll) and ragdollStates[ply] then
            return
        end

        local initialPos = ply:GetPos()
        local sniperPoints = FindSniperPoints(ply)

        if #sniperPoints == 0 then return end

        local shootPoint = sniperPoints[math.random(math.min(3, #sniperPoints))]
        local isVisible, targetPos = IsVisibleFrom(shootPoint, ply)

        if !isVisible then return end

        sound.Play(SNIPER_WARN_SOUND, shootPoint, 80, math.random(90, 110))

        targetedPlayers[ply] = {
            shootPoint = shootPoint,
            lastKnownTargetPos = targetPos,
            currentAimPos = targetPos,
            initialPos = initialPos,
            targetLeg = nil
        }

        CreateLaserEffect(shootPoint, ply, targetedPlayers[ply])

        timer.Simple(REACTION_TIME, function()
            if targetedPlayers[ply] then
                FireShot(ply, targetedPlayers[ply], 1)
            end
        end)
    end

    local function ShouldTargetPlayer(ply)
        if !IsValid(ply) or !ply:Alive() or targetedPlayers[ply] then
            return false
        end

        if ply:IsRolePolice() then return end

        local arrestState = ply:GetNW2Float("ArrestState")
        local ragdoll = ply:GetRD()

        if arrestState != 2 and arrestState != 1 and !IsValid(ragdoll) then
            return false
        end

        if arrestState == 1 and IsValid(ragdoll) and ragdollStates[ply] then
            return false
        end

        local sniperPoints = FindSniperPoints(ply)

        for _, point in ipairs(sniperPoints) do
            local visible = IsVisibleFrom(point, ply)
            if visible then
                return true
            end
        end

        return false
    end

    timer.Create("MuR_SniperSystem", SNIPER_UPDATE_TIME, 0, function()
        if !MuR.SniperArrived then return end
        local tab = table.Copy(player.GetAll())
        table.Shuffle(tab)
        for _, ply in pairs(tab) do
            if ShouldTargetPlayer(ply) then
                TargetPlayer(ply)
                break
            end
        end
    end)

    hook.Add("PlayerDisconnected", "MuR_SniperSystemCleanup", function(ply)
        targetedPlayers[ply] = nil
        ragdollStates[ply] = nil
        RemoveLaser(ply)
        timer.Remove("MuR_HeliSounds_" .. ply:EntIndex())
    end)

    hook.Add("PlayerDeath", "MuR_SniperDeathCleanup", function(ply)
        RemoveLaser(ply)
        ragdollStates[ply] = nil
        timer.Remove("MuR_HeliSounds_" .. ply:EntIndex())
    end)

    hook.Add("PlayerSpawn", "MuR_SniperSpawnCleanup", function(ply)
        ragdollStates[ply] = nil
    end)
end
