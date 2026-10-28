if not SERVER then return end

-- Stump/cap placement ported from `.needport/lua/zippygoremod3/dismemberment.lua`.
-- The transforms below are the original mod's per-bone numbers: models, scales,
-- angles and positions are applied relative to the followed bone, so a cap sits
-- where the severed bone used to be without any world-space guessing.
--
-- Missing imported assets never abort dismemberment: every profile names the
-- previous model and transform as a fallback, and a cap that cannot be resolved
-- is simply not created.

ZGM3_CAPS = ZGM3_CAPS or {}

local function copyVector(value, fallback)
    value = isvector(value) and value or fallback
    return Vector(value.x, value.y, value.z)
end

local function copyAngle(value, fallback)
    value = isangle(value) and value or fallback
    return Angle(value.p, value.y, value.r)
end

local function isFinite(value)
    return isnumber(value)
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function isFiniteVector(value)
    return isvector(value)
        and isFinite(value.x) and isFinite(value.y) and isFinite(value.z)
end

local function isFiniteAngle(value)
    return isangle(value)
        and isFinite(value.p) and isFinite(value.y) and isFinite(value.r)
end

local function numberToScale(value)
    if isvector(value) then return copyVector(value, Vector(1, 1, 1)) end
    if isnumber(value) and isFinite(value) then return Vector(value, value, value) end
    return Vector(1, 1, 1)
end

-- Body-side profiles: the cap covers the half of the cut that stays behind.
-- `partialModels`/`fullModel` are the head's variation; `models` is the hand's
-- four-model variant list; everything else is a single model.
local BODY_PROFILES = {
    ["ValveBiped.Bip01_Head1"] = {
        partialModels = {
            "models/headpartial/headpartial1.mdl",
            "models/headpartial/headpartial2.mdl",
            "models/headpartial/headpartial3.mdl",
            "models/headpartial/headpartial4.mdl",
        },
        fullModel = "models/headpartial/headpartial5.mdl",
        angle = Angle(0, -70, -90),
        partialPos = Vector(1, -2, 0),
        fullPos = Vector(2, -2, 0),
        scale = Vector(1, 1, 1),
        major = true,
        bleedKind = "arterial",
    },
    ["ValveBiped.Bip01_R_Thigh"] = {
        model = "models/limbspartial/thighright.mdl",
        angle = Angle(-90, -90, 0),
        pos = Vector(-3, -7, -2),
        scale = Vector(1, 1, 1),
        familyThigh = true,
        major = true,
        bleedKind = "arterial",
    },
    ["ValveBiped.Bip01_L_Thigh"] = {
        model = "models/limbspartial/thighleft.mdl",
        angle = Angle(-90, -90, 0),
        pos = Vector(3, -7, -2),
        scale = Vector(1, 1, 1),
        familyThigh = true,
        major = true,
        bleedKind = "arterial",
    },
    ["ValveBiped.Bip01_Spine2"] = {
        model = "models/torsopartial/abdomenvar.mdl",
        angle = Angle(0, 90, 90),
        pos = Vector(-3, 2, 0),
        scale = Vector(1.1, 1.1, 1.1),
        major = true,
        bleedKind = "arterial",
    },
    ["ValveBiped.Bip01_L_Hand"] = {
        models = {
            "models/limbspartial/handl.mdl",
            "models/limbspartial/handl1.mdl",
            "models/limbspartial/handl2.mdl",
            "models/limbspartial/handl3.mdl",
        },
        baseAngle = Angle(45, 90, 90),
        basePos = Vector(7, 0, 0),
        variantAngle = Angle(-45, 90, 90),
        variantPos = Vector(6, 0, 0),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_R_Hand"] = {
        models = {
            "models/limbspartial/handr.mdl",
            "models/limbspartial/handr1.mdl",
            "models/limbspartial/handr2.mdl",
            "models/limbspartial/handr3.mdl",
        },
        baseAngle = Angle(-45, 90, 90),
        basePos = Vector(7, 0, 0),
        variantAngle = Angle(45, 90, 90),
        variantPos = Vector(6, 0, 0),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_R_Forearm"] = {
        model = "models/limbspartial/elbowright.mdl",
        angle = Angle(-90, 0, 0),
        pos = Vector(11, 0, 1),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_L_Forearm"] = {
        model = "models/limbspartial/elbowleft.mdl",
        angle = Angle(-90, 0, 0),
        pos = Vector(11, 0, -1),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_L_Calf"] = {
        model = "models/limbspartial/kneeleft.mdl",
        angle = Angle(90, 90, -90),
        pos = Vector(14, 0, 0),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_R_Calf"] = {
        model = "models/limbspartial/kneeright.mdl",
        angle = Angle(-90, -90, 90),
        pos = Vector(14, 0, 0),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_R_UpperArm"] = {
        model = "models/limbspartial/shoulderpartial2.mdl",
        angle = Angle(90, 110, 0),
        pos = Vector(5.5, -6.5, 0),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_L_UpperArm"] = {
        model = "models/limbspartial/shoulderpartial1.mdl",
        angle = Angle(-90, -75, 0),
        pos = Vector(5.5, -7, 0),
        scale = Vector(1, 1, 1),
    },
    ["ValveBiped.Bip01_L_Foot"] = {
        model = "models/gore/lleg_legpartfootl002.mdl",
        angle = Angle(-90, 0, 0),
        pos = Vector(-8, 2, 2),
        scale = Vector(1.2, 1.2, 1.2),
    },
    ["ValveBiped.Bip01_R_Foot"] = {
        model = "models/gore/rleg_legpartfootr002.mdl",
        angle = Angle(-90, 0, 0),
        pos = Vector(-8, -2, 3),
        scale = Vector(1.2, 1.2, 1.2),
    },
}

-- The severed part is capped only where the original mod had a model for it and
-- the asset came over with this port. Everything else keeps the previous
-- limb-side creation path in dismemberment.lua.
local LIMB_PROFILES = {
    ["ValveBiped.Bip01_Spine2"] = {
        model = "models/torsopartial/torsovar.mdl",
        angle = Angle(0, 90, 90),
        pos = Vector(-2, 2, 0),
        scale = Vector(1.1, 1.1, 1.1),
        major = true,
        bleedKind = "arterial",
    },
    ["ValveBiped.Bip01_R_UpperArm"] = {
        model = "models/limbspartial/unistump.mdl",
        angle = Angle(90, 0, 0),
        pos = Vector(-0.1, 0, 0.5),
        scale = Vector(3, 3, 3),
        major = true,
        bleedKind = "arterial",
    },
    ["ValveBiped.Bip01_L_UpperArm"] = {
        model = "models/limbspartial/unistump.mdl",
        angle = Angle(90, 0, 0),
        pos = Vector(-0.1, 0, -0.5),
        scale = Vector(3, 3, 3),
        major = true,
        bleedKind = "arterial",
    },
}

local HEAD_FAMILY = {
    female = {
        fullAngle = Angle(0, -60, -90),
        fullPos = Vector(1, -2, 0),
        partialPos = Vector(0, -2, 0),
    },
    alyx_mossman = {
        fullAngle = Angle(0, -60, -90),
        fullPos = Vector(1, -1, 0),
        partialPos = Vector(0, -1, 0),
    },
    default = {
        fullPos = Vector(2.2, -2, 0),
        partialPos = Vector(1, -2, 0),
    },
}

local THIGH_FAMILY = {
    female = {
        scale = Vector(0.8, 0.8, 0.8),
        rPos = Vector(-2.4, -5, 0.5),
        lPos = Vector(2.4, -5, 0.5),
    },
    alyx_mossman = {
        scale = Vector(0.8, 0.8, 0.8),
        rPos = Vector(-2.4, -5, 0.5),
        lPos = Vector(2.4, -5, 0.5),
    },
}

function ZGM3_CAPS.ResolveModelFamily(host)
    if not IsValid(host) then return "default" end

    local model = string.lower(host:GetModel() or "")
    if string.find(model, "alyx", 1, true) or string.find(model, "mossman", 1, true) then
        return "alyx_mossman"
    end
    if string.find(model, "female", 1, true) then
        return "female"
    end
    return "default"
end

local function legacyBody(host, boneName)
    if not host.ZippyGoreMod3_GetStumpModel or not host.LookupBone then return nil end

    local boneId = host:LookupBone(boneName)
    if not boneId then return nil end

    local mdl, ang, pos, scale = host:ZippyGoreMod3_GetStumpModel(boneId)
    if not isstring(mdl) then return nil end

    return {
        model = mdl,
        angOffset = copyAngle(ang, Angle(0, 0, 0)),
        posOffset = copyVector(pos, Vector(0, 0, 0)),
        scale = numberToScale(scale),
    }
end

local function legacyLimb(host, boneName)
    if not host.ZippyGoreMod3_GetLimbStump or not host.LookupBone then return nil end

    local boneId = host:LookupBone(boneName)
    if not boneId then return nil end

    local stump = host:ZippyGoreMod3_GetLimbStump(boneId)
    if not istable(stump) or not isstring(stump.mdl) then return nil end

    return {
        model = stump.mdl,
        angOffset = copyAngle(stump.ang_offset, Angle(0, 0, 0)),
        posOffset = copyVector(stump.pos_offset, Vector(0, 0, 0)),
        scale = numberToScale(stump.scale),
    }
end

local function resolveBody(host, boneName, damageData)
    local def = BODY_PROFILES[boneName]
    if not def then return nil end

    local model, angle, pos
    local isFull = istable(damageData) and damageData.dismember == true

    if def.partialModels then
        if isFull then
            model = def.fullModel
            angle = def.angle
            pos = def.fullPos
        else
            model = def.partialModels[math.random(1, #def.partialModels)]
            angle = def.angle
            pos = def.partialPos
        end

        local override = HEAD_FAMILY[ZGM3_CAPS.ResolveModelFamily(host)]
        if override then
            if isFull then
                angle = override.fullAngle or angle
                pos = override.fullPos or pos
            else
                pos = override.partialPos or pos
            end
        end
    elseif def.models then
        local variant = math.random(0, #def.models - 1)
        model = def.models[variant + 1]
        if variant == 0 then
            angle = def.baseAngle
            pos = def.basePos
        else
            angle = def.variantAngle
            pos = def.variantPos
        end
    else
        model = def.model
        angle = def.angle
        pos = def.pos
    end

    local scale = def.scale
    if def.familyThigh then
        local override = THIGH_FAMILY[ZGM3_CAPS.ResolveModelFamily(host)]
        if override then
            scale = override.scale
            pos = boneName == "ValveBiped.Bip01_R_Thigh" and override.rPos or override.lPos
        end
    end

    local legacy = legacyBody(host, boneName)

    return {
        model = model,
        fallbackModel = legacy and legacy.model or nil,
        scale = copyVector(scale, Vector(1, 1, 1)),
        angOffset = copyAngle(angle, Angle(0, 0, 0)),
        posOffset = copyVector(pos, Vector(0, 0, 0)),
        fallbackScale = legacy and copyVector(legacy.scale, Vector(1, 1, 1)) or copyVector(scale, Vector(1, 1, 1)),
        fallbackAngOffset = legacy and copyAngle(legacy.angOffset, angle) or copyAngle(angle, Angle(0, 0, 0)),
        fallbackPosOffset = legacy and copyVector(legacy.posOffset, pos) or copyVector(pos, Vector(0, 0, 0)),
        major = def.major == true,
        bleedKind = def.bleedKind or "drip",
    }
end

local function resolveLimb(host, boneName)
    local def = LIMB_PROFILES[boneName]
    if not def then return nil end

    local legacy = legacyLimb(host, boneName)

    return {
        model = def.model,
        fallbackModel = legacy and legacy.model or nil,
        scale = copyVector(def.scale, Vector(1, 1, 1)),
        angOffset = copyAngle(def.angle, Angle(0, 0, 0)),
        posOffset = copyVector(def.pos, Vector(0, 0, 0)),
        fallbackScale = legacy and copyVector(legacy.scale, Vector(1, 1, 1)) or copyVector(def.scale, Vector(1, 1, 1)),
        fallbackAngOffset = legacy and copyAngle(legacy.angOffset, def.angle) or copyAngle(def.angle, Angle(0, 0, 0)),
        fallbackPosOffset = legacy and copyVector(legacy.posOffset, def.pos) or copyVector(def.pos, Vector(0, 0, 0)),
        major = def.major == true,
        bleedKind = def.bleedKind or "drip",
    }
end

function ZGM3_CAPS.HasLimbProfile(boneName)
    return isstring(boneName) and LIMB_PROFILES[boneName] ~= nil or false
end

function ZGM3_CAPS.ResolveProfile(host, boneName, face, damageData)
    if not isstring(boneName) then return nil end
    if face == "body" then return resolveBody(host, boneName, damageData) end
    if face == "limb" then return resolveLimb(host, boneName) end
    return nil
end

function ZGM3_CAPS.IsProfileUsable(profile)
    if not istable(profile) then return false end
    if isstring(profile.model) and util.IsValidModel(profile.model) then return true end
    if isstring(profile.fallbackModel) and util.IsValidModel(profile.fallbackModel) then return true end
    return false
end

local function storesSlot(host, boneName, face, cap)
    local slots = IsValid(host) and host.ZGM3_StumpCaps and host.ZGM3_StumpCaps[boneName]
    return slots and slots[face] == cap or false
end

function ZGM3_CAPS.ForgetSlot(host, boneName, face, removed)
    local slots = IsValid(host) and host.ZGM3_StumpCaps and host.ZGM3_StumpCaps[boneName]
    if not slots then return end
    if removed and slots[face] ~= removed then return end

    slots[face] = nil
    if not next(slots) then
        host.ZGM3_StumpCaps[boneName] = nil
    end
    if not next(host.ZGM3_StumpCaps) then
        host.ZGM3_StumpCaps = nil
    end
end

function ZGM3_CAPS.Remove(host, boneName, face)
    if not IsValid(host) or host:IsMarkedForDeletion() then return end

    local slots = host.ZGM3_StumpCaps and host.ZGM3_StumpCaps[boneName]
    if not slots then return end

    local cap = slots[face]
    slots[face] = nil
    if not next(slots) then
        host.ZGM3_StumpCaps[boneName] = nil
    end
    if not next(host.ZGM3_StumpCaps) then
        host.ZGM3_StumpCaps = nil
    end

    if IsValid(cap) and not cap:IsMarkedForDeletion() then
        cap:Remove()
    end
end

function ZGM3_CAPS.RemoveAll(host)
    if not IsValid(host) or host:IsMarkedForDeletion() then return end

    local ownership = host.ZGM3_StumpCaps
    if not ownership then return end

    for boneName, slots in pairs(ownership) do
        for face, cap in pairs(slots) do
            slots[face] = nil
            if IsValid(cap) and not cap:IsMarkedForDeletion() then
                cap:Remove()
            end
        end
        ownership[boneName] = nil
    end

    host.ZGM3_StumpCaps = nil
end

function ZGM3_CAPS.RemoveByFollowBone(host, boneId)
    if not IsValid(host) or host:IsMarkedForDeletion() then return end
    if not isnumber(boneId) then return end

    local ownership = host.ZGM3_StumpCaps
    if not ownership then return end

    for boneName, slots in pairs(ownership) do
        for face, cap in pairs(slots) do
            if IsValid(cap) and cap.ZGM3_FollowBone == boneId then
                slots[face] = nil
                cap:Remove()
            end
        end
        if not next(slots) then
            ownership[boneName] = nil
        end
    end

    if not next(ownership) then
        host.ZGM3_StumpCaps = nil
    end
end

local function applyTransform(cap, scale, angOffset, posOffset)
    cap:SetLocalPos(posOffset)
    cap:SetLocalAngles(angOffset)

    local uniform = scale.x == scale.y and scale.y == scale.z
    if uniform then
        if scale.x ~= 1 then
            cap:SetModelScale(scale.x, 0)
        end
    elseif cap:GetBoneCount() > 0 then
        cap:ManipulateBoneScale(0, scale)
    else
        cap:SetModelScale(scale.x, 0)
    end
end

function ZGM3_CAPS.Attach(host, boneId, boneName, face, damageData)
    if not IsValid(host) or host:IsMarkedForDeletion() then return nil end
    if not isnumber(boneId) or boneId < 0 then return nil end
    if face ~= "body" and face ~= "limb" then return nil end

    local profile = ZGM3_CAPS.ResolveProfile(host, boneName, face, damageData)
    if not profile then return nil end

    local model, scale, angOffset, posOffset
    if isstring(profile.model) and util.IsValidModel(profile.model) then
        model = profile.model
        scale, angOffset, posOffset = profile.scale, profile.angOffset, profile.posOffset
    elseif isstring(profile.fallbackModel) and util.IsValidModel(profile.fallbackModel) then
        model = profile.fallbackModel
        scale, angOffset, posOffset = profile.fallbackScale, profile.fallbackAngOffset, profile.fallbackPosOffset
    end
    if not model then return nil end

    if not (isFiniteVector(scale) and isFiniteVector(posOffset) and isFiniteAngle(angOffset)) then return nil end
    if scale.x <= 0 or scale.y <= 0 or scale.z <= 0 then return nil end

    ZGM3_CAPS.Remove(host, boneName, face)

    local cap = ents.Create("base_gmodentity")
    if not IsValid(cap) or cap:IsMarkedForDeletion() then return nil end

    cap:SetModel(model)
    cap:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    cap:SetNotSolid(true)
    cap:DrawShadow(false)
    cap:SetParent(host)
    cap:FollowBone(host, boneId)
    cap:Spawn()

    if not IsValid(cap) or cap:IsMarkedForDeletion() then return nil end

    applyTransform(cap, scale, angOffset, posOffset)

    cap.ZGM3_FollowBone = boneId
    cap.ZGM3_SeveredBone = boneName
    cap.ZGM3_Face = face

    host.ZGM3_StumpCaps = host.ZGM3_StumpCaps or {}
    host.ZGM3_StumpCaps[boneName] = host.ZGM3_StumpCaps[boneName] or {}
    host.ZGM3_StumpCaps[boneName][face] = cap

    host:DeleteOnRemove(cap)
    cap:CallOnRemove("ZGM3_ClearStumpCapSlot", function(removed)
        ZGM3_CAPS.ForgetSlot(host, boneName, face, removed)
    end)

    -- FollowBone can settle on the first frame; one bounded next-tick pass
    -- re-applies the resolved transform if this slot still owns the cap.
    local finalScale = Vector(scale.x, scale.y, scale.z)
    local finalAng = Angle(angOffset.p, angOffset.y, angOffset.r)
    local finalPos = Vector(posOffset.x, posOffset.y, posOffset.z)
    timer.Simple(0, function()
        if not IsValid(host) or host:IsMarkedForDeletion() then return end
        if not IsValid(cap) or cap:IsMarkedForDeletion() then return end
        if not storesSlot(host, boneName, face, cap) then return end

        cap:SetLocalPos(finalPos)
        cap:SetLocalAngles(finalAng)
        if finalScale.x == finalScale.y and finalScale.y == finalScale.z
            and finalScale.x ~= 1 then
            cap:SetModelScale(finalScale.x, 0)
        end
    end)

    return cap
end
