if not SERVER then return end

MuR = MuR or {}

local cvMaxHitFrac = CreateConVar("blsd_max_single_hit_frac", "0.75",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Largest share of max health one non-structural hit may remove (0 disables the cap).", 0, 1)

local cvDisabledModes = CreateConVar("blsd_dying_disabled_modes", "18",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Comma separated gamemode ids that keep instant death (arcade / wave modes).")

local disabledModeCache, disabledModeSource

local function getDisabledModes()
	local raw = cvDisabledModes:GetString()
	if raw ~= disabledModeSource then
		disabledModeSource = raw
		disabledModeCache = {}
		for id in string.gmatch(raw, "[^,%s]+") do
			local num = tonumber(id)
			if num then disabledModeCache[num] = true end
		end
	end

	return disabledModeCache
end

function MuR.IsArcadeMode(modeId)
	modeId = modeId or MuR.Gamemode
	if not modeId then return false end

	if getDisabledModes()[modeId] then return true end

	local mode = MuR.Mode and MuR.Mode(modeId)
	return mode and mode.instant_death == true or false
end

function MuR.IsRealisticDeathEnabled(ply)
	if MuR.IsArcadeMode() then return false end
	if IsValid(ply) and ply.IsRoleWithoutOrgans and ply:IsRoleWithoutOrgans() then return false end

	return true
end

local FATAL_DISMEMBERMENT = {
	["ValveBiped.Bip01_Head1"] = true,
	["ValveBiped.Bip01_Neck1"] = true,
	["ValveBiped.Bip01_Spine"] = true,
	["ValveBiped.Bip01_Spine1"] = true,
	["ValveBiped.Bip01_Spine2"] = true,
	["ValveBiped.Bip01_Spine4"] = true,
	["ValveBiped.Bip01_Pelvis"] = true
}

function MuR.IsFatalDismembermentBone(boneName)
	return isstring(boneName) and FATAL_DISMEMBERMENT[boneName] == true
end

function MuR.HasFatalDismemberment(rag)
	if not IsValid(rag) then return false end
	if not istable(rag.ZippyGoreMod3_GibbedPhysBones) then return false end

	for physBone, gibbed in pairs(rag.ZippyGoreMod3_GibbedPhysBones) do
		if gibbed then
			local boneId = rag:TranslatePhysBoneToBone(physBone)
			if boneId then
				local boneName = rag:GetBoneName(boneId)
				if boneName and FATAL_DISMEMBERMENT[boneName] then
					return true
				end
			end
		end
	end

	return false
end

function MuR.IsStructuralDamage(ply, dmginfo)
	if not IsValid(ply) then return false end

	if ply.MuR_StructuralDeath then return true end

	if ply.DeathBlowHead or ply.DeathBlowHeadCut or ply.DeathBlowSpine then return true end

	if istable(ply.DeathBlowBone) then return true end

	local rag = ply.GetRD and ply:GetRD()
	if IsValid(rag) and MuR.HasFatalDismemberment(rag) then return true end

	if dmginfo and bit.band(dmginfo:GetDamageType(), DMG_REMOVENORAGDOLL) ~= 0 then
		return true
	end

	return false
end

function GM:EntityTakeDamage(ent, dmg)
	if not IsValid(ent) or not ent:IsPlayer() or not ent:Alive() then return end
	if ent.MuR_TerminalDamage then return end
	if not MuR.IsRealisticDeathEnabled(ent) then return end
	if MuR.IsStructuralDamage(ent, dmg) then return end

	if ent.IsDying and ent:IsDying() then
		local att = dmg:GetAttacker()
		if IsValid(att) and att.IsPMCEnemy then
			dmg:SetDamage(0)
			return
		end

		MuR.HandleDyingDamage(ent, dmg)
		return
	end

	local incoming = dmg:GetDamage()
	local wouldBeLethal = incoming >= ent:Health()

	if wouldBeLethal and MuR.AttackerBypassesDying and MuR.AttackerBypassesDying(dmg) then
		return
	end

	if wouldBeLethal and ent.EnterDying then
		if ent:EnterDying(dmg) then
			dmg:SetDamage(0)
			return
		end
	end

	local frac = cvMaxHitFrac:GetFloat()
	if frac > 0 then
		local ceiling = ent:GetMaxHealth() * frac
		if incoming > ceiling then
			dmg:SetDamage(ceiling)
		end
	end
end
