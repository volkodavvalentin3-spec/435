if not SERVER then return end

MuR = MuR or {}

local meta = FindMetaTable("Player")
if not meta then return end

function meta:GetKillerClass()
	return MuR.KillerClasses[self:GetNW2String("KillerClass", "")]
end

function MuR.ApplyKillerClass(ply)
	local set = MuR.KillerClassSets[MuR.Gamemode]
	if not set then
		ply:SetNW2String("KillerClass", "")
		return false
	end

	local wanted = ply:GetInfo(MuR.KillerClassConVar(MuR.Gamemode), "")
	local def = MuR.GetKillerClass(MuR.Gamemode, wanted)
	if not def then
		ply:SetNW2String("KillerClass", "")
		return false
	end

	ply:SetNW2String("KillerClass", def.id)

	if def.health then
		ply:SetMaxHealth(def.health)
		ply:SetHealth(def.health)
	end

	if def.model and util.IsValidModel(def.model) then
		ply:SetModel(def.model)
	end

	if def.armor then ply:SetArmor(def.armor) end
	if def.walk then ply:SetWalkSpeed(def.walk) end
	if def.run then ply:SetRunSpeed(def.run) end

	ply:SetNW2Float("KillerStaminaMul", def.staminaMul or 1)

	if def.loadout then def.loadout(ply) end

	local extra = MuR.KillerModeExtras and MuR.KillerModeExtras[MuR.Gamemode]
	if extra then extra(ply) end

	if def.ability == "relentless" then
		MuR.StartRelentless(ply)
	end

	return true
end

local function clearClass(ply)
	timer.Remove("MuR.Relentless" .. ply:EntIndex())

	ply:SetNW2String("KillerClass", "")
	ply:SetNW2Float("KillerStaminaMul", 1)
	ply:SetNW2Bool("KillerHidden", false)

	ply.MuR_KillerStill = nil
end

hook.Add("PlayerSpawn", "MuR.KillerClassReset", clearClass)
hook.Add("PlayerDeath", "MuR.KillerClassDeath", clearClass)
hook.Add("PlayerDisconnected", "MuR.KillerClassLeave", clearClass)

function MuR.KillerSanityRate(ply)
	local rate = MuR.KillerSanityDrain(ply:GetKillerClass()) or 1
	return rate * (MuR.Mode(MuR.Gamemode).killer_sanity_mul or 1)
end

function MuR.AttackerBypassesDying(dmg)
	if not dmg then return false end

	local att = dmg:GetAttacker()
	if not IsValid(att) or not att:IsPlayer() then return false end

	local def = att:GetKillerClass()
	if not def then return false end

	if def.bypassDying then return true end

	return att.MuR_BackstabHit == true
end

function MuR.StartRelentless(ply)
	local id = "MuR.Relentless" .. ply:EntIndex()

	timer.Create(id, 1, 0, function()
		if not IsValid(ply) or not ply:Alive() then
			timer.Remove(id)
			return
		end

		local def = ply:GetKillerClass()
		if not def or def.ability ~= "relentless" then
			timer.Remove(id)
			return
		end

		if ply:Health() < ply:GetMaxHealth() then
			ply:SetHealth(math.min(ply:Health() + 6, ply:GetMaxHealth()))
		elseif ply:Armor() < (def.armor or 0) then
			ply:SetArmor(math.min(ply:Armor() + 3, def.armor))
		end
	end)
end

local ROAR_RADIUS = 700
local ROAR_INTERVAL = 0.5

function MuR.KillerRoarPulse(ply)
	local hit = 0

	for _, victim in ipairs(ents.FindInSphere(ply:GetPos(), ROAR_RADIUS)) do
		if victim:IsPlayer() and victim ~= ply and victim:Alive() and not victim:IsKiller() then
			local dist = victim:GetPos():Distance(ply:GetPos())
			local severity = 1 - dist / ROAR_RADIUS

			if severity > 0.15 then
				victim:ApplyCoordinationLoss(1, severity * 0.6, "substance")
				hit = hit + 1
			end
		end
	end

	return hit
end

hook.Add("PlayerPostThink", "MuR.KillerRoar", function(ply)
	if not ply:Alive() then return end

	local def = ply:GetKillerClass()
	if not def or def.ability ~= "roar" then return end
	if not ply:KeyDown(IN_ATTACK) then return end

	local now = CurTime()
	if (ply.MuR_NextRoar or 0) > now then return end
	ply.MuR_NextRoar = now + ROAR_INTERVAL

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "tfa_bs_chainsaw" then return end

	MuR.KillerRoarPulse(ply)
end)

local STILL_DELAY = 1.2
local STILL_SPEED = 12
local STILL_ALPHA = 4

hook.Add("PlayerPostThink", "MuR.KillerStillness", function(ply)
	local def = ply:GetKillerClass()
	if not def or def.ability ~= "stillness" then return end

	local hidden = ply:GetNW2Bool("KillerHidden", false)

	if not ply:Alive() then
		if hidden then MuR.SetKillerHidden(ply, false) end
		return
	end

	local moving = ply:GetVelocity():Length2D() > STILL_SPEED
		or ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2)

	if moving then
		ply.MuR_KillerStill = nil
		if hidden then MuR.SetKillerHidden(ply, false) end
		return
	end

	ply.MuR_KillerStill = ply.MuR_KillerStill or CurTime()

	if not hidden and CurTime() - ply.MuR_KillerStill >= STILL_DELAY then
		MuR.SetKillerHidden(ply, true)
	end
end)

function MuR.SetKillerHidden(ply, hidden)
	ply:SetNW2Bool("KillerHidden", hidden)

	ply:SetRenderMode(hidden and RENDERMODE_TRANSALPHA or RENDERMODE_NORMAL)
	ply:SetColor(Color(255, 255, 255, hidden and STILL_ALPHA or 255))

	local wep = ply:GetActiveWeapon()
	if IsValid(wep) then
		wep:SetRenderMode(hidden and RENDERMODE_TRANSALPHA or RENDERMODE_NORMAL)
		wep:SetColor(Color(255, 255, 255, hidden and STILL_ALPHA or 255))
	end
end

hook.Add("PlayerFootstep", "MuR.KillerStillnessSteps", function(ply)
	if ply:GetNW2Bool("KillerHidden", false) then return true end
end)

local BACKSTAB_DOT = -0.35
local BACKSTAB_MUL = 3

hook.Add("EntityTakeDamage", "MuR.KillerBackstab", function(victim, dmg)
	if not IsValid(victim) or not victim:IsPlayer() then return end

	local att = dmg:GetAttacker()
	if not IsValid(att) or not att:IsPlayer() or att == victim then return end

	local def = att:GetKillerClass()
	if not def or def.ability ~= "backstab" then return end

	att.MuR_BackstabHit = nil

	local toAttacker = att:GetPos() - victim:GetPos()
	toAttacker.z = 0
	toAttacker:Normalize()

	local facing = victim:GetAimVector()
	facing.z = 0
	facing:Normalize()

	if facing:Dot(toAttacker) > BACKSTAB_DOT then return end

	att.MuR_BackstabHit = true
	dmg:ScaleDamage(BACKSTAB_MUL)
end)

hook.Add("PostEntityTakeDamage", "MuR.KillerBackstabClear", function(_, dmg)
	local att = dmg:GetAttacker()
	if IsValid(att) and att:IsPlayer() then att.MuR_BackstabHit = nil end
end)
