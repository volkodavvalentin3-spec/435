-- Передвижение: настройка loco, приказы движения, застревание.

-- Развернуть корпус только по рысканью. Тангаж и крен кладут модель набок и
-- загоняют её в стены, а боевой код считает направление огня полным 3D-вектором.
--
-- Перехватить сам SetAngles нельзя: у scripted entity нативный метод Entity
-- выигрывает у метода из таблицы ENT (проверено в игре), поэтому весь свой код
-- обязан звать FaceAngle, а не SetAngles.
function ENT:FaceAngle(ang)
	self:SetAngles(Angle(0, ang.y, 0))
end

function ENT:SetupLocomotion()
	local loco = self.loco
	if not loco then return end

	loco:SetStepHeight(self.StepHeight)
	loco:SetMaxYawRate(self.MaxYawRate)
	loco:SetAcceleration(self.Acceleration)
	loco:SetDeceleration(self.Deceleration)
	loco:SetDesiredSpeed(self.WalkSpeed)

	local jp = self.JumpParams

	if jp and jp.Enabled then
		loco:SetJumpHeight(jp.MaxRise)
		loco:SetDeathDropHeight(jp.MaxDrop)
	else
		loco:SetJumpHeight(0)
		loco:SetDeathDropHeight(200)
	end
end

-- Развернуть корпус к точке. false, если точка совпадает с нашей: Angle() от
-- нулевого вектора дал бы мусорные углы.
function ENT:FaceTowards(pos)
	if not isvector(pos) then return false end

	local dir = pos - self:GetPos()
	dir.z = 0
	if dir:LengthSqr() < 1 then return false end

	self.loco:FaceTowards(self:GetPos() + dir)

	return true
end

--------------------------------------------------------------------------------
-- Приказы движения
--------------------------------------------------------------------------------

--
-- Замена связки VJ "SetLastPosition(pos) + SCHEDULE_GOTO_POSITION(task, cb)".
-- Поля opts повторяют то, что задавал колбэк VJ:
--
--   run        — бежать (иначе идти)
--   face       — "enemy": доворачиваться к врагу на ходу
--   canShoot   — разрешено стрелять в движении (читает боевой слой)
--   tolerance  — радиус, в котором цель считается достигнутой
--   lookahead  — сглаживание пути
--   maxage     — бросить приказ, если путь старше N секунд
--   repath     — перепрокладывать путь каждые N секунд
--   onFinish   — колбэк(status): "ok" | "failed" | "stuck" | "timeout" | "interrupted"
--
function ENT:OrderMove(pos, opts)
	if not isvector(pos) then return false end

	opts = opts or {}

	self.Goal = {
		pos = pos,
		run = opts.run,
		face = opts.face,
		canShoot = opts.canShoot,
		tolerance = opts.tolerance,
		lookahead = opts.lookahead,
		maxage = opts.maxage,
		repath = opts.repath,
		onFinish = opts.onFinish,
	}

	return true
end

function ENT:HasGoal()
	return self.Goal ~= nil
end

function ENT:ClearGoal()
	self.Goal = nil
	self:ClearDoorWait()

	if self.loco then
		self.loco:ClearStuck()
		self.loco:SetVelocity(vector_origin)
	end
end

-- Имя оставлено от VJ: StopMoving зовут и модули NPC, и геймдмод.
function ENT:StopMoving()
	self:ClearGoal()
end

-- Разрешено ли стрелять прямо сейчас, не прерывая движения.
function ENT:CanShootWhileMoving()
	local goal = self.Goal
	if not goal then return true end

	return goal.canShoot == true
end

--------------------------------------------------------------------------------
-- Расталкивание
--------------------------------------------------------------------------------

--
-- Мягкое расталкивание: два некстбота, упёршиеся друг в друга, иначе взаимно
-- блокируются и стоят до конца раунда.
--
-- Отключить коллизию между ними нельзя: GM:ShouldCollide работает на уровне
-- физики и на трассы передвижения loco не влияет — проверено в игре, бот
-- упирался в своего и стоял, хотя хук возвращал false. Поэтому раздвигаем их
-- скоростью.
--
-- Сила небольшая и добавляется к скорости loco, поэтому движение по пути
-- остаётся главным.
--
function ENT:UpdateSeparation()
	if not self.SeparationForce or self.SeparationForce <= 0 then return end
	if CurTime() < (self.NextSeparation or 0) then return end
	self.NextSeparation = CurTime() + 0.05

	if self:IsVaulting() or self:IsOnLadder() then return end
	if not self.loco:IsOnGround() then return end

	if self:IsBusy() then return end
	if self:IsHoldingCoverPose() then return end
	if self:IsDoorWaiting() then return end
	if not self.loco:IsAttemptingToMove() then return end

	local myPos = self:GetPos()
	local radius = self.SeparationRadius
	local push = Vector(0, 0, 0)
	local count, touching = 0, false
	local closest = math.huge

	for ent in pairs(MuR.NPC.List) do
		if ent == self then continue end
		if not IsValid(ent) then MuR.NPC.List[ent] = nil continue end
		if not ent.IsBloodshedNPC then continue end

		local away = myPos - ent:GetPos()
		away.z = 0

		local dist = away:Length()
		if dist > radius then continue end

		count = count + 1

		if dist <= self.SeparationTouch then
			touching = true
			if dist < closest then closest = dist end
		end

		-- Позиции совпали полностью: направления нет, но разойтись надо.
		if dist < 1 then continue end

		away:Normalize()
		push = push + away * (1 - dist / radius)
	end

	if count == 0 then return end

	if push:LengthSqr() < 0.01 then
		-- Детерминированное направление по индексу: соседи разойдутся в разные
		-- стороны, а не будут дёргаться случайно каждый тик.
		local ang = (self:EntIndex() % 16) * (math.pi / 8)
		push = Vector(math.cos(ang), math.sin(ang), 0)
	end

	push:Normalize()

	self.loco:SetDesiredSpeed(math.max(self.loco:GetDesiredSpeed(), self.SeparationForce))
	self.loco:Approach(myPos + push * 64, 1)

	-- Вплотную loco бессилен: габариты соседей перекрывают все направления, и
	-- ни Approach, ни SetVelocity не двигают бота с места (замерено — ноль
	-- юнитов за 1.5 с при вызове каждый тик). Расходимся сдвигом позиции.
	if not touching then return end

	-- Смотрим на фактическое смещение, а НЕ на loco:GetVelocity(): у зажатого
	-- бота она показывает 90, хотя он стоит. Это и глушило расталкивание.
	local now = CurTime()

	if not self.SepLastPos then
		self.SepLastPos = myPos
		self.SepLastTime = now

		return
	end

	if now - self.SepLastTime < 0.2 then return end

	local travelled = myPos:Distance(self.SepLastPos)
	self.SepLastPos = myPos
	self.SepLastTime = now

	-- Идёт нормально — не мешаем.
	if travelled > 6 then return end

	self:NudgeApart(myPos, push, closest)
end

--
-- Выйти из перекрытия сдвигом позиции.
--
-- Одного направления мало: нужный шаг упирается в геометрию, а мелкий соседи
-- стягивают обратно. Поэтому перебираем повороты вокруг желаемого направления
-- и две длины. Трасс немного и только когда бот реально зажат.
--
-- Полностью слипшихся ботов так не расцепить: движок откатывает любую позицию,
-- оставляющую перекрытие. Это работает на случай «зажало рядом с союзником»,
-- когда сбоку есть настоящее свободное место.
--
function ENT:NudgeApart(myPos, push, closest)
	local need = self.SeparationTouch + 4 - math.min(closest, self.SeparationTouch)
	local mins, maxs = self:GetCollisionBounds()

	-- Союзники в фильтре УЧАСТВУЮТ. Иначе сдвиг уводит в точку, где бот всё
	-- ещё перекрывает своего, а движок такую позицию откатывает сам: замерено,
	-- сдвиг 60 юнитов возвращался к 30 и затем к нулю. Двигаться есть смысл
	-- только в честно свободное место.
	local filter = function(e) return e ~= self end

	for _, len in ipairs({math.max(need, self.SeparationStep), self.SeparationStep}) do
		for turn = 0, 7 do
			-- 0, +45, -45, +90, -90 ... вокруг push
			local half = math.floor((turn + 1) / 2)
			local deg = (turn % 2 == 1) and (half * 45) or (-half * 45)
			local rad = math.rad(deg)
			local cos, sin = math.cos(rad), math.sin(rad)
			local dir = Vector(push.x * cos - push.y * sin, push.x * sin + push.y * cos, 0)

			local step = myPos + dir * len

			local tr = util.TraceHull({
				start = step,
				endpos = step,
				mins = mins,
				maxs = maxs,
				filter = filter,
				mask = MASK_NPCSOLID,
			})

			if not tr.Hit and IsValid(MuR.NPC.GetArea(step)) then
				self:SetPos(step)

				return true
			end
		end
	end

	return false
end

--
-- Обойти своего, в которого упёрлись: шаг в сторону плюс встречный толчок.
-- Сторону выбираем ту, где впереди свободнее.
--
function ENT:TryPushPastAlly()
	if not self.AllyPushForce or self.AllyPushForce <= 0 then return false end

	local dir = self:GetMoveDir()
	local tr = self:TraceObstacle(dir)
	local ally = tr.Entity

	if not IsValid(ally) then return false end
	if not ally.IsBloodshedNPC then return false end

	local right = dir:Cross(vector_up)
	right.z = 0
	if right:LengthSqr() < 0.01 then return false end
	right:Normalize()

	-- Куда свободнее шагнуть.
	local side = right
	local center = self:GetPos() + Vector(0, 0, self.loco:GetStepHeight() + 4)
	local hull = {mins = Vector(-12, -12, 0), maxs = Vector(12, 12, 40), filter = self, mask = MASK_NPCSOLID}

	hull.start = center
	hull.endpos = center + right * self.SeparationRadius
	local toRight = util.TraceHull(hull)

	hull.endpos = center - right * self.SeparationRadius
	local toLeft = util.TraceHull(hull)

	if toRight.Fraction < toLeft.Fraction then side = -right end

	self.loco:SetVelocity(self.loco:GetVelocity() + side * self.AllyPushForce)

	-- Встречного двигаем в другую сторону, но слабее: иначе двое начинают
	-- перебрасывать друг друга.
	if ally.loco then
		ally.loco:SetVelocity(ally.loco:GetVelocity() - side * self.AllyPushForce * 0.5)
	end

	return true
end

--------------------------------------------------------------------------------
-- Застревание
--------------------------------------------------------------------------------

function ENT:HandleStuck()
	self.loco:ClearStuck()

	-- Свой же NPC — не преграда карты. Разбираемся до счётчика застреваний,
	-- иначе толкучка в толпе засоряла бы список объезда площадями, по которым
	-- на самом деле пройти можно.
	if self:TryPushPastAlly() then return end

	self.StuckStreak = (self.StuckStreak or 0) + 1

	-- Закрытая дверь — самая частая причина застревания, и врага за ней не
	-- видно, так что обычный боевой цикл до неё не доберётся. Бьём её здесь.
	if self:TryBreakObstacle() then return end

	-- Уступ или ограда: пробуем перелезть.
	if self:TryVault() then return end

	--
	-- Не помогло и повторяется. Закрываем ПЕРЕХОД, на котором упёрлись, а не всю
	-- площадь впереди.
	--
	-- Раньше в объезд уходила площадь, и это давало колебание: бот отходил,
	-- оказывался на другой площади, оттуда маршрут вёл к той же ограде с чуть
	-- другой стороны, repath в погоне пересчитывал путь каждые полсекунды — и
	-- бот метался туда-сюда в паре метров. Плюс запрет жил 15 секунд и снимался
	-- сам, так что цикл возобновлялся даже когда обход был найден верно.
	--
	-- Закрытый переход держится дольше и не отрезает саму площадь: она часто
	-- большая и нужна, чтобы вдоль этой же ограды пройти до прохода.
	--
	if self.StuckStreak >= self.NavStuckLimit then
		local ahead = self:GetBlockedArea()
		local here = MuR.NPC.GetArea(self:GetPos())

		if not MuR.NPC.BlockLink(here, ahead) then
			-- Не поняли, откуда куда шли — старое поведение как запасное.
			self:AvoidArea(ahead, self.NavAvoidDuration)
		end

		self.StuckStreak = 0
	end

	if self.OnStuckCustom then self:OnStuckCustom() end
end

--
-- Преграда прямо по курсу.
--
-- Сначала хулл-трасса по направлению движения с MASK_SOLID: в неё входит
-- CONTENTS_WINDOW, поэтому остеклённая дверь ловится за само стекло. Обычная
-- LOS-трасса стекло не видит — из-за этого NPC замечал цель через стеклянную
-- дверь, шёл в неё и не понимал, что мешает.
--
-- Запасной проход сферой нужен для тонких дверей, мимо которых хулл проходит
-- (проверено на func_door_rotating).
--
function ENT:TraceObstacle(dir)
	local mins, maxs = self:GetCollisionBounds()
	local start = self:GetPos() + Vector(0, 0, self.loco:GetStepHeight() + 4)

	return util.TraceHull({
		start = start,
		endpos = start + dir * self.ObstacleReach,
		mins = Vector(mins.x, mins.y, 0),
		maxs = Vector(maxs.x, maxs.y, math.min(maxs.z, 48)),
		filter = self,
		mask = MASK_SOLID,
	})
end

--
-- Отметить, что мы разбираем эту преграду прямо сейчас.
--
-- Зовётся из каждого места, где по преграде реально ударили: и из общего
-- разбора застревания, и из вышибания дверей у наёмников.
--
function ENT:MarkBreaking(ent)
	if not IsValid(ent) then return end

	if self.BreakTarget ~= ent then
		self.BreakTarget = ent
		self.BreakStarted = CurTime()
	end
end

--
-- Занят ли разбором. Три условия, и каждое обязательно:
--
--   преграда ещё цела — иначе разбирать нечего;
--   не вышел срок — дверь, не поддавшаяся за ObstacleBreakTimeout, безнадёжна,
--     и держаться за неё значит стоять там до конца раунда;
--   мы всё ещё рядом с ней — отошли, значит занялись чем-то другим.
--
function ENT:IsBreakingObstacle()
	local ent = self.BreakTarget
	if not IsValid(ent) then return false end
	if CurTime() - (self.BreakStarted or 0) > self.ObstacleBreakTimeout then return false end

	local reach = self.ObstacleReach + 64
	if self:GetPos():DistToSqr(ent:WorldSpaceCenter()) > reach * reach then return false end

	return true
end

function ENT:StopBreaking()
	self.BreakTarget = nil
	self.BreakStarted = nil
end

-- Дверь, которую уже пробовали открыть и не смогли.
function ENT:IsDoorKnownLocked(ent)
	local t = self.LockedDoors and self.LockedDoors[ent]

	return t ~= nil and t > CurTime()
end

function ENT:FindObstacleAhead()
	local dir = self:GetMoveDir()

	local tr = self:TraceObstacle(dir)
	if tr.Hit and MuR.NPC.IsBreakable(tr.Entity) then
		return tr.Entity
	end

	local center = self:WorldSpaceCenter()
	local probe = center + dir * self.MeleeAttackDistance * 0.5

	local best, bestDist = nil, math.huge

	for _, ent in ipairs(ents.FindInSphere(probe, self.MeleeAttackDistance * 0.75)) do
		if ent == self then continue end
		if not MuR.NPC.IsBreakable(ent) then continue end

		local toEnt = ent:WorldSpaceCenter() - center
		toEnt.z = 0
		if toEnt:LengthSqr() < 1 then return ent end

		local d = toEnt:Length()
		toEnt:Normalize()
		if dir:Dot(toEnt) < 0.5 then continue end

		if d < bestDist then best, bestDist = ent, d end
	end

	return best
end

--
-- Что мешает прямо по курсу — разобрать на подходе, не дожидаясь застревания.
--
-- Одна хулл-трасса вперёд с MASK_SOLID обслуживает оба случая:
--
--   дверь — замерено, что хулл достаёт и prop_door_rotating, и func_door,
--     в отличие от MASK_SOLID_BRUSHONLY, который двери не видит вовсе. Стекло
--     входит в маску (CONTENTS_WINDOW), поэтому остеклённая дверь ловится за
--     само стекло, хотя LOS-трасса сквозь неё проходит и NPC «видит» цель
--     насквозь. Раньше двери разбирались только из HandleStuck, то есть после
--     трёх секунд утыкания;
--
--   физпроп — nextbot не толкает физику вовсе: loco двигает корпус трассами, и
--     куча мебели для него глухая стена. Подпихиваем сами.
--
-- Сущность берём из той же трассы: ents.FindInSphere перебирает ВСЕ сущности
-- карты независимо от радиуса (на боевой ~2900), и звать его на каждого NPC
-- несколько раз в секунду нельзя.
--
function ENT:ProbeAhead()
	local now = CurTime()
	if now < (self.NextProbe or 0) then return false end
	self.NextProbe = now + self.ProbeInterval

	if self:IsDoorWaiting() then return false end

	if not self.loco:IsAttemptingToMove() then return false end

	local dir = self:GetMoveDir()
	local mins, maxs = self:GetCollisionBounds()
	local start = self:GetPos() + Vector(0, 0, self.loco:GetStepHeight() + 4)

	local tr = util.TraceHull({
		start = start,
		endpos = start + dir * self.ProbeReach,
		mins = Vector(mins.x, mins.y, 0),
		maxs = Vector(maxs.x, maxs.y, math.min(maxs.z, 48)),
		filter = self,
		mask = MASK_SOLID,
	})

	local ent = tr.Entity
	if not tr.Hit or not IsValid(ent) then return false end

	if MuR.NPC.IsDoor(ent) then
		if self:IsDoorKnownLocked(ent) then return false end

		return self:TryOpenDoor(ent)
	end

	return self:PushProp(ent, dir)
end

--
-- Отпихнуть физпроп с дороги. Толчок от массы: лёгкий ящик отлетает, шкаф едва
-- трогается — тяжёлое NPC обойдёт, а не поедет на нём как на санях.
--
-- Скорость проверяем до толчка: уже разогнанный проп догонять не надо, иначе
-- он копит импульс и улетает через полкарты.
--
function ENT:PushProp(ent, dir)
	if not self.CanPushProps then return false end
	if ent:GetClass() ~= "prop_physics" and ent:GetClass() ~= "prop_physics_multiplayer" then return false end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) or not phys:IsMoveable() then return false end

	local mass = phys:GetMass()
	if mass > self.PropPushMaxMass then return false end
	if phys:GetVelocity():LengthSqr() > self.PropPushMaxSpeed ^ 2 then return false end

	phys:Wake()
	phys:ApplyForceCenter(dir * mass * self.PropPushForce)

	return true
end

--
-- Открыть дверь. true только если она реально пошла открываться.
--
-- Use уважает замок, поэтому запертая так и останется запертой — прятаться за
-- ней должно работать. Такую дверь запоминаем и больше не дёргаем, иначе NPC
-- будет вечно тыкаться в неё вместо того, чтобы искать обход.
--
function ENT:TryOpenDoor(ent)
	if not self.CanOpenDoors then return false end
	if not MuR.NPC.IsDoor(ent) then return false end
	if self:IsDoorKnownLocked(ent) then return false end

	if MuR.NPC.IsDoorOpen(ent) then
		if MuR.NPC.IsDoorFullyOpen(ent) then return false end

		return self:StartDoorWait(ent)
	end

	ent:Use(self, self, USE_TOGGLE, 1)

	if MuR.NPC.IsDoorOpen(ent) then
		return self:StartDoorWait(ent)
	end

	self.LockedDoors = self.LockedDoors or {}
	self.LockedDoors[ent] = CurTime() + self.LockedDoorMemory

	return false
end

function ENT:GetDoorClearPos(door)
	local myPos = self:GetPos()

	local away = myPos - door:WorldSpaceCenter()
	away.z = 0

	if away:LengthSqr() < 1 then
		away = -self:GetMoveDir()
		if away:LengthSqr() < 1 then away = -self:GetForward() end
	else
		away:Normalize()
	end

	local target = myPos + away * self.DoorClearDistance

	local area = MuR.NPC.GetArea(target)
	if IsValid(area) then target = area:GetClosestPointOnArea(target) + Vector(0, 0, 2) end

	if not self:CanStandAt(target) then return nil end

	return target
end

function ENT:StartDoorWait(door)
	if not IsValid(door) then return false end
	if self.DoorWait and self.DoorWait.ent == door then return true end

	self.DoorWait = {
		ent = door,
		until_ = CurTime() + self.DoorOpenWaitTime,
		clearPos = self:GetDoorClearPos(door),
	}

	return true
end

function ENT:IsDoorWaiting()
	return self.DoorWait ~= nil
end

function ENT:ClearDoorWait()
	self.DoorWait = nil
end

function ENT:UpdateDoorWait()
	local wait = self.DoorWait
	if not wait then return false end

	local door = wait.ent

	if not IsValid(door) then
		self:ClearDoorWait()

		return false
	end

	if MuR.NPC.IsDoorFullyOpen(door) then
		self:ClearDoorWait()

		return false
	end

	if not MuR.NPC.IsDoorOpen(door) then
		door:Use(self, self, USE_TOGGLE, 1)

		if not MuR.NPC.IsDoorOpen(door) then
			self.LockedDoors = self.LockedDoors or {}
			self.LockedDoors[door] = CurTime() + self.DoorJammedMemory
			self:ClearDoorWait()

			return false
		end
	end

	if CurTime() >= wait.until_ then
		self.LockedDoors = self.LockedDoors or {}
		self.LockedDoors[door] = CurTime() + self.DoorJammedMemory
		self:ClearDoorWait()

		return false
	end

	if self:IsBusy() then
		self.loco:SetDesiredSpeed(0)
		self.loco:SetVelocity(vector_origin)

		return true
	end

	local pos = wait.clearPos

	if isvector(pos) and self:GetPos():DistToSqr(pos) > 24 * 24 then
		self.loco:SetDesiredSpeed(self:GetWalkSpeed())
		self.loco:Approach(pos, 1)
		self.loco:FaceTowards(pos)
		self:PlayActivity(ACT_WALK)
	else
		self.loco:SetDesiredSpeed(0)
		self.loco:SetVelocity(vector_origin)
		self:PlayActivity(ACT_IDLE)
	end

	return true
end

--
-- Открыть или разбить преграду. true — только если что-то реально изменилось.
--
-- Возврат тут важен: HandleStuck по нему решает, продолжать ли разбор
-- (перелаз, затем объезд). Раньше запертая дверь давала true, объезд не
-- запускался, и NPC стоял перед ней бесконечно.
--
function ENT:TryBreakObstacle()
	local ent = self:FindObstacleAhead()
	if not IsValid(ent) then return false end

	if self:TryOpenDoor(ent) then return true end

	-- Проверки боя идут только здесь: открыть дверь — не атака, и замирать
	-- ради этого NPC не должен.
	if not self.HasMeleeAttack then return false end
	if not self.MeleeAttackDamageProps then return false end
	if not self:CanAttack() then return false end
	if CurTime() < (self.NextMeleeAttackT or 0) then return false end
	if not MuR.NPC.IsDamageable(ent) then return false end

	self:MarkBreaking(ent)
	self:StartMeleeAttack(ent)

	return true
end

function ENT:ContinueBreaking()
	local ent = self.BreakTarget
	if not IsValid(ent) then return end
	if not self.HasMeleeAttack or not self.MeleeAttackDamageProps then return end
	if not self:CanAttack() then return end
	if CurTime() < (self.NextMeleeAttackT or 0) then return end
	if not MuR.NPC.IsDamageable(ent) then return end

	self:StartMeleeAttack(ent)
end

--
-- Перелезть через преграду прямо по курсу.
--
-- Навмеш кладёт поверх ограды тонкую площадь NAV_MESH_OBSTACLE_TOP, путь через
-- неё строится, но CLuaLocomotion лазать не умеет. Механика перелаза лежит в
-- sv_nav.lua; здесь только вход из разбора застревания.
--
-- Куда NPC СОБИРАЕТСЯ идти. Не то же, что GetForward: у ограды корпус часто
-- развёрнут вдоль неё, и щуп по взгляду преграду не находит.
function ENT:GetMoveDir()
	local path = self.CurrentPath

	if path and path:IsValid() then
		local seg = path:GetCurrentGoal()
		if seg and isvector(seg.pos) then
			local dir = seg.pos - self:GetPos()
			dir.z = 0
			if dir:LengthSqr() > 1 then
				dir:Normalize()
				return dir
			end
		end
	end

	return self:GetForward()
end

--
-- knownBlocked — преграду впереди уже нащупал вызывающий (NeedsClimb), второй
-- раз ту же трассу не гоняем.
-- dir — куда лезть. Задаётся явно при подъёме по пути: GetMoveDir при сглаживании
-- на 250 юнитов смотрит мимо уступа.
--
function ENT:TryVault(knownBlocked, dir)
	if not self.CanJumpObstacles then return false end
	if self:IsVaulting() then return true end
	if not self.loco:IsOnGround() then return false end
	if CurTime() < (self.NextNavJumpT or 0) then return false end

	dir = dir or self:GetMoveDir()

	-- Впереди пусто — перелезать нечего, пусть работает объезд.
	if not knownBlocked and not self:IsBlockedAhead(dir) then return false end

	local dest = self:FindVaultDestination(dir)
	if not dest then return false end

	self.NextNavJumpT = CurTime() + 0.4

	return self:StartVault(dest)
end

--------------------------------------------------------------------------------
-- Аварийный перенос
--------------------------------------------------------------------------------

--
-- Сторож на случай, когда не сработало вообще ничего: ни дверь, ни перелаз, ни
-- объезд, ни расталкивание.
--
-- Считается в Think, а не в цикле пути: NPC умеет стоять и без пути — например,
-- упёршись в угол при прямом подходе к недостижимой цели, где FollowPath даже
-- не запускается.
--
function ENT:StuckWatchdog()
	local now = CurTime()
	local pos = self:GetPos()

	if not self.WatchPos or pos:DistToSqr(self.WatchPos) > self.StuckRelocateDistance ^ 2 then
		self.WatchPos = pos
		self.WatchTime = now

		return
	end

	-- Стоять смирно — не то же, что застрять: идла и ожидание приказа не считаем.
	if not self.loco:IsAttemptingToMove() then
		self.WatchTime = now

		return
	end

	if self:IsVaulting() or self:IsOnLadder() or not self:CanMove() then
		self.WatchTime = now

		return
	end

	-- Ломает дверь — стоит намеренно, а не застрял. Переносить его отсюда
	-- нельзя: со стороны это ровно «NPC исчез, не доломав».
	if self:IsBreakingObstacle() then
		self.WatchTime = now

		return
	end

	if self:IsDoorWaiting() then
		self.WatchTime = now

		return
	end

	if now - self.WatchTime < self.StuckRelocateTime then return end

	self.WatchPos = pos
	self.WatchTime = now

	self:Relocate()
end

--
-- Годится ли точка по игрокам: не на глазах и не под носом.
--
-- Два разных запрета, и оба обязательны. «Не на глазах» — чтобы перенос не
-- читался как телепорт. «Не впритык» — потому что вылезший из воздуха в трёх
-- метрах за спиной NPC ничем не лучше телепорта на глазах: игрок разворачивается
-- и видит противника там, где секунду назад никого не было.
--
local function playersAllow(self, pos)
	local head = pos + Vector(0, 0, 40)
	local nearSqr = self.RelocateMinPlayerDist * self.RelocateMinPlayerDist

	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() then continue end

		local eye = ply:EyePos()
		local distSqr = eye:DistToSqr(head)

		if distSqr < nearSqr then return false end
		if distSqr > self.RelocateSightRange * self.RelocateSightRange then continue end

		local d = head - eye
		d:Normalize()
		if ply:EyeAngles():Forward():Dot(d) < 0.4 then continue end

		local tr = util.TraceLine({start = eye, endpos = head, filter = ply, mask = MASK_SOLID})
		if not tr.Hit then return false end
	end

	return true
end

--
-- Куда переставить. Ближе к цели — но не в двух шагах от текущего места: тот же
-- тупик NPC разберёт ровно так же и снова встанет.
--
function ENT:FindRelocateSpot(radius)
	local myPos = self:GetPos()

	local areas = navmesh.Find(myPos, radius or self.StuckRelocateRadius, 96, 96)
	if not areas or #areas == 0 then return nil end

	local target = self.Goal and self.Goal.pos
	if not target then
		local en = self:GetEnemy()
		if IsValid(en) then target = en:GetPos() end
	end

	local mins, maxs = self:GetCollisionBounds()
	local minDist = self.StuckRelocateMinDist * self.StuckRelocateMinDist

	local best, bestScore = nil, math.huge

	for _ = 1, 20 do
		local area = areas[math.random(#areas)]
		if not IsValid(area) then continue end

		local p = area:GetRandomPoint() + Vector(0, 0, 4)
		if p:DistToSqr(myPos) < minDist then continue end

		local hull = util.TraceHull({
			start = p,
			endpos = p,
			mins = mins,
			maxs = maxs,
			filter = self,
			mask = MASK_NPCSOLID,
		})
		if hull.Hit then continue end

		local score = target and p:DistToSqr(target) or p:DistToSqr(myPos)
		if score >= bestScore then continue end

		-- Запрет по игрокам жёсткий: «на виду» и «впритык» не размениваются ни
		-- на какую близость к цели. Не нашлось — Relocate расширит радиус и
		-- поищет дальше, там, где игроков нет.
		if not playersAllow(self, p) then continue end

		best, bestScore = p, score
	end

	return best
end

--
-- Переставить NPC. Крайняя мера: сюда попадают только те, кто StuckRelocateTime
-- секунд подряд пытался идти и не сдвинулся.
--
-- Именно перестановка, а НЕ пересоздание сущности: NPC числится в списках
-- режимов (волны 18-го, счётчики живых), у него своё здоровье, оружие, враг и
-- таймеры. Новая сущность всё это теряет, а счётчик волны сломался бы на ровном
-- месте — волна не закрылась бы никогда.
--
function ENT:Relocate()
	--
	-- Режиму дают сказать первое слово: у волновых режимов есть свои точки
	-- появления, и вернуть застрявшего на них правильнее, чем ставить его на
	-- случайную площадь навмеша. Возврат не-вектора означает «решай сам».
	--
	local spot = hook.Run("BS_NPCRelocateSpot", self)
	if not isvector(spot) then spot = nil end

	-- Сначала рядом, потом заметно шире: под носом у игроков ставить нельзя, а
	-- дальше от них место найдётся почти всегда.
	spot = spot
		or self:FindRelocateSpot(self.StuckRelocateRadius)
		or self:FindRelocateSpot(self.StuckRelocateRadius * self.RelocateWideFactor)

	if not spot then return false end

	self:ClearGoal()
	self:SetPos(spot)

	self.loco:ClearStuck()
	self.loco:SetVelocity(vector_origin)

	self:ResetProgress()

	-- Объезды копились вокруг старого места и на новом только мешают.
	self.AvoidAreas = nil
	self.StuckStreak = 0
	self.WatchPos = spot
	self.WatchTime = CurTime()

	if self.OnRelocate then self:OnRelocate(spot) end

	return true
end

function ENT:OnStuck()
	self.StuckCount = (self.StuckCount or 0) + 1
end

function ENT:OnUnStuck()
	self.StuckCount = 0
	self.StuckStreak = 0
end
