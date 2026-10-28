-- Гражданские: страх, побег, вставание на колени от ужаса, раскрытие
-- скрытых подозреваемых и спасение полицейским (E).
--
-- Страх 0..100: растёт от выстрелов, взрывов, трупов и вооружённых людей
-- рядом; медленно спадает в тишине. Две планки: побег и паника с коленями.

local FEAR_FLEE = 40
local FEAR_COWER = 75

--------------------------------------------------------------------------------
-- Страх
--------------------------------------------------------------------------------

function ENT:AddFear(amount)
	if self:Health() <= 0 then return end
	if not self.IsCivilian or self.HasRevealed then return end

	self.Fear = math.Clamp((self.Fear or 0) + amount, 0, 100)

	-- При сильном страхе кричит.
	if amount >= 15 then MuR.EmitSound(self, MuR.Pick(self.SoundTbl_Fear), 75, 100) end
end

--
-- Мирный тик. Зовётся из CustomOnThink.
--
function ENT:CivilianThink()
	if not self.IsCivilian or self.HasRevealed then return end
	if self.Surrendering or self.IsRescued then return end

	local now = CurTime()

	-- Вооружённые люди в поле зрения пугают.
	if now >= (self.NextFearScan or 0) then
		self.NextFearScan = now + 1

		for _, ply in player.Iterator() do
			if ply:Alive() and self:GetPos():DistToSqr(ply:GetPos()) < 400 * 400 and self:HasLOS(ply) then
				local wep = ply:GetActiveWeapon()

				if IsValid(wep) and wep:GetClass() ~= "weapon_physcannon" then
					self:AddFear(4)
				end
			end
		end
	end

	-- В тишине страх утихает.
	if now >= (self.NextFearDecay or 0) then
		self.NextFearDecay = now + 1

		if (self.Fear or 0) > 0 then self.Fear = math.max(0, self.Fear - 2) end
	end

	local fear = self.Fear or 0

	if fear >= FEAR_COWER then
		-- Паника: сесть на колени и не вставать, пока не арестуют/спасут.
		self.PermanentSurrender = true
		self:StartSurrender(nil)

		return
	end

	if fear >= FEAR_FLEE and now >= (self.NextFleeCheck or 0) then
		self.NextFleeCheck = now + 2

		self:FleeFromDanger(self.LastFearPos)
	end
end

--
-- Побежать от опасности. sourcePos — точка, от которой убегать; без неё
-- бежим вперёд по направлению взгляда.
--
function ENT:FleeFromDanger(sourcePos)
	if self.Surrendering or self.IsRescued then return end
	if self:Health() <= 0 then return end
	if not self:CanMove() then return end

	local from = isvector(sourcePos) and sourcePos or self:GetPos()

	local away = self:GetPos() - from

	if away:LengthSqr() < 1 then away = self:GetAngles():Forward() end
	away.z = 0
	away:Normalize()

	local target = self:GetPos() + away * math.Rand(300, self.FleeDistance or 600)

	-- Упираться в стену нечего: обрезаем цель до стены.
	local tr = util.TraceLine({
		start = self:GetPos(),
		endpos = target,
		filter = {self},
		mask = MASK_NPCSOLID,
	})

	if tr.Hit then target = tr.HitPos - away * 40 end

	self:OrderMove(target, {run = true, maxage = 10})
end

--------------------------------------------------------------------------------
-- Раскрытие скрытого подозреваемого
--------------------------------------------------------------------------------

--
-- Скрытый подозреваемый выходит из роли: фракция, оружие, личность.
-- target — кого атаковать первым.
--
function ENT:RevealAsHostile(target)
	if not self.IsHiddenSuspect or self.HasRevealed then return end

	self.HasRevealed = true
	self.IsCivilian = nil
	self.IsSuspect = true
	self.SuspectNPC = true
	self.BSFaction = nil -- возвращается ENT.Faction = "suspect"
	self.Fear = 0
	self.FakeSurrendering = nil

	-- Раскрывшийся дерётся как агрессивный, кем и был.
	self:InitializePersonality("aggressive")

	if self.Surrendering then
		-- Мог раскрываться прямо с колен.
		self.Surrendering = nil
		self.PermanentSurrender = nil
		self:SetNW2Float("ArrestState", 0)
		self:SetState(BS_STATE_NONE)
		self.AnimLockUntil = 0
	end

	if not IsValid(self:GetActiveWeapon()) then
		self:Give(self.HiddenWeapon or "bswep_sus_melee")
	end

	if IsValid(target) then self:ForceSetEnemy(target) end

	hook.Run("BloodshedHiddenSuspectRevealed", self, target)
end

--------------------------------------------------------------------------------
-- Спасение гражданского (E полицейского)
--------------------------------------------------------------------------------

--
-- Полицейский нажал E на сдавшемся гражданском: тот эвакуируется и приносит
-- очки. Зовётся хуком PlayerUse из init.lua.
--
function ENT:RescueCivilian(rescuer)
	if not self.IsCivilian or self.HasRevealed then return false end
	if self.IsRescued or self.IsEvacuating then return false end
	if not IsValid(rescuer) or not rescuer:IsPlayer() or not rescuer:Alive() then return false end
	if isfunction(rescuer.IsRolePolice) and not rescuer:IsRolePolice() then return false end

	-- Стоит спокойно — сначала его надо заставить встать на колени страхом.
	if not self.Surrendering then
		self:AddFear(25)

		return false
	end

	self.IsRescued = true
	self.IsEvacuating = true

	local reward = self.CivilianRescueReward or 250

	hook.Run("BloodshedHostageRescued", rescuer, self, reward)

	if MuR.Gamemode == 14 then
		MuR:Mode14Score(rescuer, "civilian_secured", self)

		MuR.Mode14 = MuR.Mode14 or {}
		MuR.Mode14.CiviliansResolved = (MuR.Mode14.CiviliansResolved or 0) + 1

		MuR:Mode14RecountObjectives()
	end

	if isfunction(rescuer.PlayVoiceLine) then
		rescuer:PlayVoiceLine("ror_police_reportcivilianarrested")
	end

	-- Встать и уйти в точку эвакуации.
	self:StopSurrendering()

	local evacPos = MuR.GetRandomPos and MuR:GetRandomPos(false)

	if isvector(evacPos) then self:OrderMove(evacPos, {run = true}) end

	-- Ушёл — считаем спасённым.
	timer.Simple(20, function()
		if IsValid(self) then self:Remove() end
	end)

	return true
end
