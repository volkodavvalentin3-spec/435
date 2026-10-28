local meta = FindMetaTable("Player")
local meta2 = FindMetaTable("Entity")

local BLUNT_CONCUSSION_WEAPONS = {
	["mur_hands"] = true,
	["tfa_bs_sledge"] = true,
	["tfa_bs_wrench"] = true,
	["tfa_bs_spade"] = true,
	["tfa_bs_pipe"] = true,
	["tfa_bs_fubar"] = true,
	["tfa_bs_crowbar"] = true,
	["tfa_bs_baton"] = true,
	["tfa_bs_bat"] = true
}

local SHARP_LACERATION_WEAPONS = {
	["mur_welder"] = true,
	["tfa_bs_compactk"] = true,
	["tfa_bs_pickaxe"] = true,
	["tfa_bs_fireaxe_maniac"] = true,
	["tfa_bs_machete"] = true,
	["tfa_bs_knife"] = true,
	["tfa_bs_hatchet"] = true,
	["tfa_bs_fireaxe"] = true,
	["tfa_bs_combk"] = true,
	["tfa_bs_cleaver"] = true,
	["tfa_bs_chainsaw"] = true
}

local BLUNT_LACERATION_WEAPONS = {
	["mur_hands"] = true,
	["mur_zombie"] = true,
	["tfa_bs_wrench"] = true,
	["tfa_bs_spade"] = true,
	["tfa_bs_sledge"] = true,
	["tfa_bs_pipe"] = true,
	["tfa_bs_fubar"] = true,
	["tfa_bs_crowbar"] = true,
	["tfa_bs_baton"] = true,
	["tfa_bs_bat"] = true
}

local BLEED_WOUND_MINOR = 1
local BLEED_WOUND_DEEP = 2
local BLEED_WOUND_ARTERIAL = 3

local BLEED_WOUND_BLEED_LEVELS = {
	[0] = 0,
	[BLEED_WOUND_MINOR] = 0.5,
	[BLEED_WOUND_DEEP] = 1.4,
	[BLEED_WOUND_ARTERIAL] = 2.8
}

local SIDE_SPECIFIC_ORGAN_MIRRORS = {
	brachial_left = "brachial",
	brachial_right = "brachial",
	femoral_left = "femoral",
	femoral_right = "femoral"
}

local SIDE_SPECIFIC_ORGAN_KEYS = {
	"brain", "neck", "heart", "carotid", "liver", "lungs",
	"lung_left", "lung_right",
	"brachial", "brachial_left", "brachial_right",
	"femoral", "femoral_left", "femoral_right"
}

local SIDE_SPECIFIC_ARTERY_FLAGS = {
	"Artery_Neck", "Artery_Heart", "Artery_Generic",
	"Artery_ArmLeft", "Artery_ArmRight",
	"Artery_LegLeft", "Artery_LegRight"
}

local LUNG_PNEUMOTHORAX_FLAGS = {
	left = "PneumothoraxLeft",
	right = "PneumothoraxRight"
}

local ORGAN_AGGREGATE_CHILDREN = {
	lungs = {"lung_left", "lung_right"},
	brachial = {"brachial_left", "brachial_right"},
	femoral = {"femoral_left", "femoral_right"}
}

local LIMB_ARTERY_SLOTS = {
	left_arm = {arteryFlag = "Artery_ArmLeft", criticalStateKey = "brachial_left", aggregateKey = "brachial", bone = "ValveBiped.Bip01_L_UpperArm"},
	right_arm = {arteryFlag = "Artery_ArmRight", criticalStateKey = "brachial_right", aggregateKey = "brachial", bone = "ValveBiped.Bip01_R_UpperArm"},
	left_leg = {arteryFlag = "Artery_LegLeft", criticalStateKey = "femoral_left", aggregateKey = "femoral", bone = "ValveBiped.Bip01_L_Thigh"},
	right_leg = {arteryFlag = "Artery_LegRight", criticalStateKey = "femoral_right", aggregateKey = "femoral", bone = "ValveBiped.Bip01_R_Thigh"}
}

local LEGACY_ARTERY_FLAGS = {
	"Artery_Neck", "Artery_Heart", "Artery_Arm", "Artery_Leg", "Artery_Generic",
	"Artery_neck", "Artery_heart", "Artery_arm", "Artery_leg"
}

local function isHeadOrNeckBone(bone)
	return bone == "ValveBiped.Bip01_Head1" or bone == "ValveBiped.Bip01_Neck1"
end

local function getDamageWeaponClass(dmginfo)
	if not dmginfo then return nil end

	local inflictor = dmginfo:GetInflictor()
	if IsValid(inflictor) and inflictor:IsWeapon() then
		return inflictor:GetClass()
	end

	local attacker = dmginfo:GetAttacker()
	if IsValid(attacker) and attacker:IsPlayer() then
		local weapon = attacker:GetActiveWeapon()
		if IsValid(weapon) then
			return weapon:GetClass()
		end
	end

	if IsValid(inflictor) then
		return inflictor:GetClass()
	end

	return nil
end

local function getBleedingWoundProfile(dmginfo)
	if not dmginfo then return nil end

	local damageType = dmginfo:GetDamageType()
	local weaponClass = getDamageWeaponClass(dmginfo)

	if bit.band(damageType, DMG_SLASH) ~= 0 or SHARP_LACERATION_WEAPONS[weaponClass or ""] then
		return "sharp", weaponClass
	end

	if BLUNT_LACERATION_WEAPONS[weaponClass or ""] then
		return "blunt", weaponClass
	end

	return nil, weaponClass
end

local function isTieredLimbArteryCandidate(dmginfo, organ)
	if organ ~= "Right Brachial Artery" and organ ~= "Left Brachial Artery"
		and organ ~= "Right Femoral Artery" and organ ~= "Left Femoral Artery" then
		return false
	end

	local profile = getBleedingWoundProfile(dmginfo)
	return profile ~= nil
end

local function rollBleedingWoundTier(dmginfo, organ)
	local profile = getBleedingWoundProfile(dmginfo)
	if not profile then return nil end

	local minorChance, deepChance, arterialChance
	if profile == "sharp" then
		minorChance, deepChance, arterialChance = 0.72, 0.23, 0.05

		if string.find(organ, "Femoral", 1, true) then
			minorChance = minorChance - 0.02
			deepChance = deepChance + 0.01
			arterialChance = arterialChance + 0.01
		end
	else
		minorChance, deepChance, arterialChance = 0.84, 0.16, 0
	end

	local damage = dmginfo:GetDamage()
	if damage >= 30 then
		minorChance = minorChance - 0.1
		deepChance = deepChance + 0.07
		arterialChance = arterialChance + 0.03
	elseif damage >= 20 then
		minorChance = minorChance - 0.05
		deepChance = deepChance + 0.03
		arterialChance = arterialChance + 0.02
	elseif damage <= 12 then
		minorChance = minorChance + 0.08
		deepChance = math.max(deepChance - 0.05, 0.05)
		arterialChance = math.max(arterialChance - 0.03, 0)
	end

	local sum = minorChance + deepChance + arterialChance
	minorChance = minorChance / sum
	deepChance = deepChance / sum
	arterialChance = arterialChance / sum

	local roll = math.Rand(0, 1)
	if roll <= minorChance then
		return BLEED_WOUND_MINOR, profile
	elseif roll <= minorChance + deepChance then
		return BLEED_WOUND_DEEP, profile
	end

	return BLEED_WOUND_ARTERIAL, profile
end

local function getOrganStateInfo(organ)
	if organ == "Right Lung" then
		return {
			stateKey = "lung_right",
			aggregateKey = "lungs",
			slot = "chest_right",
			side = "right"
		}
	elseif organ == "Left Lung" then
		return {
			stateKey = "lung_left",
			aggregateKey = "lungs",
			slot = "chest_left",
			side = "left"
		}
	elseif organ == "Right Brachial Artery" then
		return {
			stateKey = "brachial_right",
			aggregateKey = "brachial",
			slot = "right_arm",
			bone = "ValveBiped.Bip01_R_UpperArm",
			arteryFlag = "Artery_ArmRight"
		}
	elseif organ == "Left Brachial Artery" then
		return {
			stateKey = "brachial_left",
			aggregateKey = "brachial",
			slot = "left_arm",
			bone = "ValveBiped.Bip01_L_UpperArm",
			arteryFlag = "Artery_ArmLeft"
		}
	elseif organ == "Right Femoral Artery" then
		return {
			stateKey = "femoral_right",
			aggregateKey = "femoral",
			slot = "right_leg",
			bone = "ValveBiped.Bip01_R_Thigh",
			arteryFlag = "Artery_LegRight"
		}
	elseif organ == "Left Femoral Artery" then
		return {
			stateKey = "femoral_left",
			aggregateKey = "femoral",
			slot = "left_leg",
			bone = "ValveBiped.Bip01_L_Thigh",
			arteryFlag = "Artery_LegLeft"
		}
	elseif organ == "Carotid Artery" then
		return {
			stateKey = "carotid",
			slot = "neck",
			bone = "ValveBiped.Bip01_Neck1",
			arteryFlag = "Artery_Neck"
		}
	elseif organ == "Heart" then
		return {
			stateKey = "heart",
			slot = "chest_center",
			bone = "ValveBiped.Bip01_Spine4",
			arteryFlag = "Artery_Heart"
		}
	elseif organ == "Neck" then
		return {
			stateKey = "neck",
			slot = "neck",
			bone = "ValveBiped.Bip01_Neck1"
		}
	elseif organ == "Liver" then
		return {
			stateKey = "liver",
			slot = "abdomen_right",
			bone = "ValveBiped.Bip01_Spine"
		}
	elseif organ == "Brain" then
		return {
			stateKey = "brain",
			slot = "head",
			bone = "ValveBiped.Bip01_Head1"
		}
	end

	return nil
end

local function getCombinedOrganStage(ply, ...)
	local maxStage = 0
	local activeSides = 0

	for i = 1, select("#", ...) do
		local key = select(i, ...)
		local stage = ply:GetOrganDamageStage(key)
		if stage > 0 then
			activeSides = activeSides + 1
			maxStage = math.max(maxStage, stage)
		end
	end

	if activeSides >= 2 then
		return math.min(maxStage + 1, 3)
	end

	return maxStage
end

local function canCauseBluntConcussion(dmginfo, bone)
	if not dmginfo or not isHeadOrNeckBone(bone) then return false end
	if bit.band(dmginfo:GetDamageType(), DMG_CLUB) == 0 then return false end

	local weaponClass = getDamageWeaponClass(dmginfo)
	return weaponClass ~= nil and BLUNT_CONCUSSION_WEAPONS[weaponClass] == true
end

local function shouldUseNetworkedPlayerBlood(ent)
	return IsValid(ent) and ent:IsPlayer() and not IsValid(ent:GetRD())
end

local function shouldUseStandaloneBlood(ent)
	return IsValid(ent) and ent:IsRagdoll()
end

local function broadcastLiveBloodSpray(ent, bone, magnitude, radius)
	if not IsValid(ent) then return end

	local pos, ang = MuR:BoneData(ent, bone)
	if not isvector(pos) then return end

	local up = isangle(ang) and ang:Up() or vector_up
	local normal = (Vector(0.5, math.Rand(-1, 1), math.Rand(0, 0.35)) + up):GetNormalized()

	if shouldUseNetworkedPlayerBlood(ent) and MuR.BroadcastBloodSplatterEffect then
		MuR:BroadcastBloodSplatterEffect(ent, pos, normal, magnitude or 1, radius or 16, 0)
	elseif shouldUseStandaloneBlood(ent) and MuR.BroadcastStandaloneBloodSpray then
		MuR:BroadcastStandaloneBloodSpray(pos, normal, magnitude or 1, radius or 16)
	end
end

local function getWoundVisualProfile(slot, tier)
	if tier == BLEED_WOUND_ARTERIAL then
		return {
			interval = string.find(slot, "leg", 1, true) and 0.3 or 0.35,
			magnitude = string.find(slot, "leg", 1, true) and 1.55 or 1.4,
			radius = string.find(slot, "leg", 1, true) and 24 or 22
		}
	elseif tier == BLEED_WOUND_DEEP then
		return {
			interval = string.find(slot, "leg", 1, true) and 0.85 or 0.95,
			magnitude = string.find(slot, "leg", 1, true) and 1.15 or 1.05,
			radius = string.find(slot, "leg", 1, true) and 17 or 15
		}
	elseif tier == BLEED_WOUND_MINOR then
		return {
			interval = string.find(slot, "leg", 1, true) and 1.45 or 1.6,
			magnitude = 0.75,
			radius = 11
		}
	end

	return nil
end

function meta2:BloodTrailBone(bone, seconds)
    local body = self:IsPlayer() and IsValid(self:GetRD()) and self:GetRD() or self
    local n = Vector(0.5,math.Rand(-1,1),0)
    local str = self:EntIndex().."BleedingEntBone_"..bone
	self.LastBleedBone = bone
    timer.Create(str, 0.18, math.ceil(seconds*5.555), function()
        if !IsValid(body) or !body:LookupBone(bone) then
            timer.Remove(str)
            return
        end
        local effectdata = EffectData()
		local pos, ang = MuR:BoneData(body, bone)
		local up = isangle(ang) and ang:Up() or vector_up
		local normal = (n + up):GetNormalized()
        effectdata:SetOrigin(pos)
        effectdata:SetNormal(normal)
        effectdata:SetMagnitude(1)
        effectdata:SetRadius(0)
        effectdata:SetFlags(2)
        effectdata:SetEntity(body)
		if shouldUseNetworkedPlayerBlood(body) or shouldUseStandaloneBlood(body) then
			broadcastLiveBloodSpray(body, bone, 1.15, 16)
		else
			util.Effect("mur_blood_splatter_effect", effectdata)
		end
    end)
end

function meta2:GetBloodTrails(pattern)
	local tab = {}
	for i=0, self:GetBoneCount()-1 do
		local bone = self:GetBoneName(i)
		if !timer.Exists(self:EntIndex().."BleedingEntBone_"..bone) then continue end
		tab[#tab+1] = bone
		if pattern and string.match(bone, pattern) then return true end
		if pattern == "remove" then
			timer.Remove(self:EntIndex().."BleedingEntBone_"..bone)
		end
	end
	return !pattern and tab or false
end

function meta:ApplyConcussion(dmg, duration, intensity, chance)
	if self:IsRoleWithoutOrgans() then return end
	chance = chance or 1
	if chance < 1 and math.Rand(0, 1) > chance then return end
	duration = duration or 2
	intensity = intensity or 1
	if self:GetNW2Float("ConcussionEnd", 0) > CurTime() then
		local left = self:GetNW2Float("ConcussionEnd") - CurTime()
		duration = duration + left * 0.4
		intensity = math.min(intensity + self:GetNW2Float("ConcussionIntensity", 0) * 0.5, 2)
	end
	self:SetNW2Float("ConcussionEnd", CurTime() + duration)
	self:SetNW2Float("ConcussionIntensity", intensity)
	MuR:GiveMessage2("concussion_hit", self)
end

function meta:ApplyInternalBleed(duration, rate)
	duration = duration or 12
	rate = rate or 3
	if self:GetNW2Float("InternalBleedEnd", 0) > CurTime() then
		self:SetNW2Float("InternalBleedEnd", math.max(self:GetNW2Float("InternalBleedEnd"), CurTime() + duration * 0.5))
		return
	end
	self:SetNW2Float("InternalBleedEnd", CurTime() + duration)
	local name = "MuR_InternalBleed_" .. self:EntIndex()
	timer.Create(name, rate, 0, function()
		if not IsValid(self) then timer.Remove(name) return end
		if CurTime() > self:GetNW2Float("InternalBleedEnd") then timer.Remove(name) return end
		if self:Alive() then
			self:DamagePlayerSystem("blood")
			if math.random(1,3) == 1 then self:DamagePlayerSystem("blood") end
		else
			timer.Remove(name)
		end
	end)
	MuR:GiveMessage2("internal_hit", self)
end

function meta:TriggerArtery(source)
	source = source or "Generic"

	local arteryKey = source
	if source == "Heart" then
		arteryKey = "Heart"
	elseif source == "Neck" or source == "Carotid Artery" then
		arteryKey = "Neck"
	elseif isstring(source) and string.find(source, "Right Brachial", 1, true) then
		arteryKey = "ArmRight"
	elseif isstring(source) and string.find(source, "Left Brachial", 1, true) then
		arteryKey = "ArmLeft"
	elseif isstring(source) and string.find(source, "Brachial", 1, true) then
		arteryKey = "Arm"
	elseif isstring(source) and string.find(source, "Right Femoral", 1, true) then
		arteryKey = "LegRight"
	elseif isstring(source) and string.find(source, "Left Femoral", 1, true) then
		arteryKey = "LegLeft"
	elseif isstring(source) and string.find(source, "Femoral", 1, true) then
		arteryKey = "Leg"
	elseif source ~= "Generic" then
		arteryKey = "Generic"
	end

	self:SetNW2Bool("Artery_" .. arteryKey, true)

	if arteryKey == "ArmLeft" or arteryKey == "ArmRight" then
		local armBleed = self:GetNW2Bool("Artery_ArmLeft", false) or self:GetNW2Bool("Artery_ArmRight", false)
		self:SetNW2Bool("Artery_Arm", armBleed)
		self:SetNW2Bool("Artery_arm", armBleed)
	elseif arteryKey == "Arm" then
		self:SetNW2Bool("Artery_arm", true)
	elseif arteryKey == "LegLeft" or arteryKey == "LegRight" then
		local legBleed = self:GetNW2Bool("Artery_LegLeft", false) or self:GetNW2Bool("Artery_LegRight", false)
		self:SetNW2Bool("Artery_Leg", legBleed)
		self:SetNW2Bool("Artery_leg", legBleed)
	elseif arteryKey == "Leg" then
		self:SetNW2Bool("Artery_leg", true)
	elseif arteryKey == "Neck" then
		self:SetNW2Bool("Artery_neck", true)
	elseif arteryKey == "Heart" then
		self:SetNW2Bool("Artery_heart", true)
	end

	if not self:GetNW2Bool("HardBleed") then
		self:SetNW2Bool("HardBleed", true)
		MuR:GiveMessage2("artery_hit", self)
	end
end

function meta:HasActiveArteryBleed()
	for _, key in ipairs(SIDE_SPECIFIC_ARTERY_FLAGS) do
		if self:GetNW2Bool(key, false) then
			return true
		end
	end

	if self:GetNW2Bool("Artery_Arm", false) or self:GetNW2Bool("Artery_Leg", false) then
		return true
	end

	return false
end

function meta:RefreshLegacyArteryFlags()
	local armBleed = self:GetNW2Bool("Artery_ArmLeft", false) or self:GetNW2Bool("Artery_ArmRight", false)
	local legBleed = self:GetNW2Bool("Artery_LegLeft", false) or self:GetNW2Bool("Artery_LegRight", false)

	self:SetNW2Bool("Artery_Arm", armBleed)
	self:SetNW2Bool("Artery_arm", armBleed)
	self:SetNW2Bool("Artery_Leg", legBleed)
	self:SetNW2Bool("Artery_leg", legBleed)
	self:SetNW2Bool("Artery_neck", self:GetNW2Bool("Artery_Neck", false))
	self:SetNW2Bool("Artery_heart", self:GetNW2Bool("Artery_Heart", false))

	if self:HasActiveArteryBleed() then
		self:SetNW2Bool("HardBleed", true)
	end
end

function meta:RefreshPneumothoraxState()
	local leftActive = self:GetNW2Bool(LUNG_PNEUMOTHORAX_FLAGS.left, false)
	local rightActive = self:GetNW2Bool(LUNG_PNEUMOTHORAX_FLAGS.right, false)
	self:SetNW2Bool("Pneumothorax", leftActive or rightActive)
	return leftActive, rightActive
end

function meta:SetLungPneumothorax(side, active)
	local flag = side and LUNG_PNEUMOTHORAX_FLAGS[side]
	if not flag then return end
	self:SetNW2Bool(flag, active == true)
	self:RefreshPneumothoraxState()
end

function meta:RefreshCombinedLungStage()
	local leftStage = self:GetOrganDamageStage("lung_left")
	local rightStage = self:GetOrganDamageStage("lung_right")
	local combinedStage = 0

	if leftStage > 0 and rightStage > 0 then
		combinedStage = math.min(math.max(leftStage, rightStage) + 1, 3)
	end

	self.OrganDamageStages = self.OrganDamageStages or {}
	self.OrganDamageStages.lungs = combinedStage
	self:SetNW2Int("OrganDamage_lungs", combinedStage)

	return leftStage, rightStage, combinedStage
end

function meta:StopBleedingWoundVisual(slot)
	if not isstring(slot) or slot == "" then return end
	timer.Remove("MuR_BleedingWoundVisual_" .. self:EntIndex() .. "_" .. slot)
end

function meta:RefreshBleedingWoundVisual(slot)
	if not isstring(slot) or slot == "" then return end

	self:StopBleedingWoundVisual(slot)

	local wound = self.BleedingWounds and self.BleedingWounds[slot]
	if not wound or (wound.tier or 0) <= 0 or not isstring(wound.bone) then
		return
	end

	local profile = getWoundVisualProfile(slot, wound.tier)
	if not profile then return end

	local timerName = "MuR_BleedingWoundVisual_" .. self:EntIndex() .. "_" .. slot
	timer.Create(timerName, profile.interval, 0, function()
		if not IsValid(self) or not self:Alive() then
			timer.Remove(timerName)
			return
		end

		local currentWound = self.BleedingWounds and self.BleedingWounds[slot]
		if not currentWound or (currentWound.tier or 0) <= 0 or not isstring(currentWound.bone) then
			timer.Remove(timerName)
			return
		end

		local currentProfile = getWoundVisualProfile(slot, currentWound.tier)
		if not currentProfile then
			timer.Remove(timerName)
			return
		end

		local body = self:IsPlayer() and IsValid(self:GetRD()) and self:GetRD() or self
		if not IsValid(body) then
			timer.Remove(timerName)
			return
		end

		broadcastLiveBloodSpray(body, currentWound.bone, currentProfile.magnitude, currentProfile.radius)
	end)
end

function meta:RefreshAggregateOrganStage(aggregateKey)
	if aggregateKey == "lungs" then
		return select(3, self:RefreshCombinedLungStage())
	end

	local children = ORGAN_AGGREGATE_CHILDREN[aggregateKey]
	if not children then return 0 end

	local maxStage = 0
	for _, key in ipairs(children) do
		maxStage = math.max(maxStage, self:GetOrganDamageStage(key))
	end

	self.OrganDamageStages = self.OrganDamageStages or {}
	self.OrganDamageStages[aggregateKey] = maxStage
	self:SetNW2Int("OrganDamage_" .. aggregateKey, maxStage)

	if maxStage <= 0 and self.CriticalOrganStates then
		self.CriticalOrganStates[aggregateKey] = nil
	end

	return maxStage
end

function meta:ClearCriticalOrganState(key)
	if not isstring(key) or key == "" then return end

	if self.CriticalOrganStates then
		self.CriticalOrganStates[key] = nil
	end

	self.OrganDamageStages = self.OrganDamageStages or {}
	self.OrganDamageStages[key] = 0
	self:SetNW2Int("OrganDamage_" .. key, 0)

	if key == "lung_left" then
		self:SetLungPneumothorax("left", false)
		self:RefreshAggregateOrganStage("lungs")
	elseif key == "lung_right" then
		self:SetLungPneumothorax("right", false)
		self:RefreshAggregateOrganStage("lungs")
	else
		local aggregateKey = SIDE_SPECIFIC_ORGAN_MIRRORS[key]
		if aggregateKey then
			self:RefreshAggregateOrganStage(aggregateKey)
		end
	end
end

function meta:StabilizeLimbArteries(mode)
	local targetTier = mode == "deep" and BLEED_WOUND_DEEP or 0
	local changed = 0

	for slot, info in pairs(LIMB_ARTERY_SLOTS) do
		local wound = self.BleedingWounds and self.BleedingWounds[slot]

		if wound and wound.tier == BLEED_WOUND_ARTERIAL then
			self:SetBleedingWoundTier(slot, targetTier, {
				arteryFlag = info.arteryFlag,
				criticalStateKey = info.criticalStateKey
			})
			changed = changed + 1
		else
			if self:GetNW2Bool(info.arteryFlag, false) then
				self:SetNW2Bool(info.arteryFlag, false)
				changed = changed + 1
			end

			self:ClearCriticalOrganState(info.criticalStateKey)
		end
	end

	self:RefreshLegacyArteryFlags()

	if not self:HasActiveArteryBleed() and self:GetNW2Int("ArterialBleedWounds", 0) <= 0 then
		self:SetNW2Bool("HardBleed", false)
	end

	return changed
end

function meta:ResetBleedingWounds()
	for slot in pairs(self.BleedingWounds or {}) do
		self:StopBleedingWoundVisual(slot)
	end
	self.BleedingWounds = {}
	self:SetNW2Int("MinorBleedWounds", 0)
	self:SetNW2Int("DeepBleedWounds", 0)
	self:SetNW2Int("ArterialBleedWounds", 0)
end

function meta:SyncBleedingWounds()
	local minor, deep, arterial = 0, 0, 0

	for _, wound in pairs(self.BleedingWounds or {}) do
		local tier = wound.tier or 0
		if tier == BLEED_WOUND_MINOR then
			minor = minor + 1
		elseif tier == BLEED_WOUND_DEEP then
			deep = deep + 1
		elseif tier == BLEED_WOUND_ARTERIAL then
			arterial = arterial + 1
		end
	end

	self:SetNW2Int("MinorBleedWounds", minor)
	self:SetNW2Int("DeepBleedWounds", deep)
	self:SetNW2Int("ArterialBleedWounds", arterial)

	return minor, deep, arterial
end

function meta:SetBleedingWoundTier(slot, tier, info)
	if not isstring(slot) or slot == "" then return 0, 0 end

	self.BleedingWounds = self.BleedingWounds or {}

	local existing = self.BleedingWounds[slot]
	local oldTier = existing and existing.tier or 0
	local woundInfo = existing or {}
	local arteryFlag = (info and info.arteryFlag) or woundInfo.arteryFlag
	local criticalStateKey = (info and info.criticalStateKey) or woundInfo.criticalStateKey
	local woundBone = (info and info.bone) or woundInfo.bone or (LIMB_ARTERY_SLOTS[slot] and LIMB_ARTERY_SLOTS[slot].bone)
	local oldBleedValue = BLEED_WOUND_BLEED_LEVELS[oldTier] or 0
	local newBleedValue = BLEED_WOUND_BLEED_LEVELS[tier] or 0

	if oldTier == BLEED_WOUND_ARTERIAL and arteryFlag then
		self:SetNW2Bool(arteryFlag, false)
	end
	if oldTier == BLEED_WOUND_ARTERIAL and criticalStateKey and tier < BLEED_WOUND_ARTERIAL then
		self:ClearCriticalOrganState(criticalStateKey)
	end

	if tier <= 0 then
		self.BleedingWounds[slot] = nil
	else
		woundInfo.tier = tier
		woundInfo.slot = slot
		woundInfo.arteryFlag = arteryFlag
		woundInfo.criticalStateKey = criticalStateKey
		woundInfo.bone = woundBone
		woundInfo.updatedAt = CurTime()
		self.BleedingWounds[slot] = woundInfo
	end

	if tier == BLEED_WOUND_ARTERIAL and arteryFlag then
		self:SetNW2Bool(arteryFlag, true)
	end

	local delta = newBleedValue - oldBleedValue
	if delta ~= 0 then
		self:SetNW2Float("BleedLevel", math.Clamp(self:GetNW2Float("BleedLevel", 0) + delta, 0, 3))
	end

	self:RefreshLegacyArteryFlags()
	self:SyncBleedingWounds()
	self:RefreshBleedingWoundVisual(slot)

	if tier == BLEED_WOUND_ARTERIAL then
		self:SetNW2Bool("HardBleed", true)
	elseif oldTier == BLEED_WOUND_ARTERIAL and not self:HasActiveArteryBleed() and self:GetNW2Int("ArterialBleedWounds", 0) <= 0 then
		self:SetNW2Bool("HardBleed", false)
	end

	return oldTier, tier
end

function meta:ApplyBleedingWound(slot, tier, info)
	local currentTier = (self.BleedingWounds and self.BleedingWounds[slot] and self.BleedingWounds[slot].tier) or 0
	if tier <= currentTier then
		return currentTier, currentTier
	end

	return self:SetBleedingWoundTier(slot, tier, info)
end

function meta:ClearBleedingWounds(maxTier)
	if not self.BleedingWounds then return 0 end

	local cleared = 0
	for slot, wound in pairs(table.Copy(self.BleedingWounds)) do
		local tier = wound.tier or 0
		if tier > 0 and tier <= maxTier then
			self:SetBleedingWoundTier(slot, 0)
			cleared = cleared + 1
		end
	end

	return cleared
end

function meta:GetBleedingWoundCounts()
	return self:GetNW2Int("MinorBleedWounds", 0), self:GetNW2Int("DeepBleedWounds", 0), self:GetNW2Int("ArterialBleedWounds", 0)
end

function meta:HasBleedingWoundsAtOrAbove(tier)
	local minor, deep, arterial = self:GetBleedingWoundCounts()

	if tier <= BLEED_WOUND_MINOR then
		return minor > 0 or deep > 0 or arterial > 0
	elseif tier == BLEED_WOUND_DEEP then
		return deep > 0 or arterial > 0
	end

	return arterial > 0
end

function meta:ClearMinorBleedingWounds()
	return self:ClearBleedingWounds(BLEED_WOUND_MINOR)
end

function meta:ClearDeepBleedingWounds()
	return self:ClearBleedingWounds(BLEED_WOUND_DEEP)
end

function meta:ClearAllBleedingWounds()
	return self:ClearBleedingWounds(BLEED_WOUND_ARTERIAL)
end

function meta:DowngradeLimbArterialWounds()
	if not self.BleedingWounds then return 0 end

	local downgraded = 0
	for slot, wound in pairs(table.Copy(self.BleedingWounds)) do
		if wound.tier == BLEED_WOUND_ARTERIAL and (slot == "left_arm" or slot == "right_arm" or slot == "left_leg" or slot == "right_leg") then
			self:SetBleedingWoundTier(slot, BLEED_WOUND_DEEP, {arteryFlag = wound.arteryFlag})
			downgraded = downgraded + 1
		end
	end

	return downgraded
end

function meta:CheckShock()
	local previous = self:GetNW2Int("ShockLevel", 0)
	local current = self:RefreshShockLevel()
	if current >= 2 and previous < 2 then
		self:ApplyConcussion(nil, 2.5, 1.2)
	end
end

function meta:ApplyCoordinationLoss(duration, severity, reason)
	if self:IsRoleWithoutOrgans() then return end
	duration = duration or 8
	severity = severity or 1
	if self:GetNW2Float("CoordinationEnd", 0) > CurTime() then
		local left = self:GetNW2Float("CoordinationEnd") - CurTime()
		duration = duration + left * 0.3
		severity = math.min(severity + self:GetNW2Float("CoordinationSeverity", 0) * 0.4, 2)
	end
	self:SetNW2Float("CoordinationEnd", CurTime() + duration)
	self:SetNW2Float("CoordinationSeverity", severity)
	MuR:GiveMessage2("coordination_loss", self)
end

function meta:ApplyUnconsciousness(duration)
	duration = duration or 4
	if self:GetNW2Bool("AdrenalineOverdosing", false) then return end

	local wasUnconscious = self:GetNW2Bool("IsUnconscious", false)
	if self:GetNW2Float("UnconsciousEnd", 0) > CurTime() then
		self:SetNW2Float("UnconsciousEnd", math.max(self:GetNW2Float("UnconsciousEnd"), CurTime() + duration * 0.7))
		if wasUnconscious then return end
	else
		if self:GetNW2Float("AdrenalineEnd", 0) > CurTime() then return end
		self:SetNW2Float("UnconsciousEnd", CurTime() + duration)
	end

	self:SetNW2Bool("IsUnconscious", true)
	self.UnconsciousStart = CurTime()
	self.IsRagStanding = false

	if isstring(self.LastVoiceLine) then
		if IsValid(self:GetRD()) then
			self:GetRD():StopSound(self.LastVoiceLine)
		end
		self:StopSound(self.LastVoiceLine)
		self.LastVoiceLine = nil
	end

	if not IsValid(self:GetRD()) then
		self:StartRagdolling(0, 0)
	end

	MuR:GiveMessage2("unconscious_state", self)
end

function meta:WakeUpFromUnconsciousness()
	if self:GetNW2Bool("AdrenalineOverdosing", false) then return end
	if not self:GetNW2Bool("IsUnconscious", false) then return end
	self:SetNW2Bool("IsUnconscious", false)
	self:SetNW2Float("UnconsciousEnd", 0)
	self:SetNW2Int("ConsciousLevel", math.max(self:GetNW2Int("ConsciousLevel", 0), 1))
	self.VoiceDelay = 0

	MuR:GiveMessage2("wake_up", self)
	MuR:PlaySoundOnClient("gasp/focus_gasp_0" .. math.random(1, 6) .. ".wav", self)
end

function meta:ResetCriticalOrgans()
	self.CriticalOrganStates = {}
	self.OrganDamageStages = {}
	self.ShockPassoutAt = nil

	local keys = SIDE_SPECIFIC_ORGAN_KEYS
	for _, key in ipairs(keys) do
		self:SetNW2Int("OrganDamage_" .. key, 0)
	end

	local arteryKeys = {}
	for _, key in ipairs(LEGACY_ARTERY_FLAGS) do
		arteryKeys[#arteryKeys + 1] = key
	end
	for _, key in ipairs(SIDE_SPECIFIC_ARTERY_FLAGS) do
		arteryKeys[#arteryKeys + 1] = key
	end
	for _, key in ipairs(arteryKeys) do
		self:SetNW2Bool(key, false)
	end

	self:SetNW2Bool("Pneumothorax", false)
	self:SetNW2Bool("PneumothoraxLeft", false)
	self:SetNW2Bool("PneumothoraxRight", false)

	self:SetNW2Int("ShockLevel", 0)
	self:SetNW2Int("ConsciousLevel", 0)
	self:ResetBleedingWounds()
end

function meta:SetOrganDamageStage(key, stage, force)
	stage = math.max(stage or 0, 0)
	self.OrganDamageStages = self.OrganDamageStages or {}

	local current = self.OrganDamageStages[key] or 0
	if stage > current or force then
		self.OrganDamageStages[key] = stage
		self:SetNW2Int("OrganDamage_" .. key, stage)
	end

	local mirrorKey = SIDE_SPECIFIC_ORGAN_MIRRORS[key]
	if mirrorKey then
		local mirrorStage = math.max(self:GetNW2Int("OrganDamage_" .. mirrorKey, 0), self.OrganDamageStages[key] or 0)
		self.OrganDamageStages[mirrorKey] = mirrorStage
		self:SetNW2Int("OrganDamage_" .. mirrorKey, mirrorStage)
	end

	return self.OrganDamageStages[key] or 0
end

function meta:GetOrganDamageStage(key)
	self.OrganDamageStages = self.OrganDamageStages or {}
	return self.OrganDamageStages[key] or 0
end

function meta:ApplyCriticalOrganState(key, data)
	if self:IsRoleWithoutOrgans() then return end

	local now = CurTime()
	local states = self.CriticalOrganStates or {}
	local state = states[key] or {
		key = key,
		startedAt = now
	}

	if data.deathIn then
		local deathAt = now + data.deathIn
		state.deathAt = state.deathAt and math.min(state.deathAt, deathAt) or deathAt
	end

	if data.passoutIn ~= nil then
		local passoutAt = now + data.passoutIn
		state.passoutAt = state.passoutAt and math.min(state.passoutAt, passoutAt) or passoutAt
	end

	state.interval = data.interval or state.interval or 1
	state.nextTick = math.min(state.nextTick or now, now)
	state.damageType = data.damageType or state.damageType or DMG_DIRECT
	state.severity = math.max(state.severity or 0, data.severity or 1)
	state.unconsciousFor = math.max(state.unconsciousFor or 0, data.unconsciousFor or 0)
	state.injuryStage = math.max(state.injuryStage or 0, data.injuryStage or 1)
	state.shockWeight = math.max(state.shockWeight or 0, data.shockWeight or 0.8)

	if data.stabilizable ~= nil then
		state.stabilizable = data.stabilizable
	elseif state.stabilizable == nil then
		state.stabilizable = true
	end

	if data.deathIn or data.passoutIn then
		state.stabilized = false
	end

	if IsValid(data.attacker) then state.attacker = data.attacker end
	if IsValid(data.inflictor) then state.inflictor = data.inflictor end

	states[key] = state
	self.CriticalOrganStates = states
	self:SetOrganDamageStage(key, state.injuryStage)

	return state
end

function meta:RefreshShockLevel()
	if not self:Alive() then return 0 end

	local hpFrac = self:Health() / math.max(self:GetMaxHealth(), 1)
	local bleedLevel = self:GetNW2Float("BleedLevel", 0)
	local toxin = self:GetNW2Float("ToxinLevel", 0)
	local load = 0

	if hpFrac < 0.85 then
		load = load + (0.85 - hpFrac) * 3.8
	end

	if self.GetHypovolemiaStage then
		load = load + self:GetHypovolemiaStage() * 1.25
	end

	if self:GetNW2Bool("HardBleed") then
		load = load + 2.2
	elseif bleedLevel > 0 then
		load = load + bleedLevel * 0.7
	end

	if self:GetNW2Float("InternalBleedEnd", 0) > CurTime() then
		load = load + 1.15
	end
	if self:GetNW2Bool("Pneumothorax") then
		load = load + 1.05
	end
	if self:GetNW2Bool("PelvisFracture") then
		load = load + 0.65
	end
	if self:GetNW2Bool("RibFracture") then
		load = load + 0.45
	end
	if self:GetNW2Bool("SpineBroken") then
		load = load + 1.2
	end
	if toxin > 0 then
		load = load + math.min(toxin / 3.5, 1.4)
	end

	local states = self.CriticalOrganStates or {}
	for key, state in pairs(states) do
		if key == "lung_left" or key == "lung_right" or key == "lungs" then
			continue
		end
		load = load + (state.shockWeight or 0.8) * math.max(state.injuryStage or 1, 1) * 0.55
	end

	local leftLungStage = self:GetOrganDamageStage("lung_left")
	local rightLungStage = self:GetOrganDamageStage("lung_right")
	local bilateralLungStage = self:GetOrganDamageStage("lungs")
	if bilateralLungStage > 0 then
		load = load + bilateralLungStage * 0.7
	elseif leftLungStage > 0 or rightLungStage > 0 then
		load = load + math.max(leftLungStage, rightLungStage) * 0.32
	end

	local stage = 0
	if load >= 5.4 then
		stage = 3
	elseif load >= 3.6 then
		stage = 2
	elseif load >= 1.9 then
		stage = 1
	end

	local lastStage = self:GetNW2Int("ShockLevel", 0)
	self:SetNW2Int("ShockLevel", stage)
	self:SetNW2Bool("ShockState", stage >= 2)

	if stage >= 2 and stage > lastStage then
		MuR:GiveMessage2("shock_state", self)
	end

	return stage
end

function meta:RefreshConsciousLevel()
	if not self:Alive() then return 0 end
	if self:GetNW2Bool("IsUnconscious", false) then
		self:SetNW2Int("ConsciousLevel", 3)
		return 3
	end

	local hpFrac = self:Health() / math.max(self:GetMaxHealth(), 1)
	local shockStage = self:GetNW2Int("ShockLevel", 0)
	local consciousnessLoad = shockStage * 1.15
	local concussionEnd = self:GetNW2Float("ConcussionEnd", 0)

	if hpFrac < 0.55 then
		consciousnessLoad = consciousnessLoad + (0.55 - hpFrac) * 4
	end

	if self.GetHypovolemiaStage then
		consciousnessLoad = consciousnessLoad + self:GetHypovolemiaStage() * 1.1
	end

	if self:GetNW2Bool("HardBleed") then
		consciousnessLoad = consciousnessLoad + 1.15
	else
		consciousnessLoad = consciousnessLoad + self:GetNW2Float("BleedLevel", 0) * 0.35
	end

	if concussionEnd > CurTime() then
		consciousnessLoad = consciousnessLoad + 0.8 + self:GetNW2Float("ConcussionIntensity", 0) * 0.45
	end

	if self:GetNW2Float("Stamina", 100) <= 20 then
		consciousnessLoad = consciousnessLoad + 0.7
	end

	consciousnessLoad = consciousnessLoad + math.min(self:GetNW2Float("ToxinLevel", 0) / 5, 1.2)
	consciousnessLoad = consciousnessLoad + self:GetOrganDamageStage("brain") * 1.35
	consciousnessLoad = consciousnessLoad + self:GetOrganDamageStage("carotid") * 0.9
	consciousnessLoad = consciousnessLoad + self:GetOrganDamageStage("heart") * 0.55

	local lungStage = math.max(self:GetOrganDamageStage("lungs"), getCombinedOrganStage(self, "lung_left", "lung_right"))
	consciousnessLoad = consciousnessLoad + math.max(lungStage - 1, 0) * 0.65

	local stage = 0
	if consciousnessLoad >= 4.6 then
		stage = 2
	elseif consciousnessLoad >= 2.3 then
		stage = 1
	end

	self:SetNW2Int("ConsciousLevel", stage)
	return stage
end

function meta:StabilizeCriticalOrgan(key)
	local state = self.CriticalOrganStates and self.CriticalOrganStates[key]
	if not state then return false end
	if state.stabilizable == false then return false end

	state.stabilized = true
	state.stabilizedAt = CurTime()
	state.deathAt = nil
	state.passoutAt = nil

	local lowered = math.max((state.injuryStage or 1) - 1, 1)
	state.injuryStage = lowered
	self:SetOrganDamageStage(key, lowered, true)

	return true
end

function meta:StabilizeAllCriticalOrgans()
	local count = 0
	for key in pairs(self.CriticalOrganStates or {}) do
		if self:StabilizeCriticalOrgan(key) then count = count + 1 end
	end

	return count
end

function meta:HasUnstabilizedLethalOrgan()
	for _, state in pairs(self.CriticalOrganStates or {}) do
		if state.deathAt and not state.stabilized then return true end
	end

	return false
end

function meta:DieFromCriticalOrgan(state)
	if not self:Alive() then return end

	local attacker = IsValid(state and state.attacker) and state.attacker or game.GetWorld()
	local inflictor = IsValid(state and state.inflictor) and state.inflictor or attacker
	local dmg = DamageInfo()
	dmg:SetAttacker(attacker)
	dmg:SetInflictor(inflictor)
	dmg:SetDamageType(state and state.damageType or DMG_DIRECT)
	dmg:SetDamage(math.max(self:Health() + 25, 50))
	dmg:SetDamagePosition(self:WorldSpaceCenter())

	self.MuR_TerminalDamage = true
	self:TakeDamageInfo(dmg)
	self.MuR_TerminalDamage = nil

	if self:Alive() then
		self:Kill()
	end
end

local function shortenTimeline(base, dmg, minValue, scale)
	return math.Clamp(base - dmg * scale, minValue, base)
end

local function processCriticalOrgans(ply)
	if not ply:Alive() then return end

	local states = ply.CriticalOrganStates
	if not states then return end

	local now = CurTime()
	local exertion = ply:GetVelocity():Length2D()

	for key, state in pairs(states) do
		if now < (state.nextTick or 0) then continue end
		state.nextTick = now + (state.interval or 1)

		if state.stabilized then
			if exertion > 190 and math.random() < 0.08 then
				state.stabilized = false
				state.deathAt = now + math.Rand(45, 90)
				MuR:GiveMessage2("wound_reopened", ply)
			else
				continue
			end
		end

		if key == "brain" then
			local stage = math.max(state.injuryStage or 1, 1)
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (4 + stage * 3), 0))
			ply:ApplyCoordinationLoss(3 + stage, 0.7 + stage * 0.2)

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 18, 8))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "neck" then
			local stage = math.max(state.injuryStage or 1, 1)
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (3 + stage * 2), 0))
			ply:ApplyCoordinationLoss(2 + stage, 0.35 + stage * 0.2)
			if math.random() < (0.05 + stage * 0.05) then
				ply:ApplyConcussion(nil, 2, 0.5)
			end

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 12, 6))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "heart" then
			local stage = math.max(state.injuryStage or 1, 1)
			if stage >= 2 then
				ply:SetNW2Bool("HardBleed", true)
			end
			if stage >= 2 or math.random() < 0.45 then
				ply:DamagePlayerSystem("blood")
			end
			ply:SetNW2Float("Stamina", 0)
			ply:ApplyCoordinationLoss(2 + stage, 0.45 + stage * 0.2)

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 14, 8))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "carotid" then
			local stage = math.max(state.injuryStage or 2, 2)
			ply:SetNW2Bool("HardBleed", true)
			ply:DamagePlayerSystem("blood")
			if stage >= 3 or math.random() < 0.45 then
				ply:DamagePlayerSystem("blood")
			end
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (10 + stage * 4), 0))

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 16, 8))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "brachial" or key == "brachial_left" or key == "brachial_right" then
			local stage = math.max(state.injuryStage or 1, 1)
			if stage >= 2 or math.random() < 0.55 then
				ply:DamagePlayerSystem("blood")
			end
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (3 + stage * 2), 0))

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 10, 6))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "femoral" or key == "femoral_left" or key == "femoral_right" then
			local stage = math.max(state.injuryStage or 2, 2)
			ply:SetNW2Bool("HardBleed", true)
			ply:DamagePlayerSystem("blood")
			if stage >= 3 or math.random() < 0.35 then
				ply:DamagePlayerSystem("blood")
			end
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (8 + stage * 2), 0))

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 14, 8))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "liver" then
			local stage = math.max(state.injuryStage or 1, 1)
			if math.random() < (0.2 + stage * 0.18) then
				ply:DamagePlayerSystem("blood")
			end
			ply:SetNW2Float("ToxinLevel", math.min(ply:GetNW2Float("ToxinLevel", 0) + (0.08 + stage * 0.08), 10))
			ply:ApplyCoordinationLoss(1 + stage, 0.2 + stage * 0.12)

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 16, 8))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "lung_left" or key == "lung_right" then
			local side = key == "lung_left" and "left" or "right"
			local stage = math.max(state.injuryStage or 1, 1)
			local _, _, combinedStage = ply:RefreshCombinedLungStage()
			ply:SetLungPneumothorax(side, true)

			if combinedStage > 0 and states.lungs then
				continue
			end

			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (1.5 + stage * 1.6), 0))

			if stage >= 2 and math.random() < (0.08 + stage * 0.07) then
				ply:DamagePlayerSystem("blood")
			end

			if stage >= 2 then
				ply:ApplyCoordinationLoss(1.5 + stage, 0.18 + stage * 0.08)
			end

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 10, 6))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		elseif key == "lungs" then
			local leftStage, rightStage, combinedStage = ply:RefreshCombinedLungStage()
			local hits = 0
			if leftStage > 0 then hits = hits + 1 end
			if rightStage > 0 then hits = hits + 1 end
			local stage = math.max(state.injuryStage or combinedStage or hits, combinedStage, hits, 1)
			ply:RefreshPneumothoraxState()
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (3 + hits * 2 + stage * 2), 0))

			if stage >= 2 or hits >= 2 then
				if math.random() < (0.15 + stage * 0.15) then
					ply:DamagePlayerSystem("blood")
				end
				ply:ApplyCoordinationLoss(2 + stage, 0.3 + stage * 0.15)
			end

			if state.passoutAt and now >= state.passoutAt and not state.passoutApplied then
				state.passoutApplied = true
				ply:ApplyUnconsciousness(math.max(state.unconsciousFor or 12, 8))
			end

			if state.deathAt and now >= state.deathAt then
				ply:DieFromCriticalOrgan(state)
				return
			end
		end
	end
end

local function processBodyState(ply)
	if not ply:Alive() then return end
	if (ply.NextBodyStateTick or 0) > CurTime() then return end
	ply.NextBodyStateTick = CurTime() + 1

	local shockStage = ply:RefreshShockLevel()
	local consciousStage = ply:RefreshConsciousLevel()

	if shockStage == 1 then
		ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - 2, 0))
		if math.random() < 0.25 then
			ply:ApplyCoordinationLoss(1.5, 0.18)
		end
	elseif shockStage == 2 then
		ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - 4, 0))
		ply:ApplyCoordinationLoss(2.5, 0.32)
	elseif shockStage >= 3 then
		ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - 7, 0))
		ply:ApplyCoordinationLoss(4, 0.55)

		if not ply:GetNW2Bool("IsUnconscious", false) then
			ply.ShockPassoutAt = ply.ShockPassoutAt or (CurTime() + math.Rand(20, 35))
			if CurTime() >= ply.ShockPassoutAt then
				ply:ApplyUnconsciousness(math.Rand(5, 9))
				ply.ShockPassoutAt = CurTime() + math.Rand(30, 45)
			end
		end
	else
		ply.ShockPassoutAt = nil
	end

	if consciousStage == 1 then
		if math.random() < 0.2 then
			ply:ApplyCoordinationLoss(1.5, 0.2)
		end
	elseif consciousStage >= 2 and not ply:GetNW2Bool("IsUnconscious", false) then
		ply:ApplyCoordinationLoss(2.5, 0.35)
	end
end

function meta:CheckForceProneOnly()
	local hp = self:Health()
	local maxhp = self:GetMaxHealth()
	local hpFrac = hp / maxhp
	local forceProneOnly = false
	if self.IsDying and self:IsDying() then
		forceProneOnly = true
	elseif self:IsRestrained() then
		forceProneOnly = true
	elseif self:GetNW2Bool("HardBleed") and hpFrac <= 0.4 then
		forceProneOnly = true
	elseif self:GetNW2Bool("PelvisFracture") then
		forceProneOnly = true
	elseif self:GetNW2Float("BleedLevel") >= 3 and hpFrac <= 0.3 then
		forceProneOnly = true
	elseif self:GetNW2Bool("LegBroken") and hpFrac <= 0.25 then
		forceProneOnly = true
	elseif self:GetNW2Bool("RibFracture") and hpFrac <= 0.2 then
		forceProneOnly = true
	elseif CurTime() < self:GetNW2Float("UnconsciousEnd", 0) then
		forceProneOnly = true
	elseif self:GetNW2Bool("SpineBroken") then
		forceProneOnly = true
	end
	self:SetNW2Bool("ForceProneOnly", forceProneOnly)
end

function meta:MakeBloodEffect(bone, delay, times)
	if not bone then return end
	if not delay then delay = 0 end
	if not times then times = 1 end
	local tar = self
	if IsValid(self:GetRD()) then
		tar = self:GetRD()
	end
	local name = bone .. "Hit" .. self:EntIndex()
	timer.Create(name, delay, times, function()
		if !IsValid(tar) or tar:IsPlayer() and !tar:Alive() then
			timer.Remove(name)
			return
		end
		local pos = MuR:BoneData(tar, bone)
		if math.random(1,3) == 1 then
			local normal = VectorRand(-1,1)
			local radius = math.random(8,32)
			local effectdata = EffectData()
			effectdata:SetOrigin(pos)
			effectdata:SetNormal(normal)
			effectdata:SetMagnitude(1)
			effectdata:SetRadius(radius)
			effectdata:SetEntity(self)
			if shouldUseNetworkedPlayerBlood(tar) or shouldUseStandaloneBlood(tar) then
				broadcastLiveBloodSpray(tar, bone, math.max(radius / 15, 1.1), radius + 4)
			else
				util.Effect("mur_blood_splatter_effect", effectdata, true, true )
			end
		end
		if math.random(1,4) == 1 then
			MuR:CreateBloodPool(tar, tar:LookupBone(bone), 1)
			tar:EmitSound("murdered/player/drip_" .. math.random(1, 5) .. ".wav", 40, math.random(80, 120))
		end
	end)
end

function meta:ClearBloodEffects()
	local tar = self
	if IsValid(self:GetRD()) then
		tar = self:GetRD()
	end

	for i = 0, tar:GetBoneCount() - 1 do
		local boneName = tar:GetBoneName(i)
		if boneName then
			local timerName = boneName .. "Hit" .. self:EntIndex()
			if timer.Exists(timerName) then
				timer.Remove(timerName)
			end
		end
	end

	if tar.GetBloodTrails then
		tar:GetBloodTrails("remove")
	end
end

function meta:DamagePlayerSystem(type, heal, dmgInfo)
	if heal then
		if type == "bone" then
			self:SetNW2Bool("LegBroken", false)
		elseif type == "blood" then
			self:SetNW2Float("BleedLevel", math.max(self:GetNW2Float("BleedLevel") - 1, 0))
		elseif type == "hard_blood" then
			self:SetNW2Bool("HardBleed", false)
		end
	else
		if self:IsRoleWithoutOrgans() then return end
		if type == "bone" and not self:GetNW2Bool("LegBroken") then
			self:SetNW2Bool("LegBroken", true)
			self:EmitSound("murdered/player/legbreak.wav", 60, math.random(80, 120))
		elseif type == "blood" then
			local damageAmount = dmgInfo and dmgInfo:GetDamage() or 10
			local bleedIncrease = 0.6

			if damageAmount >= 50 then
				bleedIncrease = 1.2
			elseif damageAmount >= 30 then
				bleedIncrease = 0.9
			end

			if dmgInfo then
				local damageType = dmgInfo:GetDamageType()
				if bit.band(damageType, DMG_SLASH) ~= 0 or bit.band(damageType, DMG_BULLET) ~= 0 then
					bleedIncrease = bleedIncrease * 1.2
				elseif bit.band(damageType, DMG_CLUB) ~= 0 then
					bleedIncrease = bleedIncrease * 0.5
				elseif bit.band(damageType, DMG_BLAST) ~= 0 then
					bleedIncrease = bleedIncrease * 1.2
				end
			end

			local armorReduction = 0
			if dmgInfo and self.GetArmorDamageReductionByHitgroup then
				local bone = self:GetNearestBoneFromPos(dmgInfo:GetDamagePosition(), dmgInfo:GetDamageForce())
				local hitgroup = HITGROUP_GENERIC
				if bone then
					local boneToHitgroup = {
						["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
						["ValveBiped.Bip01_Neck1"] = HITGROUP_HEAD,
						["ValveBiped.Bip01_Spine"] = HITGROUP_STOMACH,
						["ValveBiped.Bip01_Spine1"] = HITGROUP_CHEST,
						["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
						["ValveBiped.Bip01_Spine4"] = HITGROUP_CHEST,
					}
					hitgroup = boneToHitgroup[bone] or HITGROUP_GENERIC
				end
				armorReduction, _ = self:GetArmorDamageReductionByHitgroup(hitgroup, dmgInfo)
			end
			bleedIncrease = bleedIncrease * (1 - (armorReduction * 0.5))

			local newLevel = self:GetNW2Float("BleedLevel") + bleedIncrease
			self:SetNW2Float("BleedLevel", math.min(newLevel, 3))

			if newLevel >= 3 then
				self:SetNW2Bool("HardBleed", true)
			end
		elseif type == "hard_blood" then
			self:SetNW2Bool("HardBleed", true)
		end
	end

	timer.Simple(0.1, function()
		if IsValid(self) then
			self:UpdateBloodMovementSpeed()
			self:CheckForceProneOnly()
			self:CheckRandomUnconsciousness()
		end
	end)
end

function meta:UpdateBloodMovementSpeed()
	if not self:Alive() then return end

	local bleedLevel = self:GetNW2Float("BleedLevel")
	local hardBleed = self:GetNW2Bool("HardBleed")
	local legBroken = self:GetNW2Bool("LegBroken")
	local footFracture = self:GetNW2Bool("FootFracture")
	local pelvisFracture = self:GetNW2Bool("PelvisFracture")
	local ribFracture = self:GetNW2Bool("RibFracture")

	local baseSlowWalk = 60
	local baseWalk = self.SpawnDataSpeed[1]
	local baseRun = self.SpawnDataSpeed[2]

	local speedMultiplier = 1

	if hardBleed then
		speedMultiplier = 0.4
	elseif bleedLevel >= 3 then
		speedMultiplier = 0.6
	elseif bleedLevel == 2 then
		speedMultiplier = 0.75
	elseif bleedLevel == 1 then
		speedMultiplier = 0.9
	end

	if legBroken then
		speedMultiplier = speedMultiplier * 0.5
	end

	if footFracture then
		speedMultiplier = speedMultiplier * 0.75
	end

	if pelvisFracture then
		speedMultiplier = speedMultiplier * 0.35
	end

	if ribFracture then
		speedMultiplier = speedMultiplier * 0.9
	end

	self:SetSlowWalkSpeed(baseSlowWalk * speedMultiplier)
	self:SetWalkSpeed(baseWalk * speedMultiplier)
	self:SetRunSpeed(baseRun * speedMultiplier)
end

function meta:CheckRandomUnconsciousness()
	if not self:Alive() then return end
	if self:GetNW2Bool("IsUnconscious", false) then return end

	local hp = self:Health()
	local maxhp = self:GetMaxHealth()
	local hpFrac = hp / maxhp
	local bleedLevel = self:GetNW2Float("BleedLevel")
	local hardBleed = self:GetNW2Bool("HardBleed")
	local shockStage = self:GetNW2Int("ShockLevel", 0)
	local consciousStage = self:GetNW2Int("ConsciousLevel", 0)

	local unconsciousChance = 0

	if hpFrac <= 0.1 then
		unconsciousChance = unconsciousChance + 0.003
	elseif hpFrac <= 0.18 then
		unconsciousChance = unconsciousChance + 0.0015
	elseif hpFrac <= 0.25 then
		unconsciousChance = unconsciousChance + 0.00075
	end

	if hardBleed then
		unconsciousChance = unconsciousChance + 0.0025
	elseif bleedLevel >= 3 then
		unconsciousChance = unconsciousChance + 0.0012
	end

	if shockStage >= 3 then
		unconsciousChance = unconsciousChance + 0.0015 * shockStage
	end

	if consciousStage == 1 then
		unconsciousChance = unconsciousChance + 0.0006
	elseif consciousStage >= 2 then
		unconsciousChance = unconsciousChance + 0.0015
	end

	if unconsciousChance > 0 and math.random() < unconsciousChance then
		local duration = math.random(2, 4) + (1 - hpFrac) * 2
		self:ApplyUnconsciousness(duration)
		MuR:GiveMessage2("random_unconscious", self)
	end
end

function MuR.IsSpectator(ply)
	return IsValid(ply) and ply:IsPlayer() and not ply:Alive()
end

hook.Add("EntityTakeDamage", "MuR_DamageSystem", function(ent, dmg)
	local att = dmg:GetAttacker()

	if ent.Owner then
		ent = ent.Owner
	end

	if MuR.IsSpectator(ent) then return end

	if ent.MuR_TerminalDamage then return end

	if ent:IsPlayer() and !ent:IsRoleWithoutOrgans() then
		local force = dmg:GetDamageForce()
		if force:IsZero() and att:IsPlayer() then
			force = att:GetAimVector()*100
		end
		local bone1 = ent:GetNearestBoneFromPos(dmg:GetDamagePosition(), force)
		if IsValid(ent:GetRD()) then
			bone1 = ent:GetRD():GetNearestBoneFromPos(dmg:GetDamagePosition(), force)
		end
		ent.LastDamagedBone = bone1

		local buldmg = dmg:IsBulletDamage()
		local dm = dmg:GetDamage()
		local kndmg = dmg:GetDamageType() == DMG_SLASH

		if (buldmg or kndmg) and (bone1 == "ValveBiped.Bip01_Spine" or bone1 == "ValveBiped.Bip01_Spine2") then
			local base = dmg:GetDamage()
			if base >= 20 then
				if not ent:GetNW2Bool("RibFracture") then
					ent:SetNW2Bool("RibFracture", true)
					MuR:GiveMessage2("rib_hit", ent)
				end
			end
		end

		if (bone1 == "ValveBiped.Bip01_L_Calf" or bone1 == "ValveBiped.Bip01_R_Calf") and math.random(1, 2) == 1 and dm > 10 then
			MuR:GiveMessage2("leg_hit", ent)
			ent:DamagePlayerSystem("bone")
		end

		if canCauseBluntConcussion(dmg, bone1) then
			ent:ApplyConcussion(dmg, 2, 1)
			ent:ApplyCoordinationLoss(2.5, 0.9, "brain_blunt")
			if dm >= 50 then
				ent:ApplyUnconsciousness(4 + dm/4)
			end
		end

		if bit.band(dmg:GetDamageType(), DMG_CLUB) ~= 0 and not isHeadOrNeckBone(bone1) and dm > 25 then
			ent:ApplyCoordinationLoss(6, 0.8)
		end

		if bit.band(dmg:GetDamageType(), DMG_BLAST) ~= 0 and isHeadOrNeckBone(bone1) then
			if ent:GetNW2Float("TinnitusEnd",0) < CurTime() then
				ent:SetNW2Float("TinnitusEnd", CurTime()+6)
				MuR:GiveMessage2("tinnitus_hit", ent)
			end
			ent:ApplyCoordinationLoss(10, 1.2)
			if dm >= 40 then
				ent:ApplyUnconsciousness(5 + dm/25)
			end
		end

		if dmg:GetDamageType()==DMG_FALL and dm >= 25 then
			ent:ApplyCoordinationLoss(4, 0.6)
			if dm >= 50 then
				ent:ApplyUnconsciousness(3)
			end
		end

		ent:CheckShock()
	end
end)

hook.Add("EntityTakeDamage", "MuR.RagdollDamage", function(ent, dmg)
	if ent.MuR_TerminalDamage or (IsValid(ent.Owner) and ent.Owner.MuR_TerminalDamage) then return end

	local rdOwner = IsValid(ent.Owner) and ent.Owner or nil
	if not rdOwner and ent:IsPlayer() then rdOwner = ent end
	if MuR.IsSpectator(rdOwner) then return end

	local dt = dmg:GetDamageType()
	local att = dmg:GetAttacker()
	if IsValid(att) and IsValid(att.MindController) then
		att = att.MindController
	end

	if ent.isRDRag then
		if IsValid(rdOwner) and rdOwner:IsPlayer() and (rdOwner:IsDying() or rdOwner:IsRestrained()) and IsValid(att) and att.IsPMCEnemy then
			dmg:SetDamage(0)
		else
			ent:GiveDamageOnRag(dmg)
		end
	end

	if ent:IsPlayer() and IsValid(ent:GetRD()) then
		ent:TimeGetUpChange(dmg:GetDamage() / 8)
	end

	if ent:IsPlayer() and ent:Alive() then
		local dm = dmg:GetDamage()

		if dm >= 10 and ent:Armor() <= 0 and not IsValid(ent:GetRD()) then
			local maxhp = math.max(ent:GetMaxHealth(), 1)
			local frac = dm / maxhp
			local severity = frac * 1.35
			local dtsev = dmg:GetDamageType()
			local isBullet = dmg:IsBulletDamage()
			local isSlash = bit.band(dtsev, DMG_SLASH) ~= 0
			local isClub = bit.band(dtsev, DMG_CLUB) ~= 0
			local isBlast = bit.band(dtsev, DMG_BLAST) ~= 0
			local isCrush = bit.band(dtsev, DMG_CRUSH) ~= 0

			if ent:GetNW2Bool("HardBleed") then severity = severity + 0.08 end
			local bl = ent:GetNW2Float("BleedLevel", 0)
			if bl >= 3 then
				severity = severity + 0.08
			elseif bl >= 2 then
				severity = severity + 0.04
			elseif bl >= 1 then
				severity = severity + 0.02
			end
			if ent:GetNW2Bool("LegBroken") then severity = severity + 0.04 end

			if isBullet then
				severity = severity + math.Clamp((dm - 12) / 120, 0, 0.08)
			end
			if isSlash then severity = severity + 0.08 end
			if isClub then severity = severity + 0.14 end
			if isBlast then severity = severity + 0.2 end
			if isCrush or dmg:IsFallDamage() then severity = severity + 0.08 end

			local hp = ent:Health()
			if hp <= maxhp * 0.5 then severity = severity + 0.03 end
			if hp <= maxhp * 0.3 then severity = severity + 0.06 end
			if hp <= maxhp * 0.15 then severity = severity + 0.1 end
			if CurTime() < ent:GetNW2Float("ConcussionEnd", 0) then severity = severity + 0.05 end
			if CurTime() < ent:GetNW2Float("CoordinationEnd", 0) then severity = severity + 0.04 end
			if CurTime() < ent:GetNW2Float("UnconsciousEnd", 0) then severity = severity + 0.08 end

			local canBulletRagdoll = not isBullet
				or dm >= 18
				or severity >= 0.5
				or hp <= maxhp * 0.3
				or ent:GetNW2Bool("HardBleed")

			if canBulletRagdoll and severity >= 0.32 and CurTime() >= (ent.NextDamageRagdollRoll or 0) then
				ent.NextDamageRagdollRoll = CurTime() + 0.35

				if MuR.Gamemode == 18 and ent:Health() > 30 then

				else
					local ragdollChance = math.Clamp((severity - 0.32) * 0.42, 0.08, 0.4)
					if isSlash then
						ragdollChance = math.min(ragdollChance + 0.04, 0.45)
					end
					if isClub then
						ragdollChance = math.min(ragdollChance + 0.08, 0.5)
					end
					if isBlast then
						ragdollChance = math.min(ragdollChance + 0.12, 0.6)
					end
					if isBullet and dm >= 30 then
						ragdollChance = math.min(ragdollChance + 0.04, 0.45)
					end
					if hp <= maxhp * 0.2 then
						ragdollChance = math.min(ragdollChance + 0.05, 0.55)
					end

					if math.random() < ragdollChance then
						ent:StartRagdolling(dm / 30, dm / 6, dmg)
					end
				end
			end
		end

		if dm > 1 then
			if dt == DMG_CLUB or not IsValid(att) or att:IsWorld() or string.match(att:GetClass(), "prop_") then
				ent:PlayVoiceLine("death_blunt")
			else
				ent:PlayVoiceLine("death_default")
			end
		end
	end
end)

hook.Add("PlayerPostThink", "MuR.UnconsciousCheck", function(ply)
	if ply:GetNW2Bool("IsUnconscious", false) then
		if not ply:Alive() then
			ply:SetNW2Bool("IsUnconscious", false)
			ply:SetNW2Float("UnconsciousEnd", 0)
		elseif CurTime() >= ply:GetNW2Float("UnconsciousEnd", 0) then
			ply:WakeUpFromUnconsciousness()
		else
			ply.IsRagStanding = false
		end
	elseif ply:Alive() and (ply:Health() <= ply:GetMaxHealth() * 0.25 or ply:GetNW2Bool("HardBleed") or ply:GetNW2Float("BleedLevel") >= 3 or ply:GetNW2Int("ShockLevel", 0) >= 3 or ply:GetNW2Int("ConsciousLevel", 0) >= 2) then
		if not ply.NextUnconsciousCheck or ply.NextUnconsciousCheck <= CurTime() then
			ply:CheckRandomUnconsciousness()
			ply.NextUnconsciousCheck = CurTime() + 0.75
		end
	end
end)

hook.Add("PlayerCanHearPlayersVoice", "MuR.UnconsciousVoice", function(listener, talker)
	if talker:GetNW2Bool("IsUnconscious", false) then
		return false
	end
end)

hook.Add("PlayerDeath", "MuR.ClearUnconsciousState", function(victim)
	victim:SetNW2Bool("IsUnconscious", false)
	victim:SetNW2Float("UnconsciousEnd", 0)
	victim:SetNW2Float("ConcussionEnd", 0)
	victim:SetNW2Float("CoordinationEnd", 0)
	victim:SetNW2Int("ShockLevel", 0)
	victim:SetNW2Int("ConsciousLevel", 0)
end)

hook.Add("MuR.HandleCustomHitgroup", "MuR_OrganDamage", function(victim, owner, organ, dmginfo)
	if not IsValid(victim) or not IsValid(owner) or not owner:IsPlayer() or (not victim:IsPlayer() and not victim:IsRagdoll()) then return end

	local ply = victim:IsPlayer() and victim or (victim:IsRagdoll() and victim.Owner)
	if IsValid(ply) and MuR.Gamemode == 21 and ply:GetNW2String("Class") == "Tony" then return end
	local damageType = dmginfo:GetDamageType()
	local isBulletOrSlash = dmginfo:IsBulletDamage() or damageType == DMG_SLASH
	local isBlunt = bit.band(damageType, DMG_CLUB) ~= 0
	local armorReduction = 0

	if IsValid(ply) then
		if ply.GetArmorDamageReduction then
			armorReduction = ply:GetArmorDamageReduction(organ, dmginfo) or 0
		end

		if armorReduction <= 0 and ply.GetArmorDamageReductionByHitgroup then
			local bone = victim:GetNearestBoneFromPos(dmginfo:GetDamagePosition(), dmginfo:GetDamageForce())
			local hitgroup = HITGROUP_GENERIC
			local boneToHitgroup = {
				["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
				["ValveBiped.Bip01_Neck1"] = HITGROUP_HEAD,
				["ValveBiped.Bip01_Spine"] = HITGROUP_STOMACH,
				["ValveBiped.Bip01_Spine1"] = HITGROUP_CHEST,
				["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
				["ValveBiped.Bip01_Spine4"] = HITGROUP_CHEST,
			}
			hitgroup = boneToHitgroup[bone] or HITGROUP_GENERIC
			armorReduction = select(1, ply:GetArmorDamageReductionByHitgroup(hitgroup, dmginfo)) or 0
		end
	end

	if organ == "Brain" and isBlunt and armorReduction > 0 then
		return
	end

	if isBulletOrSlash then
		if armorReduction >= 0.8 then
			return
		elseif armorReduction > 0 and armorReduction < 0.5 then
			if math.random() > (1 - armorReduction * 2) then
				return
			end
		end
		if organ == "Brain" then
			local rawDamage = dmginfo:GetDamage()
			local brainStage = rawDamage >= 34 and 3 or (rawDamage >= 18 and 2 or 1)
			MuR:GiveMessage2("brain_hit", owner)
			dmginfo:ScaleDamage(1.05 + brainStage * 0.1)

			owner:ApplyConcussion(dmginfo, 6 + brainStage * 4, 0.9 + brainStage * 0.35)
			owner:ApplyCoordinationLoss(8 + brainStage * 4, 0.9 + brainStage * 0.3, "brain_blunt")

			local deathIn
			if brainStage >= 3 then
				deathIn = shortenTimeline(20, rawDamage, 8, 0.12)
			elseif brainStage == 2 then
				deathIn = shortenTimeline(70, rawDamage, 40, 0.5)
			end

			local state = owner:ApplyCriticalOrganState("brain", {
				attacker = dmginfo:GetAttacker(),
				inflictor = dmginfo:GetInflictor(),
				damageType = DMG_DIRECT,
				deathIn = deathIn,
				passoutIn = brainStage >= 2 and 0 or shortenTimeline(16, rawDamage, 6, 0.08),
				unconsciousFor = 10 + brainStage * 6,
				interval = 1.5,
				injuryStage = brainStage,
				shockWeight = 1.2,
				stabilizable = brainStage < 3
			})

			if not IsValid(owner:GetRD()) then
				owner:StartRagdolling(1, dmginfo:GetDamage() / 4)
			end

			if brainStage >= 2 then
				owner:ApplyUnconsciousness(10 + brainStage * 6)
				if owner.EnterDying then owner:EnterDying(dmginfo) end
			else
				owner:ApplyUnconsciousness(math.Rand(2.5, 5))
			end

		elseif organ == "Neck" then
			local neckStage = dmginfo:GetDamage() >= 26 and 3 or (dmginfo:GetDamage() >= 14 and 2 or 1)
			MuR:GiveMessage2("neck_hit", owner)
			dmginfo:ScaleDamage(1.05 + neckStage * 0.12)
			owner:ApplyConcussion(dmginfo, 2 + neckStage * 2, 0.5 + neckStage * 0.2)
			owner:ApplyCoordinationLoss(3 + neckStage * 2, 0.3 + neckStage * 0.2)
			local state = owner:ApplyCriticalOrganState("neck", {
				attacker = dmginfo:GetAttacker(),
				inflictor = dmginfo:GetInflictor(),
				damageType = DMG_DIRECT,
				deathIn = neckStage >= 2 and shortenTimeline(95 - neckStage * 10, dmginfo:GetDamage(), 34 - neckStage * 3, 0.12 + neckStage * 0.02) or nil,
				passoutIn = neckStage >= 2 and shortenTimeline(45 - neckStage * 4, dmginfo:GetDamage(), 14 - neckStage * 2, 0.08 + neckStage * 0.02) or nil,
				unconsciousFor = 8 + neckStage * 3,
				interval = 2.5,
				injuryStage = neckStage,
				shockWeight = 0.7
			})
			if victim.MakeBloodEffect then victim:MakeBloodEffect("ValveBiped.Bip01_Neck1", 0.1, 4) end
			if state and state.passoutAt and state.passoutAt <= CurTime() + 0.1 then
				owner:ApplyUnconsciousness(12)
			end

		elseif organ == "Heart" then
			local heartStage = dmginfo:GetDamage() >= 30 and 3 or (dmginfo:GetDamage() >= 16 and 2 or 1)
			MuR:GiveMessage2("heart_hit", owner)
			if heartStage >= 2 then
				MuR:GiveMessage2("artery_heart_hit", owner)
				owner:TriggerArtery("Heart")
			end
			dmginfo:ScaleDamage(1.1 + heartStage * 0.1)
			owner:ApplyCriticalOrganState("heart", {
				attacker = dmginfo:GetAttacker(),
				inflictor = dmginfo:GetInflictor(),
				damageType = DMG_DIRECT,
				deathIn = heartStage >= 2 and shortenTimeline(42 - heartStage * 8, dmginfo:GetDamage(), 14 - heartStage, 0.08 + heartStage * 0.02) or nil,
				passoutIn = heartStage >= 2 and shortenTimeline(18 - heartStage * 2, dmginfo:GetDamage(), 5, 0.04 + heartStage * 0.02) or nil,
				unconsciousFor = 8 + heartStage * 4,
				interval = 2,
				injuryStage = heartStage,
				shockWeight = 1.35
			})
			if victim.MakeBloodEffect then victim:MakeBloodEffect("ValveBiped.Bip01_Spine4", 0.1, 10) end
			if heartStage >= 2 then
				owner:EmitSound("murdered/player/heartbeat_stop.wav", 60, 100)
			end

		elseif organ == "Right Lung" or organ == "Left Lung" then
			local organInfo = getOrganStateInfo(organ)
			local lungStage = dmginfo:GetDamage() >= 22 and 2 or 1
			MuR:GiveMessage2("lung_hit", owner)
			owner:ApplyInternalBleed(10 + lungStage * 6, 5 - lungStage)
			owner:ApplyCoordinationLoss(8 + lungStage * 4, 0.55 + lungStage * 0.2)
			if organInfo and organInfo.side then
				owner:SetLungPneumothorax(organInfo.side, true)
			end
			local state = owner:ApplyCriticalOrganState(organInfo and organInfo.stateKey or "lungs", {
				attacker = dmginfo:GetAttacker(),
				inflictor = dmginfo:GetInflictor(),
				damageType = DMG_DIRECT,
				interval = 1,
				injuryStage = lungStage,
				shockWeight = 0.9
			})
			if state then
				state.injuryStage = math.max(state.injuryStage or 1, lungStage)
				local leftStage, rightStage, totalStage = owner:RefreshCombinedLungStage()

				if leftStage > 0 and rightStage > 0 then
					local now = CurTime()
					local fatalStage = math.max(totalStage, dmginfo:GetDamage() >= 26 and 3 or 2)
					local combinedState = owner:ApplyCriticalOrganState("lungs", {
						attacker = dmginfo:GetAttacker(),
						inflictor = dmginfo:GetInflictor(),
						damageType = DMG_DIRECT,
						deathIn = fatalStage >= 3 and shortenTimeline(60, dmginfo:GetDamage(), 22, 0.12) or nil,
						passoutIn = shortenTimeline(42 - fatalStage * 6, dmginfo:GetDamage(), 12 - fatalStage, 0.06 + fatalStage * 0.02),
						unconsciousFor = 10 + fatalStage * 2,
						interval = 1,
						injuryStage = fatalStage,
						shockWeight = 1.15
					})
					if combinedState then
						combinedState.hits = 2
					end
					owner.OrganDamageStages = owner.OrganDamageStages or {}
					owner.OrganDamageStages.lungs = fatalStage
					owner:SetNW2Int("OrganDamage_lungs", fatalStage)
				else
					if owner.CriticalOrganStates then
						owner.CriticalOrganStates.lungs = nil
					end
					owner.OrganDamageStages = owner.OrganDamageStages or {}
					owner.OrganDamageStages.lungs = 0
					owner:SetNW2Int("OrganDamage_lungs", 0)
				end
			end
			if math.random(1, 2) == 1 then
				owner:EmitSound("murdered/player/gasp_0" .. math.random(1, 3) .. ".wav", 60, 100)
			end

		elseif organ == "Spine" then
			MuR:GiveMessage2("spine_hit", owner)
			dmginfo:ScaleDamage(1.5)
			owner:SetNW2Bool("SpineBroken", true)
			owner:StartRagdolling(0, dmginfo:GetDamage())
			owner:ApplyCoordinationLoss(20, 1.8)
			owner:EmitSound("murdered/player/bone_break.wav", 60, 100)

		elseif organ == "Liver" then
			local liverStage = dmginfo:GetDamage() >= 30 and 3 or (dmginfo:GetDamage() >= 15 and 2 or 1)
			MuR:GiveMessage2("liver_hit", owner)
			owner:ApplyInternalBleed(8 + liverStage * 6, math.max(2, 6 - liverStage))
			owner:ApplyCriticalOrganState("liver", {
				attacker = dmginfo:GetAttacker(),
				inflictor = dmginfo:GetInflictor(),
				damageType = DMG_DIRECT,
				deathIn = liverStage >= 2 and shortenTimeline(180 - liverStage * 25, dmginfo:GetDamage(), 60 - liverStage * 5, 0.25 + liverStage * 0.05) or nil,
				passoutIn = liverStage >= 2 and shortenTimeline(110 - liverStage * 15, dmginfo:GetDamage(), 28, 0.1 + liverStage * 0.03) or nil,
				unconsciousFor = 10 + liverStage * 3,
				interval = 4,
				injuryStage = liverStage,
				shockWeight = 0.75
			})

		elseif string.find(organ, "Artery") then
			local organInfo = getOrganStateInfo(organ)

			if organ == "Carotid Artery" then
				MuR:GiveMessage2("artery_hit", owner)
				owner:TriggerArtery(organ)
				MuR:GiveMessage2("artery_neck_hit", owner)
				owner:ApplyCriticalOrganState("carotid", {
					attacker = dmginfo:GetAttacker(),
					inflictor = dmginfo:GetInflictor(),
					damageType = DMG_DIRECT,
					deathIn = shortenTimeline(28, dmginfo:GetDamage(), 12, 0.09),
					passoutIn = shortenTimeline(14, dmginfo:GetDamage(), 5, 0.05),
					unconsciousFor = 18,
					interval = 1.5,
					injuryStage = dmginfo:GetDamage() >= 20 and 3 or 2,
					shockWeight = 1.5
				})
				if victim.MakeBloodEffect then victim:MakeBloodEffect("ValveBiped.Bip01_Neck1", 0.1, 8) end
				broadcastLiveBloodSpray(victim, "ValveBiped.Bip01_Neck1", 1.7, 28)
				owner:EmitSound("murdered/player/throat_cut.wav", 60, 100)
			elseif string.find(organ, "Brachial") then
				local woundTier
				if isTieredLimbArteryCandidate(dmginfo, organ) and organInfo then
					woundTier = rollBleedingWoundTier(dmginfo, organ)
					if woundTier then
						owner:ApplyBleedingWound(organInfo.slot, woundTier, {
							arteryFlag = organInfo.arteryFlag,
							criticalStateKey = organInfo.stateKey,
							bone = organInfo.bone
						})
					end
				end

				if woundTier and woundTier ~= BLEED_WOUND_ARTERIAL then
					local sprayMagnitude = woundTier == BLEED_WOUND_DEEP and 1.2 or 0.9
					local sprayRadius = woundTier == BLEED_WOUND_DEEP and 18 or 12
					if victim.MakeBloodEffect and organInfo and organInfo.bone then
						victim:MakeBloodEffect(organInfo.bone, 0.08, woundTier == BLEED_WOUND_DEEP and 4 or 2)
					end
					if organInfo and organInfo.bone then
						broadcastLiveBloodSpray(victim, organInfo.bone, sprayMagnitude, sprayRadius)
						if owner.BloodTrailBone then
							owner:BloodTrailBone(organInfo.bone, woundTier == BLEED_WOUND_DEEP and 6 or 3.5)
						end
					end
				else
					MuR:GiveMessage2("artery_hit", owner)
					MuR:GiveMessage2("artery_arm_hit", owner)
					owner:TriggerArtery(organ)
					local ownerRag = owner:GetRD()
					if IsValid(ownerRag) and ownerRag.Gibbed then
						MuR:GiveMessage2("dismember_agony", owner)
					end
					if IsValid(owner:GetActiveWeapon()) and not owner:GetActiveWeapon().NeverDrop then
						owner:DropWeapon(owner:GetActiveWeapon())
					end
					owner:ApplyCriticalOrganState(organInfo and organInfo.stateKey or "brachial", {
						attacker = dmginfo:GetAttacker(),
						inflictor = dmginfo:GetInflictor(),
						damageType = DMG_DIRECT,
						deathIn = shortenTimeline(130, dmginfo:GetDamage(), 55, 0.2),
						passoutIn = shortenTimeline(70, dmginfo:GetDamage(), 24, 0.1),
						unconsciousFor = 10,
						interval = 3,
						injuryStage = dmginfo:GetDamage() >= 22 and 2 or 1,
						shockWeight = 0.7
					})
					if victim.MakeBloodEffect and organInfo and organInfo.bone then
						victim:MakeBloodEffect(organInfo.bone, 0.1, 6)
					end
					if organInfo and organInfo.bone then
						broadcastLiveBloodSpray(victim, organInfo.bone, 1.4, 22)
					end
				end
			elseif string.find(organ, "Femoral") then
				local woundTier
				if isTieredLimbArteryCandidate(dmginfo, organ) and organInfo then
					woundTier = rollBleedingWoundTier(dmginfo, organ)
					if woundTier then
						owner:ApplyBleedingWound(organInfo.slot, woundTier, {
							arteryFlag = organInfo.arteryFlag,
							criticalStateKey = organInfo.stateKey,
							bone = organInfo.bone
						})
					end
				end

				if woundTier and woundTier ~= BLEED_WOUND_ARTERIAL then
					local sprayMagnitude = woundTier == BLEED_WOUND_DEEP and 1.3 or 0.95
					local sprayRadius = woundTier == BLEED_WOUND_DEEP and 20 or 13
					if victim.MakeBloodEffect and organInfo and organInfo.bone then
						victim:MakeBloodEffect(organInfo.bone, 0.08, woundTier == BLEED_WOUND_DEEP and 4 or 2)
					end
					if organInfo and organInfo.bone then
						broadcastLiveBloodSpray(victim, organInfo.bone, sprayMagnitude, sprayRadius)
						if owner.BloodTrailBone then
							owner:BloodTrailBone(organInfo.bone, woundTier == BLEED_WOUND_DEEP and 6.5 or 3.75)
						end
					end
				else
					MuR:GiveMessage2("artery_hit", owner)
					MuR:GiveMessage2("artery_leg_hit", owner)
					owner:TriggerArtery(organ)
					owner:DamagePlayerSystem("bone")
					owner:ApplyCriticalOrganState(organInfo and organInfo.stateKey or "femoral", {
						attacker = dmginfo:GetAttacker(),
						inflictor = dmginfo:GetInflictor(),
						damageType = DMG_DIRECT,
						deathIn = shortenTimeline(55, dmginfo:GetDamage(), 22, 0.14),
						passoutIn = shortenTimeline(28, dmginfo:GetDamage(), 10, 0.08),
						unconsciousFor = 16,
						interval = 2,
						injuryStage = dmginfo:GetDamage() >= 24 and 3 or 2,
						shockWeight = 1.2
					})
					if victim.MakeBloodEffect and organInfo and organInfo.bone then
						victim:MakeBloodEffect(organInfo.bone, 0.1, 7)
					end
					if organInfo and organInfo.bone then
						broadcastLiveBloodSpray(victim, organInfo.bone, 1.55, 24)
					end
				end
			end
		end

		local organData = MuR.GetOrgan(organ)
		if organData and organData.bleed and organData.bleed > 0 then
			local boneName = organData.bone
			local seconds = math.Clamp(organData.bleed * 6, 2, 30)
			local times = math.max(1, organData.bleed * 2)
			local useTieredLimbWound = isTieredLimbArteryCandidate(dmginfo, organ)

			if victim:IsRagdoll() then
				victim._MuR_BledOrgans = victim._MuR_BledOrgans or {}
				if not victim._MuR_BledOrgans[organ] then
					victim._MuR_BledOrgans[organ] = true
					if victim.BloodTrailBone then victim:BloodTrailBone(boneName, seconds) end
					local pos = MuR:BoneData(victim, boneName)
					if pos then
						if MuR.BroadcastOrganBleedEffect then
							MuR:BroadcastOrganBleedEffect(victim, pos, organData.bleed)
						else
							local eff = EffectData()
							eff:SetOrigin(pos)
							eff:SetMagnitude(organData.bleed)
							eff:SetEntity(victim)
							util.Effect("mur_organ_bleed", eff)
						end
						broadcastLiveBloodSpray(victim, boneName, math.max(1.1, organData.bleed), 18 + organData.bleed * 4)
					end
				end
			else
				local plyVictim = victim:IsPlayer() and victim or (victim:IsRagdoll() and victim.Owner)
				if IsValid(plyVictim) and not useTieredLimbWound then
					local newLevel = plyVictim:GetNW2Float("BleedLevel") + organData.bleed
					plyVictim:SetNW2Float("BleedLevel", math.min(newLevel, 3))
					if newLevel >= 3 then plyVictim:SetNW2Bool("HardBleed", true) end
					if plyVictim.BloodTrailBone then plyVictim:BloodTrailBone(boneName, seconds) end
					plyVictim:MakeBloodEffect(boneName, 0.1, times)
				end
			end
		end

	elseif isBlunt and organ == "Brain" and dmginfo:GetDamage() >= 40 then
		if owner:IsPlayer() then
			owner:ApplyCriticalOrganState("brain", {
				attacker = dmginfo:GetAttacker(),
				inflictor = dmginfo:GetInflictor(),
				damageType = DMG_CLUB,
				deathIn = shortenTimeline(50, dmginfo:GetDamage(), 18, 0.18),
				passoutIn = 0,
				unconsciousFor = 18,
				interval = 1.5
			})
			owner:ApplyUnconsciousness(18)
		end
	end
end)

hook.Add("PlayerPostThink", "MuR.OrganEffects", function(ply)
	if not ply:Alive() then return end

	processCriticalOrgans(ply)
	processBodyState(ply)

	if ply:GetNW2Bool("Pneumothorax") then
		if ply:GetNW2Float("Stamina", 100) > 20 then
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina") - FrameTime() * 10, 20))
		end

		if math.random() < 0.005 then
			ply:EmitSound("murdered/player/gasp_0" .. math.random(1, 3) .. ".wav", 50, 90)
		end
	end

	local toxin = ply:GetNW2Float("ToxinLevel", 0)
	if toxin > 0 then
		if toxin > 3 and math.random() < 0.001 then
			ply:ApplyUnconsciousness(2)
		end
	end
end)

hook.Add("PlayerDeath", "MuR.ClearCriticalOrgans", function(victim)
	victim:ResetCriticalOrgans()
end)
