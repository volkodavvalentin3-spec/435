-- Групповое поведение: оповещение своих и обход с фланга.
--
-- Реестр ролей общий и живёт в lua/autorun/bs_npc_lib.lua (MuR.NPC.ClaimRole).
-- Здесь только то, что относится к конкретному NPC.

--------------------------------------------------------------------------------
-- Роль в стычке
--------------------------------------------------------------------------------

--
-- Роль берётся один раз на врага и держится, пока враг не сменился: пересчёт
-- каждый тик заставлял бы NPC топтаться, меняя решение на ходу.
--
-- Но и намертво она не закрепляется. Раз в RoleReviewTime роль отпускается и
-- берётся заново: если те, кто давил в лоб, погибли, кто-то из задних обязан их
-- заменить — иначе группа вырождается в одних обходящих и давить становится
-- некому.
--
function ENT:GetCombatRole()
	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return "support" end

	if CurTime() >= (self.RoleUntil or 0) then
		MuR.NPC.ReleaseRole(self)
		self.RoleUntil = CurTime() + self.RoleReviewTime
	end

	return MuR.NPC.ClaimRole(self, enemy)
end

--------------------------------------------------------------------------------
-- Оповещение своих
--------------------------------------------------------------------------------

-- Свой: живой ИИ, которому этот враг тоже враг, а мне — нет.
function ENT:IsAlly(ent)
	if not IsValid(ent) or ent == self then return false end
	if not ent.IsBloodshedNPC then return false end
	if ent:Health() <= 0 then return false end

	return not MuR.NPC.IsHostile(self, ent)
end

--
-- Крикнуть своим, что видишь врага.
--
-- Без этого группа воюет поодиночке: один офицер стреляет, второй в трёх метрах
-- за углом продолжает патрулировать, потому что сам цель не видел. Передаём и
-- позицию — тогда невидящий пойдёт проверять, а не будет ждать прямого контакта.
--
function ENT:AlertAllies(enemy)
	if not self.AlertsAllies then return end
	if not IsValid(enemy) then return end
	if CurTime() < (self.NextAllyAlert or 0) then return end
	self.NextAllyAlert = CurTime() + self.AllyAlertInterval

	local myPos = self:GetPos()
	local radiusSqr = self.AllyAlertRadius * self.AllyAlertRadius
	local pos = enemy:GetPos()

	for ent in pairs(MuR.NPC.List) do
		if not IsValid(ent) then MuR.NPC.List[ent] = nil continue end
		if not self:IsAlly(ent) then continue end
		if myPos:DistToSqr(ent:GetPos()) > radiusSqr then continue end
		if not ent.OnAllyAlert then continue end

		ent:OnAllyAlert(enemy, pos, self)
	end
end

--
-- Получить наводку от своего.
--
-- Чужую цель НЕ перехватываем, если уже дерёмся: иначе вся группа
-- переключается на последнего замеченного и бросает тех, кто её убивает.
--
function ENT:OnAllyAlert(enemy, pos, from)
	if IsValid(self:GetEnemy()) then return end
	if not self:IsValidEnemy(enemy) then return end

	-- Видим сами — берём как обычную цель. Не видим — идём проверять место.
	if self:CanSee(enemy) then
		self:ForceSetEnemy(enemy)

		return
	end

	self:RememberEnemyAt(pos, enemy)
end

--------------------------------------------------------------------------------
-- Прикрытие
--------------------------------------------------------------------------------

--
-- Общий на отряд откат прикрытия. Персональный тут не годится: перезаряжаются
-- в перестрелке постоянно, и с личными таймерами прикрывать бросались бы все
-- шестеро разом, оставляя позиции без единого выстрела.
--
local coverCalls = {}

--
-- Попросить прикрыть. Зовётся перед перезарядкой — в тот единственный момент,
-- когда боец гарантированно не может отвечать сам.
--
-- Откат спрашивается ДО перебора союзников: боевая корутина крутится примерно
-- раз в секунду, и проверка после розыгрыша сжигала бы удачные попытки в
-- закрытом окне — механика выглядела бы неработающей при исправном коде.
--
function ENT:RequestCover(enemy, duration)
	if not self.AlertsAllies then return false end
	if not IsValid(enemy) then return false end

	-- Ключ отката — фракция: прикрывают друг друга свои, и окно у них одно.
	local key = MuR.NPC.GetFaction(self) or "none"
	if CurTime() - (coverCalls[key] or 0) < self.CoverCallInterval then return false end

	local myPos = self:GetPos()
	local radiusSqr = self.AllyAlertRadius * self.AllyAlertRadius

	for ent in pairs(MuR.NPC.List) do
		if not IsValid(ent) then MuR.NPC.List[ent] = nil continue end
		if not self:IsAlly(ent) then continue end
		if myPos:DistToSqr(ent:GetPos()) > radiusSqr then continue end
		if not ent.OnCoverRequest then continue end

		if ent:OnCoverRequest(enemy, self, duration or self.CoverCallDuration) then
			coverCalls[key] = CurTime()

			return true
		end
	end

	return false
end

--
-- Принять просьбу прикрыть. true — взялся, и просивший больше никого не зовёт.
--
-- Берётся только тот, кто и так дерётся с этой целью и может стрелять прямо
-- сейчас: сорвать с места того, кто занят своим врагом, значит разменять одну
-- дырку в обороне на другую.
--
function ENT:OnCoverRequest(enemy, from, duration)
	if self:GetEnemy() ~= enemy then return false end
	if not self.CanSuppress then return false end
	if self.IsLowOnAmmo and self:IsLowOnAmmo() then return false end
	if self.NeedsReload and self:NeedsReload() then return false end

	-- Подавление с этой минуты идёт без личного отката: прикрывать надо СЕЙЧАС.
	self.NextSuppress = 0
	self.CoveringUntil = CurTime() + (duration or 2)

	return true
end

-- Прикрываем ли кого-то прямо сейчас.
function ENT:IsCoveringAlly()
	return CurTime() < (self.CoveringUntil or 0)
end

--------------------------------------------------------------------------------
-- Обход с фланга
--------------------------------------------------------------------------------

--
-- Точка сбоку от врага под свою сторону обхода.
--
-- Считается поворотом вокруг ВРАГА, а не сдвигом от себя: так обходящий держит
-- дистанцию боя и заходит по дуге, а не срезает угол и не выходит вплотную.
--
function ENT:FindFlankSpot(enemy)
	if not IsValid(enemy) then return nil end

	local side = self.FlankSide or 1
	local enemyPos = enemy:GetPos()
	local myPos = self:GetPos()

	local away = myPos - enemyPos
	away.z = 0

	local dist = away:Length()
	if dist < 1 then return nil end
	away:Normalize()

	local reach = math.Clamp(dist, self.FlankMinRadius, self.FlankMaxRadius)

	for _, deg in ipairs(self.FlankAngles) do
		local rad = math.rad(deg * side)
		local cos, sin = math.cos(rad), math.sin(rad)
		local dir = Vector(away.x * cos - away.y * sin, away.x * sin + away.y * cos, 0)

		local p = enemyPos + dir * reach

		local area = MuR.NPC.GetArea(p)
		if not IsValid(area) then continue end

		local spot = area:GetClosestPointOnArea(p) + Vector(0, 0, 4)

		if not self:CanReach(spot) then continue end
		if not self:CanStandAt(spot) then continue end

		return spot
	end

	return nil
end

-- Пора ли обновить обход: дошли до прежней точки или враг уехал.
function ENT:NeedsNewFlank(enemy)
	if not isvector(self.FlankTarget) then return true end
	if not IsValid(enemy) then return true end
	if CurTime() >= (self.FlankUntil or 0) then return true end

	return self:GetPos():DistToSqr(self.FlankTarget) < self.FlankReachedDist ^ 2
end

--
-- Идти не к врагу, а вбок от него. Только из корутины поведения.
--
-- false — обходить нечего или уже обошли; тогда вызывающий переходит к своему
-- обычному бою (перестрелке у людей, погоне у тварей).
--
function ENT:FlankBehaviour(enemy)
	-- После удачного обхода отдыхаем: дерёмся с новой позиции, а не наматываем
	-- круги вокруг цели до конца боя.
	if CurTime() < (self.FlankRestUntil or 0) then return false end

	if self:NeedsNewFlank(enemy) then
		local spot = self:FindFlankSpot(enemy)

		if not spot then
			self.FlankTarget = nil
			self.FlankRestUntil = CurTime() + self.FlankRestTime

			return false
		end

		self.FlankTarget = spot
		self.FlankUntil = CurTime() + self.FlankHoldTime
	end

	self:FollowPath(self.FlankTarget, {
		run = true,
		face = "enemy",
		tolerance = self.FlankReachedDist,
		maxage = self.FlankHoldTime,
		abort = function() return self:GetEnemy() ~= enemy end,
	})

	self.FlankTarget = nil
	self.FlankRestUntil = CurTime() + self.FlankRestTime

	return true
end

--------------------------------------------------------------------------------
-- Огонь по своим
--------------------------------------------------------------------------------

--
-- Кто из своих стоит на линии огня. nil — коридор чист.
--
-- Трассой это не решается: трасса ловит только то, что ровно на луче, а пуля
-- уходит с разбросом, и союзник в полуметре от линии всё равно собирает
-- очередь. Поэтому считаем цилиндр — проекцию на луч и отступ от него.
--
-- Дороже трассы это не выходит: союзников в стычке единицы, а список берётся из
-- реестра, а не из ents.FindInSphere.
--
function ENT:AllyInLineOfFire(src, aimPos)
	if not self.CheckLineOfFire then return nil end
	if not isvector(src) or not isvector(aimPos) then return nil end

	local dir = aimPos - src
	local range = dir:Length()
	if range < 1 then return nil end
	dir:Normalize()

	local radiusSqr = self.FireLaneRadius * self.FireLaneRadius

	for ent in pairs(MuR.NPC.List) do
		if not IsValid(ent) then MuR.NPC.List[ent] = nil continue end
		if not self:IsAlly(ent) then continue end

		local delta = ent:WorldSpaceCenter() - src
		local along = delta:Dot(dir)

		-- За спиной или дальше цели: пуля до него не долетит.
		if along <= 0 or along >= range then continue end
		if (delta - dir * along):LengthSqr() > radiusSqr then continue end

		return ent
	end

	return nil
end

--
-- Сдвинуться вбок, чтобы коридор освободился.
--
-- Отказ от выстрела сам по себе делает бойца хуже: он молча стоит, пока перед
-- ним ходят свои. Шаг в сторону возвращает ему огонь и заодно читается как
-- нормальное поведение стрелка в группе.
--
function ENT:StepOutOfFireLane(enemy)
	if not IsValid(enemy) then return false end

	local myPos = self:GetPos()

	local dir = enemy:GetPos() - myPos
	dir.z = 0
	if dir:LengthSqr() < 1 then return false end
	dir:Normalize()

	local side = dir:Cross(vector_up)
	side.z = 0
	side:Normalize()

	-- Высота дула относительно ног: коридор с новой точки считается от неё же.
	local muzzleZ = self:GetMuzzlePos().z - myPos.z
	local aim = enemy:WorldSpaceCenter()

	local signs = math.random(2) == 1 and {1, -1} or {-1, 1}

	for _, d in ipairs(self.FireLaneStepOffsets) do
		for _, sign in ipairs(signs) do
			local p = myPos + side * (d * sign)

			local area = MuR.NPC.GetArea(p)
			if not IsValid(area) then continue end

			p = area:GetClosestPointOnArea(p) + Vector(0, 0, 2)

			if not self:CanStandAt(p) then continue end
			-- С новой точки цель обязана простреливаться, иначе шаг бессмыслен.
			if not self:IsSpotVisibleFrom(aim, p, self.CoverEyeHeight, enemy) then continue end
			if self:AllyInLineOfFire(p + Vector(0, 0, muzzleZ), aim) then continue end

			self:FollowPath(p, {
				run = true,
				face = "enemy",
				tolerance = 24,
				maxage = 1.5,
				abort = function() return self:GetEnemy() ~= enemy end,
			})

			return true
		end
	end

	return false
end
