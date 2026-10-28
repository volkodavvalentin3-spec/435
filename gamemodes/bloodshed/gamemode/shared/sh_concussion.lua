MuR.ConcussionProfiles = {
    flashbang     = {radius = 600, power = 0.62},
    grenade_f1    = {radius = 500, power = 1.12},
    grenade_m67   = {radius = 450, power = 0.95},
    ied           = {radius = 700, power = 1.45},
    c4            = {radius = 850, power = 1.68},
    rpg           = {radius = 560, power = 1.4},
    gas_canister  = {radius = 350, power = 0.67},
    vehicle       = {radius = 600, power = 1.23}
}

MuR.ConcussionMinDuration = 3
MuR.ConcussionMaxDuration = 12

function MuR.GetConcussion(ply)
    local endTime = ply:GetNW2Float("MuR.ConcussionEnd", 0)
    local now = CurTime()
    if endTime <= now then return 0 end

    local startTime = ply:GetNW2Float("MuR.ConcussionStart", 0)
    local total = endTime - startTime
    if total <= 0 then return 0 end

    return ply:GetNW2Float("MuR.ConcussionPower", 0) * ((endTime - now) / total)
end

hook.Add("SetupMove", "MuR.ConcussionMove", function(ply, mv, cmd)
    local power = MuR.GetConcussion(ply)
    if power <= 0 then return end

    local slow = 1 - math.Clamp(power, 0, 1) * 0.35
    local cap = ply:GetWalkSpeed() * slow

    if power > 0.4 then
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_SPEED)))
    else
        cap = math.max(cap, math.min(mv:GetMaxSpeed(), ply:GetRunSpeed() * slow))
    end

    if mv:GetMaxSpeed() > cap then
        mv:SetMaxSpeed(cap)
        mv:SetMaxClientSpeed(cap)
    end
end)

if SERVER then
    util.AddNetworkString("MuR.Concussion")

    local COVER_SAMPLE_STEP = 6
    local COVER_MAX_SAMPLES = 48
    local COVER_THIN_UNITS = 6
    local COVER_THICK_UNITS = 90
    local COVER_THIN_FACTOR = 0.6
    local COVER_THICK_FACTOR = 0.2
    local COVER_OPEN_MIN = 0.35

    local PROXIMITY_RADIUS_FRAC = 0.22
    local PROXIMITY_MAX_BLEND = 0.65

    local function MeasureCoverThickness(startPos, endPos)
        local delta = endPos - startPos
        local len = delta:Length()
        if len < 1 then return 0 end

        local dir = delta / len
        local samples = math.min(COVER_MAX_SAMPLES, math.max(1, math.ceil(len / COVER_SAMPLE_STEP)))
        local step = len / samples
        local thickness = 0

        for i = 1, samples do
            local contents = util.PointContents(startPos + dir * ((i - 0.5) * step))
            if bit.band(contents, CONTENTS_SOLID) ~= 0 or bit.band(contents, CONTENTS_GRATE) ~= 0 then
                thickness = thickness + step
            end
        end

        return thickness
    end

    local function GetCoverFactor(pos, ply)
        local eyePos = ply:EyePos()

        local eyeTrace = util.TraceLine({
            start = pos,
            endpos = eyePos,
            filter = {ply},
            mask = MASK_SOLID_BRUSHONLY
        })

        if not eyeTrace.Hit then return 1 end

        local thickness = MeasureCoverThickness(pos, eyePos)
        if thickness <= 0 then thickness = COVER_SAMPLE_STEP end

        local t = math.Clamp((thickness - COVER_THIN_UNITS) / (COVER_THICK_UNITS - COVER_THIN_UNITS), 0, 1)
        local factor = Lerp(t, COVER_THIN_FACTOR, COVER_THICK_FACTOR)

        local bodyTrace = util.TraceLine({
            start = pos,
            endpos = ply:WorldSpaceCenter(),
            filter = {ply},
            mask = MASK_SOLID_BRUSHONLY
        })
        if not bodyTrace.Hit then
            factor = math.max(factor, COVER_OPEN_MIN)
        end

        return factor
    end

    local function GetArmorFactor(ply)
        if not ply.GetEquippedArmor then return 1 end

        local reduction = 0
        for bodypart, armorId in pairs(ply:GetEquippedArmor() or {}) do
            if ply.IsArmorActive and not ply:IsArmorActive(bodypart) then continue end

            local item = MuR.Armor and MuR.Armor.GetItem(armorId)
            if not item then continue end

            local value = item.concussion_reduction
            if not value then value = (item.damage_reduction or 0) * 0.4 end
            reduction = reduction + value
        end

        return math.Clamp(1 - reduction, 0.2, 1)
    end

    local function GetChemFactors(ply)
        if not ply.GetChemMods then return 1, 1 end

        local mods = ply:GetChemMods()
        if not istable(mods) then return 1, 1 end

        local dampen = math.Clamp((mods.Analgesia or 0) * 0.25 + (mods.Sedation or 0) * 0.2, 0, 0.35)
        local durationMul = 1 + math.Clamp(mods.Sedation or 0, 0, 1) * 0.4

        if (mods.StaminaMul or 1) > 1 then
            durationMul = durationMul * 0.7
        end

        return 1 - dampen, durationMul
    end

    function MuR:GetConcussionStrength(ply, pos, profile)
        local def = MuR.ConcussionProfiles[profile]
        if not def then return 0, 0 end
        if not IsValid(ply) or not ply:Alive() then return 0, 0 end

        local dist = pos:Distance(ply:EyePos())
        if dist >= def.radius then return 0, 0 end

        local falloff = math.pow(1 - dist / def.radius, 1.5)
        local chemFactor, durationMul = GetChemFactors(ply)

        local coverFactor = GetCoverFactor(pos, ply)

        local proximityZone = def.radius * PROXIMITY_RADIUS_FRAC
        if dist < proximityZone then
            local closeness = 1 - dist / proximityZone
            local blend = closeness * PROXIMITY_MAX_BLEND
            coverFactor = coverFactor * (1 - blend) + blend
        end

        local strength = def.power * falloff * coverFactor * GetArmorFactor(ply) * chemFactor
        strength = math.Clamp(strength, 0, 1)

        if strength < 0.08 then return 0, 0 end

        local duration = Lerp(strength, MuR.ConcussionMinDuration, MuR.ConcussionMaxDuration) * durationMul

        return strength, duration
    end

    function MuR:ApplyConcussionTo(ply, strength, duration)
        if not IsValid(ply) or strength <= 0 then return end

        local endTime = CurTime() + duration
        if (ply.MuR_ConcussionEnd or 0) > endTime and (ply.MuR_ConcussionStrength or 0) >= strength then return end

        ply.MuR_ConcussionEnd = endTime
        ply.MuR_ConcussionStrength = strength

        ply:SetNW2Float("MuR.ConcussionStart", CurTime())
        ply:SetNW2Float("MuR.ConcussionEnd", endTime)
        ply:SetNW2Float("MuR.ConcussionPower", strength)

        ply:SetDSP(31, false)

        ply:ViewPunch(Angle(
            math.Rand(-8, 8) * strength,
            math.Rand(-8, 8) * strength,
            math.Rand(-4, 4) * strength
        ))

        net.Start("MuR.Concussion")
        net.WriteUInt(math.floor(strength * 255), 8)
        net.WriteUInt(math.Clamp(math.floor(duration * 10), 0, 4095), 12)
        net.Send(ply)
    end

    function MuR:ApplyConcussion(pos, profile, attacker)
        if not isvector(pos) then return end
        if not MuR.ConcussionProfiles[profile] then return end

        for _, ply in player.Iterator() do
            local strength, duration = MuR:GetConcussionStrength(ply, pos, profile)
            if strength > 0 then
                MuR:ApplyConcussionTo(ply, strength, duration)
            end
        end
    end

    hook.Add("Think", "MuR.ConcussionRecovery", function()
        local now = CurTime()

        for _, ply in player.Iterator() do
            if not ply.MuR_ConcussionEnd then continue end
            if now < ply.MuR_ConcussionEnd then continue end

            ply.MuR_ConcussionEnd = nil
            ply.MuR_ConcussionStrength = nil
            ply:SetNW2Float("MuR.ConcussionEnd", 0)
            ply:SetNW2Float("MuR.ConcussionPower", 0)
            ply:SetDSP(0, false)
        end
    end)

    hook.Add("PlayerSpawn", "MuR.ConcussionReset", function(ply)
        ply.MuR_ConcussionEnd = nil
        ply.MuR_ConcussionStrength = nil
        ply:SetNW2Float("MuR.ConcussionEnd", 0)
        ply:SetNW2Float("MuR.ConcussionPower", 0)
    end)

    hook.Add("EntityTakeDamage", "MuR.ConcussionFallback", function(ent, dmg)
        if not IsValid(ent) or not ent:IsPlayer() then return end
        if bit.band(dmg:GetDamageType(), DMG_BLAST) == 0 then return end
        if dmg:GetDamage() < 15 then return end
        if (ent.MuR_ConcussionEnd or 0) > CurTime() then return end
        if (ent.MuR_LastBlastConcussion or 0) > CurTime() then return end

        ent.MuR_LastBlastConcussion = CurTime() + 0.25

        local pos = dmg:GetDamagePosition()
        if not isvector(pos) or pos == vector_origin then pos = ent:WorldSpaceCenter() end

        local strength, duration = MuR:GetConcussionStrength(ent, pos, "vehicle")
        if strength > 0 then
            MuR:ApplyConcussionTo(ent, strength, duration)
        end
    end)
end

if CLIENT then
    local phase = 0
    local nextRing = 0
    local lastPower = 0

    local function Power()
        local ply = LocalPlayer()
        if not IsValid(ply) then return 0 end
        return MuR.GetConcussion(ply)
    end

    net.Receive("MuR.Concussion", function()
        local strength = net.ReadUInt(8) / 255
        local duration = net.ReadUInt(12) / 10

        phase = 0

        if strength > 0.4 then
            util.ScreenShake(EyePos(), strength * 12, strength * 8, math.min(duration * 0.4, 3), 500)
        end
    end)

    hook.Add("Think", "MuR.ConcussionPhase", function()
        lastPower = Power()
        if lastPower <= 0 then return end

        phase = phase + FrameTime() * 2.2

        if CurTime() >= nextRing and lastPower > 0.35 then
            nextRing = CurTime() + math.Rand(1.4, 2.6)
            surface.PlaySound("murdered/player/cncl/contusion_tinnitus_0"..math.random(1,8)..".wav")
        end
    end)

    hook.Add("RenderScreenspaceEffects", "MuR.ConcussionEffects", function()
        local intensity = lastPower
        if intensity < 0.02 then return end

        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        DrawMotionBlur(0.2, math.min(intensity * 0.8, 0.75), 0.01)

        DrawColorModify({
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -intensity * 0.06,
            ["$pp_colour_contrast"] = 1 + intensity * 0.25,
            ["$pp_colour_colour"] = 1 - intensity * 0.55,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })

        if intensity > 0.35 then
            DrawBloom(0.65, intensity * 1.4, intensity * 6, intensity * 6, 2, intensity, 1, 1, 1)
        end
    end)

    hook.Add("CalcView", "MuR.ConcussionSway", function(ply, pos, angles, fov)
        local intensity = lastPower
        if intensity < 0.05 then return end

        local sway = intensity * 2.5

        return {
            origin = pos,
            angles = Angle(
                angles.p + math.sin(phase) * sway,
                angles.y + math.cos(phase * 0.73) * sway * 0.8,
                angles.r + math.sin(phase * 1.31) * sway * 0.6
            ),
            fov = fov + intensity * 4,
            drawviewer = false
        }
    end)

    hook.Add("AdjustMouseSensitivity", "MuR.ConcussionAim", function()
        local intensity = lastPower
        if intensity < 0.1 then return end

        return math.Clamp(1 - intensity * 0.35, 0.5, 1)
    end)

    hook.Add("HUDPaint", "MuR.ConcussionVignette", function()
        local intensity = lastPower
        if intensity < 0.05 then return end
        if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") then return end

        local alpha = intensity * 90 * (0.75 + math.sin(phase * 0.9) * 0.25)

        surface.SetDrawColor(20, 18, 16, alpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end)
end
