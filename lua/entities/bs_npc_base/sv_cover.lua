-- Укрытия: поиск места, где угроза тебя не видит, и позиции для выстрела рядом с ним.
--
-- Всё держится на трассах видимости по точкам навмеша. Замерено на
-- ttt_warsaw_city_school: navmesh.Find стоит 0.005 мс и отдаёт 8..30 площадей,
-- одна трасса MASK_BLOCKLOS — 0.0038 мс. То есть поиск в бюджете 60 точек это
-- меньше половины миллисекунды, и его спокойно можно звать раз в CoverSearchInterval.
--
-- Важно: укрытие ищется от ТОЧКИ, а не от сущности. Так одна и та же функция
-- обслуживает и живого врага, и последнее место, где его видели.

--------------------------------------------------------------------------------
-- Простреливаемость точки
--------------------------------------------------------------------------------

--
-- Видно ли из threatPos точку pos на высоте height.
--
-- Фильтр из двух сущностей, а не self: проверяем чужое место, и собственный
-- корпус, стоящий сейчас совсем в другом месте, к делу не относится. Врага тоже
-- убираем — иначе он закрывает сам себя.
--
--
-- Видна ли точка из threatPos — ОДИН луч в центр.
--
-- Этого достаточно везде, где вопрос стоит «смогу ли я отсюда выстрелить»:
-- позиция для выстрела, подавление, проверка «вижу ли цель». Лишние лучи тут
-- только дорожают: поиск укрытия с тремя лучами на каждую пробу вырос с 0.4 до
-- 13 мс на вызов.
--
function ENT:IsSpotVisibleFrom(threatPos, pos, height, threat)
	return not util.TraceLine({
		start = threatPos,
		endpos = pos + Vector(0, 0, height),
		filter = {self, threat},
		mask = MASK_BLOCKLOS,
	}).Hit
end

--
-- Укрыта ли точка — три луча по ШИРИНЕ корпуса.
--
-- Вопрос «спрячет ли меня это» и вопрос «увижу ли я отсюда» несимметричны.
-- Одной линии в центр для укрытия мало: боец шириной 32 юнита прятался за всем,
-- что перекрывало её середину, — за фонарным столбом, за тонкой стойкой
-- ограждения. Снаружи это выглядело как «встал посреди открытого места и
-- считает себя укрытым», потому что по бокам его видно целиком.
--
-- Укрытой точка считается, только когда перекрыты ВСЕ три луча: один просвет —
-- значит попасть можно.
--
function ENT:IsSpotCoveredFrom(threatPos, pos, height, threat)
	local target = pos + Vector(0, 0, height)

	local side = (target - threatPos):Cross(vector_up)
	side.z = 0

	if side:LengthSqr() < 1 then
		return not self:IsSpotVisibleFrom(threatPos, pos, height, threat)
	end

	side:Normalize()
	side = side * self.CoverWidthProbe

	for _, offset in ipairs({vector_origin, side, -side}) do
		local tr = util.TraceLine({
			start = threatPos,
			endpos = target + offset,
			filter = {self, threat},
			mask = MASK_BLOCKLOS,
		})

		if not tr.Hit then return false end
	end

	return true
end

-- Точка, из которой смотрит угроза. У игрока это глаза, у NPC — свои глаза.
function ENT:ThreatEyePos(threat, fallback)
	if IsValid(threat) then
		if threat:IsPlayer() then return threat:EyePos() end
		if threat.GetEyeOrigin then return threat:GetEyeOrigin() end

		return threat:WorldSpaceCenter()
	end

	return fallback
end

--
-- Что даёт точка против этой угрозы:
--   "open"  — простреливается и стоя, и в приседе;
--   "low"   — стоя видно, в приседе нет (низкое укрытие, из-за него можно
--             привставать и стрелять);
--   "full"  — не видно вовсе.
--
function ENT:RateSpot(threatPos, pos, threat)
	if not self:IsSpotCoveredFrom(threatPos, pos, self.CoverCrouchEyeHeight, threat) then
		return "open"
	end

	if not self:IsSpotCoveredFrom(threatPos, pos, self.CoverEyeHeight, threat) then
		return "low"
	end

	return "full"
end

-- Прикрыт ли NPC там, где стоит прямо сейчас.
function ENT:IsInCover(threat, threatPos)
	threatPos = self:ThreatEyePos(threat, threatPos)
	if not isvector(threatPos) then return false end

	return self:RateSpot(threatPos, self:GetPos(), threat) ~= "open"
end

--------------------------------------------------------------------------------
-- Перебор точек навмеша
--------------------------------------------------------------------------------

--
-- Точки-кандидаты на площади. Одного центра мало: площади бывают огромные
-- (замерено 75x700 юнитов), и её центр может лежать в совершенно другой
-- тактической обстановке, чем края.
--
local function SamplePoints(area, out, step, budget)
	local corner = area:GetCorner(0)
	local sx, sy = area:GetSizeX(), area:GetSizeY()

	if sx <= step and sy <= step then
		out[#out + 1] = area:GetCenter()

		return
	end

	local added = 0

	for x = step * 0.5, sx, step do
		for y = step * 0.5, sy, step do
			if added >= budget then return end

			out[#out + 1] = area:GetClosestPointOnArea(Vector(corner.x + x, corner.y + y, corner.z))
			added = added + 1
		end
	end
end

-- Габарит там встанет и это не воздух.
function ENT:CanStandAt(pos)
	local mins, maxs = self.CollisionMins, self.CollisionMaxs

	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 2),
		endpos = pos + Vector(0, 0, 2),
		mins = mins,
		maxs = maxs,
		filter = self,
		mask = MASK_NPCSOLID,
	})

	return not tr.Hit
end

--
-- Есть ли рядом с точкой ПРЕГРАДА, к которой можно прижаться.
--
-- RateSpot отвечает только на вопрос «простреливается ли точка», а скрытой её
-- делает что угодно: рельеф, дальний угол дома, машина в двадцати метрах.
-- Занимать такую точку как укрытие можно, но прижиматься там не к чему — и
-- боец вставал в позу прижатого к стене посреди открытой дороги.
--
-- Щуп короткий (CoverWallProbe): преграда дальше вытянутой руки укрытием в этом
-- смысле не является.
--
function ENT:HasCoverWallNear(pos, threatPos, threat)
	local dir = threatPos - pos
	dir.z = 0
	if dir:LengthSqr() < 1 then return false end
	dir:Normalize()

	for _, h in ipairs({self.CoverEyeHeight, self.CoverCrouchEyeHeight}) do
		local from = pos + Vector(0, 0, h)

		local tr = util.TraceLine({
			start = from,
			endpos = from + dir * self.CoverWallProbe,
			filter = {self, threat},
			mask = MASK_SHOT_HULL,
		})

		if tr.Hit then return true end
	end

	return false
end

--------------------------------------------------------------------------------
-- Поиск укрытия
--------------------------------------------------------------------------------

--
-- Найти, куда спрятаться от угрозы.
--
-- Возвращает pos, kind ("full" | "low") либо nil.
--
--   threat     — сущность угрозы (может быть NULL, тогда берётся threatPos)
--   threatPos  — откуда стреляют, если сущности нет
--   opts.radius     — где искать
--   opts.needPeek   — требовать, чтобы рядом была позиция для выстрела
--   opts.minThreat  — не ближе этого к угрозе
--   opts.maxThreat  — и не дальше. Нужно наступлению перебежками: следующий
--                     угол обязан быть ближе к цели, чем тот, где мы стоим,
--                     иначе это не наступление, а метание вдоль фронта
--
-- Без needPeek NPC найдёт самый безопасный угол и просидит там весь бой. Именно
-- поэтому позиция для выстрела — часть требования к укрытию, а не приятное
-- дополнение: укрытие, из которого нельзя стрелять, это не укрытие, а бегство.
--
function ENT:FindCoverSpot(threat, threatPos, opts)
	if not self.CanUseCover then return nil end
	if not navmesh.IsLoaded() then return nil end

	opts = opts or {}
	threatPos = self:ThreatEyePos(threat, threatPos)
	if not isvector(threatPos) then return nil end

	local myPos = self:GetPos()
	local radius = opts.radius or self.CoverSearchRadius
	local minThreat = opts.minThreat or self.CoverMinDistance
	local minThreatSqr = minThreat * minThreat
	local maxThreatSqr = opts.maxThreat and opts.maxThreat * opts.maxThreat or nil

	local areas = navmesh.Find(myPos, radius, self.CoverStepDown, self.CoverStepUp)
	if not areas or #areas == 0 then return nil end

	local myArea = MuR.NPC.GetArea(myPos)

	local budget = self.CoverSampleBudget
	local points = {}

	local best, bestKind, bestScore = nil, nil, math.huge

	for _, area in ipairs(areas) do
		if budget <= 0 then break end
		if not IsValid(area) then continue end
		if area:IsUnderwater() and not self.CanSwim then continue end
		if self:IsAreaAvoided(area) then continue end
		-- Отрезанный от нас кусок карты: добежать до него всё равно нельзя.
		if myArea and not MuR.NPC.CanReachArea(myArea, area) then continue end

		table.Empty(points)
		SamplePoints(area, points, self.CoverSampleStep, 4)

		for _, p in ipairs(points) do
			if budget <= 0 then break end
			budget = budget - 1

			local toThreat = p:DistToSqr(threatPos)
			if toThreat < minThreatSqr then continue end
			if maxThreatSqr and toThreat > maxThreatSqr then continue end

			local kind = self:RateSpot(threatPos, p, threat)
			if kind == "open" then continue end

			--
			-- Цена — это путь, который придётся пробежать под огнём, поэтому
			-- считается от НАС, а не от угрозы. Полное укрытие предпочтительнее
			-- низкого, но не любой ценой: скидка, а не абсолютный приоритет.
			--
			local score = math.sqrt(p:DistToSqr(myPos))
			if kind == "full" then score = score * self.CoverFullBonus end

			if score >= bestScore then continue end
			if not self:CanStandAt(p) then continue end

			-- Прижаться должно быть к чему, иначе это не укрытие, а просто
			-- место, которое сейчас не простреливается.
			if opts.needWall and not self:HasCoverWallNear(p, threatPos, threat) then continue end

			if opts.needPeek and not self:FindPeekSpot(p, threat, threatPos) then continue end

			best, bestKind, bestScore = p, kind, score
		end
	end

	return best, bestKind
end

--
-- Позиция для выстрела рядом с укрытием: точка, откуда угроза ВИДНА, в пределах
-- пары шагов от места, где мы прячемся.
--
-- Это и есть «выглянуть из-за угла». Настоящего leaning у nextbot нет, а шаг в
-- сторону, очередь и шаг обратно читаются как оно же.
--
function ENT:FindPeekSpot(coverPos, threat, threatPos)
	threatPos = self:ThreatEyePos(threat, threatPos)
	if not isvector(threatPos) then return nil end

	local area = MuR.NPC.GetArea(coverPos)
	if not IsValid(area) then return nil end

	local toThreat = threatPos - coverPos
	toThreat.z = 0
	if toThreat:LengthSqr() < 1 then return nil end
	toThreat:Normalize()

	-- Вбок от направления на угрозу, а не к ней: выходить надо из-за края
	-- укрытия, а не на середину простреливаемого пространства.
	local side = toThreat:Cross(vector_up)
	side.z = 0
	side:Normalize()

	--
	-- Вторым значением возвращается СТОРОНА выхода ("l" или "r"). Она тут и так
	-- считается, а анимация выглядывания без неё не выбирается: боец у левого
	-- края укрытия обязан выглядывать влево.
	--
	for _, d in ipairs(self.CoverPeekOffsets) do
		for _, sign in ipairs({1, -1}) do
			local p = coverPos + side * (d * sign)

			local spotArea = MuR.NPC.GetArea(p)
			if not IsValid(spotArea) then continue end

			p = spotArea:GetClosestPointOnArea(p)
			p.z = p.z + 2

			if not self:IsSpotVisibleFrom(threatPos, p, self.CoverEyeHeight, threat) then continue end
			if not self:CanStandAt(p) then continue end

			return p, sign > 0 and "l" or "r"
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- Поиск огневой позиции
--------------------------------------------------------------------------------

--
-- Найти ближайшую точку, откуда цель ВИДНО. Обратная задача к FindCoverSpot и
-- тот же перебор площадей, только критерий вывернут наизнанку.
--
-- Зачем: раньше потерявший видимость NPC просто шёл к позиции врага с
-- tolerance = Weapon_RetreatDistance. Когда цель стояла за углом, переход
-- закрывался «ok» сразу — мы уже были в пределах tolerance, — видимость не
-- появлялась, и следующий кадр начинал то же самое заново. Снаружи это
-- выглядело как «NPC встал в десяти метрах и тупит».
--
-- Цена — путь под огнём, поэтому счёт считается от НАС, как и в поиске укрытий.
--
function ENT:FindFiringSpot(threat, threatPos, opts)
	if not navmesh.IsLoaded() then return nil end

	opts = opts or {}
	threatPos = self:ThreatEyePos(threat, threatPos)
	if not isvector(threatPos) then return nil end

	local myPos = self:GetPos()
	local radius = opts.radius or self.FiringSpotRadius
	local minThreat = opts.minThreat or self.CoverMinDistance
	local minThreatSqr = minThreat * minThreat

	local areas = navmesh.Find(myPos, radius, self.CoverStepDown, self.CoverStepUp)
	if not areas or #areas == 0 then return nil end

	local myArea = MuR.NPC.GetArea(myPos)

	local budget = self.CoverSampleBudget
	local points = {}

	local best, bestScore = nil, math.huge

	for _, area in ipairs(areas) do
		if budget <= 0 then break end
		if not IsValid(area) then continue end
		if area:IsUnderwater() and not self.CanSwim then continue end
		if self:IsAreaAvoided(area) then continue end
		if myArea and not MuR.NPC.CanReachArea(myArea, area) then continue end

		table.Empty(points)
		SamplePoints(area, points, self.CoverSampleStep, 4)

		for _, p in ipairs(points) do
			if budget <= 0 then break end
			budget = budget - 1

			if p:DistToSqr(threatPos) < minThreatSqr then continue end

			local score = math.sqrt(p:DistToSqr(myPos))
			if score >= bestScore then continue end

			-- Стоя: приходить в точку, откуда видно только лёжа, смысла нет.
			if not self:IsSpotVisibleFrom(threatPos, p, self.CoverEyeHeight, threat) then continue end
			if not self:CanStandAt(p) then continue end

			best, bestScore = p, score
		end
	end

	return best
end

--------------------------------------------------------------------------------
-- Троттлинг
--------------------------------------------------------------------------------

-- Поиск дешёвый, но не настолько, чтобы звать его каждый тик на каждого бота.
function ENT:CanSearchCover()
	return CurTime() >= (self.NextCoverSearch or 0)
end

function ENT:MarkCoverSearched()
	self.NextCoverSearch = CurTime() + self.CoverSearchInterval
end

-- Укрытие, которое мы занимаем сейчас. Забывается, когда его простреляли.
--
-- Нормаль и сторона нужны анимациям: без нормали «прижатый к стене» силуэт
-- смотрит в пустоту, без стороны не выбрать, влево или вправо выглядывать.
function ENT:SetCurrentCover(pos, kind, normal, side)
	self.CoverPos = pos
	self.CoverKind = kind
	self.CoverNormal = normal
	self.CoverSide = side
end

function ENT:ClearCover()
	self.CoverPos = nil
	self.CoverKind = nil
	self.CoverNormal = nil
	self.CoverSide = nil
end

--
-- Куда смотрит стена, за которой мы прячемся: нормаль ОТ стены в нашу сторону.
--
-- Щупается веером вокруг направления на угрозу, а не одним лучом. Одного луча
-- мало: укрытие сплошь и рядом это УГОЛ здания, а не стена напротив, и прямой
-- луч на врага проходит мимо него в пустоту. Замерено на живом бойце — нормаль
-- не находилась примерно в половине занятых укрытий, и тогда ни разворот к
-- стене, ни шаг вдоль неё не работали вовсе.
--
-- Из всех попаданий берётся ближайшее: ближняя поверхность и есть то, за чем
-- боец прячется.
--
-- Высот тоже две. Низкое укрытие луч на уровне глаз просто перелетает, и
-- парапет, за которым надо сидеть, остался бы ненайденным.
--
function ENT:CoverWallNormal(pos, threat, threatPos)
	threatPos = self:ThreatEyePos(threat, threatPos)
	if not isvector(pos) or not isvector(threatPos) then return nil end

	local toThreat = threatPos - pos
	toThreat.z = 0
	if toThreat:LengthSqr() < 1 then return nil end
	toThreat:Normalize()

	local bestNormal, bestDist, bestHit = nil, math.huge, nil

	for _, h in ipairs({self.CoverEyeHeight, self.CoverCrouchEyeHeight}) do
		local from = pos + Vector(0, 0, h)

		for _, deg in ipairs(self.CoverWallAngles) do
			local dir = Vector(toThreat)
			dir:Rotate(Angle(0, deg, 0))

			local tr = util.TraceLine({
				start = from,
				endpos = from + dir * self.CoverWallProbe,
				filter = {self, threat},
				mask = MASK_BLOCKLOS,
			})

			if tr.Hit and tr.HitNormal then
				local n = tr.HitNormal
				n.z = 0

				-- Пол и потолок укрытием не считаем: у них нормаль почти
				-- вертикальна, и после обнуления z от неё ничего не остаётся.
				if n:LengthSqr() > 0.01 then
					local d = tr.HitPos:Distance(from)

					if d < bestDist then
						n:Normalize()
						bestNormal, bestDist = n, d
						bestHit = tr.HitPos
					end
				end
			end
		end
	end

	--
	-- Стену не нашли: бывает, когда прикрывает не поверхность, а рельеф или
	-- дальний угол. Отдаём направление ОТ угрозы — поза встанет спиной к
	-- обстрелу, и это заведомо лучше, чем не встать вовсе.
	--
	if not bestNormal then return -toThreat, nil, nil end

	return bestNormal, bestDist, bestHit
end

--
-- Придвинуть точку укрытия вплотную к преграде.
--
-- Поиск отдаёт точку навмеша, а она лежит там, где легла сетка, — обычно в
-- метре-полутора от стены. Боец вставал «около» укрытия, а не за ним: и
-- простреливался, и выглядел так, будто просто остановился рядом.
--
-- Возвращает подтянутую точку либо исходную, если притираться не к чему или
-- у стены не помещается габарит.
--
function ENT:HugCover(pos, normal, wallPos)
	if not isvector(pos) or not isvector(normal) or not isvector(wallPos) then return pos end

	local hugged = wallPos + normal * self.CoverHugDistance
	hugged.z = pos.z

	local area = MuR.NPC.GetArea(hugged)
	if not IsValid(area) then return pos end

	hugged = area:GetClosestPointOnArea(hugged)
	hugged.z = hugged.z + 2

	if not self:CanStandAt(hugged) then return pos end

	return hugged
end

function ENT:HasCover()
	return isvector(self.CoverPos)
end

--
-- Укрытие перестало работать: угроза сменила позицию и теперь простреливает то,
-- за чем мы сидим. Проверять обязательно — иначе NPC держится за угол, который
-- обошли, и умирает в нём.
--
function ENT:IsCoverStillGood(threat, threatPos)
	if not self:HasCover() then return false end

	threatPos = self:ThreatEyePos(threat, threatPos)
	if not isvector(threatPos) then return true end

	return self:RateSpot(threatPos, self.CoverPos, threat) ~= "open"
end
