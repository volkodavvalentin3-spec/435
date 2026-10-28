AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

--
-- Наёмники ЧВК. Порт npc_vj_bloodshed_pmc_base на собственную базу.
--
-- Отличие от полиции по смыслу: полиция задерживает по уровню розыска, а эти
-- работают по контракту — стреляют во всё враждебное и вяжут только тех, кто
-- уже не может сопротивляться.
--

-- Реестр живых наёмников. Имя оставлено от VJ-версии: его читает mode24
-- (подсчёт волны, «отряд уничтожен») и трогать тот код незачем.
MuR.PMCEnemies = MuR.PMCEnemies or setmetatable({}, {__mode = "k"})

--
-- Откат на бросок гранат ОБЩИЙ для всех наёмников, а не персональный.
-- Иначе отряд из шести человек закидывает игрока шестью гранатами разом: у
-- каждого свой кулдаун, и все они истекают одновременно.
--
local grenadeCooldowns = {}

-- Готов ли общий откат. Только вопрос, без захвата: спрашивают до розыгрыша.
local function GrenadeReady(key, cooldown)
	return CurTime() - (grenadeCooldowns[key or "frag"] or 0) >= (cooldown or 3)
end

-- Занять окно отряда под свой бросок.
local function ClaimGrenade(key, cooldown)
	if not GrenadeReady(key, cooldown) then return false end

	grenadeCooldowns[key or "frag"] = CurTime()

	return true
end

--------------------------------------------------------------------------------
-- Спавн
--------------------------------------------------------------------------------

local function PickWeighted(list)
	local total = 0
	for _, v in ipairs(list) do total = total + v.weight end
	if total <= 0 then return list[1] and list[1].id end

	local roll, acc = math.random() * total, 0

	for _, v in ipairs(list) do
		acc = acc + v.weight
		if roll <= acc then return v.id end
	end

	return list[#list].id
end

function ENT:CustomOnInitialize()
	self.PMCCooldowns = {}

	-- Разворачиваем список стволов из функции варианта. CustomOnInitialize идёт
	-- до отложенной выдачи оружия в PostInitialize, так что успеваем.
	self.DefaultWeapons = self:GetSpawnWeapons()
	self.ArmorHP = self.ArmorMaxHP or 0
	self.BaseRetreatDistance = self.Weapon_RetreatDistance

	self:AssignArchetype()

	MuR.PMCEnemies[self] = true
end

function ENT:CustomOnRemove()
	MuR.PMCEnemies[self] = nil
	if self.PMCOnRemove then self:PMCOnRemove() end
end

--
-- Манера боя. Кроме дистанции и точности архетип задаёт AdvanceStyle — то, как
-- боец вообще идёт на цель. Из-за него отряд перестаёт быть однородной толпой,
-- бегущей в одну точку.
--
function ENT:AssignArchetype()
	self.PMCArchetype = self.ForcedArchetype or PickWeighted(self.PMCArchetypes)

	if self.PMCArchetype == "rusher" then
		-- Лезет в упор и лупит от бедра: разброс больше, дистанция меньше,
		-- гранату кидает почти вплотную. PMCAccuracyMul — множитель РАЗБРОСА,
		-- как его понимает mode24, то есть больше значит хуже.
		self.GrenadeMinDistance = 150
		self.Weapon_RetreatDistance = 40
		self.PMCAccuracyMul = 1.25
		self.AdvanceStyle = "rush"
		-- За укрытием не засиживается: оно ему пересадочная станция, а не позиция.
		self.PMCCoverStyle = {peek = 30, blind = 15, slide = 15, advance = 30, hold = 5}
	elseif self.PMCArchetype == "cautious" then
		-- Идёт перебежками от угла к углу и охотно работает по площадям.
		self.Weapon_RetreatDistance = 220
		self.FlinchChance = (self.FlinchChance or 2) * 2
		self.PMCAccuracyMul = 0.8
		self.AdvanceStyle = "bound"
		-- Работает от угла: выглядывает, бьёт вслепую, переходит к другому краю.
		self.PMCCoverStyle = {peek = 45, blind = 25, slide = 25, advance = 5, hold = 10}
	elseif self.PMCArchetype == "ambusher" then
		--
		-- Занимает точку с обзором и ждёт. Дальность огня ему нужнее
		-- скорострельности, поэтому дистанцию держит большую.
		--
		self.Weapon_RetreatDistance = 300
		self.PMCAccuracyMul = 0.9
		self.AdvanceStyle = "hold"
		self.CanWander = false
		self.SuppressInterval = {4, 7}
		-- Не наступает вовсе: сидит и стреляет по тем, кто высунулся.
		self.PMCCoverStyle = {peek = 45, blind = 5, slide = 10, advance = 0, hold = 40}
	else
		-- squad: держится своих, манера обычная.
		self.PMCAccuracyMul = 1
		self.AdvanceStyle = "rush"
		self.PMCCoverStyle = {peek = 45, blind = 20, slide = 20, advance = 10, hold = 15}
	end

	if self.ForcedAdvanceStyle then self.AdvanceStyle = self.ForcedAdvanceStyle end

	--
	-- Ambusher без манеры наступления обязан и за укрытием сидеть. Иначе
	-- архетип раздваивается: сближаться не идёт, а из-за угла рвётся вперёд.
	--
	if self.AdvanceStyle == "hold" then self.PMCCoverStyle.advance = 0 end

	self.BaseRetreatDistance = self.Weapon_RetreatDistance

	-- В волнах разброс всё равно перезадаёт mode24 по числу игроков, но в
	-- песочнице и в остальных режимах архетип обязан отличаться сам по себе.
	self.Weapon_Accuracy = self.Weapon_Accuracy * self.PMCAccuracyMul
end

--
-- Веса действий за укрытием у этого наёмника. Архетип назначает их в
-- AssignArchetype; до него (или у наследника без архетипа) работают базовые.
--
function ENT:GetCoverStyle()
	return self.PMCCoverStyle or self.BaseClass.GetCoverStyle(self)
end

--------------------------------------------------------------------------------
-- Кулдауны
--------------------------------------------------------------------------------

function ENT:SetPMCCooldown(name, time)
	self.PMCCooldowns = self.PMCCooldowns or {}
	self.PMCCooldowns[name] = CurTime() + time
end

function ENT:GetPMCCooldown(name)
	local t = self.PMCCooldowns and self.PMCCooldowns[name]

	return t and math.max(t - CurTime(), 0) or 0
end

--------------------------------------------------------------------------------
-- Броня
--------------------------------------------------------------------------------

--
-- Броня срезает долю урона, пока цела, и ломается со звуком.
--
-- Сделано хуком базы, а НЕ глобальным EntityTakeDamage, как было в VJ-версии:
-- там хук висел на всех сущностях карты и на каждое попадание проверял
-- принадлежность к ЧВК.
--
function ENT:CustomOnTakeDamage_BeforeDamage(dmginfo, hitgroup)
	local armor = self.ArmorHP or 0
	if armor <= 0 then return end

	local reduction = self.ArmorReduction or 0
	if reduction <= 0 then return end

	local amount = dmginfo:GetDamage()
	if amount <= 0 then return end

	local absorbed = math.min(armor, amount * reduction)
	dmginfo:SetDamage(amount - absorbed)

	self.ArmorHP = armor - absorbed

	if self.ArmorHP <= 0 then
		self.ArmorHP = 0
		self:EmitSound("physics/metal/metal_solid_break" .. math.random(1, 3) .. ".wav", 70)
	end
end

--------------------------------------------------------------------------------
-- Состояние «ранен»
--------------------------------------------------------------------------------

--
-- Раненый становится осторожнее независимо от архетипа: держит дистанцию
-- больше. Обратно не отыгрывается — подлечиться ему нечем.
--
function ENT:UpdateWoundedState()
	if self.PMCWounded then return end

	local maxHP = self:GetMaxHealth()
	if maxHP <= 0 then return end

	local threshold = self.PMCArchetype == "rusher"
		and self.WoundedThresholdRusher or self.WoundedThreshold

	if self:Health() / maxHP > threshold then return end

	self.PMCWounded = true
	self.Weapon_RetreatDistance = math.max(self.BaseRetreatDistance, self.WoundedRetreatDistance)
end

--------------------------------------------------------------------------------
-- Пленение сбитых
--------------------------------------------------------------------------------

local function Restrained(ply)
	return isfunction(ply.IsRestrained) and ply:IsRestrained()
end

-- Сбит с ног и сопротивляться не может.
function ENT:IsTargetDowned(ply)
	if not isfunction(ply.IsCombatEffective) then return false end

	return not ply:IsCombatEffective()
end

-- Годится ли этот вообще в пленные: игрок, живой, ещё не связанный.
function ENT:IsCaptureCandidate(ply)
	if not self.CanCapture then return false end
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if not isfunction(ply.RestrainToRagdoll) then return false end

	return not Restrained(ply)
end

--
-- Беспомощен ли настолько, что его проще взять живым.
--
-- Два условия сразу, и оба нужны. Только «мало здоровья» превратило бы каждую
-- перестрелку в погоню за подранком: наёмники прекращали бы огонь по любому
-- раненому и шли обниматься под стволы его напарников. Только «один» — тем
-- более: здоровый одиночка отобьётся.
--
function ENT:IsTargetHelpless(ply)
	--
	-- Только вблизи. Иначе наёмник на другом конце карты прекращал бы огонь по
	-- подранку, до которого ему идти полминуты, — и всё это время стоял бы со
	-- стволом вниз, потому что запрет огня дистанции не знает.
	--
	local reach = self.CaptureHelplessRange
	if self:GetPos():DistToSqr(ply:GetPos()) > reach * reach then return false end

	local maxHP = ply:GetMaxHealth()
	if maxHP <= 0 then return false end
	if ply:Health() / maxHP > self.CaptureWoundedFraction then return false end

	return not self:HasLivingAllyNear(ply)
end

-- Есть ли рядом с целью кто-то из её своих, кто может вмешаться.
function ENT:HasLivingAllyNear(ply)
	local radiusSqr = self.CaptureLonelyRadius * self.CaptureLonelyRadius
	local pos = ply:GetPos()

	for _, other in player.Iterator() do
		if other == ply then continue end
		if not other:Alive() then continue end
		if MuR.NPC.IsHostile(self, other) ~= MuR.NPC.IsHostile(self, ply) then continue end
		if pos:DistToSqr(other:GetPos()) > radiusSqr then continue end
		if not isfunction(other.IsCombatEffective) or other:IsCombatEffective() then return true end
	end

	return false
end

--
-- За кем ИДТИ, чтобы связать, вместо того чтобы добивать.
--
-- Только за сбитым. CaptureAnyInMelee сюда не входит намеренно: этот флаг
-- означает «вяжу того, до кого дотянулся ударом», а не «бросаю бой и иду
-- хватать». Пока он попадал и сюда, джаггернаут за весь бой не стрелял ни
-- разу — OnWeaponCanFire держал запрет огня по будущему пленному, а пленным у
-- него числился любой живой игрок.
--
function ENT:WantsToCapture(ply)
	if not self:IsCaptureCandidate(ply) then return false end
	if self:IsTargetDowned(ply) then return true end

	return self.CaptureHelpless and self:IsTargetHelpless(ply)
end

-- Кого вязать, когда удар уже дошёл.
function ENT:CanCaptureOnMelee(ply)
	if not self:IsCaptureCandidate(ply) then return false end

	return self.CaptureAnyInMelee or self:IsTargetDowned(ply)
end

function ENT:GetCapturePos(ply)
	if isfunction(ply.GetRD) then
		local rag = ply:GetRD()
		if IsValid(rag) then return rag:GetPos() end
	end

	return ply:GetPos()
end

function ENT:PerformCapture(ply)
	if not self:IsCaptureCandidate(ply) then return false end

	ply:RestrainToRagdoll("ziptie")
	self:EmitSound(")murdered/other/arrest_body.mp3", 60)

	local dur = self:PlayAnim(self.AnimTbl_MeleeAttack, true)
	if dur <= 0 then dur = 1 end
	self:SetState(BS_STATE_ANIM, dur)

	-- Связанный больше не цель: иначе наёмник стоит над ним до конца волны.
	if not self.CaptureAnyInMelee then self:ResetEnemy() end

	return true
end

--------------------------------------------------------------------------------
-- Гранаты
--------------------------------------------------------------------------------

function ENT:IsFleeingGrenade()
	return self.PMCFleeUntil ~= nil and CurTime() < self.PMCFleeUntil
end

--
-- Куда бросать.
--
-- Обычно в цель. Но если она сидит за углом дольше GrenadeFlushTime — по тому
-- месту, где её видели в последний раз: выкурить из-за укрытия граната и нужна,
-- а прежнее требование прямой видимости запрещало ровно этот случай.
--
-- nil — бросать не во что.
--
function ENT:GetGrenadeAimPos(enemy)
	if self:HasLOS(enemy) then
		-- Упреждение по высоте: граната летит по дуге.
		return enemy:WorldSpaceCenter() + Vector(0, 0, 48)
	end

	local pos = self.LastLOSPos
	if not isvector(pos) then return nil end

	local hidden = CurTime() - (self.LastLOSTime or 0)
	if hidden < self.GrenadeFlushTime then return nil end
	if hidden > self.EnemyMemoryTime then return nil end

	local aim = pos + Vector(0, 0, self.CoverCrouchEyeHeight)

	--
	-- Граната обязана хотя бы долететь до укрытия, а не отскочить от стены
	-- перед носом. Считаем по одной геометрии карты: свои и пропы ей не помеха,
	-- она их обкатывает.
	--
	local tr = util.TraceLine({
		start = self:LocalToWorld(self.GrenadeOffset),
		endpos = aim,
		mask = MASK_SOLID_BRUSHONLY,
	})

	if tr.Hit and tr.Fraction < self.GrenadeFlushClearance then return nil end

	return aim
end

function ENT:CanThrowGrenade(enemy)
	if (self.GrenadeChance or 0) <= 0 then return false end
	if not IsValid(enemy) then return false end
	if self:IsFleeingGrenade() then return false end
	if self:GetPMCCooldown("grenade_try") > 0 then return false end

	--
	-- Общий откат спрашиваем ДО розыгрыша и до личного таймера попытки.
	--
	-- Раньше он проверялся только в момент броска: удачный бросок отряда
	-- съедался тем, кто раскатал его в закрытое окно, и следующая попытка у
	-- него была лишь через GrenadeTryInterval. На короткой стычке это означало
	-- ноль гранат при честно работающей механике (замерено: 7 вызовов за 12
	-- секунд боя, из них 4 упёрлись в личный откат, ни одного броска).
	--
	if not GrenadeReady(self.GrenadeSharedKey, self.GrenadeSharedCooldown) then return false end

	self:SetPMCCooldown("grenade_try", self.GrenadeTryInterval)

	local aim = self:GetGrenadeAimPos(enemy)
	if not aim then return false end

	-- Дистанцию меряем до точки броска, а не до цели: вслепую бросают туда, где
	-- её видели, и это может быть заметно ближе или дальше.
	local dist = self:GetPos():Distance(aim)
	if dist < self.GrenadeMinDistance or dist > self.GrenadeMaxDistance then return false end

	if math.random(1, 100) > self.GrenadeChance then return false end

	self.GrenadeAimPos = aim

	return true
end

--
-- Бросок. Возвращает длительность, чтобы вызывающий подождал.
--
function ENT:ThrowGrenade(enemy)
	if not ClaimGrenade(self.GrenadeSharedKey, self.GrenadeSharedCooldown) then return 0 end

	local src = self:LocalToWorld(self.GrenadeOffset)
	local nade = ents.Create(self.GrenadeEntity)
	if not IsValid(nade) then return 0 end

	local aim = self.GrenadeAimPos or (enemy:WorldSpaceCenter() + Vector(0, 0, 48))
	self:FaceTowards(aim)

	nade:SetPos(src)
	nade:SetAngles(self:GetAngles())
	nade:SetOwner(self)
	nade.Owner = self
	nade.BSOwner = self
	nade:Spawn()
	nade:Activate()

	local dir = (aim - src):GetNormalized()
	local phys = nade:GetPhysicsObject()

	if IsValid(phys) then
		phys:SetVelocity(dir * self.GrenadeSpeed)
	else
		nade:SetVelocity(dir * self.GrenadeSpeed)
	end

	-- Хук варианта: осколочная/зажигательная/газовая настраивают снаряд тут.
	-- Имя оставлено от VJ-версии, чтобы описания вариантов переезжали как есть.
	if self.OnGrenadeAttackExecute then self:OnGrenadeAttackExecute(nade) end

	self.PMCFleeUntil = CurTime() + MuR.Roll(self.GrenadeFleeTime, 2)

	local dur = self:PlayAnim(self.AnimTbl_MeleeAttack, true)

	return dur > 0 and dur or 0.6
end

-- Отбежать от собственной гранаты.
function ENT:FleeBehaviour(enemy)
	local away = self:GetPos() - enemy:GetPos()
	away.z = 0
	if away:LengthSqr() < 1 then away = self:GetForward() end
	away:Normalize()

	local target = self:GetPos() + away * 400
	local area = MuR.NPC.GetArea(target)
	if IsValid(area) then target = area:GetClosestPointOnArea(target) + Vector(0, 0, 4) end

	local status = self:FollowPath(target, {
		run = true,
		tolerance = 64,
		maxage = 2,
		abort = function() return not self:IsFleeingGrenade() end,
	})

	if status == "failed" or status == "unreachable" then
		self:ApproachDirectly(target, true)
		coroutine.wait(0.3)
	end
end

--------------------------------------------------------------------------------
-- Ветка боя
--------------------------------------------------------------------------------

--
-- Врезка в бой людей. Возврат true = кадр обслужен здесь, обычная перестрелка
-- не запускается.
--
function ENT:CustomCombatBehaviour(enemy)
	-- Своя граната уже в воздухе — уносим ноги, всё остальное подождёт.
	if self:IsFleeingGrenade() then
		self:FleeBehaviour(enemy)

		return true
	end

	if self:WantsToCapture(enemy) then
		local pos = self:GetCapturePos(enemy)

		if self:GetPos():Distance(pos) <= self.CaptureRange then
			if not self:PerformCapture(enemy) then coroutine.wait(self.CaptureRetryDelay) end

			return true
		end

		local status = self:FollowPath(pos, {
			run = true,
			face = "enemy",
			tolerance = self.CaptureRange * 0.75,
			repath = 0.4,
			maxage = 10,
			target = function() return self:GetCapturePos(enemy) end,
			abort = function()
				if not self:WantsToCapture(enemy) then return true end

				return self:GetPos():Distance(self:GetCapturePos(enemy)) <= self.CaptureRange
			end,
		})

		if status == "unreachable" or status == "failed" then
			self:ApproachDirectly(pos, true)
			coroutine.wait(self.UnreachablePause)
		end

		return true
	end

	if self:CanThrowGrenade(enemy) then
		local dur = self:ThrowGrenade(enemy)
		if dur > 0 then
			coroutine.wait(dur)

			return true
		end
	end

	return false
end

-- Лежачего не расстреливаем: его берут живым.
function ENT:OnWeaponCanFire()
	if self:IsFleeingGrenade() then return false end

	local enemy = self:GetEnemy()
	if IsValid(enemy) and self:WantsToCapture(enemy) then return false end

	return true
end

-- Удар в упор по тому, кого можно связать, кончается пленением.
function ENT:CustomOnMeleeAttack_AfterChecks(ent)
	if not self:CanCaptureOnMelee(ent) then return false end

	return self:PerformCapture(ent)
end

--------------------------------------------------------------------------------
-- Засада
--------------------------------------------------------------------------------

--
-- Насколько с точки просматривается местность: сколько направлений из count
-- открыто дальше range.
--
local function OpenDirections(self, pos, count, range)
	local eye = pos + Vector(0, 0, self.CoverEyeHeight)
	local open = 0

	for i = 1, count do
		local dir = Angle(0, (360 / count) * i, 0):Forward()

		local tr = util.TraceLine({
			start = eye,
			endpos = eye + dir * range,
			filter = self,
			mask = MASK_BLOCKLOS,
		})

		if tr.Fraction > 0.8 then open = open + 1 end
	end

	return open
end

--
-- Место для засады: точка навмеша, с которой видно дальше всего.
--
-- Перебираем не все площади подряд, а горсть случайных. Нужна приличная точка,
-- а не лучшая на карте, и стоить это должно один кадр: полный перебор радиуса
-- в 900 юнитов — это сотни площадей и тысячи трасс.
--
function ENT:FindAmbushSpot()
	if not navmesh.IsLoaded() then return nil end

	local myPos = self:GetPos()

	local areas = navmesh.Find(myPos, self.AmbushSearchRadius, self.CoverStepDown, self.CoverStepUp)
	if not areas or #areas == 0 then return nil end

	local myArea = MuR.NPC.GetArea(myPos)

	local best, bestOpen = nil, self.AmbushMinOpen - 1

	for _ = 1, 12 do
		local area = areas[math.random(#areas)]
		if not IsValid(area) then continue end
		if area:IsUnderwater() then continue end
		if myArea and not MuR.NPC.CanReachArea(myArea, area) then continue end

		local p = area:GetCenter()
		if not self:CanStandAt(p) then continue end

		local open = OpenDirections(self, p, self.AmbushProbeCount, self.AmbushProbeRange)
		if open <= bestOpen then continue end

		best, bestOpen = p, open
	end

	return best
end

--
-- Мирное поведение засадника: занять точку с обзором и ждать там.
--
-- Патруль ему противопоказан: бродящий по кругу боец сам натыкается на игрока и
-- никакой засады не получается. Возврат true означает, что кадр обслужен здесь.
--
function ENT:CustomPeaceBehaviour()
	if self.PMCArchetype ~= "ambusher" then return false end

	local now = CurTime()

	if isvector(self.AmbushSpot) and now < (self.AmbushUntil or 0) then
		if self:GetPos():DistToSqr(self.AmbushSpot) > 64 * 64 then
			local status = self:FollowPath(self.AmbushSpot, {
				-- Шагом, а не бегом: он занимает позицию, а не спешит в бой.
				run = false,
				tolerance = 48,
				maxage = 20,
				abort = function() return IsValid(self:GetEnemy()) end,
			})

			-- Не дошли — точка не годится, на следующем кадре возьмём другую.
			if status ~= "ok" and status ~= "interrupted" then self.AmbushSpot = nil end

			return true
		end

		-- Стоим и посматриваем по сторонам: сектор обзора 150 градусов, зашедший
		-- сбоку иначе так и останется незамеченным.
		self:LookAround()

		return true
	end

	self.AmbushSpot = self:FindAmbushSpot()
	self.AmbushUntil = now + MuR.Roll(self.AmbushHoldTime, 35)

	-- Точки не нашлось — стоим где стоим, но бродить всё равно не идём.
	if not isvector(self.AmbushSpot) then
		self:PlayActivity(ACT_IDLE)
		coroutine.wait(1)
	end

	return true
end

--------------------------------------------------------------------------------
-- Вышибание запертых дверей
--------------------------------------------------------------------------------

--
-- Отдельно от TryBreakObstacle базы: та открывает незапертые двери, упёршись в
-- них. Здесь наёмник выбивает запертую, не дожидаясь застревания.
--
function ENT:KickDoors()
	if not self.CanKickDoors then return end
	if self.PMCKicking then return end
	if self:GetPMCCooldown("kick") > 0 then return end
	self:SetPMCCooldown("kick", 1)

	local eye = self:GetPos() + Vector(0, 0, 32)
	local fwd = self:GetForward()

	local tr = util.TraceLine({
		start = eye,
		endpos = eye + fwd * self.KickReach,
		filter = function(ent) return MuR.NPC.IsDoor(ent) end,
	})

	local door = tr.Entity
	if not tr.Hit or not IsValid(door) then return end
	if not door:GetInternalVariable("m_bLocked") then return end

	self.PMCKicking = true
	self:SetPMCCooldown("kick", MuR.Roll(self.KickCooldown, 8))

	-- Пока вышибает — он не застрявший и маршрут не перестраивает.
	self:MarkBreaking(door)

	self:PlayAnim(self.KickAnim, true, 1.1)
	self:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(1, 3) .. ".wav", 65, math.random(90, 105))

	timer.Simple(0.5, function()
		if not IsValid(self) then return end
		self.PMCKicking = false

		if not IsValid(door) then
			self:StopBreaking()
			return
		end

		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamage(math.random(self.KickDamage[1], self.KickDamage[2]))
		dmg:SetDamageForce(fwd * 100000)
		dmg:SetDamageType(DMG_CRUSH)
		dmg:SetDamagePosition(self:WorldSpaceCenter())
		door:TakeDamageInfo(dmg)

		-- Поддалась — задача закрыта, дальше идём как обычно.
		if not IsValid(door) or MuR.NPC.IsDoorOpen(door) then self:StopBreaking() end
	end)
end

--------------------------------------------------------------------------------
-- Тик
--------------------------------------------------------------------------------

function ENT:CustomOnThink()
	self:UpdateWoundedState()
	self:KickDoors()

	if self.PMCOnThink then self:PMCOnThink() end
end
