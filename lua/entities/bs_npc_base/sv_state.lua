-- Инициализация, состояния, тик.

--
-- Отладочные конвары движка. Движковых NPC они останавливают силами самого
-- движка, а nextbot про них не знает вовсе — значит спрашиваем сами.
--
-- GetConVar кэшируем: он делает поиск по строке, а спрашивают это каждый тик на
-- каждом боте.
--
-- Кэш заполняется при первом УСПЕШНОМ поиске, а не на загрузке файла: движковый
-- конвар в этот момент может быть ещё не зарегистрирован, и разовый GetConVar
-- запомнил бы nil навсегда — фича молча не работала бы вовсе.
local cvarAIDisabled, cvarIgnorePlayers

function MuR.NPC.AIDisabled()
	cvarAIDisabled = cvarAIDisabled or GetConVar("ai_disabled")

	return cvarAIDisabled ~= nil and cvarAIDisabled:GetBool()
end

--
-- ai_ignoreplayers: NPC перестают замечать игроков, но продолжают жить своей
-- жизнью и драться между собой. Именно так ведёт себя движок, и именно этим
-- конвар отличается от ai_disabled.
--
function MuR.NPC.IgnorePlayers()
	cvarIgnorePlayers = cvarIgnorePlayers or GetConVar("ai_ignoreplayers")

	return cvarIgnorePlayers ~= nil and cvarIgnorePlayers:GetBool()
end

local function OrderBounds(a, b)
	local mins = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
	local maxs = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))

	return mins, maxs
end

function ENT:Initialize()
	self:SetModel(MuR.Pick(self.Model))

	self.NPCState = BS_STATE_NONE
	self.StateUntil = 0
	self.Cooldowns = {}
	self.Goal = nil
	self.Enemy = NULL
	self.LastSawEnemy = 0
	self.BSLastHitGroup = HITGROUP_GENERIC
	self.NextEnemyScan = 0
	self.NextFootStep = 0
	self.NextIdleSound = CurTime() + MuR.Roll(self.IdleSoundInterval, 10)
	self.NextMeleeAttackT = 0
	self.NextRangeAttackT = 0
	self.NextLeapAttackT = 0
	self.NextFlinchT = 0
	self.AnimLockUntil = 0
	self.AnimationTranslations = self.AnimationTranslations or {}

	-- Своя копия: подстановка недостающих активити дописывает сюда, а общую
	-- таблицу класса портить нельзя — у одного класса бывает несколько моделей
	-- с разными наборами анимаций.
	self.MoveActivities = table.Copy(self.MoveActivities)
	self.ActivityCache = nil

	local mins, maxs = OrderBounds(self.CollisionMins, self.CollisionMaxs)
	self:SetCollisionBounds(mins, maxs)

	self:SetMaxHealth(self.StartHealth)
	self:SetHealth(self.StartHealth)
	self:SetBloodColor(self.BloodColorEngine)

	if self.RandomSkins then
		local count = self:SkinCount()
		if count and count > 1 then self:SetSkin(math.random(0, count - 1)) end
	end

	if self.RandomBodygroups then
		for i = 0, self:GetNumBodyGroups() - 1 do
			local count = self:GetBodygroupCount(i)
			if count and count > 1 then self:SetBodygroup(i, math.random(0, count - 1)) end
		end
	end

	self:SetupLocomotion()

	--
	-- Через PlayActivity, а НЕ голым StartActivity: у моделей на игроцком
	-- скелете ACT_IDLE нет вовсе, и прямой вызов оставлял только что
	-- заспавненного бойца в референс-позе — той самой букве Т — до первого
	-- решения корутины поведения.
	--
	self:PlayActivity(ACT_IDLE)

	if self.CustomOnInitialize then self:CustomOnInitialize() end

	-- Отдельный хук для промежуточных баз (bs_npc_human), чтобы им не
	-- приходилось перекрывать Initialize: self.BaseClass.Initialize при трёх
	-- уровнях наследования зовёт сам себя и уходит в бесконечную рекурсию.
	if self.PostInitialize then self:PostInitialize() end
end

function ENT:OnRemove()
	self:ClearGoal()
	-- Слот в группе обязан освободиться вместе с NPC, иначе живые обходят с
	-- фланга, считая, что в лоб уже кто-то давит, а давить некому.
	MuR.NPC.ReleaseRole(self)
	if self.CustomOnRemove then self:CustomOnRemove() end
end

--------------------------------------------------------------------------------
-- Состояния (замена VJ:SetState)
--------------------------------------------------------------------------------

-- Вызов без аргумента возвращает NPC в обычное поведение — так же, как
-- VJ:SetState() без аргументов.
function ENT:SetState(state, duration)
	state = state or BS_STATE_NONE
	self.NPCState = state

	if state == BS_STATE_NONE then
		self.StateUntil = 0
		return
	end

	self.StateUntil = duration and (CurTime() + duration) or 0

	-- Заморозка обязана снять текущий приказ: иначе корутина продолжит
	-- дотягивать путь, как только состояние отпустит, и NPC уедет туда,
	-- куда его посылали до заморозки.
	self:ClearGoal()
	self.loco:SetVelocity(vector_origin)
end

function ENT:GetState()
	return self.NPCState or BS_STATE_NONE
end

function ENT:CanMove()
	return self:GetState() == BS_STATE_NONE
end

function ENT:CanAttack()
	if self:GetState() ~= BS_STATE_NONE then return false end
	if CurTime() < (self.AnimLockUntil or 0) then return false end

	return true
end

-- Занят анимацией или атакой. Раньше это был VJ:IsBusy().
function ENT:IsBusy()
	if self:GetState() ~= BS_STATE_NONE then return true end
	if CurTime() < (self.AnimLockUntil or 0) then return true end
	if self.IsAttacking then return true end

	return false
end

--------------------------------------------------------------------------------
-- Кулдауны
--------------------------------------------------------------------------------

function ENT:SetCooldown(name, duration)
	self.Cooldowns = self.Cooldowns or {}
	self.Cooldowns[name] = CurTime() + (duration or 0)
end

function ENT:GetCooldown(name)
	local t = self.Cooldowns and self.Cooldowns[name]
	if not t then return 0 end

	return math.max(0, t - CurTime())
end

function ENT:OnCooldown(name)
	return self:GetCooldown(name) > 0
end

--------------------------------------------------------------------------------
-- Тик
--------------------------------------------------------------------------------

function ENT:Think()
	if self:Health() <= 0 then return end

	--
	-- Перелаз и подъём по лестнице ведут корпус вручную и не должны ни с чем
	-- соседствовать. Их проверяем ДО ai_disabled: обе механики двигают бота
	-- скриптом по времени, и обрыв на середине оставил бы его висеть в воздухе
	-- над оградой. Длятся они доли секунды и заканчиваются сами.
	--
	if self:UpdateVault() then return end
	if self:UpdateLadder() then return end

	self:UpdateDoorWait()

	if MuR.NPC.AIDisabled() then
		self:ClearGoal()
		self.loco:SetVelocity(vector_origin)
		self:PlayActivity(ACT_IDLE)

		return
	end

	local now = CurTime()

	if self.StateUntil > 0 and now >= self.StateUntil then
		self:SetState(BS_STATE_NONE)
	end

	self:UpdateEnemy()
	self:UpdateSeparation()
	self:ProbeAhead()
	self:StuckWatchdog()
	self:IdleSoundThink()

	if self.CustomOnThink then self:CustomOnThink() end
	if self.OnThink then self:OnThink() end
end

function ENT:IdleSoundThink()
	local tbl = IsValid(self:GetEnemy()) and self.SoundTbl_CombatIdle or self.SoundTbl_Idle
	if not tbl then return end
	if CurTime() < self.NextIdleSound then return end

	self.NextIdleSound = CurTime() + MuR.Roll(self.IdleSoundInterval, 10)
	MuR.EmitSound(self, tbl, 70, math.random(95, 105))
end

--------------------------------------------------------------------------------
-- Скорости
--------------------------------------------------------------------------------

-- Общий множитель: им пользуются режимы, чтобы разгонять или замедлять NPC,
-- не переписывая их описания (волны Last Stand, рывки Заражения).
function ENT:GetSpeedScale()
	return self.SpeedScale or 1
end

function ENT:GetWalkSpeed()
	return self.WalkSpeed * self:GetSpeedScale()
end

function ENT:GetRunSpeed()
	return self.RunSpeed * self:GetSpeedScale()
end
