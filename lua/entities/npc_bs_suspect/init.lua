AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

include("sv_profile.lua")
include("sv_surrender.lua")
include("sv_civilian.lua")
include("sv_flashbang.lua")
include("sv_traps.lua")

--
-- Подозреваемый/гражданский режима «Розыск». Роль разыгрывается в
-- CustomOnInitialize; капсюльные хуки (голосовая сдача, спасение, слух)
-- зарегистрированы внизу файла.
--

--------------------------------------------------------------------------------
-- Жизненный цикл
--------------------------------------------------------------------------------

-- Розыгрыш обязан быть СИНХРОННЫМ: mode14.SpawnSuspectNPC сразу после Spawn
-- читает ent.IsSuspect, чтобы выдать оружие.
function ENT:CustomOnInitialize()
	self:InitializeProfile()
end

function ENT:CustomOnRemove()
	if istable(MuR.ActiveSuspects) then MuR.ActiveSuspects[self] = nil end
end

--
-- Гражданские и скрытые подозреваемые сами врагов не ищут: раскрывает их
-- только угроза (урон/флешка) или голосовая команда.
--
function ENT:FindEnemy()
	if self.IsCivilian and not self.HasRevealed then return nil end

	return self.BaseClass.FindEnemy(self)
end

-- Первая цель найдена: личность задаёт время реакции до первого выстрела.
function ENT:OnAlert(ent)
	self.NextWeaponFire = CurTime() + (self.ReactionTime or 0.5)
	self:AddSuppression(20)
end

function ENT:CustomOnThink()
	if self:Health() <= 0 then return end

	-- Подавление гаснет в тишине.
	if (self.SuppressionLevel or 0) > 0 and CurTime() >= (self.NextSuppressionDecay or 0) then
		self.NextSuppressionDecay = CurTime() + 1
		self.SuppressionLevel = math.max(0, self.SuppressionLevel - 3)
	end

	if self.Surrendering then
		self:SurrenderThink()
		self:FakeSurrenderThink()
		return
	end

	-- Оглушённый флешкой сидит без действий.
	if CurTime() < (self.FlashbangEnd or 0) then return end

	if self.IsCivilian and not self.HasRevealed then
		self:CivilianThink()
		return
	end

	self:TryPlaceTrap()
end

--------------------------------------------------------------------------------
-- Урон
--------------------------------------------------------------------------------

function ENT:CustomOnTakeDamage_BeforeDamage(dmginfo, hitgroup)
	if self:Health() <= 0 or self.Surrendering then return end

	local dmg = dmginfo:GetDamage()
	local attacker = dmginfo:GetAttacker()

	self:AddSuppression(dmg * 0.5)

	-- Скрытый подозреваемый под обстрелом не сдаётся, а раскрывается.
	if self.IsHiddenSuspect and not self.HasRevealed then
		self:RevealAsHostile(IsValid(attacker) and attacker or nil)
		return
	end

	-- Гражданский от боли паникует, а не воюет.
	if self.IsCivilian then
		self:AddFear(math.max(15, dmg))
		self.LastFearPos = dmginfo:GetDamagePosition()
		return
	end

	-- Сильное попадание ломает слабовольных (aggressive не ломается).
	if dmg >= 20 and self.BreaksUnderFire and IsValid(attacker) then
		self:TrySurrender(true, attacker)
	end
end

-- Добил цель — короткая победная реплика.
function ENT:CustomOnEnemyKilled(dmginfo, hitgroup)
	if self.IsCivilian and not self.HasRevealed then return end

	MuR.EmitSound(self, MuR.Pick(self.SoundTbl_Kill), 75, 100)
end

-- Штраф за убитого гражданского вешает сам режим через хук.
function ENT:OnDeath(dmginfo, hitgroup, status)
	if not self.IsCivilian or self.HasRevealed then return end

	local attacker = IsValid(dmginfo) and dmginfo:GetAttacker() or nil

	hook.Run("BloodshedCivilianKilled", attacker, self, self.CivilianPenaltyMoney, self.CivilianPenaltyGuilt)
end

--------------------------------------------------------------------------------
-- Слух
--------------------------------------------------------------------------------

--
-- pos — откуда звук, kind — "gunshot"/"breach"/"door"/"footstep",
-- loud — громкость (у оружия с глушителем 0.35).
--
function ENT:HearSound(pos, kind, loud)
	if self:Health() <= 0 then return end
	if not isvector(pos) then return end

	if self.IsCivilian and not self.HasRevealed then
		self:AddFear(kind == "gunshot" and 30 * (loud or 1) or 12)
		self.LastFearPos = pos
		return
	end

	if self.Surrendering then return end
	if kind == "footstep" then return end

	if kind == "breach" then self:AddSuppression(15) end

	-- Некому стрелять — хотя бы проверить, откуда шумело.
	if not IsValid(self:GetEnemy()) then self:RememberEnemyAt(pos) end
end

--------------------------------------------------------------------------------
-- Голосовая команда «Всем стоять!» (ror_police_surrender)
--------------------------------------------------------------------------------

--
-- Полицейский кричит сдаться: все подозреваемые/гражданские в радиусе 800,
-- которых он видит, по очереди поворачиваются к нему и пробуют сдаться.
-- Возврат зовётся из sv_commands.lua; true — команда состоялась.
--
function MuR.ShoutSurrender(ply)
	if MuR.Gamemode ~= 14 then return false end
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if isfunction(ply.IsRolePolice) and not ply:IsRolePolice() then return false end
	if CurTime() < (ply.DelayBeforeNextUseSurrender or 0) then return false end

	local targets = {}

	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 800)) do
		if IsValid(ent) and ent.IsRoNSuspect and not ent.Surrendering and ent:Health() > 0
			and ply:Visible(ent) then
			targets[#targets + 1] = ent
		end
	end

	if #targets == 0 then return false end

	ply.DelayBeforeNextUseSurrender = CurTime() + 3

	table.sort(targets, function(a, b)
		return a:GetPos():DistToSqr(ply:GetPos()) < b:GetPos():DistToSqr(ply:GetPos())
	end)

	for i, ent in ipairs(targets) do
		timer.Simple(i * 0.1, function()
			if not IsValid(ent) or not IsValid(ply) then return end
			if ent.Surrendering or ent:Health() <= 0 then return end

			local ang = (ent:GetPos() - ply:GetPos()):Angle()
			ent:SetAngles(Angle(0, ang.y, 0))

			if ent.IsCivilian and not ent.IsHiddenSuspect then
				ent:FullSurrender()
			elseif not ent:TrySurrender(false, ply) then
				-- Отказался: теперь он точно знает, где полицейский.
				if not IsValid(ent:GetEnemy()) then ent:ForceSetEnemy(ply) end
			end
		end)
	end

	return true
end

--------------------------------------------------------------------------------
-- Спасение гражданского (E полицейского)
--------------------------------------------------------------------------------

hook.Add("PlayerUse", "MuR.RescueCivilian", function(ply, ent)
	if not IsValid(ent) or not ent.IsRoNSuspect then return end
	if not ent.IsCivilian or ent.HasRevealed then return end
	if ent.IsRescued or ent.IsEvacuating then return end
	if not ply:Alive() then return end
	if isfunction(ply.IsRolePolice) and not ply:IsRolePolice() then return end
	if CurTime() < (ply.NextRescueUse or 0) then return end
	if ply:GetPos():DistToSqr(ent:GetPos()) > 100 * 100 then return end

	ply.NextRescueUse = CurTime() + 0.5

	ent:RescueCivilian(ply)
end)

--------------------------------------------------------------------------------
-- Слух на выстрелы и звуки мира (общие хуки)
--------------------------------------------------------------------------------

hook.Add("EntityFireBullets", "BloodshedSuspectHearGunfire", function(ent, data)
	if not IsValid(ent) or not istable(MuR.ActiveSuspects) then return end

	local loud = 1

	local wep = ent:IsPlayer() and ent:GetActiveWeapon() or nil
	if IsValid(wep) and wep.Silenced then loud = 0.35 end

	local r2 = (3000 * loud) ^ 2
	local pos = ent.GetEyeOrigin and ent:GetEyeOrigin() or ent:GetPos()

	for npc in pairs(MuR.ActiveSuspects) do
		if IsValid(npc) and npc:GetPos():DistToSqr(pos) < r2 then
			npc:HearSound(pos, "gunshot", loud)
		end
	end
end)

--
-- Классификация по имени звука с кэшем: полный перебор строк на каждый чих
-- мира — дорого.
--
local soundKinds = {}

local function ClassifySound(name)
	local kind = soundKinds[name]
	if kind ~= nil then return kind end

	local lower = string.lower(name)

	if string.find(lower, "break", 1, true) or string.find(lower, "breach", 1, true)
		or string.find(lower, "kick", 1, true) or string.find(lower, "smash", 1, true) then
		kind = "breach"
	elseif string.find(lower, "door", 1, true) then
		kind = "door"
	elseif string.find(lower, "footstep", 1, true) or string.find(lower, "/steps/", 1, true) then
		kind = "footstep"
	else
		kind = false
	end

	soundKinds[name] = kind
	return kind
end

hook.Add("EntityEmitSound", "BloodshedSuspectHearSounds", function(data)
	if not istable(data) or not istable(MuR.ActiveSuspects) then return end

	local sndName = data.SoundName
	local sndPos = data.Pos
	local sndVol = data.Volume

	if not IsValid(data.Entity) or not isstring(sndName) or not isvector(sndPos) then return end

	local kind = ClassifySound(sndName)
	if not kind then return end

	local radius = (kind == "breach" and 1200) or (kind == "door" and 600) or 300
	local fear = (kind == "breach" and 55) or (kind == "door" and 12) or 5
	local r2 = radius * radius

	for npc in pairs(MuR.ActiveSuspects) do
		if IsValid(npc) and npc:GetPos():DistToSqr(sndPos) < r2 then
			if npc.IsCivilian and not npc.HasRevealed then
				npc:AddFear(fear)
				npc.LastFearPos = sndPos
			else
				npc:HearSound(sndPos, kind, sndVol)
			end
		end
	end
end)
