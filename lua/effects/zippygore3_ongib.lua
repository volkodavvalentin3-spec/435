local function create_materials(mat_names)
    local mats = {}
    for _, v in ipairs(mat_names) do
        local imat = Material(v)
        table.insert(mats, imat)
    end
    return mats
end

local blood_materials = {}
for i = 1, 21 do
    local imat = Material("rlb/blood" .. i)
    table.insert(blood_materials, imat)
end

local yblood_materials = create_materials({
    "decals/yblood1",
    "decals/yblood2",
    "decals/yblood3",
    "decals/yblood4",
    "decals/yblood5",
    "decals/yblood6",
})

local particleMat1 = Material("particle/particle_smokegrenade")
local particleMat2 = Material("effects/blood")

local blood_colors = {
    [BLOOD_COLOR_RED] = Color(85, 0, 0),
    [BLOOD_COLOR_ANTLION] = Color(100, 50, 0),
    [BLOOD_COLOR_ANTLION_WORKER] = Color(200, 200, 0),
    [BLOOD_COLOR_GREEN] = Color(100, 100, 0),
    [BLOOD_COLOR_ZOMBIE] = Color(100, 100, 0),
    [BLOOD_COLOR_YELLOW] = Color(100, 100, 0),
}

local splatter_distance = 50
local CustomBloodMaterials = {}
local GORE_KIND = "dismember"

local function SpendRender(particleCost, decalCost, preserveCore)
    return MuR
        and MuR.SpendGoreRenderBudget
        and MuR:SpendGoreRenderBudget(GORE_KIND, particleCost, decalCost, preserveCore)
end

local function TryDecal(pos)
    return MuR
        and MuR.TryGoreDecalCell
        and MuR:TryGoreDecalCell(pos, 0.12)
end

function EFFECT:Init(data)
	-- Жидкая кровь из модуля gmcl_bsblood, если он стоит у игрока (client/cl_bsblood.lua).
	if MuR and MuR.BSBlood and MuR.BSBlood:Effect("zippygore3_ongib", data) then return end
    local blood_color = data:GetFlags()
    local blood_color_tbl = blood_colors[blood_color]
    if not blood_color_tbl then return end

    local profile = MuR and MuR.GetGoreQualityProfile and MuR:GetGoreQualityProfile()
    if not profile then return end

    local pos_min, pos_max = data:GetOrigin(), data:GetStart()
    local phys_bone_size = (pos_max - pos_min):Length()
    local base_particle_size = phys_bone_size * 2.5
    local coreAdmissionUsed = false

    local function SpendVisual(particleCost, decalCost)
        local preserveCore = not coreAdmissionUsed
        coreAdmissionUsed = true
        return SpendRender(particleCost, decalCost, preserveCore)
    end

    local emitter = ParticleEmitter(pos_min, false)
    if emitter then
        local particleCount = math.max(1, math.floor(14 * profile.particleScale + 0.5))

        for i = 1, particleCount do
            if not SpendVisual(1, 0) then break end

            local particle_pos = VectorRand(pos_min, pos_max)
            local particle = emitter:Add(table.Random({particleMat1, particleMat2}), particle_pos)
            if particle then
                particle:SetDieTime(math.Rand(0.25, 1.25) * profile.lifetimeScale)
                particle:SetStartSize(0)
                particle:SetEndSize(math.Rand(base_particle_size * 0.5, base_particle_size))
                particle:SetStartAlpha(math.Rand(155, 255))
                particle:SetEndAlpha(0)
                particle:SetColor(blood_color_tbl.r, blood_color_tbl.g, blood_color_tbl.b)
                particle:SetGravity(Vector(0, 0, -math.Rand(25, 50)))
                particle:SetVelocity(VectorRand() * 35)
                particle:SetRollDelta(math.Rand(-math.pi * 0.2, math.pi * 0.2))
            end
        end

        emitter:Finish()
    end

    local ent = data:GetEntity()
    local customDecal = IsValid(ent) and ent:GetNWString("DynamicBloodSplatter_CustomBlood_Decal", false)
    local customBloodMats
    if isstring(customDecal) then
        local decal_mat_name = util.DecalMaterial(customDecal)
        CustomBloodMaterials[customDecal] = CustomBloodMaterials[customDecal] or {}

        if not CustomBloodMaterials[customDecal][decal_mat_name] then
            local imat = Material(decal_mat_name)
            CustomBloodMaterials[customDecal][decal_mat_name] = imat
        end

        customBloodMats = table.Copy(CustomBloodMaterials[customDecal])
    end

    local bc = blood_color
    local splatter_materials = customBloodMats or (bc == BLOOD_COLOR_RED and table.Copy(blood_materials)) or
        ((bc == BLOOD_COLOR_ANTLION or bc == BLOOD_COLOR_ANTLION_WORKER or bc == BLOOD_COLOR_GREEN or bc == BLOOD_COLOR_ZOMBIE or bc == BLOOD_COLOR_YELLOW) and table.Copy(yblood_materials))

    if not splatter_materials then return end

    local splatter_directions = {
        Vector(splatter_distance, 0, 0),
        Vector(0, splatter_distance, 0),
        Vector(0, 0, splatter_distance),
        Vector(-splatter_distance, 0, 0),
        Vector(0, -splatter_distance, 0),
        Vector(0, 0, -splatter_distance),
    }
    local directionCount = math.max(1, math.floor(#splatter_directions * profile.decalScale + 0.5))
    local filter_ents = {}

    for i = 1, directionCount do
        local directionIndex = math.floor((i - 1) * #splatter_directions / directionCount) + 1
        local v = splatter_directions[directionIndex]
        local splatter_start_pos = VectorRand(pos_min, pos_max)

        if ZGM3_INSANE_BLOOD_EFFECTS and bc == BLOOD_COLOR_RED then
            if SpendVisual(1, 0) then
                local maxDamageCvar = GetConVar("realistic_blood_max_damage")
                local effectdata = EffectData()
                effectdata:SetEntity(NULL)
                effectdata:SetStart(splatter_start_pos)
                effectdata:SetNormal((v + VectorRand() * splatter_distance * 0.5):GetNormalized())
                effectdata:SetMagnitude((maxDamageCvar and maxDamageCvar:GetInt() or 100) * 0.75)
                effectdata:SetFlags(math.random(1, 2))
                util.Effect("realisticblood_splatter", effectdata)
            end
        else
            local tr = util.TraceLine({
                start = splatter_start_pos,
                endpos = splatter_start_pos + v,
                filter = filter_ents,
            })
            if IsValid(tr.Entity) then
                filter_ents[tr.Entity:EntIndex()] = tr.Entity
            end

            if tr.Hit and SpendVisual(0, 1) and TryDecal(tr.HitPos) then
                local decal_size = math.Clamp(phys_bone_size * 0.1, 0.5, 8)
                util.DecalEx(
                    table.Random(splatter_materials),
                    IsValid(tr.Entity) and tr.Entity or Entity(0),
                    tr.HitPos,
                    tr.HitNormal,
                    Color(255, 255, 255),
                    decal_size,
                    decal_size
                )
            end
        end
    end
end

function EFFECT:Think() return false end
function EFFECT:Render() end
