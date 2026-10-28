-- Общая библиотека собственных NPC (bs_npc_base и наследники).
--
-- Лежит в lua/autorun, а не в геймдмоде, потому что сами NPC живут в
-- lua/entities и обязаны работать вне bloodshed — например, при спавне из
-- Q-меню в песочнице. Геймдмод позже делает MuR = MuR or {}, так что эта
-- таблица переживает его загрузку.

MuR = MuR or {}
MuR.NPC = MuR.NPC or {}

--------------------------------------------------------------------------------
-- Состояния NPC (замена VJ_STATE_*)
--------------------------------------------------------------------------------

BS_STATE_NONE = 0 -- обычное поведение
BS_STATE_FREEZE = 1 -- стоит на месте, не атакует
BS_STATE_ANIM = 2 -- отдан анимации: не ходит и не атакует, сам снимется по таймеру
BS_STATE_ANIM_HOLD = 3 -- то же, но держится, пока состояние не снимут явно

--------------------------------------------------------------------------------
-- Хелперы
--------------------------------------------------------------------------------

-- Живая сущность с ИИ. Entity:IsNPC() для nextbot возвращает false, поэтому
-- по всему аддону нужна одна проверка, покрывающая оба вида.
function MuR.IsAI(ent)
	return IsValid(ent) and (ent:IsNPC() or ent:IsNextBot())
end

-- Наш nextbot (не движковый NPC и не чужой nextbot).
function MuR.IsBSNPC(ent)
	return IsValid(ent) and ent.IsBloodshedNPC == true
end

-- Замена VJ.PICK: значение как есть, случайный элемент из таблицы, nil из пустой.
function MuR.Pick(v)
	if not istable(v) then return v end

	local n = #v
	if n == 0 then return nil end
	if n == 1 then return v[1] end

	return v[math.random(n)]
end

-- Замена VJ.SET: диапазон, который потом разворачивает MuR.Roll.
function MuR.Range(min, max)
	return {min, max}
end

-- Число как есть, {min, max} — случайное значение в диапазоне.
function MuR.Roll(v, default)
	if istable(v) then return math.Rand(v[1], v[2]) end
	if isnumber(v) then return v end

	return default or 0
end

-- Замена VJ.EmitSound. Entity:EmitSound сам разбирает префиксы ')' и '<',
-- поэтому от старой обёртки нужен только выбор из таблицы.
function MuR.EmitSound(ent, snd, level, pitch, volume)
	if not IsValid(ent) then return end

	snd = MuR.Pick(snd)
	if not isstring(snd) or snd == "" then return end

	ent:EmitSound(snd, level or 75, pitch or 100, volume or 1)

	return snd
end

-- Замена VJ.AnimDuration. Принимает и имя последовательности, и её индекс.
function MuR.AnimDuration(ent, anim)
	if not IsValid(ent) or anim == nil then return 0 end

	local seq = isnumber(anim) and anim or ent:LookupSequence(anim)
	if not seq or seq < 0 then return 0 end

	return ent:SequenceDuration(seq)
end

-- Замена VJ.Color2Byte: упаковка цвета в 3-3-2 для EffectData:SetColor.
function MuR.Color2Byte(col)
	if not col then return 0 end

	return math.Round(col.r / 255 * 7) * 32
		+ math.Round(col.g / 255 * 7) * 4
		+ math.Round(col.b / 255 * 3)
end

-- Собрать список звуков из папки. Копия локальной функции, которая была
-- продублирована в четырёх nz_*-NPC.
function MuR.SoundDir(path)
	local out = {}
	local files = file.Find("sound/" .. path .. "/*", "GAME")

	for _, name in ipairs(files or {}) do
		out[#out + 1] = path .. "/" .. name
	end

	return out
end

--------------------------------------------------------------------------------
-- Фракции (замена VJ_NPC_Class)
--------------------------------------------------------------------------------

-- faction -> набор враждебных фракций
MuR.NPC.Factions = MuR.NPC.Factions or {}

function MuR.NPC.AddFaction(name, hostile)
	local set = {}
	for _, f in ipairs(hostile or {}) do set[f] = true end
	MuR.NPC.Factions[name] = set
end

MuR.NPC.AddFaction("player", {"zombie", "pmc", "suspect"})
MuR.NPC.AddFaction("zombie", {"player", "police", "civilian", "suspect", "pmc"})
MuR.NPC.AddFaction("police", {"zombie", "suspect", "pmc"})
MuR.NPC.AddFaction("suspect", {"zombie", "police", "player"})
MuR.NPC.AddFaction("pmc", {"zombie", "police", "player"})
MuR.NPC.AddFaction("civilian", {"zombie"})

-- Классы, которые фракцию сами не объявляют: NPC на VJ Base (свои люди пока
-- там же) и чужие движковые NPC. Порядок важен — сначала конкретные правила.
local classFactions = {
	{match = "bloodshed_suspect", faction = "suspect"},
	{match = "bloodshed_pmc", faction = "pmc"},
	{match = "bloodshed_police", faction = "police"},
	{match = "bloodshed_swat", faction = "police"},
	-- Зомби режима 18 приходят из чужого аддона SMOD; они обязаны быть с
	-- нашими тварями в одной фракции, иначе волна передерётся сама с собой.
	{match = "vj_smod", faction = "zombie"},
	{match = "psyonic", faction = "zombie"},
	{match = "zombie", faction = "zombie"},
	{match = "infected", faction = "zombie"},
	{match = "antlion", faction = "zombie"},
	{match = "headcrab", faction = "zombie"},
	{match = "metropolice", faction = "police"},
	{match = "combine", faction = "police"},
	{match = "citizen", faction = "civilian"},
}

function MuR.NPC.GetFaction(ent)
	if not IsValid(ent) then return nil end
	if ent:IsPlayer() then return ent.BSFaction or "player" end

	-- BSFaction перекрывает всё: им режимы меняют сторону конкретной особи.
	if ent.BSFaction then return ent.BSFaction end
	if ent.IsBloodshedNPC then return ent.Faction end
	if not ent:IsNPC() then return nil end

	local class = ent:GetClass()
	for _, rule in ipairs(classFactions) do
		if string.find(class, rule.match, 1, true) then return rule.faction end
	end

	return "civilian"
end

function MuR.NPC.IsHostile(a, b)
	local fa = MuR.NPC.GetFaction(a)
	local fb = MuR.NPC.GetFaction(b)
	if not fa or not fb then return false end
	if fa == fb then return false end

	local set = MuR.NPC.Factions[fa]

	return set ~= nil and set[fb] == true
end

function MuR.NPC.IsDoor(ent)
	return IsValid(ent) and string.find(ent:GetClass(), "door", 1, true) ~= nil
end

-- Есть ли смысл вообще по этому бить. Двери на картах почти всегда с нулевым
-- здоровьем — урон по ним не делает ничего, их надо открывать.
function MuR.NPC.IsDamageable(ent)
	return IsValid(ent) and ent:GetMaxHealth() > 0 and ent:Health() > 0
end

--
-- Открыта ли дверь. У двух семейств дверей разные внутренние переменные:
--   prop_door_rotating — m_eDoorState: 0 закрыта, 1 открывается, 2 открыта, 3 закрывается
--   func_door*         — m_toggle_state: 0 сверху, 1 снизу (закрыта), 2 идёт вверх, 3 вниз
--
-- Нужно, чтобы отличать «дверь открылась» от «дверь заперта и Use ничего не
-- сделал». Без этой проверки NPC считал запертую дверь решённой задачей и
-- вставал перед ней навсегда.
--
function MuR.NPC.IsDoorOpen(ent)
	if not IsValid(ent) then return false end

	local st = ent:GetInternalVariable("m_eDoorState")
	if st ~= nil then return st == 1 or st == 2 end

	st = ent:GetInternalVariable("m_toggle_state")
	if st ~= nil then return st == 0 or st == 2 end

	return false
end

function MuR.NPC.IsDoorFullyOpen(ent)
	if not IsValid(ent) then return true end

	local st = ent:GetInternalVariable("m_eDoorState")
	if st ~= nil then return st == 2 end

	st = ent:GetInternalVariable("m_toggle_state")
	if st ~= nil then return st == 0 end

	return true
end

-- Двери и то, что можно сломать.
function MuR.NPC.IsBreakable(ent)
	if not IsValid(ent) then return false end

	local class = ent:GetClass()

	if string.find(class, "door", 1, true) then return true end
	if class == "prop_physics" or class == "prop_physics_multiplayer" then return true end
	if string.find(class, "breakable", 1, true) then return true end

	return false
end

--------------------------------------------------------------------------------
-- Навмеш
--------------------------------------------------------------------------------
--
-- Свои обёртки, а не MuR:GetNavArea из геймдмода: NPC должны работать и в
-- песочнице, где sv_nodegraph.lua не загружен вовсе. Замечено по ошибке
-- "attempt to call method 'GetNavArea' (a nil value)" в логе.

--
-- Максимальный подъём на стыке площадей, который NPC способен исполнить.
--
-- Ровно столько, сколько делает перелаз (bs_npc_base.VaultMaxHeight). Выше
-- подниматься нечем: CLuaLocomotion лазать не умеет, а навмеш такие соединения
-- ставит охотно — замерено соединение с перепадом 81 юнит между двумя обычными
-- площадями без атрибутов, с сегментами пути типа GO.
--
-- Читают двое: генератор стоимости пути у NPC и заливка компонент связности в
-- геймдмоде. Число обязано быть одно на всех, иначе NPC считает достижимым то,
-- что не строится, и наоборот.
--
-- 128, а не «сколько берёт игрок»: перелаз скриптовый и физически способен на
-- любую высоту, ограничение тут — здравый смысл и проверки в FindVaultDestination.
-- Замерено на ttt_warsaw_city_school: из 2287 подъёмов навмеша 173 (7.6%) выше
-- прежних 72, и основная их гроздь лежит в 96..127 — это карнизы и парапеты,
-- ради которых пришлось бы править карту. Выше 128 остаются единицы, и там уже
-- честно недостижимые места (крыши), которые обходить и не надо.
--
MuR.NPC.MaxRise = 128

--
-- Максимальный СПУСК на стыке площадей.
--
-- Отдельное число, а не MaxRise: спуск и подъём — разные решения, и раньше они
-- разъезжались. Заливка компонент резала переход по |dz| <= MaxRise в обе
-- стороны, а генератор стоимости пути разрешал падать вплоть до
-- loco:GetDeathDropHeight() (320). Из-за этого CanReach и Path:Compute отвечали
-- по-разному, а маршрут строился через связи «земля — крыша», которых
-- nav_generate наставил в обе стороны.
--
-- Замерено на bs_lost_forest_dusk (1600 площадей, 6737 переходов): глубже 64
-- уходят 142 перехода, глубже 128 — 86, глубже 200 — 30. Это и есть те самые
-- связи с земли на крышу; настоящие пологие спуски сюда не попадают, их
-- вылавливает проверка стыка ниже.
--
MuR.NPC.MaxDrop = 64

--
-- Проходимые переходы навмеша: MuR.NavLinks[fromID][toID] = true.
--
-- Рёбра НАПРАВЛЕННЫЕ. Спрыгнуть с парапета можно, забраться обратно — нет, и
-- одна таблица на оба направления это бы потеряла.
--
MuR.NavLinks = MuR.NavLinks or nil

local LINK_MINS = Vector(-16, -16, 0)
local LINK_MAXS = Vector(16, 16, 72)

-- Насколько отступить от кромки внутрь своей площади, прежде чем щупать габаритом.
local LINK_INSET = 24

--
-- Точка стыка двух площадей. Крест-накрест: ближайшая к чужому центру точка на
-- своей площади. GetClosestPointOnArea прижимает её к поверхности, поэтому на
-- наклонной площади высота получается настоящая, а не от плоскости.
--
local function EdgePoints(from, to)
	return from:GetClosestPointOnArea(to:GetCenter()), to:GetClosestPointOnArea(from:GetCenter())
end

-- Отойти от кромки вглубь площади: в самой кромке габарит всегда наполовину в
-- геометрии соседнего уровня, и любая проба оттуда врёт.
local function Inset(area, p, awayFrom)
	local dir = p - awayFrom
	dir.z = 0
	if dir:LengthSqr() < 1 then return p end

	dir:Normalize()

	return area:GetClosestPointOnArea(p + dir * LINK_INSET)
end

--
-- Посадить габарит на настоящий пол.
--
-- Плоскость площади навмеша лежит НИЖЕ пола, и фиксированный подъём врёт: в
-- точке площади +2 коробка упирается в worldspawn, а с +8 уже свободна. Без
-- посадки проба возвращала StartSolid на 59 переходах из 209 — то есть каждый
-- четвёртый оказывался «непроходим» по причине, к геометрии не относящейся.
--
-- nil означает «пощупать нечем»: над точкой меньше 112 юнитов свободного места
-- (низкий проход, площадь под потолком). Это НЕ повод резать переход.
--
local function Settle(p)
	local tr = util.TraceHull({
		start = p + Vector(0, 0, 40),
		endpos = p - Vector(0, 0, 24),
		mins = LINK_MINS,
		maxs = LINK_MAXS,
		mask = MASK_PLAYERSOLID,
	})

	if tr.StartSolid then return nil end

	return tr.HitPos
end

--
-- Влезает ли габарит в сам переход.
--
-- Проба идёт Г-образно и повторяет то, как NPC переход исполняет: сначала
-- вертикально над нижней точкой на высоту верхней, потом горизонтально на
-- площадку. Прямая трасса от кромки к кромке для этого не годится — она
-- тавтология: между точками с разной высотой стоит сама ступень, и трасса
-- упиралась в неё на 202 переходах из 209, то есть резала ровно то, ради чего
-- перелаз и написан.
--
local function HullFits(low, high, step)
	local ls, hs = Settle(low), Settle(high)

	-- Пощупать нечем — оставляем переход на совести порогов высоты.
	if not ls or not hs then return true end

	local clear = Vector(0, 0, math.max(hs.z - ls.z, 0) + step)

	if util.TraceHull({
		start = ls + Vector(0, 0, 2),
		endpos = ls + clear,
		mins = LINK_MINS,
		maxs = LINK_MAXS,
		mask = MASK_PLAYERSOLID,
	}).Hit then return false end

	return not util.TraceHull({
		start = ls + clear,
		endpos = hs + Vector(0, 0, 2),
		mins = LINK_MINS,
		maxs = LINK_MAXS,
		mask = MASK_PLAYERSOLID,
	}).Hit
end

--
-- Проходим ли переход from -> to. Одно место, где это решается.
--
function MuR.NPC.IsLinkPassable(from, to, step)
	if not IsValid(from) or not IsValid(to) then return false end

	step = step or 18

	local dz = from:ComputeAdjacentConnectionHeightChange(to)

	-- Ровный стык. На bs_lost_forest_dusk это 6358 переходов из 6737 (94%), то
	-- есть щупать габаритом приходится считаные проценты сетки.
	if math.abs(dz) <= step then return true end

	local pa, pb = EdgePoints(from, to)

	--
	-- Пандус и лестничный марш: перепад между ЦЕНТРАМИ большой, а сам стык
	-- плоский. Это ровно тот случай, ради которого правило и писалось — резать
	-- надо вертикальные связки «земля — крыша», а не наклонные переходы между
	-- уровнями.
	--
	if math.abs(pb.z - pa.z) <= step then return true end

	if dz > 0 then
		if dz > MuR.NPC.MaxRise then return false end
	else
		if -dz > MuR.NPC.MaxDrop then return false end
	end

	local lowArea, highArea, low, high = from, to, pa, pb
	if pa.z > pb.z then lowArea, highArea, low, high = to, from, pb, pa end

	low = Inset(lowArea, low, high)
	high = Inset(highArea, high, low)

	return HullFits(low, high, step)
end

--
-- Пересчитать все переходы. Зовётся один раз на карту.
--
function MuR.NPC.BuildLinks()
	MuR.NavLinks = nil
	-- Наученное относится к геометрии этой карты и вместе с ней устаревает.
	MuR.NPC.BlockedLinks = {}

	if not navmesh.IsLoaded() then return 0, 0 end

	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then return 0, 0 end

	local links = {}
	local total, open = 0, 0

	for i = 1, #areas do
		local from = areas[i]
		if not IsValid(from) then continue end

		local row = nil

		for _, to in ipairs(from:GetAdjacentAreas()) do
			if not IsValid(to) then continue end

			total = total + 1

			if MuR.NPC.IsLinkPassable(from, to) then
				row = row or {}
				row[to:GetID()] = true
				open = open + 1
			end
		end

		if row then links[from:GetID()] = row end
	end

	MuR.NavLinks = links

	return total, open
end

--
-- Переходы, которые НЕ УДАЛОСЬ пройти в бою: [fromID][toID] = время, до которого
-- считать закрытым.
--
-- Зачем отдельно от предпроверки. BuildLinks щупает габаритом только стыки с
-- перепадом выше ступеньки, а ровные пропускает как заведомо честные. Ограда,
-- парапет и угол стоят на ровном месте: перепада между площадями нет, и такой
-- переход выглядит проходимым. Замерено на ttt_warsaw_city_school — из 16410
-- ровных переходов 1139 перекрыты мировой геометрией.
--
-- Автоматически резать их по трассе нельзя: тот же щуп задевает двери, ломаемое
-- и узкие проходы, то есть режет законные пути. Поэтому вместо предсказания —
-- факт: бот упёрся, перелезть не смог, переход закрыт.
--
-- Реестр ОБЩИЙ на карту, а не на бота. Личный список означал бы, что каждый
-- следующий NPC заново отыгрывает то же колебание у той же ограды на глазах у
-- игрока.
--
MuR.NPC.BlockedLinks = MuR.NPC.BlockedLinks or {}

-- Сколько держать переход закрытым. Ограда за это время никуда не денется, а
-- случайная преграда (застрявший проп, толпа) успеет разойтись.
MuR.NPC.BlockedLinkTime = 60

function MuR.NPC.BlockLink(from, to, duration)
	if not IsValid(from) or not IsValid(to) or from == to then return false end

	local id = from:GetID()
	local row = MuR.NPC.BlockedLinks[id]

	if not row then
		row = {}
		MuR.NPC.BlockedLinks[id] = row
	end

	row[to:GetID()] = CurTime() + (duration or MuR.NPC.BlockedLinkTime)

	return true
end

function MuR.NPC.IsLinkBlocked(from, to)
	if not IsValid(from) or not IsValid(to) then return false end

	local row = MuR.NPC.BlockedLinks[from:GetID()]
	if not row then return false end

	local until_ = row[to:GetID()]
	if not until_ then return false end

	if until_ > CurTime() then return true end

	row[to:GetID()] = nil

	return false
end

--
-- Открыт ли переход. Без построенной таблицы (карта без навмеша, ранний вызов)
-- отвечаем «да» — решение остаётся за A*, как и было до появления рёбер.
--
-- Лестницы сюда НЕ попадают: они не лежат в GetAdjacentAreas() и остаются
-- единственным способом сменить уровень, который не режется никогда.
--
function MuR.NPC.IsLinkOpen(from, to)
	local links = MuR.NavLinks
	if not links then return true end
	if not IsValid(from) or not IsValid(to) then return false end

	local row = links[from:GetID()]

	return row ~= nil and row[to:GetID()] == true
end

--
-- Строим и в песочнице тоже: sv_nodegraph.lua живёт в геймдмоде, а NPC
-- спавнятся из Q-меню где угодно. Геймдмод потом зовёт это сам, до заливки
-- компонент — повторный вызов просто пересчитывает таблицу.
--
-- Пути считает сервер, клиенту рёбра не нужны, и навмеша у него нет вовсе.
if SERVER then
	local function BuildLinksIfNoGamemode()
		if MuR.BuildNavNodes then return end

		MuR.NPC.BuildLinks()
	end

	hook.Add("InitPostEntity", "MuR.NPC.BuildLinks", function()
		timer.Simple(0, BuildLinksIfNoGamemode)
	end)

	hook.Add("PostCleanupMap", "MuR.NPC.BuildLinks", BuildLinksIfNoGamemode)

	--
	-- Порог спуска вынесен в convar: подбирать его придётся под карту, а
	-- перестроить рёбра дешевле, чем менять код и перезапускать сервер.
	--
	local maxDropCvar = CreateConVar("bs_nav_maxdrop", tostring(MuR.NPC.MaxDrop), FCVAR_ARCHIVE,
		"Максимальный спуск на стыке площадей навмеша. Выше — переход считается непроходимым.", 0, 512)

	MuR.NPC.MaxDrop = maxDropCvar:GetInt()

	cvars.AddChangeCallback("bs_nav_maxdrop", function(_, _, new)
		MuR.NPC.MaxDrop = math.max(tonumber(new) or 64, 0)
		MuR.NPC.BuildLinks()
	end, "MuR.NPC.MaxDrop")

	--
	-- Отброшенные переходы рисуются красным, открытые с перепадом — зелёным.
	-- Без картинки порог подбирается вслепую: по числам не видно, отрезало ли
	-- лишний двор или ровно те связки «земля — крыша», ради которых всё затевалось.
	--
	concommand.Add("bs_nav_showlinks", function(ply, _, args)
		if not navmesh.IsLoaded() then return end

		local radius = tonumber(args[1]) or 2000
		local origin = IsValid(ply) and ply:GetPos() or Vector(0, 0, 0)
		local step = 18
		local cut, kept = 0, 0

		for _, from in ipairs(navmesh.Find(origin, radius, 512, 512)) do
			if not IsValid(from) then continue end

			for _, to in ipairs(from:GetAdjacentAreas()) do
				if not IsValid(to) then continue end

				local dz = from:ComputeAdjacentConnectionHeightChange(to)
				if math.abs(dz) <= step then continue end

				local a = from:GetClosestPointOnArea(to:GetCenter()) + Vector(0, 0, 4)
				local b = to:GetClosestPointOnArea(from:GetCenter()) + Vector(0, 0, 4)

				if MuR.NPC.IsLinkOpen(from, to) then
					kept = kept + 1
					debugoverlay.Line(a, b, 20, Color(0, 255, 0), true)
				else
					cut = cut + 1
					debugoverlay.Line(a, b, 20, Color(255, 0, 0), true)
					debugoverlay.Text(b, string.format("%d->%d dz=%.0f", from:GetID(), to:GetID(), dz), 20, false)
				end
			end
		end

		MsgN(string.format("[bs_nav] в радиусе %d: отброшено %d, оставлено %d переходов с перепадом", radius, cut, kept))
	end)
end

function MuR.NPC.GetArea(pos)
	if not isvector(pos) then return nil end
	if not navmesh.IsLoaded() then return nil end

	local area = navmesh.GetNearestNavArea(pos, false, 512, false, true, -2)

	return IsValid(area) and area or nil
end

--
-- Достижимо ли пешком. Компоненты связности считает геймдмод при построении
-- сетки; без него (песочница) отвечаем "да" и оставляем решение за A*.
--
function MuR.NPC.CanReachArea(fromArea, toArea)
	if not IsValid(fromArea) or not IsValid(toArea) then return false end

	local comps = MuR.NavComponents
	if not comps then return true end

	local a, b = comps[fromArea:GetID()], comps[toArea:GetID()]
	if a == nil or b == nil then return true end

	return a == b
end

--------------------------------------------------------------------------------
-- Реестр живых ИИ
--------------------------------------------------------------------------------

-- ents.FindInSphere с радиусом обзора возвращал на боевой карте ~2900 сущностей,
-- и это на КАЖДОГО NPC дважды в секунду. Держим готовый список: NPC и nextbot
-- на карте редко больше нескольких десятков.
MuR.NPC.List = MuR.NPC.List or {}

if SERVER then
	hook.Add("OnEntityCreated", "MuR.NPC.Track", function(ent)
		-- На момент создания тип ещё не определён, отсюда отложенная проверка.
		timer.Simple(0, function()
			if IsValid(ent) and MuR.IsAI(ent) then MuR.NPC.List[ent] = true end
		end)
	end)

	hook.Add("EntityRemoved", "MuR.NPC.Track", function(ent)
		MuR.NPC.List[ent] = nil
		-- Притязания заведены НА цель, поэтому вместе с целью и снимаются:
		-- иначе таблица копит записи по каждому убитому за раунд.
		MuR.NPC.Claims[ent] = nil
	end)

	-- Хук ловит только то, что создано после его установки; при перезагрузке
	-- файла на живой карте список надо добрать.
	for _, ent in ipairs(ents.GetAll()) do
		if MuR.IsAI(ent) then MuR.NPC.List[ent] = true end
	end
end

--------------------------------------------------------------------------------
-- Координация: кто на кого идёт и с какой стороны
--------------------------------------------------------------------------------

--
-- Общий реестр притязаний: враг -> {npc -> роль}. Нужен ровно для одного —
-- чтобы вся группа не лезла в одну дверь по одному маршруту.
--
-- Роли:
--   "assault" — давит в лоб. Таких намеренно мало.
--   "flank"   — заходит сбоку, по одному на сторону.
--   "support" — держит дистанцию и стреляет, никуда не лезет.
--
MuR.NPC.Claims = MuR.NPC.Claims or {}

--
-- Сколько народу одновременно давит в лоб и сколько заходит с боков. Все
-- остальные — "support": они дерутся как раньше, просто не лезут вперёд.
--
-- Числа рассчитаны на типичную стычку в 4-6 стволов: двое давят, двое-четверо
-- обходят, остальные работают с места. Для толпы зомби это тоже правильно —
-- орда и должна в основном переть в лоб, обход ей нужен лишь чтобы передние не
-- запирали собой дверной проём.
--
MuR.NPC.MaxAssault = 2
MuR.NPC.MaxFlankPerSide = 2

local function ClaimsFor(enemy)
	local t = MuR.NPC.Claims[enemy]

	if not t then
		t = {}
		MuR.NPC.Claims[enemy] = t
	end

	return t
end

-- Снять притязание. Зовётся при смене цели, потере врага и смерти.
function MuR.NPC.ReleaseRole(npc)
	local prev = npc.ClaimedEnemy

	if IsValid(prev) then
		local t = MuR.NPC.Claims[prev]

		if t then
			t[npc] = nil
			if not next(t) then MuR.NPC.Claims[prev] = nil end
		end
	end

	npc.ClaimedEnemy = nil
	npc.CombatRole = nil
	npc.FlankSide = nil
end

--
-- Взять роль против врага. Уже занятая роль подтверждается, а не выдаётся
-- заново: иначе NPC на каждом тике менял бы решение и топтался на месте.
--
-- Возвращает роль.
--
function MuR.NPC.ClaimRole(npc, enemy)
	if not IsValid(enemy) then
		MuR.NPC.ReleaseRole(npc)

		return "support"
	end

	if npc.ClaimedEnemy == enemy and npc.CombatRole then return npc.CombatRole end

	MuR.NPC.ReleaseRole(npc)

	local t = ClaimsFor(enemy)

	local assault, sides = 0, {[1] = 0, [-1] = 0}

	for other, role in pairs(t) do
		if not IsValid(other) or other:Health() <= 0 then
			t[other] = nil
			continue
		end

		if role == "assault" then
			assault = assault + 1
		elseif role == "flank" and other.FlankSide then
			sides[other.FlankSide] = (sides[other.FlankSide] or 0) + 1
		end
	end

	local role, side = "support", nil

	if assault < MuR.NPC.MaxAssault then
		role = "assault"
	elseif sides[1] < MuR.NPC.MaxFlankPerSide then
		role, side = "flank", 1
	elseif sides[-1] < MuR.NPC.MaxFlankPerSide then
		role, side = "flank", -1
	end

	t[npc] = role
	npc.ClaimedEnemy = enemy
	npc.CombatRole = role
	npc.FlankSide = side

	return role
end

--------------------------------------------------------------------------------
-- Спавн-меню
--------------------------------------------------------------------------------

MuR.NPC.SpawnList = MuR.NPC.SpawnList or {}

function MuR.NPC.Register(class, name, category, weapons)
	MuR.NPC.SpawnList[class] = {name = name, category = category, weapons = weapons}

	list.Set("NPC", class, {
		Name = name,
		Class = class,
		Category = category or "Bloodshed",
		Weapons = weapons,
	})
end
