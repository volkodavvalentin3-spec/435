if not SERVER then return end

MuR = MuR or {}

local meta = FindMetaTable("Player")
if not meta then return end

local boneFallbackTypeByName = {
	["ValveBiped.Bip01_L_Clavicle"] = "clavicle",
	["ValveBiped.Bip01_R_Clavicle"] = "clavicle",

	["ValveBiped.Bip01_L_UpperArm"] = "arm",
	["ValveBiped.Bip01_R_UpperArm"] = "arm",

	["ValveBiped.Bip01_L_Forearm"] = "forearm",
	["ValveBiped.Bip01_L_Hand"] = "forearm",
	["ValveBiped.Bip01_R_Forearm"] = "forearm",
	["ValveBiped.Bip01_R_Hand"] = "forearm",

	["ValveBiped.Bip01_L_Thigh"] = "leg",
	["ValveBiped.Bip01_L_Calf"] = "leg",
	["ValveBiped.Bip01_R_Thigh"] = "leg",
	["ValveBiped.Bip01_R_Calf"] = "leg",

	["ValveBiped.Bip01_L_Foot"] = "foot",
	["ValveBiped.Bip01_L_Toe0"] = "foot",
	["ValveBiped.Bip01_R_Foot"] = "foot",
	["ValveBiped.Bip01_R_Toe0"] = "foot",

	["ValveBiped.Bip01_Pelvis"] = "pelvis",

	["ValveBiped.Bip01_Spine"] = "ribs",
	["ValveBiped.Bip01_Spine1"] = "ribs",
	["ValveBiped.Bip01_Spine2"] = "ribs",
	["ValveBiped.Bip01_Spine4"] = "ribs",

	["ValveBiped.Bip01_Head1"] = "jaw",
	["ValveBiped.Bip01_Neck1"] = "jaw",
}

local fractureTypes = {
	clavicle = {
		flag = "ClavicleFracture",
		message = "arm_fracture",
		cooldown = 10,
		minDamage = 16,
		scale = 50,
		maxChance = 0.4,
		duration = 12,
		severity = 1.25,
		dropChance = 1,
		bulletMul = 0.95,
		slashMul = 0.35
	},
	arm = {
		flag = "ArmFracture",
		message = "arm_fracture",
		cooldown = 8,
		minDamage = 18,
		scale = 55,
		maxChance = 0.45,
		duration = 10,
		severity = 1.0,
		dropChance = 3,
		bulletMul = 0.75,
		slashMul = 0.3
	},
	forearm = {
		flag = "ForearmFracture",
		message = "arm_fracture",
		cooldown = 8,
		minDamage = 14,
		scale = 48,
		maxChance = 0.5,
		duration = 11,
		severity = 1.15,
		dropChance = 2,
		bulletMul = 0.95,
		slashMul = 0.45
	},
	leg = {
		flag = "LegBroken",
		message = "leg_fracture",
		cooldown = 8,
		minDamage = 12,
		scale = 50,
		maxChance = 0.6,
		damageSystem = "bone",
		bulletMul = 0.8,
		slashMul = 0.25
	},
	foot = {
		flag = "FootFracture",
		message = "leg_fracture",
		cooldown = 9,
		minDamage = 10,
		scale = 50,
		maxChance = 0.45,
		duration = 6,
		severity = 0.7,
		staminaLoss = 12,
		bulletMul = 0.7,
		slashMul = 0.2
	},
	pelvis = {
		flag = "PelvisFracture",
		message = "pelvis_fracture",
		cooldown = 12,
		minDamage = 25,
		scale = 55,
		maxChance = 0.45,
		duration = 14,
		severity = 1.3,
		staminaLoss = 25,
		ragdoll = true,
		bulletMul = 0.75,
		slashMul = 0.15
	},
	ribs = {
		flag = "RibFracture",
		message = "rib_hit",
		cooldown = 9,
		minDamage = 14,
		scale = 55,
		maxChance = 0.4,
		duration = 8,
		severity = 0.7,
		staminaLoss = 14,
		bulletMul = 0.9,
		slashMul = 0.2
	},
	jaw = {
		flag = "JawFracture",
		message = "jaw_fracture",
		cooldown = 10,
		minDamage = 20,
		scale = 60,
		maxChance = 0.35,
		concussionDuration = 4,
		concussionIntensity = 1.1,
		bulletMul = 1,
		slashMul = 0.3
	}
}

local function consumeFractureCooldown(ply, key, cooldown)
	ply.BoneFractureCooldowns = ply.BoneFractureCooldowns or {}
	if (ply.BoneFractureCooldowns[key] or 0) > CurTime() then return false end
	ply.BoneFractureCooldowns[key] = CurTime() + (cooldown or 6)
	return true
end

local function applyFractureCoordinationPenalty(ply, duration, severity, reason)
	if reason ~= "brain_blunt" then return end
	duration = duration or 6
	severity = severity or 0.5

	local endTime = ply:GetNW2Float("CoordinationEnd", 0)
	if endTime > CurTime() then
		local left = endTime - CurTime()
		duration = duration + left * 0.25
		severity = math.min(severity + ply:GetNW2Float("CoordinationSeverity", 0) * 0.2, 2)
	end

	ply:SetNW2Float("CoordinationEnd", CurTime() + duration)
	ply:SetNW2Float("CoordinationSeverity", math.max(ply:GetNW2Float("CoordinationSeverity", 0), severity))
end

local function dropActiveWeapon(ply, chance)
	if chance <= 0 then return end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep.NeverDrop or wep.CantDrop then return end
	if math.random(1, chance) == 1 then
		ply:DropWeapon(wep)
	end
end

local function passesFractureRoll(damage, minDamage, scale, maxChance)
	if damage <= minDamage then return false end

	local frac = (damage - minDamage) / scale
	frac = math.Clamp(frac, 0, maxChance)

	return math.Rand(0, 1) < frac
end

local function getFractureDamageMode(dmg)
	local dt = dmg:GetDamageType()
	local blunt = bit.band(dt, DMG_CLUB) ~= 0 or bit.band(dt, DMG_CRUSH) ~= 0 or dmg:IsFallDamage()
	local blast = bit.band(dt, DMG_BLAST) ~= 0
	local bullet = dmg:IsBulletDamage()
	local slash = bit.band(dt, DMG_SLASH) ~= 0

	if bullet then return "bullet" end
	if slash then return "slash" end
	if blast then return "blast" end
	if blunt then return "blunt" end

	return nil
end

local function getScaledFractureDamage(cfg, dmg)
	local mode = getFractureDamageMode(dmg)
	if not mode then return 0, nil end

	local damage = dmg:GetDamage()
	if mode == "bullet" then
		damage = damage * (cfg.bulletMul or 0.85)
	elseif mode == "slash" then
		damage = damage * (cfg.slashMul or 0.25)
	elseif mode == "blast" then
		damage = damage * (cfg.blastMul or 1.1)
	elseif mode == "blunt" then
		damage = damage * (cfg.bluntMul or 1)
	end

	return damage, mode
end

local function tryApplyFracture(ply, fractureType, dmg)
	local cfg = fractureTypes[fractureType]
	if not cfg then return end
	if ply:GetNW2Bool(cfg.flag, false) then return end
	if not consumeFractureCooldown(ply, fractureType, cfg.cooldown) then return end

	local scaledDamage = getScaledFractureDamage(cfg, dmg)
	if scaledDamage <= 0 then return end
	if not passesFractureRoll(scaledDamage, cfg.minDamage, cfg.scale, cfg.maxChance) then return end

	if cfg.damageSystem then
		if ply.DamagePlayerSystem then
			ply:DamagePlayerSystem(cfg.damageSystem)
		end
	else
		ply:SetNW2Bool(cfg.flag, true)
	end

	if cfg.staminaLoss then
		ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - cfg.staminaLoss, 0))
	end

	if cfg.duration and cfg.severity then
		applyFractureCoordinationPenalty(ply, cfg.duration, cfg.severity)
	end

	if cfg.concussionDuration then
		ply:ApplyConcussion(dmg, cfg.concussionDuration, cfg.concussionIntensity or 1)
	end

	if cfg.dropChance then
		dropActiveWeapon(ply, cfg.dropChance)
	end

	if cfg.ragdoll and not IsValid(ply:GetRD()) then
		ply:StartRagdolling(0, dmg:GetDamage(), dmg)
	end

	if MuR.GiveMessage2 then
		MuR:GiveMessage2(cfg.message, ply)
	end

	timer.Simple(0, function()
		if not IsValid(ply) then return end
		if ply.UpdateBloodMovementSpeed then ply:UpdateBloodMovementSpeed() end
		if ply.CheckForceProneOnly then ply:CheckForceProneOnly() end
	end)
end

local function consumeFractureEffectCooldown(ply, key, delay)
	ply.BoneFractureEffectCooldowns = ply.BoneFractureEffectCooldowns or {}
	if (ply.BoneFractureEffectCooldowns[key] or 0) > CurTime() then return false end
	ply.BoneFractureEffectCooldowns[key] = CurTime() + delay
	return true
end

hook.Add("EntityTakeDamage", "MuR_BoneFractures", function(ent, dmg)
	if not IsValid(ent) then return end
	if ent.Owner and ent.Owner:IsPlayer() then ent = ent.Owner end
	if not ent:IsPlayer() or not ent:Alive() then return end
	if ent.IsRoleWithoutOrgans and ent:IsRoleWithoutOrgans() then return end
	if ent.MuR_TerminalDamage then return end

	local force = dmg:GetDamageForce()
	local att = dmg:GetAttacker()
	if force:IsZero() and IsValid(att) and att:IsPlayer() then
		force = att:GetAimVector() * 100
	end

	local tar = ent
	local rd = ent.GetRD and ent:GetRD()
	if IsValid(rd) then tar = rd end

	local dm = dmg:GetDamage()
	if dm < 8 then return end

	local fractureType
	local hitPos = dmg:GetDamagePosition()
	local traceBoneZones = MuR.TraceBodyZones or MuR.TraceHitboxEntries
	if hitPos ~= vector_origin and traceBoneZones and istable(MuR.BoneZones) then
		local hit = traceBoneZones(tar, MuR.BoneZones, hitPos, dmg, ent)
		if hit and hit.data then
			fractureType = hit.data.fractureType
		end
	end

	if not fractureType then
		local dt = dmg:GetDamageType()
		local blunt = bit.band(dt, DMG_CLUB) ~= 0 or bit.band(dt, DMG_CRUSH) ~= 0 or dmg:IsFallDamage()
		local blast = bit.band(dt, DMG_BLAST) ~= 0
		if not blunt and not blast then return end

		local bone = tar:GetNearestBoneFromPos(dmg:GetDamagePosition(), force)
		if not bone then return end
		fractureType = boneFallbackTypeByName[bone]
	end

	if not fractureType then return end

	tryApplyFracture(ent, fractureType, dmg)
end)

hook.Add("PlayerPostThink", "MuR_BoneFractures_Effects", function(ply)
	if not IsValid(ply) or not ply:Alive() then return end

	if ply:GetNW2Bool("PelvisFracture", false) then
		if consumeFractureEffectCooldown(ply, "pelvis", 1) then
			if ply:GetVelocity():Length2D() > 70 then
				ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - 6, 0))
			end
			applyFractureCoordinationPenalty(ply, 2.5, 0.45)
		end

		if ply.CheckForceProneOnly then
			ply:CheckForceProneOnly()
		end
	end

	if ply:GetNW2Bool("RibFracture", false) and consumeFractureEffectCooldown(ply, "ribs", 1.25) then
		if ply:IsSprinting() or ply:GetVelocity():Length2D() > 140 then
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - 5, 0))
			if math.random() < 0.2 then
				ply:EmitSound("murdered/player/gasp_0" .. math.random(1, 3) .. ".wav", 50, 95)
			end
		end
	end

	if ply:GetNW2Bool("FootFracture", false) and consumeFractureEffectCooldown(ply, "foot", 1) then
		if ply:GetVelocity():Length2D() > 90 then
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - 4, 0))
		end
	end

	local armBroken = ply:GetNW2Bool("ArmFracture", false)
	local clavicleBroken = ply:GetNW2Bool("ClavicleFracture", false)
	local forearmBroken = ply:GetNW2Bool("ForearmFracture", false)
	if (armBroken or clavicleBroken or forearmBroken) and consumeFractureEffectCooldown(ply, "arm", 0.9) then
		if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) or ply:GetVelocity():Length2D() > 150 then
			local severity = 0.45
			if armBroken then severity = severity + 0.2 end
			if clavicleBroken then severity = severity + 0.2 end
			if forearmBroken then severity = severity + 0.15 end

			applyFractureCoordinationPenalty(ply, 1.8, severity)

			if forearmBroken and math.random() < 0.08 then
				dropActiveWeapon(ply, 1)
			end
		end
	end
end)

hook.Add("PlayerSpawn", "MuR_BoneFractures_Reset", function(ply)
	if not IsValid(ply) then return end

	ply:SetNW2Bool("ArmFracture", false)
	ply:SetNW2Bool("ClavicleFracture", false)
	ply:SetNW2Bool("ForearmFracture", false)
	ply:SetNW2Bool("FootFracture", false)
	ply:SetNW2Bool("JawFracture", false)
	ply:SetNW2Bool("PelvisFracture", false)
	ply:SetNW2Bool("RibFracture", false)
	ply.BoneFractureCooldowns = nil
	ply.BoneFractureEffectCooldowns = nil
end)
