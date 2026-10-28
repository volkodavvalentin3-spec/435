if CLIENT then return end

util.AddNetworkString("LITEGIBDMG")
util.AddNetworkString("LITEGIBPS")
util.AddNetworkString("LITEGIBCLIENTRAG")
util.AddNetworkString("LGCopyWounds")
util.AddNetworkString("CLBloodType")

local ValidHitGroups = {HITGROUP_HEAD, HITGROUP_CHEST, HITGROUP_STOMACH, HITGROUP_LEFTARM, HITGROUP_RIGHTARM, HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG}
local keepcorpses = GetConVar("ai_serverragdolls")

local function GetClosestBone(ent, pos)
	local biggestDist = math.huge
	local b
	for i = 0, ent:GetBoneCount() - 1 do
		local p = ent:GetBonePosition(i)
		local d = pos:Distance(p)
		if d < biggestDist then
			biggestDist = d
			b = i
		end
	end
	return b
end

local function fixHitGroupDir(hg, bn)
	local nhg = hg
	if bn:EndsWith("_r") or bn:find("_r_") then
		if nhg == HITGROUP_LEFTLEG then
			nhg = HITGROUP_RIGHTLEG
		elseif nhg == HITGROUP_LEFTARM then
			nhg = HITGROUP_RIGHTARM
		end
	end
	return nhg
end

local function fixHitGroup(ent, hg, dmg)
	local tr = {}
	local traceRes
	if hg == HITGROUP_GENERIC then
		local centerpos = ent:GetPos()
		if ent.GetShootPos then centerpos = (centerpos + ent:GetShootPos()) / 2 end
		tr.start = dmg:GetDamagePosition() or centerpos
		tr.endpos = centerpos
		traceRes = util.TraceLine(tr)
		hg = traceRes.HitGroup or hg
		if hg == HITGROUP_GENERIC and traceRes.Entity == ent and traceRes.PhysicsBone and traceRes.PhysicsBone >= 0 then
			if LiteWounds.PhysBoneBlacklistClass[ent:GetClass()] then
				local bone = GetClosestBone(ent, tr.start)
				if not bone then return HITGROUP_STOMACH end
				local bn = string.lower(ent:GetBoneName(bone) or "valvebiped.bip01_spine1")
				for k, v in pairs(LiteWounds.BoneHitGroups) do
					if string.find(bn, k) then return fixHitGroupDir(v, bn) end
				end
			else
				local bone = ent:TranslatePhysBoneToBone(traceRes.PhysicsBone)
				if not bone then return HITGROUP_STOMACH end
				local bn = string.lower(ent:GetBoneName(bone) or "valvebiped.bip01_spine1")
				for k, v in pairs(LiteWounds.BoneHitGroups) do
					if string.find(bn, k) then return fixHitGroupDir(v, bn) end
				end
			end
		end
	end

	if hg == HITGROUP_GENERIC then return HITGROUP_STOMACH end
	return hg
end

local function IsDamageType(dmg, typev)
	return bit.band(dmg, typev) == typev
end

local function AddToDamageTable(ent, hitgroup, damage, damageType, vec)
	ent.LGDamageTable = ent.LGDamageTable or {}
	if IsDamageType(damageType, DMG_BLAST) then
		for _, hgruppe in pairs(ValidHitGroups) do
			ent.LGDamageTable[hgruppe] = ent.LGDamageTable[hgruppe] or {}
			ent.LGDamageTable[hgruppe].damage = ent.LGDamageTable[hgruppe].damage or 0
			ent.LGDamageTable[hgruppe].damage = ent.LGDamageTable[hgruppe].damage + damage * math.Rand(0.5, 1.5)
			ent.LGDamageTable[hgruppe].damageType = bit.bor(damageType, ent.LGDamageTable[hgruppe].damageType or 0)
		end

		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage or 0
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage + damage / 2
		ent.LGDamageTable[hitgroup].damageType = bit.bor(damageType, ent.LGDamageTable[hitgroup].damageType or 0)
	elseif IsDamageType(damageType, DMG_SLASH) then
		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage or 0
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage + damage
		ent.LGDamageTable[hitgroup].damageType = bit.bor(damageType, ent.LGDamageTable[hitgroup].damageType or 0)
	end

	if IsDamageType(damageType, DMG_ALWAYSGIB) then
		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = 1000
		if damage < 160 then
			ent.LGDamageTable[hitgroup].damageType = DMG_SLASH
		else
			ent.LGDamageTable[hitgroup].damageType = damageType
		end
	elseif not IsDamageType(damageType, DMG_NEVERGIB) then
		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = damage
		ent.LGDamageTable[hitgroup].damageType = damageType
	end
end

local function NetworkDamage(ent, hg, dmg)
	local dmgVal = dmg:GetBaseDamage()
	if dmgVal <= 1 then return end
	local hgf = fixHitGroup(ent, hg, dmg)
	local vec = dmg:GetDamagePosition()
	local wep = dmg:GetInflictor()
	if IsValid(wep) and wep:IsPlayer() then wep = wep:GetActiveWeapon() end
	if IsValid(wep) and wep:IsWeapon() and not dmg:IsDamageType(DMG_SLASH) and not dmg:IsDamageType(DMG_CLUB) and not dmg:IsDamageType(DMG_CRUSH) then
		if wep.GetStat then
			dmgVal = math.min(dmgVal * wep:GetStat("Primary.NumShots"), wep:GetStat("Primary.Damage", wep.Primary.Damage) * wep:GetStat("Primary.NumShots"))
		elseif wep.Primary and wep.Primary.Damage and type(wep.Primary.Damage) == "number" and wep.Primary.NumShots then
			dmgVal = math.min(wep.Primary.Damage * wep.Primary.NumShots, dmgVal)
		end

		local mod = LiteWounds.WeaponDamageScales[wep:GetClass()] or 1
		dmgVal = dmgVal * mod
	end

	if dmgVal > ent:GetMaxHealth() * 2 and hg == 0 then hg = HITGROUP_STOMACH end
	AddToDamageTable(ent, hgf, math.Round(dmgVal), math.Round(dmg:GetDamageType()), vec)

	net.Start("LITEGIBDMG")
	net.WriteEntity(ent)
	net.WriteUInt(hgf, 4)
	net.WriteInt(math.Round(dmgVal), 12)
	net.WriteUInt(math.Round(dmg:GetDamageType()), 31)
	net.WriteVector(vec)
	if IsValid(wep) then net.WriteEntity(wep) end
	net.SendPVS(ent:GetPos())
	ent.LGLastNWDamage = CurTime()
end

hook.Add("ScaleNPCDamage", "LGNetworkDamage", NetworkDamage)
hook.Add("ScalePlayerDamage", "LGNetworkDamage", NetworkDamage)

hook.Add("EntityTakeDamage", "LGNetworkDamage", function(ent, dmg)
	if ent.LGLastNWDamage and ent.LGLastNWDamage >= CurTime() then return end
	if ent:IsRagdoll() then
		local phys = ent:GetPhysicsObjectNum(0)
		local mat = IsValid(phys) and phys:GetMaterial() or -1
		if mat ~= "flesh" and mat ~= "alienflesh" and mat ~= "antlion" then return end
	else
		if ent:GetBloodColorLG() == DONT_BLEED then return end
	end

	if ent.BehaveStart or ent.ClearCondition or ent:IsNPC() or ent:IsPlayer() or ent:IsRagdoll() then
		NetworkDamage(ent, ent.LastHitGroup and ent:LastHitGroup() or HITGROUP_GENERIC, dmg)
	end
end)

hook.Add("PlayerSpawn", "LGPlayerSpawn", function(ply)
	ply.LGDamageTable = nil
	ply.gibbedBones = nil
	net.Start("LITEGIBPS")
	net.WriteEntity(ply)
	net.Broadcast()
end)

local btOverrides = {
	["npc_antlion"] = BLOOD_COLOR_ANTLION,
	["npc_antlionguard"] = BLOOD_COLOR_ANTLION,
	["npc_hunter"] = BLOOD_COLOR_SYNTH,
	["npc_turret_floor"] = DONT_BLEED
}

hook.Add("OnEntityCreated", "LGNWBloodType", function(ent)
	timer.Simple(0.01, function()
		if IsValid(ent) then
			ent.BloodColor = btOverrides[ent:GetClass()] or ent.BloodColor or ent:GetBloodColor()
			if isnumber(ent.BloodColor) then
				net.Start("CLBloodType")
				net.WriteEntity(ent)
				net.WriteInt(ent.BloodColor, 8)
				net.SendPVS(ent:GetPos())
			end
		end
	end)
end)

local meta = FindMetaTable("Entity")
function meta:CopyWoundsFrom(ent)
	timer.Simple(0.1, function()
		if !IsValid(self) or !IsValid(ent) then return end
		net.Start("LGCopyWounds")
		net.WriteEntity(ent)
		net.WriteEntity(self)
		net.SendPVS(self:GetPos())
	end)
end

hook.Add("CreateEntityRagdoll", "LGCreateEntityRag", function(ent, rag)
	rag:CopyWoundsFrom(ent)
end)

LiteWounds.EntitiesPatched = {}

local function patch(cl)
	local tbl = scripted_ents.GetStored(cl)
	if tbl and tbl.t then
		local ENT = scripted_ents.GetStored(cl).t
		function ENT:MorphRagdoll(dmginfo)
			self:BecomeRagdoll(dmginfo or DamageInfo())
		end

		function ENT:TransformRagdoll(dmginfo)
			self:BecomeRagdoll(dmginfo or DamageInfo())
		end
	end
end

hook.Add("OnEntityCreated", "LGForceClientRagdolls_NextBot", function(ent)
	local cl = ent:GetClass()
	if not LiteWounds.EntitiesPatched[cl] then
		patch(cl)
		LiteWounds.EntitiesPatched[cl] = true
	end

	timer.Simple(0, function()
		if IsValid(ent) and ent:Health() > ent:GetMaxHealth() then
			ent:SetMaxHealth(ent:Health())
		end
	end)
end)
