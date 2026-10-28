local NETWORK_KIND = {
    pool = "pool",
    splatter = "impact",
    organ = "organ",
    standalone = "arterial",
    dismemberment = "dismember"
}

if SERVER then
    util.AddNetworkString("MuR.RagdollBloodSmear")
    util.AddNetworkString("MuR.BloodPoolEffect")
    util.AddNetworkString("MuR.BloodSplatterEffect")
    util.AddNetworkString("MuR.OrganBleedEffect")
    util.AddNetworkString("MuR.StandaloneBloodSpray")

    local ragdollBloodData = {}

    local function SafeNormal(normal)
        if not isvector(normal) or normal:LengthSqr() < 0.0001 then return vector_up end
        return normal:GetNormalized()
    end

    local function SendBloodSmear(pos, normal, velocity, size, source)
        local kind = "drag"
        if not MuR:TryAdmitGoreEvent(kind, pos, nil, source) then return false end

        local recipients = MuR:CollectGoreRecipients(pos, kind)
        if #recipients == 0 then return false end

        net.Start("MuR.RagdollBloodSmear")
        net.WriteVector(pos)
        net.WriteNormal(SafeNormal(normal))
        net.WriteUInt(math.Clamp(math.floor(velocity:Length()), 0, 4095), 12)
        net.WriteUInt(math.Clamp(math.floor(size * 100), 0, 255), 8)
        net.Send(recipients)
        return true
    end

    local function GetBloodEffectOrigin(ent, boneid)
        if not IsValid(ent) then return vector_origin end

        local origin = ent:WorldSpaceCenter()
        if isnumber(boneid) and boneid >= 0 and ent.GetBonePosition then
            local bonePos = ent:GetBonePosition(boneid)
            local isFinite = isvector(bonePos)
                and bonePos.x == bonePos.x
                and bonePos.y == bonePos.y
                and bonePos.z == bonePos.z
            if isFinite and (bonePos ~= vector_origin or origin:DistToSqr(vector_origin) <= 1) then
                origin = bonePos
            end
        end

        return origin
    end

    function MuR:BroadcastBloodPoolEffect(ent, boneid, flags, needvel, kind)
        if not IsValid(ent) then return false end

        boneid = math.max(math.floor(tonumber(boneid) or 0), 0)
        flags = math.Clamp(math.floor(tonumber(flags) or 0), 0, 255)
        needvel = tonumber(needvel) or 0
        kind = kind or NETWORK_KIND.pool

        local origin = GetBloodEffectOrigin(ent, boneid)
        if not self:TryAdmitGoreEvent(kind, origin, nil, ent) then return false end

        local recipients = self:CollectGoreRecipients(origin, kind)
        if #recipients == 0 then return false end

        net.Start("MuR.BloodPoolEffect")
        net.WriteEntity(ent)
        net.WriteUInt(boneid, 16)
        net.WriteUInt(flags, 8)
        net.WriteUInt(math.Clamp(math.floor(needvel), 0, 4095), 12)
        net.WriteVector(origin)
        net.Send(recipients)
        return true
    end

    function MuR:BroadcastBloodSplatterEffect(ent, pos, normal, magnitude, radius, flags, kind)
        if not isvector(pos) then return false end

        kind = kind or NETWORK_KIND.splatter
        local source = IsValid(ent) and ent or nil
        if not self:TryAdmitGoreEvent(kind, pos, nil, source) then return false end

        local recipients = self:CollectGoreRecipients(pos, kind)
        if #recipients == 0 then return false end

        net.Start("MuR.BloodSplatterEffect")
        net.WriteEntity(IsValid(ent) and ent or NULL)
        net.WriteVector(pos)
        net.WriteNormal(SafeNormal(normal))
        net.WriteUInt(math.Clamp(math.floor((tonumber(magnitude) or 1) * 20), 0, 4095), 12)
        net.WriteUInt(math.Clamp(math.floor(tonumber(radius) or 0), 0, 4095), 12)
        net.WriteUInt(math.Clamp(math.floor(tonumber(flags) or 0), 0, 255), 8)
        net.Send(recipients)
        return true
    end

    function MuR:BroadcastOrganBleedEffect(ent, pos, magnitude, kind)
        if not isvector(pos) then return false end

        kind = kind or NETWORK_KIND.organ
        local source = IsValid(ent) and ent or nil
        if not self:TryAdmitGoreEvent(kind, pos, nil, source) then return false end

        local recipients = self:CollectGoreRecipients(pos, kind)
        if #recipients == 0 then return false end

        net.Start("MuR.OrganBleedEffect")
        net.WriteEntity(IsValid(ent) and ent or NULL)
        net.WriteVector(pos)
        net.WriteUInt(math.Clamp(math.floor((tonumber(magnitude) or 1) * 20), 0, 4095), 12)
        net.Send(recipients)
        return true
    end

    function MuR:BroadcastStandaloneBloodSpray(pos, normal, magnitude, radius, kind, source)
        if not isvector(pos) then return false end

        kind = kind or NETWORK_KIND.standalone
        if not self:TryAdmitGoreEvent(kind, pos, nil, source) then return false end

        local recipients = self:CollectGoreRecipients(pos, kind)
        if #recipients == 0 then return false end

        net.Start("MuR.StandaloneBloodSpray")
        net.WriteVector(pos)
        net.WriteNormal(SafeNormal(normal))
        net.WriteUInt(math.Clamp(math.floor((tonumber(magnitude) or 1) * 20), 0, 4095), 12)
        net.WriteUInt(math.Clamp(math.floor(tonumber(radius) or 16), 0, 4095), 12)
        net.Send(recipients)
        return true
    end

    function MuR:RemoveSmearingBlood(ent)
        if !IsValid(ent) or !istable(ragdollBloodData[ent]) then return end
        ragdollBloodData[ent] = nil
    end

    function MuR:AddSmearingBlood(ent)
        if !IsValid(ent) or istable(ragdollBloodData[ent]) then return end
        ragdollBloodData[ent] = {
            lastPos = ent:WorldSpaceCenter(),
            lastVel = Vector(0, 0, 0),
            nextBloodTime = 0
        }
    end

    hook.Add("EntityRemoved", "MuR.CleanupRagdollBloodS", function(ent)
        if ragdollBloodData[ent] then
            ragdollBloodData[ent] = nil
        end
    end)

    hook.Add("Think", "MuR.RagdollBloodSmearing", function()
        local curTime = CurTime()

        for ragdoll, data in pairs(ragdollBloodData) do
            if not IsValid(ragdoll) then
                ragdollBloodData[ragdoll] = nil
                continue
            end

            do
                local physObj = ragdoll:GetPhysicsObjectNum(1)
                if IsValid(physObj) then
                    local pos = physObj:GetPos()
                    local vel = physObj:GetVelocity()
                    local speed = vel:Length()

                    if speed > 20 and curTime > data.nextBloodTime then
                        local trace = util.TraceLine({
                            start = pos,
                            endpos = pos + vel:GetNormalized() * 4 - Vector(0,0,16),
                            mask = MASK_SOLID,
                            filter = function(ent)
                                if ent == ragdoll then return false end
                                if ent:IsPlayer() or MuR.IsAI(ent) then return false end
                                return true
                            end
                        })

                        if trace.Hit then
                            SendBloodSmear(trace.HitPos, vel:GetNormalized(), vel, 0.4, ragdoll)
                            data.nextBloodTime = curTime + 0.05
                            break
                        end
                    end
                end
            end

            data.lastPos = ragdoll:GetPos()
            data.lastVel = ragdoll:GetVelocity()
        end
    end)
end

if CLIENT then
    local bloodMaterials = {}
    for i = 1,21 do
        local imat = "rlb/blood"..i
        table.insert(bloodMaterials, imat)
    end

    local function StampBloodDecal(pos, normal, scale, ent, kind, cooldown)
        if not isvector(pos) then return false end

        normal = isvector(normal) and normal:GetNormalized() or Vector(0, 0, -1)
        if normal:LengthSqr() <= 0.001 then
            normal = Vector(0, 0, -1)
        end

        local traceFilter = function(traceEnt)
            if traceEnt == ent then return false end
            return true
        end

        local traceDistance = math.max(scale * 28, 24)
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + normal * traceDistance,
            mask = MASK_SOLID,
            filter = traceFilter
        })

        if not tr.Hit then
            tr = util.TraceLine({
                start = pos + Vector(0, 0, 8),
                endpos = pos - Vector(0, 0, 56),
                mask = MASK_SOLID,
                filter = traceFilter
            })
        end

        if not tr.Hit then return false end

        kind = kind or NETWORK_KIND.splatter
        if not MuR:SpendGoreRenderBudget(kind, 0, 1, false) then return false end
        if not MuR:TryGoreDecalCell(tr.HitPos, cooldown or 0.12) then return false end

        util.DecalEx(
            Material(bloodMaterials[math.random(#bloodMaterials)]),
            IsValid(tr.Entity) and tr.Entity or game.GetWorld(),
            tr.HitPos,
            tr.HitNormal,
            Color(255, 255, 255, 255),
            scale,
            scale
        )
        return true
    end

    local function StampBloodBurst(pos, normal, radius, ent, kind)
        local profile = MuR:GetGoreQualityProfile()
        local requested = math.Clamp(math.floor((radius or 18) / 8), 2, 5)
        local decalCount = math.max(1, math.floor(requested * profile.decalScale + 0.5))
        local burstScale = math.Clamp((radius or 18) / 20, 0.55, 1.6)

        for i = 1, decalCount do
            local offset = VectorRand() * math.Rand(0, math.max(radius or 18, 8) * 0.35)
            StampBloodDecal(
                pos + offset,
                normal,
                burstScale * math.Rand(0.8, 1.2),
                ent,
                kind
            )
        end
    end

    local function CreateBloodSmear(pos, normal, velocity, size)
        if not isvector(pos) or not isvector(velocity) then return end

        local speed = velocity:Length()
        local smearDir = velocity:GetNormalized()
        local profile = MuR:GetGoreQualityProfile()

        if speed > 50 then
            local requested = math.Clamp(math.floor(speed / 100), 2, 5)
            local smearCount = math.max(1, math.floor(requested * profile.decalScale + 0.5))
            local smearLength = size * speed / 50

            for i = 0, smearCount do
                local offset = (i / smearCount) * smearLength
                local smearPos = pos + smearDir * offset
                local currentSize = size * (1 - i / smearCount * 0.3)

                if not MuR:SpendGoreRenderBudget("drag", 0, 1, false) then break end
                if MuR:TryGoreDecalCell(smearPos, 0.1) then
                    util.DecalEx(
                        Material(bloodMaterials[math.random(#bloodMaterials)]),
                        game.GetWorld(),
                        smearPos,
                        normal,
                        Color(255, 255, 255, 255),
                        currentSize * 3,
                        currentSize
                    )
                end
            end
        elseif MuR:SpendGoreRenderBudget("drag", 0, 1, false)
            and MuR:TryGoreDecalCell(pos, 0.1) then

            util.DecalEx(
                Material(bloodMaterials[math.random(#bloodMaterials)]),
                game.GetWorld(),
                pos,
                normal,
                Color(255, 255, 255, 255),
                size,
                size
            )
        end
    end

    local function CreateStandaloneBloodSpray(pos, normal, magnitude, radius, ent, kind)
        if not isvector(pos) then return end

        normal = isvector(normal) and normal:GetNormalized() or vector_up
        if normal:LengthSqr() <= 0.001 then
            normal = vector_up
        end

        kind = kind or NETWORK_KIND.standalone
        magnitude = math.Clamp(tonumber(magnitude) or 1, 0.5, 3)
        radius = math.Clamp(tonumber(radius) or 16, 8, 36)

        local profile = MuR:GetGoreQualityProfile()
        if MuR:SpendGoreRenderBudget(kind, 1, 0, false) then
            ParticleEffect("blood_impact_red_01", pos, normal:Angle())
        end

        local emitter = ParticleEmitter(pos, false)
        if emitter then
            local requested = math.Clamp(math.floor(8 * magnitude), 8, 22)
            local count = math.max(1, math.floor(requested * profile.particleScale + 0.5))

            for i = 1, count do
                if not MuR:SpendGoreRenderBudget(kind, 1, 0, false) then break end

                local sprayNormal = (normal + VectorRand() * 0.45):GetNormalized()
                local particle = emitter:Add(bloodMaterials[math.random(#bloodMaterials)], pos + VectorRand() * 1.5)
                if particle then
                    particle:SetVelocity(sprayNormal * math.Rand(135, 290) * magnitude + Vector(0, 0, math.Rand(15, 70)))
                    particle:SetDieTime(math.Rand(0.55, 1.05) * profile.lifetimeScale)
                    particle:SetStartAlpha(220)
                    particle:SetEndAlpha(0)
                    particle:SetStartSize(math.Rand(1.4, 2.8) * magnitude)
                    particle:SetEndSize(0)
                    particle:SetStartLength(math.Rand(5, 10) * magnitude)
                    particle:SetEndLength(math.Rand(10, 18) * magnitude)
                    particle:SetGravity(Vector(0, 0, -420))
                    particle:SetAirResistance(60)
                    particle:SetColor(160, 10, 10)
                    particle:SetCollide(true)
                    particle:SetBounce(0.12)
                    particle:SetCollideCallback(function(_, hitPos, hitNormal, hitEnt)
                        StampBloodDecal(hitPos, hitNormal, math.Rand(0.3, 0.7), hitEnt, kind)
                    end)
                end
            end
            emitter:Finish()
        end

        StampBloodBurst(pos, normal, radius * 1.15, ent, kind)
    end

    net.Receive("MuR.RagdollBloodSmear", function()
        local pos = net.ReadVector()
        local normal = net.ReadNormal()
        local speed = net.ReadUInt(12)
        local size = net.ReadUInt(8) / 100

        CreateBloodSmear(pos, normal, normal * speed, size)
    end)

    net.Receive("MuR.BloodPoolEffect", function()
        local ent = net.ReadEntity()
        local boneid = net.ReadUInt(16)
        local flags = net.ReadUInt(8)
        local needvel = net.ReadUInt(12)
        local origin = net.ReadVector()

        if MuR.BSBlood and MuR.BSBlood:Handle("pool", ent, origin, flags) then return end

        if not MuR:SpendGoreRenderBudget(NETWORK_KIND.pool, 1, 0, false) then return end

        local effectdata = EffectData()
        effectdata:SetEntity(IsValid(ent) and ent or NULL)
        effectdata:SetAttachment(boneid)
        effectdata:SetFlags(flags)
        effectdata:SetRadius(needvel)
        effectdata:SetOrigin(origin)
        util.Effect("bloodshed_blood_pool", effectdata, true, true)
    end)

    net.Receive("MuR.BloodSplatterEffect", function()
        local ent = net.ReadEntity()
        local pos = net.ReadVector()
        local normal = net.ReadNormal()
        local magnitude = net.ReadUInt(12) / 20
        local radius = net.ReadUInt(12)
        local flags = net.ReadUInt(8)

        if MuR.BSBlood and MuR.BSBlood:Handle("splatter", ent, pos, normal, magnitude) then return end

        local effectdata = EffectData()
        effectdata:SetEntity(IsValid(ent) and ent or NULL)
        effectdata:SetOrigin(pos)
        effectdata:SetNormal(normal)
        effectdata:SetMagnitude(magnitude)
        effectdata:SetRadius(radius)
        effectdata:SetFlags(flags)
        if IsValid(ent) and ent:IsPlayer() and not IsValid(ent:GetRD()) then
            if MuR:SpendGoreRenderBudget(NETWORK_KIND.splatter, 1, 0, false) then
                local legacyEffectData = EffectData()
                legacyEffectData:SetEntity(NULL)
                legacyEffectData:SetOrigin(pos)
                legacyEffectData:SetNormal(normal)
                legacyEffectData:SetMagnitude(math.max(magnitude, 1))
                legacyEffectData:SetRadius(radius)
                legacyEffectData:SetFlags(flags)
                util.Effect("mur_blood_splatter_effect", legacyEffectData, true, true)
            end

            CreateStandaloneBloodSpray(
                pos,
                normal,
                math.max(magnitude, 1),
                radius > 0 and radius or 16,
                ent,
                NETWORK_KIND.splatter
            )
        else
            if MuR:SpendGoreRenderBudget(NETWORK_KIND.splatter, 1, 0, false) then
                util.Effect("mur_blood_splatter_effect", effectdata, true, true)
            end

            StampBloodBurst(
                pos,
                normal,
                radius > 0 and radius or 16,
                ent,
                NETWORK_KIND.splatter
            )
        end
    end)

    net.Receive("MuR.OrganBleedEffect", function()
        local ent = net.ReadEntity()
        local pos = net.ReadVector()
        local magnitude = net.ReadUInt(12) / 20

        if MuR.BSBlood and MuR.BSBlood:Handle("organ", ent, pos, magnitude) then return end

        if MuR:SpendGoreRenderBudget(NETWORK_KIND.organ, 1, 0, false) then
            local effectdata = EffectData()
            effectdata:SetEntity(IsValid(ent) and ent or NULL)
            effectdata:SetOrigin(pos)
            effectdata:SetMagnitude(magnitude)
            util.Effect("mur_organ_bleed", effectdata, true, true)
        end

        StampBloodDecal(
            pos,
            Vector(0, 0, -1),
            math.Clamp(0.7 + magnitude * 0.35, 0.7, 1.6),
            ent,
            NETWORK_KIND.organ
        )
    end)

    net.Receive("MuR.StandaloneBloodSpray", function()
        local pos = net.ReadVector()
        local normal = net.ReadNormal()
        local magnitude = net.ReadUInt(12) / 20
        local radius = net.ReadUInt(12)

        if MuR.BSBlood and MuR.BSBlood:Handle("spray", nil, pos, normal, magnitude) then return end
        CreateStandaloneBloodSpray(pos, normal, magnitude, radius, nil, NETWORK_KIND.standalone)
    end)
end
