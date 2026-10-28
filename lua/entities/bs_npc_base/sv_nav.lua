-- Навигация: стоимость пути и прохождение особых участков навмеша.
--
-- CLuaLocomotion сам умеет только ходить по земле. Лазание по уступам и
-- лестницам он НЕ реализует — движок ждёт этого от нас. Именно поэтому NPC
-- залипали у ограды: навмеш кладёт поверх неё тонкую площадь с атрибутом
-- NAV_MESH_OBSTACLE_TOP, путь через неё строится, а loco туда не забирается.
--
-- Здесь два слоя:
--   1. Генератор стоимости для Path:Compute — отговаривает от неудобных мест
--      (ограды, зоны AVOID, приседания, лестницы) и режет непроходимое.
--   2. NavAssist — каждый тик добавляет то, чего loco не делает сам: прыжок на
--      уступ, перелёт разрыва, подъём по лестнице, приседание.

-- Source Path::SegmentType
BS_PATH_GO = 0
BS_PATH_CLIMB_UP = 1
BS_PATH_DROP_DOWN = 2
BS_PATH_JUMP_GAP = 3
BS_PATH_LADDER_UP = 4
BS_PATH_LADDER_DOWN = 5

--------------------------------------------------------------------------------
-- Стоимость пути
--------------------------------------------------------------------------------

-- Площади, которые этот NPC временно объезжает: id -> время, до которого избегать.
function ENT:AvoidArea(area, duration)
	if not IsValid(area) then return end

	self.AvoidAreas = self.AvoidAreas or {}
	self.AvoidAreas[area:GetID()] = CurTime() + (duration or 15)
end

function ENT:IsAreaAvoided(area)
	local t = self.AvoidAreas and self.AvoidAreas[area:GetID()]

	return t ~= nil and t > CurTime()
end

--
-- Генератор для Path:Compute. Отрицательная стоимость = площадь непроходима.
-- Подпись задаёт движок: (area, fromArea, ladder, elevator, length).
--
function ENT:PathCost(area, fromArea, ladder, elevator, length)
	-- Стартовая площадь.
	if not IsValid(fromArea) then return 0 end

	if not self.loco:IsAreaTraversable(area) then return -1 end
	if area:IsBlocked() then return -1 end
	if self:IsAreaAvoided(area) then return -1 end
	if area:IsUnderwater() and not self.CanSwim then return -1 end

	local dist
	if IsValid(ladder) then
		dist = ladder:GetLength()
	elseif length > 0 then
		dist = length
	else
		dist = area:GetCenter():Distance(fromArea:GetCenter())
	end

	local cost = dist + fromArea:GetCostSoFar()

	--
	-- Лестница разбирается ПЕРВОЙ и в обход проверки перепада: она и есть способ
	-- взять высоту, которую обычным ходом не взять. Мерить тут
	-- ComputeAdjacentConnectionHeightChange бессмысленно — концы лестницы в
	-- списках смежности друг друга не лежат, и осмысленного числа оттуда не
	-- придёт (лестница #3 на ttt_warsaw_city_school поднимает на 139 при пределе
	-- подъёма 128).
	--
	if IsValid(ladder) then
		if not self.CanUseLadders then return -1 end

		return cost + dist * self.NavLadderPenalty
	end

	--
	-- Проходим ли сам переход. Решение принято один раз при построении сетки
	-- (MuR.NPC.BuildLinks) и лежит в таблице рёбер: там и пределы подъёма и
	-- спуска, и исключение для пандусов, и честная проверка габаритом.
	--
	-- Считать это здесь нельзя по двум причинам. Первая — цена: A* зовёт
	-- генератор тысячи раз за путь, а габаритная трасса стоит как три трассы
	-- видимости. Вторая важнее: заливка компонент связности в геймдмоде обязана
	-- идти по ТОМУ ЖЕ набору рёбер, иначе CanReach обещает маршрут, которого
	-- Path:Compute не находит, и NPC каждый тик считает полный A* впустую.
	--
	if not MuR.NPC.IsLinkOpen(fromArea, area) then return -1 end

	--
	-- Переход, на котором кто-то из наших уже упёрся и не смог перелезть.
	-- Предпроверка такие не ловит: ограда стоит на ровном месте, перепада между
	-- площадями нет, и стык выглядит честным.
	--
	if MuR.NPC.IsLinkBlocked(fromArea, area) then return -1 end

	-- Перепад высот на стыке. Ребро уже признано проходимым, осталось понять,
	-- надо ли за него доплачивать: подъём исполняется перелазом, а он медленный.
	local dz = fromArea:ComputeAdjacentConnectionHeightChange(area)

	if dz >= self.loco:GetStepHeight() then
		if not self.CanJumpObstacles then return -1 end
		cost = cost + dist * self.NavJumpPenalty
	end

	-- Верх ограды или ящика. Штраф большой намеренно: если рядом есть проход,
	-- обойти всегда лучше, чем перелезать.
	if area:HasAttributes(NAV_MESH_OBSTACLE_TOP) then
		cost = cost + dist * self.NavObstaclePenalty
	end

	if area:HasAttributes(NAV_MESH_AVOID) then
		cost = cost + dist * self.NavAvoidPenalty
	end

	if area:HasAttributes(NAV_MESH_CROUCH) then
		if not self.CanCrouch then return -1 end
		cost = cost + dist * self.NavCrouchPenalty
	end

	return cost
end

-- Замыкание для Path:Compute.
function ENT:GetPathCostFunc()
	self.BSPathCostFunc = self.BSPathCostFunc or function(area, fromArea, ladder, elevator, length)
		return self:PathCost(area, fromArea, ladder, elevator, length)
	end

	return self.BSPathCostFunc
end

--------------------------------------------------------------------------------
-- Достижимость и троттлинг поиска пути
--------------------------------------------------------------------------------

--
-- Можно ли вообще дойти. Проверка по компонентам связности навмеша, посчитанным
-- при построении сетки: O(1) против полного обхода A*.
--
-- Это главная защита от просадок. Если игрок встал туда, куда пути нет (крыша,
-- отрезанный двор), Path:Compute не проваливается — он молча возвращает путь до
-- ближайшей достижимой точки. NPC доходит туда мгновенно, путь закрывается, и на
-- следующем же тике всё повторяется: полноценный A* по нескольку раз в секунду
-- на каждого бота. Здесь эта ветка отсекается до поиска.
--
function ENT:CanReach(pos)
	if not isvector(pos) then return false end

	local area = MuR.NPC.GetArea(pos)
	if not area then return false end

	local myArea = MuR.NPC.GetArea(self:GetPos())
	if not myArea then return false end

	return MuR.NPC.CanReachArea(myArea, area)
end

-- Не чаще, чем раз в PathComputeInterval: A* дорогой, а цель за 0.1 с не убежит.
function ENT:CanComputePath()
	return CurTime() >= (self.NextPathCompute or 0)
end

function ENT:MarkPathComputed()
	self.NextPathCompute = CurTime() + self.PathComputeInterval
end

--------------------------------------------------------------------------------
-- Застревание без ожидания loco
--------------------------------------------------------------------------------

--
-- Своё определение «упёрся»: NPC пытается идти, но реально не сдвинулся.
--
-- Ждать loco:IsStuck() нельзя — он латается несколько секунд, а за это время
-- цикл преследования успевает несколько раз перестроить путь и сбросить его
-- же счётчик. Именно поэтому NPC подолгу стоял у ограды, хотя перелаз работает.
--
function ENT:UpdateProgress()
	local now = CurTime()
	local pos = self:GetPos()

	if not self.ProgressPos then
		self.ProgressPos = pos
		self.ProgressTime = now

		return false
	end

	-- Грация после старта пути: NPC сначала доворачивается (до 0.7 с при
	-- MaxYawRate 250) и разгоняется. Без неё «упёрся» срабатывает на ровном
	-- месте и приказ умирает через пару секунд.
	if now - (self.ProgressStart or 0) < self.ProgressGrace then return false end

	--
	-- Проверки «едет по скорости» здесь БЫЛО и её пришлось убрать:
	-- loco:GetVelocity() у прижатого к преграде бота показывает желаемую
	-- скорость (замерено 65 при желаемой 65 и нулевом смещении), так что
	-- застревание у стены не находилось вовсе.
	--
	-- Обход угла ложным срабатыванием не грозит и без неё: за ProgressTimeout
	-- (1.2 с) идущий шагом NPC проходит под восемьдесят юнитов, а порогом стоит
	-- ProgressDistance = 24.
	--
	if not self.loco:IsAttemptingToMove() then
		self.ProgressPos = pos
		self.ProgressTime = now

		return false
	end

	if pos:DistToSqr(self.ProgressPos) > self.ProgressDistance * self.ProgressDistance then
		self.ProgressPos = pos
		self.ProgressTime = now

		return false
	end

	if now - self.ProgressTime < self.ProgressTimeout then return false end

	self.ProgressPos = pos
	self.ProgressTime = now

	return true
end

function ENT:ResetProgress()
	self.ProgressPos = nil
	self.ProgressTime = nil
	self.ProgressStart = CurTime()
end

--------------------------------------------------------------------------------
-- Приседание
--------------------------------------------------------------------------------

function ENT:SetCrouching(state)
	if self.IsCrouching == state then return end
	self.IsCrouching = state

	local mins, maxs = self.CollisionMins, self.CollisionMaxs

	if state then
		self:SetCollisionBounds(mins, Vector(maxs.x, maxs.y, math.min(maxs.z, self.CrouchHeight)))
	else
		self:SetCollisionBounds(mins, maxs)
	end
end

--------------------------------------------------------------------------------
-- Лестницы
--------------------------------------------------------------------------------

--
-- Подъём и спуск CLuaLocomotion не реализует вовсе, поэтому корпус ведём сами —
-- ровно как в перелазе, и по той же причине.
--
-- Через loco это не делается совсем: замерено в игре на лестнице #3
-- ttt_warsaw_city_school — loco:SetVelocity(0,0,100), выставляемая каждый тик,
-- за две секунды дала РОВНО НОЛЬ подъёма, при этом loco:GetVelocity() честно
-- показывала z=100, а IsOnGround оставался true. Та же ложь про скорость, что и
-- у зажатого бота.
--
-- Приращением от текущей позиции (SetPos(pos.z + speed * dt)) тоже нельзя:
-- гравитация успевает просадить корпус между обновлениями, просадка копится в
-- следующем же шаге, и вместо 120 юнитов/с получается ~18 с проседанием
-- (замерено). Поэтому интерполяция АБСОЛЮТНАЯ: позиция считается от
-- зафиксированного старта и прошедшего времени, и просадка каждый кадр
-- затирается, а не накапливается.
--

-- Площадь, на которую сходим наверху. Движок заполняет не все четыре стороны —
-- на лестнице #3 задана только Forward.
local function TopArea(ladder)
	local a = ladder:GetTopForwardArea()
	if IsValid(a) then return a end

	a = ladder:GetTopBehindArea()
	if IsValid(a) then return a end

	a = ladder:GetTopLeftArea()
	if IsValid(a) then return a end

	a = ladder:GetTopRightArea()
	if IsValid(a) then return a end

	return nil
end

-- Где цепляемся за лестницу: на её плоскости, отступив на габарит.
function ENT:GetLadderHoldPos(ladder, z)
	return ladder:GetPosAtHeight(z) + ladder:GetNormal() * self.LadderHugDistance
end

--
-- Куда сходим. Точка берётся с площади навмеша, а НЕ от самой лестницы: верх
-- лестницы висит в воздухе над краем, и сход туда кончается падением обратно
-- вниз (замерено — бот, поставленный в ladder:GetTop() + normal * 20, улетал с
-- -24 обратно на -160).
--
function ENT:FindLadderExit(ladder, goingUp)
	local area = goingUp and TopArea(ladder) or ladder:GetBottomArea()
	if not IsValid(area) then return nil end

	local edge = goingUp and ladder:GetTop() or ladder:GetBottom()
	local base = area:GetClosestPointOnArea(edge)

	-- Вглубь площадки, если первая точка занята: чаще всего своим же союзником,
	-- слезшим первым.
	local inward = area:GetCenter() - edge
	inward.z = 0
	local hasInward = inward:LengthSqr() > 1
	if hasInward then inward:Normalize() end

	local mins, maxs = self:GetCollisionBounds()
	local crouched = Vector(maxs.x, maxs.y, math.min(maxs.z, self.CrouchHeight))

	--
	-- Сначала пробуем встать в полный рост, и только если не выходит нигде —
	-- пригнувшись. Верх лестницы это почти всегда люк или чердачный лаз, и
	-- отказаться от лестницы из-за низкого потолка хуже, чем вылезти на
	-- четвереньках.
	--
	for _, hull in ipairs({maxs, crouched}) do
		for _, d in ipairs(self.LadderExitInsets) do
			local spot = (hasInward and d > 0) and (base + inward * d) or base
			local p = self:SettleHullAt(spot, mins, hull)

			if p then return p, hull ~= maxs end
		end
	end

	return nil
end

--
-- Куда сядет габарит над точкой. nil — не встанет никак.
--
-- Щуп идёт СВЕРХУ ВНИЗ хуллом, а не линией и не по плоскости площади. Обе
-- простые проверки тут врут:
--
--   площадь навмеша лежит ниже настоящего пола — габарит ровно в точке площади
--     упирается в worldspawn (замерено у верха лестницы #3 на
--     ttt_warsaw_city_school);
--
--   линия вниз проваливается в сам люк, через который проходит лестница, и
--     находит пол ниже площадки вокруг люка. Габарит в люк не пролезает, и сход
--     отбраковывался как занятый.
--
-- Высота щупа подбирается под РЕАЛЬНЫЙ запас над головой, а не берётся
-- константой. Фиксированные 64 юнита означали требование 64 + 72 = 136 юнитов
-- свободного пространства над точкой схода; над площадкой у люка бывает 87
-- (замерено на ttt_fernwood, лестница #4, площадь 1969). Щуп возвращал
-- StartSolid на всех трёх инсетах, сход не находился, StartLadder отказывался
-- лезть — и NPC не пользовались лестницами вовсе.
--
function ENT:SettleHullAt(spot, mins, maxs)
	local height = maxs.z - mins.z
	local reach = self.LadderExitProbe + height

	local up = util.TraceLine({
		start = spot + Vector(0, 0, 4),
		endpos = spot + Vector(0, 0, reach),
		filter = self,
		mask = MASK_NPCSOLID,
	})

	local room = up.Hit and (up.HitPos.z - spot.z) or reach

	-- Ниже нуля щуп не опускаем: под точкой площади начинается пол, и оттуда
	-- трасса вниз ничего не найдёт.
	local probe = math.Clamp(room - height - 2, 0, self.LadderExitProbe)

	local drop = util.TraceHull({
		start = spot + Vector(0, 0, probe),
		endpos = spot - Vector(0, 0, 16),
		mins = mins,
		maxs = maxs,
		filter = self,
		mask = MASK_NPCSOLID,
	})

	if drop.StartSolid or not drop.Hit then return nil end

	local p = drop.HitPos + Vector(0, 0, 2)

	local hull = util.TraceHull({
		start = p,
		endpos = p,
		mins = mins,
		maxs = maxs,
		filter = self,
		mask = MASK_NPCSOLID,
	})

	if hull.Hit then return nil end

	return p
end

--
-- Вход из NavAssist. Возвращает true, пока движение на этот тик под нашим
-- контролем: сначала подход к подножию силами loco, потом сам подъём.
--
function ENT:TraverseLadder(ladder, goingUp)
	if not IsValid(ladder) then return false end
	if self:IsOnLadder() then return true end
	if CurTime() < (self.NextLadderT or 0) then return false end

	local myPos = self:GetPos()
	local mountZ = goingUp and ladder:GetBottom().z or ladder:GetTop().z
	local mount = self:GetLadderHoldPos(ladder, mountZ)

	-- Подходим к подножию обычным ходом. Цепляться издалека нельзя: корпус
	-- потянуло бы к лестнице сквозь то, что стоит между нами и ей.
	local flat = Vector(mount.x - myPos.x, mount.y - myPos.y, 0)

	if flat:Length() > self.LadderMountDistance then
		self.loco:SetDesiredSpeed(self:GetWalkSpeed())
		self.loco:Approach(mount, 1)
		self.loco:FaceTowards(mount)
		self:PlayActivity(ACT_WALK)

		return true
	end

	-- По высоте тоже должны стоять у нужного конца: путь мог привести нас к
	-- верхней площадке, когда сегмент говорит «вверх».
	if math.abs(myPos.z - mountZ) > self.LadderMountHeight then
		self.NextLadderT = CurTime() + 0.5

		return false
	end

	return self:StartLadder(ladder, goingUp)
end

function ENT:StartLadder(ladder, goingUp)
	local exit, crouch = self:FindLadderExit(ladder, goingUp)
	if not exit then
		-- Слезть некуда — не лезем вовсе, иначе застрянем на середине.
		self.NextLadderT = CurTime() + 1

		return false
	end

	local from = self:GetPos()
	local targetZ = goingUp and ladder:GetTop().z or ladder:GetBottom().z
	local rise = math.abs(targetZ - from.z)

	self.LadderEnt = ladder
	self.LadderUp = goingUp
	self.LadderFromZ = from.z
	self.LadderToZ = targetZ
	self.LadderExit = exit
	self.LadderExitCrouch = crouch == true
	self.LadderStarted = CurTime()
	self.LadderDuration = math.max(rise / self.LadderSpeed, 0.1)

	self:PlayActivity(self.LadderActivity or (goingUp and ACT_CLIMB_UP or ACT_CLIMB_DOWN))

	return true
end

function ENT:IsOnLadder()
	return self.LadderEnt ~= nil
end

function ENT:StopLadder()
	self.LadderEnt = nil
	self.LadderExit = nil
	self.NextLadderT = CurTime() + 0.3

	if self.loco then
		self.loco:ClearStuck()
		self.loco:SetVelocity(vector_origin)
	end

	self:ResetProgress()
end

--
-- Вызывается из Think. true, пока подъём идёт.
--
function ENT:UpdateLadder()
	local ladder = self.LadderEnt
	if ladder == nil then return false end

	-- Лестница пропала вместе с навмешем (смена карты, перегенерация).
	if not IsValid(ladder) then
		self:StopLadder()

		return false
	end

	local f = (CurTime() - self.LadderStarted) / self.LadderDuration

	if f >= 1 then
		-- Сход нашёлся только под низким потолком: вылезаем пригнувшись, иначе
		-- габарит в полный рост тут же упрётся в перекрытие.
		if self.LadderExitCrouch then self:SetCrouching(true) end

		self:SetPos(self.LadderExit)
		self:StopLadder()

		return false
	end

	local z = Lerp(f, self.LadderFromZ, self.LadderToZ)
	local hold = self:GetLadderHoldPos(ladder, z)

	self:SetPos(Vector(hold.x, hold.y, z))

	-- Лицом к лестнице: нормаль смотрит ОТ неё, поэтому цель ставим за спину.
	self:FaceAngle((-ladder:GetNormal()):Angle())
	self.loco:SetVelocity(vector_origin)

	return true
end

--------------------------------------------------------------------------------
-- Перелаз через преграду
--------------------------------------------------------------------------------

function ENT:CanProbeClimb()
	local now = CurTime()
	if now < (self.NextClimbProbe or 0) then return false end
	self.NextClimbProbe = now + self.ClimbProbeInterval

	return true
end

--
-- Пора ли лезть вверх, хотя сегмент пути — обычный GO.
--
-- Тип CLIMB_UP движок ставит далеко не всегда: соединение площадей бывает самым
-- обычным, без атрибутов и хинтов, а физически там уступ или парапет. Тогда
-- loco просто упирается в него и идёт в стену на месте. Поэтому решаем по
-- геометрии, а не по типу сегмента и не по атрибутам площади.
--
-- По seg.pos судить нельзя: при SetMinLookAheadDistance(250) текущая точка пути
-- бывает в четверти сотни метров впереди, и её высота ничего не говорит о том,
-- что под носом.
--
-- Ждать застревания тоже нельзя — это полторы секунды грации плюс таймаут,
-- почти три секунды стояния лицом в парапет. Вместо этого щупаем сами, но
-- только когда NPC реально притормозило: пока он идёт свободно, щупать нечего.
--
function ENT:NeedsClimb(dir)
	if not self.CanJumpObstacles then return false end
	if self:IsVaulting() then return false end
	if not self.loco:IsOnGround() then return false end
	if not self.loco:IsAttemptingToMove() then return false end

	--
	-- Никакой проверки «стоит на месте» здесь нет намеренно, и это важно.
	--
	-- Сначала пробовалось по loco:GetVelocity() — она врёт: у бота, упёртого в
	-- стену, равна желаемой (замерено 65 при желаемой 65 и нулевом смещении).
	-- Затем по фактическому смещению — но упёртый в парапет NPC не стоит, а
	-- скребёт вдоль него: сдвиг за интервал скакал от 0.7 до 17 юнитов, и любой
	-- порог срабатывал через раз.
	--
	-- Условие подъёма и без этого полное: путь ведёт на сегмент выше нас (его
	-- ищет FindClimbDir) И в том направлении стоит твёрдое. Больше знать нечего.
	--
	return (self:IsBlockedAhead(dir or self:GetMoveDir()))
end

--
-- Куда подниматься по текущему пути: горизонтальное направление на первый
-- сегмент, который выше нас настолько, что loco его не перешагнёт.
--
-- GetMoveDir здесь НЕ годится: при SetMinLookAheadDistance(250) текущая цель
-- пути — сглаженная точка далеко впереди, и направление на неё смотрит мимо
-- уступа. Замерено: щуп уходил по открытому тротуару, находил там ровное место
-- и NPC подскакивал на месте вместо подъёма.
--
function ENT:FindClimbDir(path)
	if not path or not path:IsValid() then return nil end

	local myPos = self:GetPos()
	local step = self.loco:GetStepHeight()

	for _, seg in ipairs(path:GetAllSegments() or {}) do
		if not isvector(seg.pos) then continue end

		local dz = seg.pos.z - myPos.z
		if dz <= step or dz > self.VaultMaxHeight then continue end

		local flat = Vector(seg.pos.x - myPos.x, seg.pos.y - myPos.y, 0)
		local d = flat:Length()
		if d > self.ClimbSegmentReach then continue end

		if d < 1 then return self:GetForward() end

		flat:Normalize()

		return flat
	end

	return nil
end

-- Есть ли прямо по курсу твёрдая преграда (в отличие от разрыва в полу).
function ENT:IsBlockedAhead(dir)
	local foot = self:GetPos() + Vector(0, 0, self.loco:GetStepHeight() + 4)

	local tr = util.TraceHull({
		start = foot,
		endpos = foot + dir * self.VaultReach,
		mins = Vector(-12, -12, 0),
		maxs = Vector(12, 12, 16),
		filter = self,
		mask = MASK_NPCSOLID,
	})

	return tr.Hit, tr
end

--
-- Место, где габарит реально встанет. Точка приземления не обязана быть ровно
-- там, куда смотрит щуп: на узком карнизе за стеклом корпус помещается только
-- у наружного края, и проверка строго в точке щупа отклоняла перелаз вовсе.
--
-- Порядок перебора не случаен: сначала сама точка, потом ближе к наружному краю
-- (мы подходим снаружи, там свободнее), потом вдоль карниза.
--
function ENT:FitHullAt(cand, dir, mins, maxs)
	local side = dir:Cross(vector_up)

	for _, off in ipairs(self.VaultFitOffsets) do
		local p = cand - dir * off[1] + side * off[2]

		local hull = util.TraceHull({
			start = p,
			endpos = p,
			mins = mins,
			maxs = maxs,
			filter = self,
			mask = MASK_NPCSOLID,
		})

		if not hull.Hit then
			-- Пол под точкой обязателен: иначе перелаз кончается шагом в пустоту.
			local floor = util.TraceLine({
				start = p + Vector(0, 0, 4),
				endpos = p - Vector(0, 0, self.loco:GetStepHeight() + 12),
				filter = self,
				mask = MASK_NPCSOLID,
			})

			if floor.Hit then return floor.HitPos + Vector(0, 0, 2) end
		end
	end

	return nil
end

--
-- Куда можно перелезть. Условия жёсткие намеренно: перелаз переносит корпус,
-- поэтому цена ошибки — проход сквозь стену.
--
--   * под точкой есть пол;
--   * габарит там встаёт (допускается сдвиг в пределах карниза, см. FitHullAt);
--   * это валидная площадь навмеша, и не верх той же преграды;
--   * перепад высот в пределах VaultMaxHeight;
--   * над преградой есть свободный коридор — значит перелезаем, а не
--     просачиваемся через толстую стену.
--
function ENT:FindVaultDestination(dir)
	local maxHeight = self.VaultMaxHeight

	local mins, maxs = self:GetCollisionBounds()
	local myPos = self:GetPos()
	local myArea = MuR.NPC.GetArea(myPos)

	for d = self.VaultReach * 0.5, self.VaultMaxDistance, 8 do
		local probe = myPos + dir * d + Vector(0, 0, maxHeight)

		local down = util.TraceLine({
			start = probe,
			endpos = probe - Vector(0, 0, maxHeight + self.loco:GetDeathDropHeight()),
			filter = self,
			mask = MASK_NPCSOLID,
		})

		if not down.Hit then continue end

		local cand = down.HitPos + Vector(0, 0, 2)

		local dz = cand.z - myPos.z
		if math.abs(dz) > maxHeight then continue end

		cand = self:FitHullAt(cand, dir, mins, maxs)
		if not cand then continue end
		dz = cand.z - myPos.z

		local area = MuR.NPC.GetArea(cand)
		if not IsValid(area) then continue end
		if area:HasAttributes(NAV_MESH_OBSTACLE_TOP) then continue end

		--
		-- Перелаз, который ничего не даёт: тот же уровень и та же площадь.
		-- Замерено — щуп по открытому тротуару находил ровное место в двух
		-- юнитах, NPC подскакивал на месте, попытка тратилась, а настоящая
		-- преграда так и оставалась неразобранной.
		--
		if dz < self.loco:GetStepHeight() and area == myArea then continue end

		--
		-- Дуга перелаза целиком: ВВЕРХ, поперёк, ВНИЗ.
		--
		-- Раньше проверялся только горизонтальный отрезок на высоте дуги, и это
		-- пропускало самый заметный случай — лестницу. Щуп ищет пол трассой
		-- сверху вниз от точки, поднятой на VaultMaxHeight: под лестничным
		-- маршем он находит пол СЛЕДУЮЩЕГО этажа, перепад укладывается в предел,
		-- коридор на высоте дуги внутри проёма свободен — и бот «перелезает»
		-- сквозь перекрытие вместо того, чтобы подняться по ступеням.
		--
		-- Вертикальные отрезки это и ловят: над головой перекрытие, значит
		-- взлететь оттуда нельзя.
		--
		local apex = math.max(myPos.z, cand.z) + self.VaultArc
		local overFrom = Vector(myPos.x, myPos.y, apex)
		local overTo = Vector(cand.x, cand.y, apex)

		local probeMins, probeMaxs = Vector(-12, -12, -8), Vector(12, 12, 8)

		-- Подъём: между макушкой и дугой не должно быть потолка.
		local rise = util.TraceHull({
			start = myPos + Vector(0, 0, maxs.z),
			endpos = overFrom,
			mins = probeMins,
			maxs = probeMaxs,
			filter = self,
			mask = MASK_NPCSOLID,
		})
		if rise.Hit then continue end

		-- Коридор над преградой: если и он перекрыт, значит впереди стена.
		local over = util.TraceHull({
			start = overFrom,
			endpos = overTo,
			mins = probeMins,
			maxs = probeMaxs,
			filter = self,
			mask = MASK_NPCSOLID,
		})
		if over.Hit then continue end

		-- Спуск на площадку: сверху над целью тоже должно быть открыто.
		local drop = util.TraceHull({
			start = overTo,
			endpos = cand + Vector(0, 0, maxs.z),
			mins = probeMins,
			maxs = probeMaxs,
			filter = self,
			mask = MASK_NPCSOLID,
		})
		if drop.Hit then continue end

		return cand
	end

	return nil
end

--
-- Управляемый перелаз: корпус ведётся по дуге за VaultTime.
--
-- loco:Jump() и JumpAcrossGap упёртому в геометрию боту не помогают — замерено
-- в игре: бот отрывается от земли, но высота не растёт вообще, и он остаётся
-- у ограды. CLuaLocomotion лазания не реализует, так что двигаем сами.
--
function ENT:StartVault(dest)
	if not isvector(dest) then return false end

	local from = self:GetPos()

	-- Длительность по высоте: низкий парапет берётся рывком, а подъём на
	-- полтора роста за то же время выглядит телепортом вверх.
	local rise = math.max(dest.z - from.z, 0)
	local dur = self.VaultTime * math.max(1, rise / self.VaultRefHeight)

	self.VaultFrom = from
	self.VaultTo = dest
	self.VaultStarted = CurTime()
	self.VaultDuration = math.min(dur, self.VaultMaxTime)

	-- Ни ClearGoal, ни SetState: приказ и путь обязаны пережить перелаз.
	-- FollowPath просто ждёт, пока IsVaulting не отпустит.
	self:PlayAnim(self.VaultAnim, true, self.VaultDuration)

	return true
end

function ENT:IsVaulting()
	return self.VaultTo ~= nil
end

-- Вызывается из Think. true, пока перелаз идёт.
function ENT:UpdateVault()
	local dest = self.VaultTo
	if not dest then return false end

	local f = (CurTime() - self.VaultStarted) / self.VaultDuration

	if f >= 1 then
		self:SetPos(dest)
		self.VaultTo = nil
		self.VaultFrom = nil
		self.loco:ClearStuck()
		self.loco:SetVelocity(vector_origin)

		--
		-- Перелаз перенёс корпус через сегмент пути, а тот об этом не знает:
		-- оставшиеся узлы могут тянуть обратно через преграду, и бот лезет
		-- через неё туда-сюда. FollowPath по этому флагу переложит путь от
		-- новой позиции.
		--
		self.PathDirty = true

		return false
	end

	local pos = LerpVector(f, self.VaultFrom, dest)
	pos.z = pos.z + math.sin(f * math.pi) * self.VaultArc

	self:SetPos(pos)
	self.loco:SetVelocity(vector_origin)

	return true
end

--
-- Взять преграду. Через разрыв в полу летим дугой движка, через твёрдое —
-- перелезаем сами.
--
function ENT:TraverseJump(goalPos, forward)
	if self:IsVaulting() then return true end

	--
	-- Разбор последнего прыжка. Делается ЗДЕСЬ, а не по таймеру: следующий
	-- вызов на этом же сегменте означает, что бот приземлился и путь снова
	-- требует прыгать.
	--
	-- Короткое смещение = недолёт: бот взлетел и вернулся на ту же сторону.
	-- Без счётчика такие попытки повторялись каждые 0.4 с вечно — путь-то не
	-- меняется. Два промаха — сегмент помечается на объезд, и пересчёт пути
	-- прокладывает маршрут в обход.
	--
	if self.JumpAttemptPos then
		if not self.loco:IsOnGround() then return true end -- ещё в воздухе

		local moved = self:GetPos() - self.JumpAttemptPos
		moved.z = 0

		if moved:Length() < 30 then
			self.JumpMisses = (self.JumpMisses or 0) + 1
		else
			self.JumpMisses = 0
		end

		self.JumpAttemptPos = nil

		if (self.JumpMisses or 0) >= 2 then
			self.JumpMisses = 0
			self.NextNavJumpT = CurTime() + 2

			self:AvoidArea(self:GetBlockedArea(), self.NavAvoidDuration)

			-- false: прыжок не удался, пусть разбирается обычный сторож
			-- застревания — он и пересчитает путь.
			return false
		end
	end

	if not self.loco:IsOnGround() then return true end
	if CurTime() < (self.NextNavJumpT or 0) then return true end

	--
	-- Направление обязано быть ГОРИЗОНТАЛЬНЫМ.
	--
	-- seg.forward у сегмента прыжка бывает вертикальным: замерено (0, 0, -1) на
	-- спуске. Проверки "не ноль" мало — такой вектор не ноль, но щуп преграды и
	-- поиск точки приземления уходили по нему вертикально вниз, ничего не
	-- находили, и прыжок молча не исполнялся.
	--
	local dir = forward and Vector(forward.x, forward.y, 0) or nil

	if not dir or dir:LengthSqr() < 0.01 then
		dir = goalPos - self:GetPos()
		dir.z = 0
		if dir:LengthSqr() < 1 then return false end
	end

	dir:Normalize()

	self.NextNavJumpT = CurTime() + 0.4

	if not self:IsBlockedAhead(dir) then
		-- Чистый разрыв: движок сам построит дугу. Запомним, откуда прыгали:
		-- если приземлимся рядом, это промах (см. начало функции).
		self.JumpAttemptPos = self:GetPos()
		self.loco:JumpAcrossGap(goalPos, dir)

		return true
	end

	local dest = self:FindVaultDestination(dir)
	if dest then return self:StartVault(dest) end

	return false
end

--------------------------------------------------------------------------------
-- Один тик прохождения пути
--------------------------------------------------------------------------------

--
-- Вызывается из FollowPath после path:Update. Возвращает true, если движение на
-- этот тик взято под свой контроль (лестница, прыжок) — тогда обычные скорости
-- трогать не надо.
--
function ENT:NavAssist(path)
	local seg = path:GetCurrentGoal()
	if not seg then
		self:SetCrouching(false)
		return false
	end

	local area = seg.area
	local segType = seg.type or BS_PATH_GO

	-- Приседание держим по площади, а не по типу сегмента: зона тянется на
	-- несколько шагов, и вставать посередине нельзя.
	if IsValid(area) then
		self:SetCrouching(self.CanCrouch and area:HasAttributes(NAV_MESH_CROUCH))
	end

	if segType == BS_PATH_LADDER_UP or segType == BS_PATH_LADDER_DOWN then
		if self.CanUseLadders then
			return self:TraverseLadder(seg.ladder, segType == BS_PATH_LADDER_UP)
		end

		return false
	end

	if segType == BS_PATH_CLIMB_UP or segType == BS_PATH_JUMP_GAP then
		if self.CanJumpObstacles then
			return self:TraverseJump(seg.pos, seg.forward)
		end

		return false
	end

	if self:CanProbeClimb() then
		local climbDir = self:FindClimbDir(path)

		if climbDir and self:NeedsClimb(climbDir) then
			if self:TryVault(true, climbDir) then return true end
		end
	end

	-- Атрибуты скорости у площади: WALK и RUN задают мапперы вручную.
	if IsValid(area) then
		if area:HasAttributes(NAV_MESH_WALK) then
			self.loco:SetDesiredSpeed(self:GetWalkSpeed())
		elseif area:HasAttributes(NAV_MESH_RUN) then
			self.loco:SetDesiredSpeed(self:GetRunSpeed())
		end

		-- PRECISE — узкий карниз или мостик: никакого объезда препятствий.
		self.loco:SetAvoidAllowed(not area:HasAttributes(NAV_MESH_PRECISE))
	end

	return false
end

--
-- Площадь, на которую NPC пытался пройти в момент застревания. По ней
-- HandleStuck решает, что объезжать.
--
-- Запасной вариант по направлению движения обязателен: путь могли уже
-- сбросить, и тогда объезд молча не срабатывал бы вовсе.
--
function ENT:GetBlockedArea()
	local path = self.CurrentPath

	if path and path:IsValid() then
		local seg = path:GetCurrentGoal()
		if seg and IsValid(seg.area) then return seg.area end
	end

	local ahead = self:GetPos() + self:GetMoveDir() * (self.ObstacleReach + 24)
	local area = MuR.NPC.GetArea(ahead)

	-- Свою же площадь объезжать нельзя: NPC отрежет себя от карты.
	if IsValid(area) and area ~= MuR.NPC.GetArea(self:GetPos()) then return area end

	return nil
end
