local viewpunch = 1
local viewpunchExplosion = 1
local viewpunchIntensity = 0.3
local buildupSpeed = 1
local sharpen = 1
local muffle = 0
local sharpenIntensity = 0.5
local soundVolume = 1
local bloom = 1
local blur = 1
local blurIntensity = 0.05
local bloomIntensity = 0.5
local enabled = 1
local gaspEnabled = 1
local enableVehicle = 1
local enableCover = 0

if SERVER then
    util.AddNetworkString("mursupviewpunch_punch")
end

function ApplySuppressionEffect(attacker, hitPos, startPos, multiplier)
    local traceStart = startPos or attacker:EyePos()
    local traceEnd = hitPos

    for _, player in player.Iterator() do
        local distance, suppressionPoint = util.DistanceToLine(traceStart, traceEnd, player:GetPos())

        if player:IsPlayer() and player:Alive() and enabled == 1 and distance < 100 and player ~= attacker then
            local trace = util.TraceLine({
                start = suppressionPoint,
                endpos = player:EyePos(),
                filter = player
            })

            if enableCover == 0 and trace.Hit then return end
            if player:InVehicle() and enableVehicle == 0 then return end

            local currentEffect = math.Clamp(player:GetNW2Float("EffectAMT"), 0, 1)
            player:SetNW2Float("EffectAMT", currentEffect + 0.05 * multiplier * buildupSpeed)

            if viewpunch == 1 then
                net.Start("mursupviewpunch_punch")
                net.WriteVector(suppressionPoint)
                net.WriteFloat(distance)
                net.Send(player)
            end

            timer.Remove(player:Name() .. "blurreset")
            timer.Create(player:Name() .. "blurreset", 4, 1, function()
                local effectAmount = player:GetNW2Float("EffectAMT")
                for i = 1, (effectAmount / 0.05) + 1 do
                    timer.Simple(0.1 * i, function()
                        if IsValid(player) then
                            local newAmount = math.Clamp(player:GetNW2Float("EffectAMT") - 0.1, 0, 100000)
                            player:SetNW2Float("EffectAMT", newAmount)

                            if muffle == 1 then
                                player:SetDSP(1, false)
                            end
                        end
                    end)
                end

                if IsValid(player) and player:Alive() and gaspEnabled == 1 and player:GetNW2Float("EffectAMT") >= 0.4 then
                    local gaspSound = "gasp/focus_gasp_0" .. math.random(1, 6) .. ".wav"
                    player:EmitSound(gaspSound, 75, math.random(90, 110), soundVolume)
                end
            end)
        end
    end
end

hook.Add("EntityFireBullets", "SuppressionFunc", function(attacker, bulletData)
    local originalCallback = bulletData.Callback

    bulletData.Callback = function(shooter, traceResult, damageInfo)
        if originalCallback then
            originalCallback(shooter, traceResult, damageInfo)
        end

        if SERVER then
            ApplySuppressionEffect(shooter, traceResult.HitPos, traceResult.StartPos, 1)
        end
    end
end)

hook.Add("OnDamagedByExplosion", "SuppressExplosion", function(player, damageInfo)
    if viewpunchExplosion == 0 then return end
    if damageInfo:GetDamage() < 30 and not player:Alive() then return end

    if SERVER then
        ApplySuppressionEffect(nil, player:GetPos(), player:GetPos(), 20)
    end
end)

local sharpenLerp = 0
local bloomLerp = 0
local effectLerp = 0

hook.Add("RenderScreenspaceEffects", "ApplySuppression", function()
    local localPlayer = LocalPlayer()
    local effectAmount = localPlayer:GetNW2Float("EffectAMT")

    if effectAmount == 0 then return end

    if effectAmount >= 0.7 and localPlayer:Alive() and muffle == 1 then
        localPlayer:SetDSP(14, false)
    end

    if sharpen == 1 then
        sharpenLerp = Lerp(6 * FrameTime(), sharpenLerp, effectAmount * sharpenIntensity)
        DrawSharpen(sharpenLerp, 0.4)
    end

    if bloom == 1 then
        bloomLerp = Lerp(6 * FrameTime(), bloomLerp, effectAmount * 0.5 * bloomIntensity)
        DrawBloom(0.30, bloomLerp, 0.33, 4.5, 1, 0, 1, 1, 1)
    end
end)

net.Receive("mursupviewpunch_punch", function()
    local effectAmount = LocalPlayer():GetNW2Float("EffectAMT")
    local punchIntensity = effectAmount * viewpunchIntensity
    local punchAngle = Angle(
        math.Rand(-100, 100) * punchIntensity,
        math.Rand(-100, 100) * punchIntensity,
        math.Rand(-100, 100) * punchIntensity
    )
    LocalPlayer():CLViewPunch(punchAngle)

    local suppressionPoint = net.ReadVector()
    local distance = net.ReadFloat()

    if distance < 30 then
        local snapSound = "bul_snap/supersonic_snap_" .. math.random(1, 18) .. ".wav"
        sound.Play(snapSound, suppressionPoint, 75, 100, soundVolume)
    end

    local flybySound = "bul_flyby/subsonic_" .. math.random(1, 27) .. ".wav"
    sound.Play(flybySound, suppressionPoint, 75, 100, soundVolume*0.5)
end)

hook.Add("PlayerInitialSpawn", "Initialize", function(player)
    player:SetNW2Float("EffectAMT", 0)
end)

hook.Add("PlayerDeath", "ClearDeath", function(player, inflictor, attacker)
    player:SetNW2Float("EffectAMT", 0)
end)

hook.Add("GetMotionBlurValues", "SuppressionBlur", function(horizontal, vertical, forward, rotational)
    if blur == 0 then return end

    effectLerp = Lerp(RealFrameTime() * 5, effectLerp, LocalPlayer():GetNW2Float("EffectAMT"))
    local blurForward = (effectLerp * blurIntensity) / 1.5

    return blurForward / 500, blurForward / 500, blurForward, rotational
end)

if CLIENT then
    local meta = FindMetaTable("Player")
    local metavec = FindMetaTable("Vector")

    local PUNCH_DAMPING = 10
    local PUNCH_SPRING_CONSTANT = 600

    local function lensqr(ang)
        return (ang[1] ^ 2) + (ang[2] ^ 2) + (ang[3] ^ 2)
    end

    function metavec:Approach(x, y, z, speed)
        if !isnumber(x) then
            local vec = x
            speed = y
            x, y, z = vec:Unpack()
        end
        self[1] = math.Approach(self[1], x, speed)
        self[2] = math.Approach(self[2], y, speed)
        self[3] = math.Approach(self[3], z, speed)
    end

    local function CLViewPunchThink()
        local self = LocalPlayer()
        if !self.ViewPunchVelocity then
            self.ViewPunchVelocity = Angle()
            self.ViewPunchAngle = Angle()
        end
        local vpa = self.ViewPunchAngle
        local vpv = self.ViewPunchVelocity

        if !self.ViewPunchDone and lensqr(vpa) + lensqr(vpv) > 0.000001 then
            local FT = FrameTime()

            vpa = vpa + (vpv * FT)
            local damping = 1 - (PUNCH_DAMPING * FT)
            if damping < 0 then
                damping = 0
            end
            vpv = vpv * damping

            local springforcemagnitude = PUNCH_SPRING_CONSTANT * FT
            springforcemagnitude = math.Clamp(springforcemagnitude, 0, 2)
            vpv = vpv - (vpa * springforcemagnitude)

            vpa[1] = math.Clamp(vpa[1], -89.9, 89.9)
            vpa[2] = math.Clamp(vpa[2], -179.9, 179.9)
            vpa[3] = math.Clamp(vpa[3], -89.9, 89.9)

            self.ViewPunchAngle = vpa
            self.ViewPunchVelocity = vpv
        else
            self.ViewPunchDone = true
        end
    end
    hook.Add("Think", "CLViewPunch", CLViewPunchThink)

    local PunchPos = Vector()
    local runfwd = 0
    local function CLViewPunchCalc(ply, pos, ang)
        if ply.ViewPunchAngle then
            ang:Add(ply.ViewPunchAngle)
        end

        local vel = ply:GetVelocity():Length()
        local punchang = ply:GetViewPunchAngles() + (ply.ViewPunchAngle or angle_zero)
        PunchPos:Approach(0, 0, 0, FrameTime()*2.5)
        runfwd = math.Approach(runfwd, 1, FrameTime()*5)
        local punchlocal = LocalToWorld(PunchPos, angle_zero, pos, ang)
        punchlocal:Sub(pos)
        punchlocal.z = -punchlocal:Length()
        pos:Add(punchlocal)
    end

    hook.Add("CalcView","CLViewPunch",CLViewPunchCalc)

    function meta:CLViewPunch(angle)
        self.ViewPunchVelocity:Add(angle * 1)

        local ang = self.ViewPunchVelocity

        ang[1] = math.Clamp(ang[1], -180, 180)
        ang[2] = math.Clamp(ang[2], -180, 180)
        ang[3] = math.Clamp(ang[3], -180, 180)

        self.ViewPunchDone = false
    end

    function meta:GetCLViewPunchAngles()
        return self.ViewPunchAngle
    end
end
