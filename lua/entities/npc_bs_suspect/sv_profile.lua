-- Профиль роли: гражданский или подозреваемый, личность, ловушки, гранаты.
--
-- Розыгрыш обязан завершиться в CustomOnInitialize: mode14.SpawnSuspectNPC
-- читает ent.IsSuspect СИНХРОННО сразу после Spawn, чтобы выдать оружие.

--------------------------------------------------------------------------------
-- Раздача ролей
--------------------------------------------------------------------------------

function ENT:InitializeProfile()
	if math.random(100) <= 35 then
		self:SetupCivilian()
	else
		self:SetupSuspect()
	end

	self:InitializePersonality()
	self:InitializeTrapVars()

	self:SetNW2Float("ArrestState", 0)

	-- Свой реестр живых подозреваемых/гражданских. Имя от VJ-версии: его
	-- читают mode14 и голосовая команда ror_police_surrender.
	MuR.ActiveSuspects = MuR.ActiveSuspects or setmetatable({}, {__mode = "k"})
	MuR.ActiveSuspects[self] = true
end

--------------------------------------------------------------------------------
-- Гражданский
--------------------------------------------------------------------------------

function ENT:SetupCivilian()
	self.IsCivilian = true
	self.IsSuspect = nil
	self.BSFaction = "civilian"

	self:SetMaxHealth(40)
	self:SetHealth(40)

	-- Гражданский не ищет врагов и не дерётся (FindEnemy в init.lua закрыт).
	self.HasMeleeAttack = false
	self.DefaultWeapons = nil
	self.CanWander = true

	-- Поля читает mode14 и арест наручниками.
	self.CanBeRescued = true
	self.IsRescued = false
	self.IsEvacuating = false
	self.CivilianPenaltyMoney = 100
	self.CivilianPenaltyGuilt = math.random(10, 25)
	self.CivilianRescueReward = math.random(200, 400)

	self.Fear = 0
	self.LastFearPos = nil
	self.FleeDistance = 1500

	-- Каждый третий «гражданский» — подозреваемый со спрятанным стволом.
	-- Раскрывается при угрозе (sv_civilian.lua:RevealAsHostile).
	if math.random(1, 3) == 1 then
		self.IsHiddenSuspect = true
		self.HasRevealed = false
		self.HiddenWeapon = math.random(1, 3) == 1 and "bswep_sus_secondary" or "bswep_sus_melee"
	end

	-- Гражданский сдаётся от страха, а не по боевому расчёту.
	self.BaseSurrenderChance = 70
	self.FakeSurrenderChance = 0
	self.ReactionTime = 0.9

	-- Мирные реплики вместо подозреваемых.
	self.SoundTbl_Surrender = {
		"vo/npc/male01/illstayhere01.wav",
		"vo/npc/male01/help01.wav",
		"vo/npc/male01/imstickinghere01.wav",
		"vo/npc/male01/no02.wav",
		"vo/npc/male01/ohno.wav",
		"vo/npc/male01/pleaseno.wav",
		"vo/npc/male01/imhurt01.wav",
		"vo/npc/male01/imhurt02.wav",
	}
end

--------------------------------------------------------------------------------
-- Подозреваемый
--------------------------------------------------------------------------------

function ENT:SetupSuspect()
	self.IsSuspect = true
	self.IsCivilian = nil
	-- Поле-синоним из VJ-версии: старые хуки гейммода могут искать его.
	self.SuspectNPC = true

	-- Часть подозреваемых не бродит: держат позицию, как того требует засада
	-- режима. У остальных CanWander наследуется от базы.
	if math.random(100) > 60 then self.CanWander = false end
end

--------------------------------------------------------------------------------
-- Личность
--------------------------------------------------------------------------------

--
-- Личность определяет сдачу, фальшивую сдачу, время реакции и точность.
--
-- Weapon_Accuracy у нашей базы — множитель РАЗБРОСА: больше значит хуже.
-- Поэтому у агрессивного 0.85 (лучше паспортного), у труса 1.4.
--
-- force — форсировать личность (раскрытие скрытого подозреваемого).
--
function ENT:InitializePersonality(force)
	local personality = force

	if not personality then
		if self.IsCivilian and not self.IsHiddenSuspect then
			personality = "coward"
		else
			local roll = math.random(100)

			if roll <= 20 then
				personality = "aggressive"
			elseif roll <= 60 then
				personality = "cautious"
			else
				personality = "coward"
			end
		end
	end

	self.Personality = personality

	if personality == "aggressive" then
		self.BaseSurrenderChance = 15
		self.FakeSurrenderChance = 40
		self.ReactionTime = 0.3
		self.Weapon_Accuracy = 0.85
		-- Ломается под огнём только от очень сильного урона.
		self.BreaksUnderFire = false
	elseif personality == "cautious" then
		self.BaseSurrenderChance = 35
		self.FakeSurrenderChance = 20
		self.ReactionTime = 0.6
		self.Weapon_Accuracy = 1.0
		self.BreaksUnderFire = math.random(2) == 1
	else
		self.BaseSurrenderChance = 60
		self.FakeSurrenderChance = 8
		self.ReactionTime = 0.9
		self.Weapon_Accuracy = 1.4
		self.BreaksUnderFire = true
	end

	self.SuppressionLevel = 0
	self.MaxSuppression = 100

	-- Гранаты — только агрессивным подозреваемым.
	self.HasGrenades = (not self.IsCivilian) and personality == "aggressive"
end

--------------------------------------------------------------------------------
-- Ловушки
--------------------------------------------------------------------------------

function ENT:InitializeTrapVars()
	self.CanSetTraps = (not self.IsCivilian)
		and (self.Personality == "cautious" or self.Personality == "aggressive")
		and math.random(100) <= 70

	self.TrapsPlaced = 0
	self.MaxTraps = 5
	self.NextTrapTime = CurTime() + math.Rand(10, 30)
	self.LastTrapPos = nil
end
