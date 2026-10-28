-- Навигационная сетка режима. Раньше строилась из AI Nodes (VJ_Nodegraph.Data),
-- теперь — из навмеша. Формат элемента MuR.AI_Nodes сохранён ({pos = Vector}),
-- поэтому потребители (mode8, mode16, sv_traps) не меняются.
--
-- Ключевое отличие от старой версии: тяжёлые трейсы (крыша над точкой, влезает
-- ли туда габарит игрока) считаются ОДИН раз при построении и лежат в самом
-- узле. Старый MuR:GetRandomPos гонял по два трейса на каждый узел при каждом
-- вызове — на карте с тысячами узлов это тысячи трейсов за вызов, а зовут его
-- sv_rounds, sv_npc, шесть режимов и GetFlankPosition (три раза подряд).

MuR.AI_Nodes = MuR.AI_Nodes or {}
MuR.NavReady = MuR.NavReady or false

util.AddNetworkString("MuR.NoNodes")

local HULL_MINS = Vector(-16, -16, 0)
local HULL_MAXS = Vector(16, 16, 72)
local NODE_UP = Vector(0, 0, 4)

-- Площади мельче этого nav_generate плодит сотнями по углам и лестницам;
-- как точки спавна они бесполезны. Габарит игрока 32 в ширину, так что на
-- площади уже такого размера он стоит впритирку и застревает при первом шаге.
local MIN_AREA_SIZE = 48
-- Крупную площадь режем сеткой, иначе на открытой местности один центр даёт
-- одну точку спавна на пол-карты.
local SAMPLE_STEP = 150
local MAX_SAMPLES_PER_AREA = 9

-- Компоненты связности навмеша: area:GetID() -> номер компоненты. Нужны,
-- чтобы не спавнить NPC в отрезанной от карты комнате.
MuR.NavComponents = MuR.NavComponents or {}

--
-- Минимальная доля сетки в основной компоненте, при которой отсеву можно верить.
--
-- Страховка: если навмеш разорван в клочья и «основная» компонента оказалась
-- маленькой, отсечь всё остальное значит остаться без карты. Тогда лучше не
-- фильтровать вовсе.
--
local MAIN_COMP_SANITY = 0.5

--------------------------------------------------------------------------------
-- Построение
--------------------------------------------------------------------------------

-- Живая проверка габарита: ловит всё, включая игроков и NPC. Ей проверяется
-- только уже выбранный узел, а не вся сетка.
local function IsSpotFree(pos)
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 2),
		endpos = pos + Vector(0, 0, 2),
		filter = function(ent) return true end,
		mins = HULL_MINS,
		maxs = HULL_MAXS,
		mask = MASK_SHOT_HULL,
	})

	return not tr.Hit
end

MuR.IsSpotFree = IsSpotFree

-- Статический снимок на момент построения: только мир и карта, без живых
-- сущностей. Живое состояние докручивает IsSpotFree на выбранном узле.
local function IsSpotFreeStatic(pos)
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 2),
		endpos = pos + Vector(0, 0, 2),
		filter = function(ent)
			return not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot())
		end,
		mins = HULL_MINS,
		maxs = HULL_MAXS,
		mask = MASK_SOLID,
	})

	return not tr.Hit
end

--
-- Вода. Флага площади мало: IsUnderwater ставится генератором далеко не всегда,
-- а спавн по пояс в воде выглядит одинаково плохо в обоих случаях.
--
local function IsInWater(pos)
	local c = util.PointContents(pos + Vector(0, 0, 8))

	return bit.band(c, CONTENTS_WATER) ~= 0 or bit.band(c, CONTENTS_SLIME) ~= 0
end

--
-- Компонента связности, в которой стоят спавны игроков.
--
-- Это и есть «игровое поле»: всё, до чего оттуда можно дойти пешком. Площади
-- вне её — крыши, карнизы, запечатанные комнаты и куски за границей карты;
-- спавн там означает NPC, который никогда никого не встретит, или игрока,
-- который никуда не денется.
--
-- Через клип-браши это НЕ делается, проверено замером на ttt_warsaw_city_school:
-- трасса маской CONTENTS_PLAYERCLIP до разбросанных по карте якорей режет 58
-- площадей, из которых 30 — обычное игровое поле. Половина мимо. Клипы стоят и
-- внутри карты, и «отрезан от всех якорей» ловит не только заграждение.
-- Связность в тех же условиях даёт 221 площадь, и 197 из них выше поля больше
-- чем на сотню юнитов — крыши, ровно то, что и надо убрать.
--
local function PlayfieldComponent()
	local votes = {}

	local classes = {
		"info_player_start", "info_player_deathmatch", "info_player_terrorist",
		"info_player_counterterrorist", "info_player_rebel", "info_player_combine",
		"info_player_axis", "info_player_allies", "gmod_player_start",
	}

	for _, class in ipairs(classes) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			local area = navmesh.GetNearestNavArea(ent:GetPos(), false, 512, false, true, -2)
			if not IsValid(area) then continue end

			local comp = MuR.NavComponents[area:GetID()]
			if comp then votes[comp] = (votes[comp] or 0) + 1 end
		end
	end

	local best, bestVotes = nil, 0
	for comp, n in pairs(votes) do
		if n > bestVotes then best, bestVotes = comp, n end
	end

	return best
end

local function IsUnderRoof(pos)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos + Vector(0, 0, 9999),
	})

	return not tr.HitSky
end

-- Точки внутри площади: центр плюс сетка для крупных.
-- GetClosestPointOnArea прижимает точку к поверхности, поэтому высота
-- получается правильной даже на наклонных площадях.
local function SampleArea(area, out)
	out[#out + 1] = area:GetCenter()

	local sx, sy = area:GetSizeX(), area:GetSizeY()
	if sx <= SAMPLE_STEP and sy <= SAMPLE_STEP then return end

	local corner = area:GetCorner(0) -- NORTH_WEST
	local added = 0

	for x = SAMPLE_STEP * 0.5, sx, SAMPLE_STEP do
		for y = SAMPLE_STEP * 0.5, sy, SAMPLE_STEP do
			if added >= MAX_SAMPLES_PER_AREA then return end
			out[#out + 1] = area:GetClosestPointOnArea(Vector(corner.x + x, corner.y + y, corner.z))
			added = added + 1
		end
	end
end

--
-- Заливка по смежным площадям. Смежность в Source односторонняя (обрывы вниз),
-- но для вопроса "вообще связано ли это с остальной картой" её достаточно
-- трактовать как двустороннюю.
--
-- Непроходимые переходы в заливке НЕ участвуют: считать такую площадь
-- достижимой — значит обещать маршрут, которого нет. Что именно непроходимо,
-- решает MuR.NPC.IsLinkOpen, и он же потом отвечает генератору стоимости.
--
-- Цена ложного обещания высокая. Path:Compute на недостижимую цель не
-- проваливается, а молча отдаёт путь до ближайшей точки: NPC доходит туда
-- мгновенно, путь закрывается, и на следующем тике всё повторяется — полный A*
-- по нескольку раз в секунду на каждого бота. Именно так игрок, стоящий на
-- недоступном карнизе, укладывал кадры.
--
-- Обрыв ВНИЗ NPC пройти может, но заливка двусторонняя и отличить направление
-- не умеет, поэтому спуски глубже предела теряются вместе с подъёмами. Потеря
-- терпимая: цель за обрывом считается недостижимой, NPC идёт к ней напрямую
-- (ApproachDirectly) и доходит до кромки.
--
-- Лестницы обходятся ОТДЕЛЬНО от смежности и без проверки перепада: этажи они
-- соединяют по определению, а высота у них любая. Без этого шага каждая лестница
-- на карте оказывалась стыком двух разных компонент — замерено на
-- ttt_warsaw_city_school, все три лестницы соединяли разные компоненты, CanReach
-- отвечал false, и NPC не строил маршрут наверх вообще.
--
local function LadderAreas(ladder, out)
	out[#out + 1] = ladder:GetBottomArea()
	out[#out + 1] = ladder:GetTopForwardArea()
	out[#out + 1] = ladder:GetTopBehindArea()
	out[#out + 1] = ladder:GetTopLeftArea()
	out[#out + 1] = ladder:GetTopRightArea()

	return out
end

local function BuildComponents(areas)
	local comps = {}
	local current = 0
	local linked = {}

	for i = 1, #areas do
		local root = areas[i]
		local rootID = root:GetID()
		if comps[rootID] then continue end

		current = current + 1
		comps[rootID] = current

		local stack = {root}
		while #stack > 0 do
			local area = table.remove(stack)

			for _, adj in ipairs(area:GetAdjacentAreas()) do
				local id = adj:GetID()
				if not comps[id] then
					--
					-- Ровно тот же набор рёбер, по которому строит маршрут
					-- генератор стоимости у NPC (MuR.NPC.IsLinkOpen). Раньше
					-- здесь стояла своя проверка перепада, и она была строже
					-- той, что применял PathCost: CanReach отвечал "нет" там,
					-- где A* маршрут находил, и наоборот.
					--
					-- Связность нужна для прохода туда И обратно, поэтому
					-- ребро засчитывается только когда открыты оба направления.
					--
					if MuR.NPC.IsLinkOpen(area, adj) and MuR.NPC.IsLinkOpen(adj, area) then
						comps[id] = current
						stack[#stack + 1] = adj
					end
				end
			end

			-- Обе стороны лестницы: движок кладёт её и в список подъёма, и в
			-- список спуска смежных площадей.
			table.Empty(linked)

			for dir = 0, 1 do
				for _, ladder in ipairs(area:GetLadders(dir) or {}) do
					if IsValid(ladder) then LadderAreas(ladder, linked) end
				end
			end

			for _, adj in ipairs(linked) do
				if IsValid(adj) and not comps[adj:GetID()] then
					comps[adj:GetID()] = current
					stack[#stack + 1] = adj
				end
			end
		end
	end

	return comps
end

local function BuildNodes()
	MuR.AI_Nodes = {}
	MuR.NavComponents = {}
	MuR.NavReady = false

	if not navmesh.IsLoaded() then
		MuR:BroadcastNoNav()
		return
	end

	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then
		MuR:BroadcastNoNav()
		return
	end

	-- Рёбра считаются ДО заливки: компоненты строятся по ним же.
	MuR.NPC.BuildLinks()

	MuR.NavComponents = BuildComponents(areas)

	local nodes = {}
	local samples = {}

	--
	-- nil означает карту без спавнов игроков или без навмеша под ними: тогда
	-- отсекать не от чего, и фильтр молча не работает. Резать наугад нельзя.
	--
	local mainComp = PlayfieldComponent()
	local outside = {}
	local outsideCount = 0

	for i = 1, #areas do
		local area = areas[i]
		if not IsValid(area) then continue end
		if area:IsUnderwater() then continue end
		if area:GetSizeX() < MIN_AREA_SIZE or area:GetSizeY() < MIN_AREA_SIZE then continue end

		table.Empty(samples)
		SampleArea(area, samples)

		local comp = MuR.NavComponents[area:GetID()]

		for j = 1, #samples do
			local pos = samples[j] + NODE_UP
			if IsInWater(pos) then continue end

			local node = {
				pos = pos,
				area = area,
				comp = comp,
				underroof = IsUnderRoof(pos),
				blocked = not IsSpotFreeStatic(pos),
			}

			nodes[#nodes + 1] = node

			if mainComp and comp ~= mainComp then
				outside[#nodes] = true
				outsideCount = outsideCount + 1
			end
		end
	end

	--
	-- Применяем, только если игровое поле осталось большинством сетки. Иначе
	-- «основной» посчиталась случайная мелкая компонента, и отсев выкосит карту.
	--
	if outsideCount > 0 and (#nodes - outsideCount) >= #nodes * MAIN_COMP_SANITY then
		local kept = {}

		for i = 1, #nodes do
			if not outside[i] then kept[#kept + 1] = nodes[i] end
		end

		nodes = kept
	elseif outsideCount > 0 then
		outsideCount = 0
	end

	MuR.NavOutsideCulled = outsideCount
	MuR.AI_Nodes = nodes
	MuR.NavReady = #nodes > 0

	if not MuR.NavReady then
		MuR:BroadcastNoNav()
	end
end

function MuR:BroadcastNoNav()
	net.Start("MuR.NoNodes")
	net.Broadcast()
end

MuR.BuildNavNodes = BuildNodes

hook.Add("InitPostEntity", "MuR.BuildNavNodes", BuildNodes)
hook.Add("PostCleanupMap", "MuR.BuildNavNodes", BuildNodes)

-- Игрок, зашедший после построения, оверлей о пропавшем навмеше не увидел бы.
hook.Add("PlayerInitialSpawn", "MuR.BuildNavNodes", function(ply)
	if MuR.NavReady then return end

	timer.Simple(3, function()
		if not IsValid(ply) or MuR.NavReady then return end
		net.Start("MuR.NoNodes")
		net.Send(ply)
	end)
end)

-- InitPostEntity не сработает, если геймдмод подняли на уже загруженной карте
-- (changegamemode). Один отложенный проход добивает такой случай.
timer.Simple(1, function()
	if MuR.NavReady or #MuR.AI_Nodes > 0 then return end
	if not navmesh.IsLoaded() then return end
	BuildNodes()
end)

--------------------------------------------------------------------------------
-- Доступ к навмешу
--------------------------------------------------------------------------------

function MuR:GetNavArea(pos)
	if not isvector(pos) then return nil end

	local area = navmesh.GetNearestNavArea(pos, false, 512, false, true, -2)
	if IsValid(area) then return area end

	return nil
end

-- Достижимо ли b из a пешком. Сравнение компонент связности, посчитанных при
-- построении: O(1) вместо прокладки пути.
function MuR:IsReachable(a, b)
	local areaA = isvector(a) and self:GetNavArea(a) or a
	local areaB = isvector(b) and self:GetNavArea(b) or b

	if not IsValid(areaA) or not IsValid(areaB) then return false end

	local compA = MuR.NavComponents[areaA:GetID()]
	local compB = MuR.NavComponents[areaB:GetID()]

	return compA ~= nil and compA == compB
end

--------------------------------------------------------------------------------
-- Выбор позиций
--------------------------------------------------------------------------------

-- skipLOS: только дистанция, без трассировки взгляда. Так работала проверка в
-- FindNearbySpawnPosition до перехода на навмеш; добавить туда LOS значит на
-- открытой карте почти всегда возвращать исходную точку.
local function IsVisibleToPlayers(pos, nearDistSqr, skipLOS)
	local players = player.GetAll()
	local pos2 = pos + Vector(0, 0, 64)

	for i = 1, #players do
		local ply = players[i]
		if not ply:Alive() then continue end

		if ply:GetPos():DistToSqr(pos) < nearDistSqr then return true end
		if not skipLOS and (ply:VisibleVec(pos) or ply:VisibleVec(pos2)) then return true end
	end

	return false
end

--
-- Та же проверка наружу: ручные точки спавна (sv_spawnpoints.lua) обязаны
-- отсеивать «на виду у игроков» по тому же правилу, что и случайные, иначе
-- расставленная точка вела бы себя иначе, чем точка навмеша рядом с ней.
--
function MuR:IsSpawnVisible(pos, nearDistSqr, skipLOS)
	return IsVisibleToPlayers(pos, nearDistSqr or 100000, skipLOS)
end

-- Сколько случайных кандидатов пробуем, прежде чем согласиться на точку,
-- которую видят игроки. Именно здесь раньше сгорал бюджет: старая версия
-- прогоняла VisibleVec по КАЖДОМУ узлу сетки на каждый вызов.
local PICK_ATTEMPTS = 25

-- underroof: true — только под крышей, false — только под небом, nil — любые.
-- withoutply: не отсеивать точки, которые видят игроки.
function MuR:GetRandomPos(underroof, frompos, mindist, maxdist, withoutply)
	local tab = MuR.AI_Nodes
	if #tab == 0 then return nil end

	local minSq = mindist and mindist * mindist or nil
	local maxSq = maxdist and maxdist * maxdist or nil

	-- Дешёвые фильтры: только сравнения полей, посчитанных при построении.
	local candidates = {}

	for i = 1, #tab do
		local node = tab[i]

		if underroof ~= nil then
			if node.underroof ~= underroof or node.blocked then continue end
		end

		local pos = node.pos

		if frompos then
			local dist = frompos:DistToSqr(pos)
			if minSq and dist < minSq then continue end
			if maxSq and dist > maxSq then continue end
		end

		candidates[#candidates + 1] = pos
	end

	if #candidates == 0 then return nil end

	-- Трейсы (габарит и видимость) идут только по вытянутым кандидатам.
	local fallback = nil

	for _ = 1, math.min(PICK_ATTEMPTS, #candidates) do
		local idx = math.random(1, #candidates)
		local pos = candidates[idx]
		table.remove(candidates, idx)

		if IsSpotFree(pos) then
			if withoutply or not IsVisibleToPlayers(pos, 100000) then
				return pos
			end

			-- Точка годная, но на виду: держим про запас на случай, если
			-- скрытой не найдётся вовсе.
			fallback = fallback or pos
		end

		if #candidates == 0 then break end
	end

	return fallback
end

function MuR:FindTwoDistantSpawnLocations(minDistance, maxAttempts)
	minDistance = minDistance or 1500
	maxAttempts = maxAttempts or 100

	local tab = MuR.AI_Nodes
	if #tab == 0 then return nil, nil end

	local validNodes = {}

	for i = 1, #tab do
		local node = tab[i]
		if node.blocked then continue end

		local pos = node.pos
		if IsVisibleToPlayers(pos, 50000) then continue end

		validNodes[#validNodes + 1] = node
	end

	if #validNodes < 2 then return nil, nil end

	local attempts = 0

	while attempts < maxAttempts do
		attempts = attempts + 1

		local firstIndex = math.random(1, #validNodes)
		local first = validNodes[firstIndex]
		local firstPos = first.pos

		local candidates = {}
		for i = 1, #validNodes do
			if i == firstIndex then continue end

			local node = validNodes[i]
			if node.comp ~= first.comp then continue end

			if firstPos:DistToSqr(node.pos) >= minDistance * minDistance then
				candidates[#candidates + 1] = node.pos
			end
		end

		if #candidates > 0 then
			return firstPos, candidates[math.random(1, #candidates)]
		end
	end

	return nil, nil
end

-- Точка на проходимой поверхности в радиусе dist от pos. Раньше это был перебор
-- 360 случайных смещений с четырьмя трейсами на каждое; навмеш отвечает на тот
-- же вопрос напрямую.
function MuR:FindPositionInRadius(pos, dist)
	if not isvector(pos) then return nil end

	local areas = navmesh.Find(pos, dist, 40, 40)
	if not areas or #areas == 0 then return nil end

	local candidates = {}

	for i = 1, #areas do
		local area = areas[i]
		if not IsValid(area) or area:IsUnderwater() then continue end

		local spot = area:GetRandomPoint() + NODE_UP
		if spot:DistToSqr(pos) <= dist * dist and IsSpotFree(spot) then
			candidates[#candidates + 1] = spot
		end
	end

	if #candidates == 0 then return nil end

	return candidates[math.random(1, #candidates)]
end

function MuR:FindNearbySpawnPosition(basePos, maxDistance)
	maxDistance = maxDistance or 500

	if not isvector(basePos) then return basePos end

	local areas = navmesh.Find(basePos, maxDistance, 40, 40)
	if not areas or #areas == 0 then return basePos end

	local nearby = {}

	for i = 1, #areas do
		local area = areas[i]
		if not IsValid(area) or area:IsUnderwater() then continue end

		local spot = area:GetClosestPointOnArea(basePos) + NODE_UP
		local distSqr = basePos:DistToSqr(spot)
		if distSqr > maxDistance * maxDistance then continue end
		if IsVisibleToPlayers(spot, 40000, true) then continue end
		if not IsSpotFree(spot) then continue end

		nearby[#nearby + 1] = {pos = spot, dist = distSqr}
	end

	if #nearby == 0 then return basePos end

	table.SortByMember(nearby, "dist", true)

	return nearby[math.random(1, math.min(5, #nearby))].pos
end

function MuR:FindFarthestSpawnFromPlayers()
	local tab = MuR.AI_Nodes
	if #tab == 0 then return nil end

	local alivePlayers = {}
	for _, ply in player.Iterator() do
		if ply:Alive() then
			alivePlayers[#alivePlayers + 1] = ply
		end
	end

	if #alivePlayers == 0 then
		return MuR:GetRandomPos()
	end

	local bestPos = nil
	local bestMinDist = 0

	for i = 1, #tab do
		local node = tab[i]
		if node.blocked then continue end

		local pos = node.pos
		local minDistToPlayer = math.huge
		local isVisible = false

		for j = 1, #alivePlayers do
			local ply = alivePlayers[j]
			local distSqr = ply:GetPos():DistToSqr(pos)
			if distSqr < minDistToPlayer then
				minDistToPlayer = distSqr
			end
			if ply:VisibleVec(pos) or ply:VisibleVec(pos + Vector(0, 0, 64)) then
				isVisible = true
				break
			end
		end

		if not isVisible and minDistToPlayer > bestMinDist then
			bestMinDist = minDistToPlayer
			bestPos = pos
		end
	end

	if bestPos and IsSpotFree(bestPos) then
		return bestPos
	end

	return bestPos or MuR:GetRandomPos()
end
