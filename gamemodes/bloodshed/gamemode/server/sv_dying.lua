if not SERVER then return end

MuR = MuR or {}

local meta = FindMetaTable("Player")
if not meta then return end

local cvEnabled = CreateConVar("blsd_dying_enabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Lethal damage drops players into a bleeding-out state instead of killing outright.", 0, 1)

local cvFinishDamage = CreateConVar("blsd_dying_finish_damage", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Damage in one hit needed to finish off a downed player.", 1, 100)

local cvGrace = CreateConVar("blsd_dying_grace", "4", {FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Seconds a freshly downed player cannot be finished off by ordinary damage.", 0, 30)

local DYING_BLEED_MULTIPLIER = 1.35
local DYING_MIN_BLEED = 0.35

function meta:IsDying()
	return self:GetNW2Bool("MuR.Dying", false)
end

function meta:GetDyingTimeLeft()
	if not self:IsDying() then return 0 end
	return self:GetOxygenTimeLeft() or math.huge
end

function meta:EnterDying(dmginfo)
	if self:IsDying() then return false end
	if not self:Alive() then return false end
	if not MuR.IsRealisticDeathEnabled(self) then return false end
	if not cvEnabled:GetBool() then return false end

	local attacker = dmginfo and dmginfo:GetAttacker()
	if IsValid(attacker) and attacker ~= self then
		self.MuR_DyingAttacker = attacker
	elseif IsValid(self.LastAttacker) then
		self.MuR_DyingAttacker = self.LastAttacker
	end

	self:SetNW2Bool("MuR.Dying", true)
	self:SetNW2Float("MuR.DyingGraceUntil", CurTime() + cvGrace:GetFloat())
	self:SetHealth(1)

	self:SetCerebralOxygen(self:GetCerebralOxygen() - 15)

	self:SetNW2Bool("ForceProneOnly", true)
	self.IsRagStanding = false

	self:ForceDyingCollapse()

	local wep = self:GetActiveWeapon()
	if IsValid(wep) and not wep.NeverDrop and not wep.CantDrop then
		self:DropWeapon(wep)
	end

	self:SetNW2Float("Stamina", 0)
	MuR:GiveMessage2("dying_state", self)

	MuR:RefreshNoTarget(self)

	hook.Run("MuR.PlayerEnteredDying", self, dmginfo)
	return true
end

function meta:ShortenDyingWindow(amount)
	if not self:IsDying() or (amount or 0) <= 0 then return end
	self:AddBloodVolume(-amount * 0.4)
	self:SetCerebralOxygen(self:GetCerebralOxygen() - amount * 0.5)
end

function meta:ForceDyingCollapse()
	if IsValid(self:GetRD()) then return true end

	if self:InVehicle() then self:ExitVehicle() end
	self:StartRagdolling(1, 0)

	if IsValid(self:GetRD()) then return true end

	self:SetNW2Bool("ForceProneOnly", true)
	self:SetWalkSpeed(1)
	self:SetRunSpeed(1)
	self:SetSlowWalkSpeed(1)
	self:SetJumpPower(0)

	timer.Simple(0.5, function()
		if IsValid(self) and self:Alive() and self:IsDying() and not IsValid(self:GetRD()) then
			self:ForceDyingCollapse()
		end
	end)

	return false
end

local function clearDyingState(ply)
	ply:SetNW2Bool("MuR.Dying", false)
	ply:SetNW2Float("MuR.DyingGraceUntil", 0)
	ply.MuR_NextDyingTick = nil
end

function meta:StabilizeDying(healer)
	if not self:IsDying() then return false end

	clearDyingState(self)
	self:SetHealth(math.random(10, 20))
	self:SetNW2Bool("ForceProneOnly", false)
	self:UpdateBloodMovementSpeed()

	if self:GetNW2Bool("IsUnconscious", false) then
		self:WakeUpFromUnconsciousness()
	end

	self:TimeGetUpChange(2, true)

	MuR:RefreshNoTarget(self)

	MuR:GiveMessage2("dying_stabilized", self)
	if IsValid(healer) and healer ~= self then
		MuR:GiveMessage2("dying_stabilized_medic", healer)
	end

	hook.Run("MuR.PlayerStabilized", self, healer)
	return true
end

function meta:FinishDying(attacker, inflictor)
	if not self:Alive() then return end

	attacker = IsValid(attacker) and attacker
		or (IsValid(self.MuR_DyingAttacker) and self.MuR_DyingAttacker)
		or game.GetWorld()

	clearDyingState(self)

	local dmg = DamageInfo()
	dmg:SetAttacker(attacker)
	dmg:SetInflictor(IsValid(inflictor) and inflictor or attacker)
	dmg:SetDamageType(DMG_DIRECT)
	dmg:SetDamage(self:Health() + 25)
	dmg:SetDamagePosition(self:WorldSpaceCenter())

	self.MuR_TerminalDamage = true
	self:TakeDamageInfo(dmg)
	self.MuR_TerminalDamage = nil

	if self:Alive() then self:Kill() end
end

function MuR.HandleDyingDamage(ply, dmg)
	if not ply:IsDying() then return false end

	if MuR.IsStructuralDamage(ply, dmg) then
		ply:FinishDying(dmg:GetAttacker(), dmg:GetInflictor())
		return true
	end

	local incoming = dmg:GetDamage()

	if CurTime() < ply:GetNW2Float("MuR.DyingGraceUntil", 0) then
		ply:ShortenDyingWindow(incoming * 0.15)
		dmg:SetDamage(0)
		return true
	end

	if incoming >= cvFinishDamage:GetFloat() then
		ply:FinishDying(dmg:GetAttacker(), dmg:GetInflictor())
		return true
	end

	ply:ShortenDyingWindow(incoming * 0.25)
	dmg:SetDamage(0)
	return true
end

hook.Add("PlayerPostThink", "MuR.DyingThink", function(ply)
	if not ply:Alive() or not ply:IsDying() then return end

	local now = CurTime()
	if (ply.MuR_NextDyingTick or 0) > now then return end
	ply.MuR_NextDyingTick = now + 0.5

	ply:SetNW2Bool("ForceProneOnly", true)
	ply.IsRagStanding = false
	ply:SetNW2Float("Stamina", 0)

	if not IsValid(ply:GetRD()) then
		ply:ForceDyingCollapse()
	end

	local rate = math.max(ply:GetBleedRate() * DYING_BLEED_MULTIPLIER, DYING_MIN_BLEED)
	ply:AddBloodVolume(-rate * 0.5)

	if ply:GetBloodVolume() <= 0 then
		ply:FinishDying(ply.MuR_DyingAttacker)
	end
end)

hook.Add("PlayerSpawn", "MuR.DyingReset", function(ply)
	clearDyingState(ply)
	ply.MuR_DyingAttacker = nil
	ply:SetNW2Bool("ForceProneOnly", false)

	ply.MuR_StructuralDeath = nil
	ply.DeathBlowHead = nil
	ply.DeathBlowHeadCut = nil
	ply.DeathBlowSpine = nil
	ply.DeathBlowBone = nil
end)

hook.Add("PlayerDeath", "MuR.DyingClear", function(ply)
	clearDyingState(ply)
end)

function MuR.ForceKill(ply, attacker)
	if not IsValid(ply) or not ply:Alive() then return end

	clearDyingState(ply)
	ply.MuR_TerminalDamage = true

	if IsValid(attacker) then
		local dmg = DamageInfo()
		dmg:SetAttacker(attacker)
		dmg:SetInflictor(attacker)
		dmg:SetDamageType(DMG_DIRECT)
		dmg:SetDamage(ply:Health() + 100)
		dmg:SetDamagePosition(ply:WorldSpaceCenter())
		ply:TakeDamageInfo(dmg)
	end

	if ply:Alive() then ply:Kill() end
	ply.MuR_TerminalDamage = nil
end

function meta:IsCombatEffective()
	return self:Alive()
		and not self:IsDying()
		and not self:GetNW2Bool("IsUnconscious", false)
end

function meta:IsRoundParticipant()
	if not self:Alive() or self:IsDying() then return false end
	return not (self:GetNW2Bool("MuR.Cuffed", false) and self:GetNW2Bool("MuR.CuffLawful", false))
end

function MuR:GetActivePlayers()
	local out = {}
	for _, ply in player.Iterator() do
		if ply:IsCombatEffective() then out[#out + 1] = ply end
	end

	return out
end
