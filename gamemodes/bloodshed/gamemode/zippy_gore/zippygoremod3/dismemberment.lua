if !SERVER then return end

util.AddNetworkString("ZGM3_SyncBoneScale")

local nanVec = Vector(0, 0, 0)

local function ZGM3_MarkBoneHidden(ent, bone)
	local hidden = ent.ZGM3_HiddenBones
	if not hidden then
		hidden = {}
		ent.ZGM3_HiddenBones = hidden
	end
	if hidden[bone] then return end

	hidden[bone] = true

	local list = {}
	for idx in pairs(hidden) do list[#list + 1] = idx end
	table.sort(list)

	local str = table.concat(list, ",")
	if #str > 500 then return end
	ent:SetNW2String("ZGM3_HiddenBones", str)
end

local function ZGM3_SetBoneScaleSync(ent, bone, scale)
	if not IsValid(ent) then return end
	ent:ManipulateBoneScale(bone, scale)
	ZGM3_MarkBoneHidden(ent, bone)

	net.Start("ZGM3_SyncBoneScale")
	net.WriteEntity(ent)
	net.WriteUInt(bone, 16)
	net.WriteVector(scale)
	net.SendPVS(ent:GetPos())
end

local ENT = FindMetaTable("Entity")
local blood_particles = {
    [BLOOD_COLOR_RED] = ZGM3_INSANE_BLOOD_EFFECTS && "blood_stream_goop_large" or "blood_impact_red_01_goop",
    [BLOOD_COLOR_ANTLION] = "blood_impact_yellow_01",
    [BLOOD_COLOR_ANTLION_WORKER] = "blood_impact_yellow_01",
    [BLOOD_COLOR_GREEN] = "blood_impact_yellow_01",
    [BLOOD_COLOR_ZOMBIE] = "blood_impact_yellow_01",
    [BLOOD_COLOR_YELLOW] = "blood_impact_yellow_01",
    [BLOOD_COLOR_ZGM3SYNTH] = "blood_impact_synth_01",
}
local blood_decals = {
    [BLOOD_COLOR_RED] = "Blood",
    [BLOOD_COLOR_ANTLION] = "YellowBlood",
    [BLOOD_COLOR_ANTLION_WORKER] = "YellowBlood",
    [BLOOD_COLOR_GREEN] = "YellowBlood",
    [BLOOD_COLOR_ZOMBIE] = "YellowBlood",
    [BLOOD_COLOR_YELLOW] = "YellowBlood",
}
local bleed_timer_name = "ZippyGore3_LimbBleedEffectTimer"

local ZGM3_GUTS_MODEL = "models/gore/fatalityguts.mdl"
local ZGM3_GUTS_WELD_FORCE = 5000
local ZGM3_GUTS_WELD_BONE_PARENT = "ValveBiped.Bip01_Pelvis"
local ZGM3_GUTS_WELD_BONE_CHILD = "ValveBiped.Bip01_Spine4"
local ZGM3_GUTS_PARENT_PHYS = 1
local ZGM3_GUTS_CHILD_PHYS = 20
local ZGM3_BONE_SPINE2 = "ValveBiped.Bip01_Spine2"
local ZGM3_BONE_PELVIS = "ValveBiped.Bip01_Pelvis"
local ZGM3_GUTS_PARENT_ANG_OFFSET = Angle(0,0,0)
local ZGM3_GUTS_CHILD_ANG_OFFSET = Angle(0,-90,0)

local function ZGM3_AddLocalAngle(baseAng, offset)
    if not offset or (offset.p==0 and offset.y==0 and offset.r==0) then return baseAng end
    local a = Angle(baseAng.p, baseAng.y, baseAng.r)
    if offset.r ~= 0 then a:RotateAroundAxis(a:Forward(), offset.r) end
    if offset.p ~= 0 then a:RotateAroundAxis(a:Right(), offset.p) end
    if offset.y ~= 0 then a:RotateAroundAxis(a:Up(), offset.y) end
    return a
end

function ENT:ZippyGoreMod3_BleedEffect( phys_bone )
    if !ZGM3_CVARS["zippygore3_bleed_effect"] then return end

    local timer_name_real = bleed_timer_name..self:EntIndex().."_Bone: "..phys_bone
    local delayMult = self.ZippyGoreMod3_BloodColor==BLOOD_COLOR_ZGM3SYNTH && 3 or 1
    timer.Create(timer_name_real, math.Rand(0.1, 0.4)*delayMult, math.random(12, 16)/delayMult, function()
        local effect_pos = IsValid(self) && self:GetBonePosition( self:TranslatePhysBoneToBone(phys_bone) )
        if !IsValid(self) or !effect_pos then timer.Remove(timer_name_real) return end
        if effect_pos.x ~= effect_pos.x or effect_pos.y ~= effect_pos.y or effect_pos.z ~= effect_pos.z then
            timer.Remove(timer_name_real) return
        end

        local particleName = blood_particles[self.ZippyGoreMod3_BloodColor]

        particleName = self:GetNW2String("DynamicBloodSplatter_CustomBlood_Particle", false) or particleName
        if !particleName then timer.Remove(timer_name_real) return end

        ParticleEffect(particleName, effect_pos, AngleRand())
        local effectdata = EffectData()
		effectdata:SetOrigin( effect_pos )
		effectdata:SetNormal( VectorRand(-1,1) )
		effectdata:SetMagnitude( 1 )
		effectdata:SetRadius(20)
		effectdata:SetEntity( self )
		util.Effect("mur_blood_splatter_effect", effectdata, true, true )

        local decal = self:GetNW2String("DynamicBloodSplatter_CustomBlood_Decal", false) or blood_decals[self.ZippyGoreMod3_BloodColor]
        if decal && timer.RepsLeft(timer_name_real) == 0 then
            local tr = util.TraceLine({
                start = effect_pos + Vector(0,0,10),
                endpos = effect_pos - Vector(0,0,50),
                filter = self,
            })
            util.Decal(decal, tr.HitPos, tr.HitPos-tr.HitNormal*10, self)
        end

    end)
end

local forcedPhysBoneRagdolls = setmetatable({}, {__mode = "k"})
local FORCED_PHYSBONE_STABLE_DIST_SQR = 0.25
local FORCED_PHYSBONE_STABLE_ANGLE = 0.5

local function addForcedPhysBonePair(rag, physBone, parentPhysBone)
    if not IsValid(rag) or rag:IsMarkedForDeletion() then return false end
    if not isnumber(physBone) or physBone < 0 then return false end
    if not isnumber(parentPhysBone) or parentPhysBone < 0 then return false end
    if physBone == parentPhysBone then return false end

    rag.ZippyGoreMod3_GibbedPhysBoneParents =
        rag.ZippyGoreMod3_GibbedPhysBoneParents or {}
    rag.ZippyGoreMod3_GibbedPhysBoneParents[physBone] = parentPhysBone
    forcedPhysBoneRagdolls[rag] = true

    -- A hidden bone has no constraint and no collisions left; with gravity on it falls
    -- through the floor between corrections and drags the skinned mesh along with it.
    local phys = rag:GetPhysicsObjectNum(physBone)
    if IsValid(phys) then phys:EnableGravity(false) end
    return true
end

local function physBonePairIsStable(phys, parentPhys)
    if not phys:IsAsleep() or not parentPhys:IsAsleep() then return false end
    if phys:GetPos():DistToSqr(parentPhys:GetPos()) > FORCED_PHYSBONE_STABLE_DIST_SQR then return false end

    local ang = phys:GetAngles()
    local parentAng = parentPhys:GetAngles()
    return math.abs(math.AngleDifference(ang.p, parentAng.p)) <= FORCED_PHYSBONE_STABLE_ANGLE
        and math.abs(math.AngleDifference(ang.y, parentAng.y)) <= FORCED_PHYSBONE_STABLE_ANGLE
        and math.abs(math.AngleDifference(ang.r, parentAng.r)) <= FORCED_PHYSBONE_STABLE_ANGLE
end

function ENT:ZippyGoreMod3_ForcePhysBonePos()
    if not IsValid(self) or self:IsMarkedForDeletion() then return false end

    local parentMap = self.ZippyGoreMod3_GibbedPhysBoneParents
    if not parentMap then return false end

    for physBone, parentPhysBone in pairs(parentMap) do
        if not isnumber(physBone) or physBone < 0
            or not isnumber(parentPhysBone) or parentPhysBone < 0
            or physBone == parentPhysBone then

            parentMap[physBone] = nil
            continue
        end

        -- Follow the chain up to the first bone that is not itself hidden. Snapping to the
        -- direct parent instead lets a foot trail its calf, which trails its thigh, one
        -- correction behind each, and the mesh stretches across the gap while it moves.
        local anchor = parentPhysBone
        for _ = 1, 32 do
            local nextAnchor = parentMap[anchor]
            if not nextAnchor or nextAnchor == physBone then break end
            anchor = nextAnchor
        end

        local phys = self:GetPhysicsObjectNum(physBone)
        local parentPhys = self:GetPhysicsObjectNum(anchor)
        if not IsValid(phys) or not IsValid(parentPhys) then
            parentMap[physBone] = nil
            continue
        end

        -- Settled pairs are only skipped, never dropped: the body wakes up again when it
        -- is shot, kicked or dragged, and a hidden bone let go at that point flies off
        -- and stretches the mesh after it.
        if physBonePairIsStable(phys, parentPhys) then continue end

        phys:SetPos(parentPhys:GetPos())
        phys:SetAngles(parentPhys:GetAngles())
        phys:SetVelocity(vector_origin)
    end

    if not next(parentMap) then
        self.ZippyGoreMod3_GibbedPhysBoneParents = nil
        return false
    end

    return true
end

-- Every tick: anything slower shows up as the mesh stretching while the body is moving.
-- Settled pairs cost a sleep check and a distance, so idle corpses stay cheap.
hook.Add("Think", "ZippyGore3_ForcePhysbonePositions_Think", function()
    for rag in pairs(forcedPhysBoneRagdolls) do
        if not IsValid(rag) or not rag:ZippyGoreMod3_ForcePhysBonePos() then
            forcedPhysBoneRagdolls[rag] = nil
        end
    end
end)

local stumpcvar = ZGM3_CVARS["zippygore3_stumps"]

function ENT:ZippyGoreMod3_CreateLimbRagdoll( SeveredPhysBone, damageData )

    local limb_ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(limb_ragdoll) or limb_ragdoll:IsMarkedForDeletion() then return nil end

    limb_ragdoll:SetPos(self:GetPos())
    limb_ragdoll:SetAngles(self:GetAngles())
    limb_ragdoll:SetModel(self:GetModel())
    limb_ragdoll:TransferModelData(self)
    limb_ragdoll:DrawShadow(false)
    limb_ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
    limb_ragdoll:Spawn()
    if not IsValid(limb_ragdoll) or limb_ragdoll:IsMarkedForDeletion() then return nil end

    limb_ragdoll:CopyWoundsFrom(self)
    if isvector(self.PlyColor) then
        limb_ragdoll:SetNW2Vector("RagColor", self.PlyColor)
	    limb_ragdoll:MakePlayerColor(self.PlyColor)
    end
    limb_ragdoll.ZGM3_NoConvulsions = true
    limb_ragdoll:ZippyGoreMod3_BecomeGibbableRagdoll( self.ZippyGoreMod3_BloodColor )
    limb_ragdoll:ZippyGoreMod3_BleedEffect( SeveredPhysBone )
    limb_ragdoll.ZippyGoreMod3_GibbedPhysBones = {}

    limb_ragdoll.ZippyGoreMod3_Ragdoll = false
    if ZGM3_INSANE_BLOOD_EFFECTS && self.ZippyGoreMod3_BloodColor==BLOOD_COLOR_RED then limb_ragdoll:RealisticBlood_Setup() end

    local severedBone = limb_ragdoll:TranslatePhysBoneToBone(SeveredPhysBone)

    for i = 0, limb_ragdoll:GetPhysicsObjectCount()-1 do
        local phys_obj = limb_ragdoll:GetPhysicsObjectNum(i)
        local src_obj = self:GetPhysicsObjectNum(i)
        if IsValid(phys_obj) && IsValid(src_obj) then
            phys_obj:SetPos( src_obj:GetPos() )
            phys_obj:SetAngles( src_obj:GetAngles() )
        end
    end

    local child_bones = {}
    local function get_all_child_bones_recursive( bone )
        for _, v in ipairs(limb_ragdoll:GetChildBones(bone)) do
            if !self.ZippyGoreMod3_GibbedPhysBones[ self:TranslateBoneToPhysBone(v) ] then
                child_bones[v] = true
                get_all_child_bones_recursive(v)
            end
        end
    end
    get_all_child_bones_recursive( severedBone )

    local parent_bones = {}
    local function get_all_parent_bones_recursive( bone )
        local parent_bone = limb_ragdoll:GetBoneParent(bone)
        parent_bones[parent_bone] = true
        if parent_bone != 0 then
            get_all_parent_bones_recursive(parent_bone)
        end
    end
    get_all_parent_bones_recursive( severedBone )

    local function remove_bone( bone )
        ZGM3_SetBoneScaleSync(limb_ragdoll, bone, nanVec)

        local phys_bone = limb_ragdoll:TranslateBoneToPhysBone( bone )

        if !limb_ragdoll.ZippyGoreMod3_GibbedPhysBones[ phys_bone ] then
            local phys_bone_bone_translated = limb_ragdoll:TranslatePhysBoneToBone(phys_bone)
            if !child_bones[phys_bone_bone_translated] && phys_bone_bone_translated != severedBone then

                local phys_obj = limb_ragdoll:GetPhysicsObjectNum( phys_bone )
                if !IsValid(phys_obj) then return end

                phys_obj:EnableCollisions(false)
                phys_obj:SetMass(0.1)

                if !parent_bones[phys_bone_bone_translated] then
                    addForcedPhysBonePair(limb_ragdoll, phys_bone, 0)
                    limb_ragdoll:RemoveInternalConstraint(phys_bone)
                end
            end
            limb_ragdoll.ZippyGoreMod3_GibbedPhysBones[ phys_bone ] = true
        end
    end
    for i = 0, limb_ragdoll:GetBoneCount()-1 do
        if i != severedBone && !child_bones[i] then remove_bone( i ) end
    end

    for parent_bone in pairs(parent_bones) do
        local parent_physbone = limb_ragdoll:TranslateBoneToPhysBone(parent_bone)
        addForcedPhysBonePair(limb_ragdoll, parent_physbone, SeveredPhysBone)
    end

    limb_ragdoll:RemoveInternalConstraint(SeveredPhysBone)

    -- Cap the open end of the piece that just came off. The body half keeps its own cap
    -- through the stump code further down; this is the other side of the same cut, and
    -- without it a severed arm is an open tube and a body split at the waist is a hollow
    -- torso seen from below.
    local severedBoneName = limb_ragdoll:GetBoneName(severedBone)
    if ZGM3_CAPS and stumpcvar and ZGM3_CAPS.HasLimbProfile(severedBoneName) then
        -- Imported .needport faces sit relative to the severed bone itself.
        local limbCap = ZGM3_CAPS.Attach(limb_ragdoll, severedBone, severedBoneName, "limb", damageData)
        if IsValid(limbCap) then
            limb_ragdoll.ZGM3_LimbStump = limbCap
        end
    else
        local limbStump = self:ZippyGoreMod3_GetLimbStump(self:TranslatePhysBoneToBone(SeveredPhysBone))
        if limbStump and util.IsValidModel(limbStump.mdl) then
            local severedPhys = limb_ragdoll:GetPhysicsObjectNum(SeveredPhysBone)
            local parentBone = limb_ragdoll:GetBoneParent(severedBone)
            local parentPhys = parentBone and
                limb_ragdoll:GetPhysicsObjectNum(limb_ragdoll:TranslateBoneToPhysBone(parentBone))

            if IsValid(severedPhys) then
                local physPos = severedPhys:GetPos()

                -- Pointing the opposite way to the body-side cap: this one faces up into the
                -- piece that left rather than down into what stayed.
                local forward = IsValid(parentPhys)
                    and (physPos - parentPhys:GetPos()):GetNormalized()
                    or vector_up

                local right = forward:Cross(vector_up):GetNormalized()
                local up = right:Cross(forward):GetNormalized()

                local stump = ents.Create("base_gmodentity")
                if IsValid(stump) and not stump:IsMarkedForDeletion() then
                    stump:SetParent(limb_ragdoll)
                    stump:SetModel(limbStump.mdl)
                    stump:FollowBone(limb_ragdoll, severedBone)
                    stump:SetPos(physPos
                        + forward * limbStump.pos_offset.x
                        + right * limbStump.pos_offset.y
                        + up * limbStump.pos_offset.z)
                    stump:SetAngles(limb_ragdoll:GetAngles() + limbStump.ang_offset)
                    if (limbStump.scale or 1) != 1 then stump:SetModelScale(limbStump.scale, 0) end
                    stump:Spawn()

                    if IsValid(stump) and not stump:IsMarkedForDeletion() then
                        limb_ragdoll.ZGM3_LimbStump = stump
                    end
                end
            end
        end
    end

    -- Only now: the cap fallback above aims along the parent bone, which this collapses.
    limb_ragdoll:ZippyGoreMod3_ForcePhysBonePos()

    local gibbed_physobj = limb_ragdoll:GetPhysicsObjectNum(SeveredPhysBone)
    if IsValid(gibbed_physobj) then
        gibbed_physobj:SetVelocity( damageData.ForceVec:GetNormalized()*damageData.Damage )
    end
    self.ZGM3_LastCreatedLimbRagdoll = limb_ragdoll
    return limb_ragdoll
end

local stumpTbl = {
    ["ValveBiped.Bip01_Head1"] = { mdl = "models/mosi/fnv/props/character/headcap.mdl", ang_offset=Angle(0, 84, 442), pos_offset=Vector(6, 0, 0) },
    -- `mdl` caps the half that stays behind and `limb` the half that flies off. The waist
    -- is the only cut whose two faces are different from each other; everywhere else the
    -- severed part reuses `mdl`, turned around.
    ["ValveBiped.Bip01_Spine2"] = {
        mdl = "models/gore/pelvis.mdl", ang_offset=Angle(0, 84, 442), pos_offset=Vector(-2, 0, 0), scale=1,
        limb = { mdl = "models/gore/uppertorso.mdl", ang_offset=Angle(0, 84, 442), pos_offset=Vector(4, 0, 0), scale=1 }
    },
    ["ValveBiped.Bip01_R_UpperArm"] = { mdl="models/mosi/fnv/props/character/legcap02.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(5, -2, 0) },
    ["ValveBiped.Bip01_L_UpperArm"] = { mdl="models/mosi/fnv/props/character/legcap02.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(5, 2, 0) },
    ["ValveBiped.Bip01_R_Forearm"] = { mdl="models/mosi/fnv/props/character/armcap.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(4, 0, 0) },
    ["ValveBiped.Bip01_L_Forearm"] = { mdl="models/mosi/fnv/props/character/armcap.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(4, 0, 0) },
    ["ValveBiped.Bip01_R_Hand"] = { mdl="models/mosi/fnv/props/character/armcap.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(4, 0, 0), scale=0.7 },
    ["ValveBiped.Bip01_L_Hand"] = { mdl="models/mosi/fnv/props/character/armcap.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(4, 0, 0), scale=0.7 },
    ["ValveBiped.Bip01_R_Foot"] = { mdl="models/mosi/fnv/props/character/armcap.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(6, 0, 0), scale=1.2 },
    ["ValveBiped.Bip01_L_Foot"] = { mdl="models/mosi/fnv/props/character/armcap.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(6, 0, 0), scale=1.2 },
    ["ValveBiped.Bip01_R_Calf"] = { mdl="models/mosi/fnv/props/character/legcap02.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(7, 0, 0) },
    ["ValveBiped.Bip01_L_Calf"] = { mdl="models/mosi/fnv/props/character/legcap02.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(7, 0, 0) },
    ["ValveBiped.Bip01_R_Thigh"] = { mdl="models/mosi/fnv/props/character/legcap01.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(5, -2, 0) },
    ["ValveBiped.Bip01_L_Thigh"] = { mdl="models/mosi/fnv/props/character/legcap01.mdl", ang_offset=Angle(77, 373, 0), pos_offset=Vector(5, 2, 0) },
}
-- Every cut has two faces. The severed part gets the same cap as the body it left,
-- turned to face back the other way, unless the entry names a model of its own -- only
-- the waist does, where the two halves are anatomically different from each other.
--
-- `limb_flip` per entry overrides the turn if one of the caps ends up facing inwards.
local LIMB_STUMP_FLIP = Angle(180, 0, 0)

function ENT:ZippyGoreMod3_GetLimbStump( gibbed_bone )
    local tbl = stumpTbl[self:GetBoneName(gibbed_bone)]
    if not tbl then return end
    if tbl.limb then return tbl.limb end

    return {
        mdl = tbl.mdl,
        ang_offset = tbl.ang_offset + (tbl.limb_flip or LIMB_STUMP_FLIP),
        pos_offset = tbl.pos_offset,
        scale = tbl.scale or 1
    }
end

function ENT:ZippyGoreMod3_GetStumpModel( gibbed_bone )
    local bone_name = self:GetBoneName(gibbed_bone)
    local tbl = stumpTbl[bone_name]

    if !tbl then
        return
    end

    return tbl.mdl, tbl.ang_offset, tbl.pos_offset, tbl.scale or 1
end

local stump_adjust = CreateConVar("zgm3_stump_adjust", 0, FCVAR_NONE, "Do not enable this.")
local dev = GetConVar("developer")
function ENT:ZippyGoreMod3_BreakPhysBone( phys_bone_idx, data )
    local gibbed_bone = self:TranslatePhysBoneToBone(phys_bone_idx)
    if not gibbed_bone or gibbed_bone < 0 then return end

    local EnhancedSplatter = DynSplatterFullyInitialized and false

    self:DrawShadow(false)

    local function gib_bone_recursive( bone, dismember, MakeLimbRag )
        ZGM3_SetBoneScaleSync(self, bone, nanVec)

        local timer_name_real = bleed_timer_name..self:EntIndex().."_Bone: "..phys_bone_idx
        if timer.Exists(timer_name_real) then
            timer.Remove(timer_name_real)
        end

        local phys_bone = self:TranslateBoneToPhysBone( bone )
        if phys_bone != -1 then
            if !self.ZippyGoreMod3_GibbedPhysBones then self.ZippyGoreMod3_GibbedPhysBones = {} end
            if !self.ZippyGoreMod3_GibbedPhysBones[ phys_bone ] then
                local phys_obj = self:GetPhysicsObjectNum( phys_bone )
                if IsValid(phys_obj) then

                    phys_obj:EnableCollisions(false)

                    if phys_bone != 0 then
                        local parentBone = self:GetBoneParent(bone)
                        local parentPhysBone = parentBone and parentBone >= 0
                            and self:TranslateBoneToPhysBone(parentBone)

                        addForcedPhysBonePair(self, phys_bone, parentPhysBone)
                        self:RemoveInternalConstraint(phys_bone)
                    end

                    local damageData = {
                        Damage = data.damage,
                        ForceVec = data.forceVec,
                    }
                    if dismember then
                        if MakeLimbRag && phys_bone != 0 then
                            self:ZippyGoreMod3_CreateLimbRagdoll( phys_bone, damageData )
                        elseif phys_bone == 0 then
                            self:ZippyGoreMod3_CreateGibs( phys_bone, damageData )
                        end
                    else
                        self:ZippyGoreMod3_CreateGibs( phys_bone, damageData )
                    end

                    -- How much blood the room gets is decided by what just happened to
                    -- the body, not by a single default: a body opened at the waist
                    -- empties, a destroyed part bleeds out, a limb taken off whole
                    -- barely marks the floor.
                    local poolBone = self:TranslatePhysBoneToBone(phys_bone)
                    local poolBoneName = self:GetBoneName(poolBone)
                    local pool

                    if poolBoneName == ZGM3_BONE_SPINE2 or poolBoneName == ZGM3_BONE_PELVIS then
                        pool = MuR.BLOOD_POOL.GUSH
                    elseif dismember and MakeLimbRag and phys_bone != 0 then
                        pool = MuR.BLOOD_POOL.SMALL
                    else
                        pool = MuR.BLOOD_POOL.MEDIUM
                    end

                    MuR:CreateBloodPool(self, poolBone, pool, 0)

                    if self.ZippyGoreMod3_StartDragTrail then
                        self:ZippyGoreMod3_StartDragTrail()
                    end

                    local boneName = self:GetBoneName(bone)
                    if self.ZGM3_SetDismemberExpression then
                        self:ZGM3_SetDismemberExpression(boneName)
                    end

					timer.Remove("RagdollStruggle"..self:EntIndex())
					if IsValid(self.Owner) and self.isRDRag and self.Owner:IsPlayer() then
						self.Owner:TimeGetUpChange(99999, true)
						self.Owner:DamagePlayerSystem("hard_blood")
						self.Gibbed = true

						-- Taking the head off, or splitting the body through the spine or
						-- pelvis, is structural: there is nothing left to bleed out. A
						-- limb coming off is not -- that is a traumatic amputation, and it
						-- kills through the blood loss set up just above, over time.
						local gibbedBone = self:GetBoneName(bone)
						if MuR.IsFatalDismembermentBone and MuR.IsFatalDismembermentBone(gibbedBone) then
							if isstring(self.Owner.LastVoiceLine) then
								self.Owner:StopSound(self.Owner.LastVoiceLine)
							end
							self.Owner.MuR_StructuralDeath = true
							self.Owner:Kill()
						elseif self.Owner.EnterDying then
							-- Losing a limb is a mortal wound, not a flesh wound: the stump
							-- is what kills, and it kills on the clock. Going down here
							-- rather than staying upright also means a tourniquet from a
							-- medic is a real save instead of a formality.
							self.Owner:EnterDying()
						end
					end

                    local physObjPos = phys_obj:GetPos()
                    local aabb_min, aabb_max = phys_obj:GetAABB()

                    local effect_pos_data = { blood_color=self.ZippyGoreMod3_BloodColor, pos_min = physObjPos + aabb_min, pos_max = physObjPos + aabb_max, ent=self }
                    local effectdata = EffectData()
                    effectdata:SetFlags( effect_pos_data.blood_color or -1 )
                    effectdata:SetOrigin( effect_pos_data.pos_min )
                    effectdata:SetStart( effect_pos_data.pos_max )
                    effectdata:SetEntity(effect_pos_data.ent)
                    util.Effect("zippygore3_ongib", effectdata, true, true)

                    if bone == 0 then
                        self:EmitSound("ZippyGore3OnRootBoneGib")
                    else
                        self:EmitSound("ZippyGore3OnGib")
                    end

                end

                self.ZippyGoreMod3_GibbedPhysBones[ phys_bone ] = true
            end

            if ZGM3_CAPS then
                ZGM3_CAPS.RemoveByFollowBone(self, bone)
            end

            for _, v in ipairs(self:GetChildBones(bone)) do
                gib_bone_recursive(v, dismember, phys_bone==0)
            end
        end
    end

    gib_bone_recursive( gibbed_bone, data.dismember, true )
    self:ZippyGoreMod3_ForcePhysBonePos()

    if phys_bone_idx == 0 then

        self:Remove()
    elseif blood_particles[self.ZippyGoreMod3_BloodColor] then

        self:ZippyGoreMod3_BleedEffect( phys_bone_idx )

        local boneName = self:GetBoneName(gibbed_bone)
        if boneName == ZGM3_BONE_PELVIS and not self.ZGM3_Spine2Gibbed then
            if not self.ZGM3_GutsSpawned then
                local guts = ents.Create("prop_ragdoll")
                if IsValid(guts) and not guts:IsMarkedForDeletion() then
                    guts:SetModel(ZGM3_GUTS_MODEL)
                    local gutsPos = self:GetBonePosition(1)
                    if not isvector(gutsPos) or gutsPos.x ~= gutsPos.x then gutsPos = self:GetPos() end
                    guts:SetPos(gutsPos)
                    guts:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
                    local pelvisBone = self:LookupBone(ZGM3_BONE_PELVIS)
                    if pelvisBone then
                        local m = self:GetBoneMatrix(pelvisBone)
                        if m then guts:SetAngles(ZGM3_AddLocalAngle(m:GetAngles(), ZGM3_GUTS_PARENT_ANG_OFFSET)) else guts:SetAngles(ZGM3_AddLocalAngle(self:GetAngles(), ZGM3_GUTS_PARENT_ANG_OFFSET)) end
                    else
                        guts:SetAngles(ZGM3_AddLocalAngle(self:GetAngles(), ZGM3_GUTS_PARENT_ANG_OFFSET))
                    end
                    guts:Spawn()
                    if IsValid(guts) and not guts:IsMarkedForDeletion() then
                        local gutsPhys = guts:GetPhysicsObjectNum(ZGM3_GUTS_CHILD_PHYS)
                        if IsValid(gutsPhys) then
                            gutsPhys:SetVelocity(data.forceVec or vector_origin)
                        end
                        self.ZGM3_GutsSpawned = true
                    end
                end
            end
        elseif boneName == ZGM3_BONE_SPINE2 then
            self.ZGM3_Spine2Gibbed = true
            local guts = ents.Create("prop_ragdoll")
            if IsValid(guts) and not guts:IsMarkedForDeletion() then
                guts:SetModel(ZGM3_GUTS_MODEL)
                local gutsPos = self:GetBonePosition(1)
                if not isvector(gutsPos) or gutsPos.x ~= gutsPos.x then gutsPos = self:GetPos() end
                guts:SetPos(gutsPos)
                guts:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
                local s2idx = self:LookupBone(ZGM3_BONE_SPINE2)
                if s2idx then
                    local m = self:GetBoneMatrix(s2idx)
                    if m then guts:SetAngles(ZGM3_AddLocalAngle(m:GetAngles(), ZGM3_GUTS_PARENT_ANG_OFFSET)) else guts:SetAngles(ZGM3_AddLocalAngle(self:GetAngles(), ZGM3_GUTS_PARENT_ANG_OFFSET)) end
                else
                    guts:SetAngles(ZGM3_AddLocalAngle(self:GetAngles(), ZGM3_GUTS_PARENT_ANG_OFFSET))
                end
                guts:Spawn()
                if IsValid(guts) and not guts:IsMarkedForDeletion() then
                    local gutsForcePhys = guts:GetPhysicsObjectNum(ZGM3_GUTS_CHILD_PHYS)
                    if IsValid(gutsForcePhys) then
                        gutsForcePhys:SetVelocity(data.forceVec or vector_origin)
                    end
                    local created = self.ZGM3_LastCreatedLimbRagdoll
                local function getPhysByBone(ent, boneStr)
                    if !IsValid(ent) then return nil end
                    local b = ent:LookupBone(boneStr)
                    if !b then return nil end
                    local pb = ent:TranslateBoneToPhysBone(b)
                    if pb < 0 then return nil end
                    return ent:GetPhysicsObjectNum(pb), pb
                end
                local pSelf, idxSelf = getPhysByBone(self, ZGM3_GUTS_WELD_BONE_PARENT)
                local pLimb, idxLimb = getPhysByBone(created, ZGM3_GUTS_WELD_BONE_CHILD)
                local pGuts1 = guts:GetPhysicsObjectNum(0)
                local gParentPhys = guts:GetPhysicsObjectNum(ZGM3_GUTS_PARENT_PHYS)
                local gChildPhys = guts:GetPhysicsObjectNum(ZGM3_GUTS_CHILD_PHYS)
                local function alignPhysToBone(hostEnt, boneName, physObj, angOffset)
                    if not (IsValid(hostEnt) and IsValid(physObj)) then return end
                    local b = hostEnt:LookupBone(boneName)
                    if not b then return end
                    local m = hostEnt:GetBoneMatrix(b)
                    if not m then return end
                    physObj:SetPos(m:GetTranslation())
                    physObj:SetAngles(ZGM3_AddLocalAngle(m:GetAngles(), angOffset or angle_zero))
                    physObj:Wake()
                end
                alignPhysToBone(self, ZGM3_GUTS_WELD_BONE_PARENT, gParentPhys, ZGM3_GUTS_PARENT_ANG_OFFSET)
                if IsValid(created) then alignPhysToBone(created, ZGM3_GUTS_WELD_BONE_CHILD, gChildPhys, ZGM3_GUTS_CHILD_ANG_OFFSET) end
                local weldCount = 0
                local lastConstraint
                if IsValid(pSelf) and IsValid(pGuts1) then
                    lastConstraint = constraint.Weld(self, guts, idxSelf or 0, ZGM3_GUTS_PARENT_PHYS, ZGM3_GUTS_WELD_FORCE, false, false)
                    if lastConstraint then weldCount = weldCount + 1 end
                end
                if IsValid(pLimb) and IsValid(pGuts1) then
                    local c2 = constraint.Weld(created, guts, idxLimb or 0, ZGM3_GUTS_CHILD_PHYS, ZGM3_GUTS_WELD_FORCE, false, false)
                    if c2 then weldCount = weldCount + 1 end
                end
                if weldCount == 0 and IsValid(pSelf) and IsValid(pGuts1) then
                    lastConstraint = constraint.Weld(self, guts, idxSelf or 0, ZGM3_GUTS_PARENT_PHYS, ZGM3_GUTS_WELD_FORCE, false, false)
                    if lastConstraint then weldCount = 1 end
                elseif weldCount == 0 and IsValid(pLimb) and IsValid(pGuts1) then
                    lastConstraint = constraint.Weld(created, guts, idxLimb or 0, ZGM3_GUTS_CHILD_PHYS, ZGM3_GUTS_WELD_FORCE, false, false)
                    if lastConstraint then weldCount = 1 end
                end
                    guts.ZGM3_GutsWelds = weldCount
                    self.ZGM3_GutsSpawned = true
                end
            end
        end

        if ZGM3_CAPS and stumpcvar then
            local parent_bone = self:GetBoneParent(gibbed_bone)
            local parent_phys_bone = parent_bone and parent_bone >= 0
                and self:TranslateBoneToPhysBone(parent_bone)
            local parent_gibbed = parent_phys_bone and self.ZippyGoreMod3_GibbedPhysBones
                and self.ZippyGoreMod3_GibbedPhysBones[parent_phys_bone]

            if parent_bone and parent_bone >= 0 and not parent_gibbed then
                local cap = ZGM3_CAPS.Attach(self, parent_bone, boneName, "body", data)

                if IsValid(cap) and stump_adjust:GetBool() and dev:GetBool() then
                    cap.ZGM3_DevAngOffset = Angle()
                    hook.Add("Tick", cap, function()
                        if !IsValid(cap) or cap:IsMarkedForDeletion() then
                            hook.Remove("Tick", cap)
                            return
                        end

                        local ply = Entity(1)

                        if IsValid(ply) && ply:IsPlayer() then

                            local did_adjust = false

                            if ply:KeyDown(IN_FORWARD) then
                                cap.ZGM3_DevAngOffset = cap.ZGM3_DevAngOffset+Angle(1, 0, 0)
                                did_adjust = true
                            elseif ply:KeyDown(IN_MOVERIGHT) then
                                cap.ZGM3_DevAngOffset = cap.ZGM3_DevAngOffset+Angle(0, 1, 0)
                                did_adjust = true
                            elseif ply:KeyDown(IN_JUMP) then
                                cap.ZGM3_DevAngOffset = cap.ZGM3_DevAngOffset+Angle(0, 0, 1)
                                did_adjust = true
                            elseif ply:KeyDown(IN_BACK) then
                                cap.ZGM3_DevAngOffset = cap.ZGM3_DevAngOffset+Angle(-1, 0, 0)
                                did_adjust = true
                            elseif ply:KeyDown(IN_MOVELEFT) then
                                cap.ZGM3_DevAngOffset = cap.ZGM3_DevAngOffset+Angle(0, -1, 0)
                                did_adjust = true
                            elseif ply:KeyDown(IN_SPEED) then
                                cap.ZGM3_DevAngOffset = cap.ZGM3_DevAngOffset+Angle(0, 0, -1)
                                did_adjust = true
                            end

                            if did_adjust then
                                cap:SetLocalAngles(cap.ZGM3_DevAngOffset)
                                PrintMessage(HUD_PRINTTALK, tostring(cap.ZGM3_DevAngOffset))
                                ply:SetPos(cap:GetPos())
                            end

                        end

                    end)
                end
            end
        end

    end

    if ZGM3_CVARS["zippygore3_print_gibbed_bone"] then
        PrintMessage(HUD_PRINTCENTER, self:GetBoneName( gibbed_bone ) )
        PrintMessage(HUD_PRINTTALK, self:GetBoneName( gibbed_bone ) )
    end
end