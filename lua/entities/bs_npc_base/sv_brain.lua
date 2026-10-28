-- Поведение: корутина RunBehaviour и прокладка путей.
--
-- Разделение обязанностей: Think (sv_state.lua) принимает решения и выставляет
-- self.Goal, корутина ниже эти решения исполняет. Держать всё в корутине нельзя
-- — подсистемы вроде морали и памяти обязаны считаться каждый тик независимо
-- от того, идёт ли сейчас NPC по пути.

--
-- Пройти к точке. Только из корутины поведения.
-- Возвращает "ok" | "failed" | "stuck" | "timeout" | "interrupted".
--
--   run        — бежать
--   face       — "enemy": доворачиваться к врагу на ходу
--   fire       — стрелять на ходу, если цель в коридоре (только кто умеет:
--                см. TryFireWhileMoving у bs_npc_human)
--   tolerance  — радиус достижения
--   lookahead  — сглаживание пути
--   maxage     — максимум секунд на весь переход
--   repath     — перепрокладывать путь каждые N секунд
--   target     — функция, возвращающая актуальную цель (для движущегося врага)
--   abort      — функция; true = бросить переход
--
function ENT:FollowPath(pos, opts)
	if not isvector(pos) then return "failed" end

	opts = opts or {}

	-- Недостижимую цель даже не пытаемся считать: Compute не провалится, а
	-- вернёт путь до ближайшей точки, и цикл преследования будет гонять A*
	-- впустую по нескольку раз в секунду.
	if not self:CanReach(pos) then return "unreachable" end

	local cost = self:GetPathCostFunc()

	local path = Path("Follow")
	path:SetMinLookAheadDistance(opts.lookahead or 250)
	path:SetGoalTolerance(opts.tolerance or 24)
	path:Compute(self, pos, cost)
	self:MarkPathComputed()

	if not path:IsValid() then return "failed" end

	self:ResetProgress()

	-- Новый путь обнуляет счётчик промахов прыжков: недолёты считают на одну
	-- попытку прохождения, а не на всю жизнь. Флаг грязного пути тоже снимается:
	-- этот путь уже лежит от текущей позиции.
	self.JumpAttemptPos = nil
	self.JumpMisses = 0
	self.PathDirty = nil

	-- HandleStuck смотрит на текущий сегмент, чтобы понять, что объезжать.
	self.CurrentPath = path

	local speed = opts.run and self:GetRunSpeed() or self:GetWalkSpeed()
	self.loco:SetDesiredSpeed(speed)

	local started = CurTime()

	while path:IsValid() do
		-- Перелаз и лестница ведут корпус сами: путь не бросаем, просто ждём.
		if self:IsVaulting() or self:IsOnLadder() then
			coroutine.yield()
			continue
		end

		if not self:CanMove() then return "interrupted" end
		if opts.abort and opts.abort() then return "interrupted" end

		if self:UpdateDoorWait() then
			coroutine.yield()
			continue
		end

		--
		-- Разбираем преграду: путь НЕ бросаем и заново не считаем.
		--
		-- Дверь ломается несколькими ударами с паузами, и каждая пауза раньше
		-- читалась как застревание: путь умирал, строился новый, тот приводил к
		-- той же двери — и так по кругу, пока площадь не уходила в объезд.
		-- Досчитать до конца дешевле и выглядит осмысленно.
		--
		if self:IsBreakingObstacle() then
			self:ResetProgress()
			self:ContinueBreaking()
			coroutine.yield()
			continue
		end

		path:Update(self)

		-- Порядок важен: сначала движок ведёт по пути, потом мы добавляем то,
		-- чего loco не умеет — лестницы, прыжки, приседание.
		local taken = self:NavAssist(path)

		-- Перелаз или подъём мог начаться прямо сейчас: корпус ведёт Think, и
		-- проверка прогресса ниже приняла бы это за застревание и убила бы путь.
		if self:IsVaulting() or self:IsOnLadder() then
			coroutine.yield()
			continue
		end

		--
		-- Перелаз перенёс корпус через сегмент: переложить путь от новой
		-- позиции, иначе оставшиеся узлы потянут обратно через преграду и бот
		-- полезет через неё туда-сюда (UpdateVault ставит PathDirty).
		--
		if self.PathDirty and self:CanComputePath() then
			self.PathDirty = nil

			local goal = opts.target and opts.target() or pos

			if not self:CanReach(goal) then return "unreachable" end

			path:Compute(self, goal, cost)
			self:MarkPathComputed()

			if not path:IsValid() then return "failed" end
		end

		if not taken and opts.face == "enemy" then
			local enemy = self:GetEnemy()
			if IsValid(enemy) then self.loco:FaceTowards(enemy:GetPos()) end
		end

		--
		-- Анимацию передвижения ставим КАЖДЫЙ тик, а не один раз на старте пути.
		--
		-- Раз в начале было мало: перелаз, лестница и удар подменяют
		-- последовательность напрямую (PlayAnim), и вернуть ходьбу было некому —
		-- NPC доезжал остаток маршрута в позе прыжка или замаха. Повтор ничего
		-- не стоит: PlayActivity выходит сразу, если активити та же, и молчит,
		-- пока анимация залочена.
		--
		-- Скорость читаем у loco, а не из opts: атрибуты площади (NAV_MESH_WALK,
		-- NAV_MESH_RUN) меняют её по дороге, и анимация обязана идти за ней.
		--
		local cur = self.loco:GetDesiredSpeed()
		self:PlayActivity(cur >= self.RunActivityThreshold and ACT_RUN or ACT_WALK)

		--
		-- Огонь на ходу: жест стрельбы не останавливает ноги, поэтому вызов стоит
		-- прямо в цикле перехода, а не в отдельной корутине. Метод есть только у
		-- стрелков (bs_npc_human), твари его не имеют — отсюда guard по наличию.
		--
		if opts.fire and self.TryFireWhileMoving then self:TryFireWhileMoving() end

		-- Два признака: собственный (не сдвинулся, хотя шёл) и штатный от loco.
		if self:UpdateProgress() or self.loco:IsStuck() then
			self:HandleStuck()
			return "stuck"
		end

		if opts.maxage and CurTime() - started > opts.maxage then return "timeout" end

		if opts.repath and path:GetAge() > opts.repath and self:CanComputePath() then
			local goal = opts.target and opts.target() or pos

			if not self:CanReach(goal) then return "unreachable" end

			path:Compute(self, goal, cost)
			self:MarkPathComputed()

			if not path:IsValid() then return "failed" end
		end

		coroutine.yield()
	end

	self:SetCrouching(false)
	-- Путь пройден целиком: серия застреваний прервана.
	self.StuckStreak = 0

	return "ok"
end

--------------------------------------------------------------------------------
-- Корутина
--------------------------------------------------------------------------------

function ENT:RunBehaviour()
	while true do
		if self:Health() <= 0 then
			coroutine.yield()
			continue
		end

		-- ai_disabled: стоим смирно, как это делают движковые NPC.
		if MuR.NPC.AIDisabled() then
			coroutine.yield()
			continue
		end

		if self:IsVaulting() or self:IsOnLadder() then
			coroutine.yield()
			continue
		end

		if not self:CanMove() then
			self:PlayActivity(ACT_IDLE)
			coroutine.yield()
			continue
		end

		local goal = self.Goal

		if goal then
			self:RunGoal(goal)
		else
			self:RunIdle()
		end

		coroutine.yield()
	end
end

-- Исполнение внешнего приказа (OrderMove).
--
-- Застревание НЕ отменяет приказ: после первой же неудачи HandleStuck успевает
-- занести преграду в объезд, и следующая попытка строит путь уже вокруг неё.
-- Без этого NPC упирался в ограду один раз и уходил бродить.
function ENT:RunGoal(goal)
	local status

	for attempt = 1, self.GoalRetries do
		status = self:FollowPath(goal.pos, {
			run = goal.run,
			face = goal.face,
			tolerance = goal.tolerance,
			lookahead = goal.lookahead,
			maxage = goal.maxage,
			repath = goal.repath,
			-- Приказ могли заменить новым, пока мы шли по старому пути.
			abort = function() return self.Goal ~= goal end,
		})

		if status ~= "stuck" and status ~= "failed" then break end
		if self.Goal ~= goal then break end

		-- Пауза, чтобы преграда успела разъехаться (дверь, толпа) и чтобы не
		-- жечь кадр на бесконечные пересчёты пути.
		coroutine.wait(self.GoalRetryDelay)
	end

	self:PlayActivity(ACT_IDLE)

	if self.Goal == goal then self.Goal = nil end
	if goal.onFinish then goal.onFinish(status) end
end

-- Поведение без приказа. Базовый NPC просто стоит; наследники переопределяют.
function ENT:RunIdle()
	self:PlayActivity(ACT_IDLE)
end

--------------------------------------------------------------------------------
-- Преследование и блуждание — общие кирпичи для наследников
--------------------------------------------------------------------------------

function ENT:ChaseEnemy(enemy)
	if not IsValid(enemy) then return "failed" end
	if not self:CanComputePath() then return "throttled" end

	return self:FollowPath(enemy:GetPos(), {
		run = true,
		tolerance = math.max(16, self.MeleeAttackDistance * 0.6),
		lookahead = 200,
		repath = 0.4,
		target = function()
			local e = self:GetEnemy()

			return IsValid(e) and e:GetPos() or enemy:GetPos()
		end,
		abort = function()
			if self.Goal then return true end
			if self:GetEnemy() ~= enemy then return true end

			return self:CanMeleeAttack() or self:CanLeapAttack() or self:CanRangeAttack()
		end,
	})
end

-- Навмеш не достаёт до врага (он на крыше, за окном, в закрытой комнате).
-- Идём напрямую: хотя бы упрёмся в стену рядом с ним, а не замрём на месте.
function ENT:ApproachDirectly(pos, run)
	-- Во время перелаза корпусом управляет UpdateVault; не мешаем.
	if self:IsVaulting() then return end

	if self:IsDoorWaiting() then return end

	local speed = run and self:GetRunSpeed() or self:GetWalkSpeed()
	self.loco:SetDesiredSpeed(speed)
	self.loco:FaceTowards(pos)
	self.loco:Approach(pos, 1)
	self:PlayActivity(speed >= self.RunActivityThreshold and ACT_RUN or ACT_WALK)
end

--------------------------------------------------------------------------------
-- Поиск потерянной цели
--------------------------------------------------------------------------------

--
-- Проверить последнее место, где врага видели. true — значит занялись этим и
-- патруль сейчас не нужен.
--
-- Без этой ветки потеря контакта означала «забыть и уйти бродить»: NPC терял
-- цель за углом и возвращался к патрулю, хотя в него секунду назад стреляли.
--
function ENT:SearchBehaviour()
	local pos = self:GetLastEnemyPos()
	if not pos then return false end

	-- Дошли и никого не нашли: осмотреться и снять наводку.
	if self.SearchedLastPos then
		self:LookAround()
		self:ClearEnemyMemory()

		return true
	end

	if self:GetPos():DistToSqr(pos) < self.SearchReachedDist ^ 2 then
		self.SearchedLastPos = true

		return true
	end

	local status = self:FollowPath(pos, {
		run = true,
		tolerance = self.SearchReachedDist,
		maxage = 15,
		repath = 1,
		abort = function() return IsValid(self:GetEnemy()) end,
	})

	-- Любой исход, кроме прерывания на найденного врага, означает «проверили».
	if status ~= "interrupted" then self.SearchedLastPos = true end

	return true
end

--
-- Повертеть головой на месте. Не украшение: сектор обзора у большинства 150
-- градусов, и зашедший сбоку иначе так и останется незамеченным.
--
function ENT:LookAround()
	for _ = 1, self.SearchLookCount do
		if IsValid(self:GetEnemy()) then return end

		local ang = self:GetAngles()
		ang.y = ang.y + math.Rand(-110, 110)

		self:FaceTowards(self:GetPos() + ang:Forward() * 128)
		self:PlayActivity(ACT_IDLE)
		coroutine.wait(math.Rand(0.5, 1))
	end
end

function ENT:WanderOnce(radius)
	radius = radius or 1200

	local areas = navmesh.Find(self:GetPos(), radius, 60, 60)
	if not areas or #areas == 0 then return "failed" end

	local area = areas[math.random(#areas)]
	if not IsValid(area) then return "failed" end

	return self:FollowPath(area:GetRandomPoint(), {
		run = false,
		maxage = 20,
		abort = function()
			return self.Goal ~= nil or IsValid(self:GetEnemy())
		end,
	})
end
