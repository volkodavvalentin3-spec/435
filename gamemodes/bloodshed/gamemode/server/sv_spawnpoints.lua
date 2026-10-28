-- Ручные точки спавна: хранение, выдача и правка из редактора.
--
-- Зачем они вообще, если есть навмеш. Случайная точка из MuR.AI_Nodes честно
-- отвечает на вопрос «где тут можно стоять», но не отвечает ни на один из тех,
-- что задаёт карта: откуда заходит полиция, где начинают команды, в каком
-- подвале лежит аптечка. Навмеш остаётся запасным вариантом и работает ровно
-- там, где расставленных точек не хватило.
--
-- Источник истины — СЕРВЕР. Редактор только присылает правки и получает список
-- обратно: править вдвоём и сохранять на клиенте одинаково бессмысленно.

MuR.Spawns = MuR.Spawns or {}

util.AddNetworkString("MuR.SpawnEditor.Sync")
util.AddNetworkString("MuR.SpawnEditor.Edit")
util.AddNetworkString("MuR.SpawnEditor.Save")
util.AddNetworkString("MuR.SpawnEditor.Toggle")

local SPAWN_DIR = "bloodshed/spawns"

local function SpawnFile()
	return SPAWN_DIR .. "/" .. game.GetMap() .. ".json"
end

--------------------------------------------------------------------------------
-- Загрузка и сохранение
--------------------------------------------------------------------------------

local function EmptySet()
	local out = {}
	for _, kind in ipairs(MuR.SpawnKinds) do out[kind.id] = {} end

	return out
end

--
-- Разбор одной точки. Файл правится руками чаще, чем кажется, поэтому каждое
-- поле проверяется: одна битая запись не должна ронять весь набор карты.
--
local function ParsePoint(raw)
	if not istable(raw) or not istable(raw.p) then return nil end

	local x, y, z = tonumber(raw.p[1]), tonumber(raw.p[2]), tonumber(raw.p[3])
	if not x or not y or not z then return nil end

	return {
		pos = Vector(x, y, z),
		ang = tonumber(raw.a) or 0,
		chance = math.Clamp(tonumber(raw.c) or MuR.SpawnItemChance, 0, 100),
	}
end

function MuR:LoadSpawns()
	MuR.Spawns = EmptySet()

	local raw = file.Read(SpawnFile(), "DATA")
	if not raw then return 0 end

	local data = util.JSONToTable(raw)
	if not istable(data) then return 0 end

	local total = 0

	for _, kind in ipairs(MuR.SpawnKinds) do
		local list = data[kind.id]
		if not istable(list) then continue end

		for _, entry in ipairs(list) do
			local point = ParsePoint(entry)

			if point then
				local out = MuR.Spawns[kind.id]
				out[#out + 1] = point
				total = total + 1
			end
		end
	end

	return total
end

function MuR:SaveSpawns()
	local data = {}

	for _, kind in ipairs(MuR.SpawnKinds) do
		local list = {}

		for _, point in ipairs(MuR.Spawns[kind.id] or {}) do
			-- Координаты пишем массивом, а не вектором: util.TableToJSON
			-- разворачивает Vector в {x=,y=,z=}, и файл раздувается втрое.
			local entry = {p = {point.pos.x, point.pos.y, point.pos.z}, a = math.Round(point.ang)}

			if kind.id == "items" then entry.c = math.Round(point.chance) end

			list[#list + 1] = entry
		end

		data[kind.id] = list
	end

	local json = util.TableToJSON(data, true)
	if not json then return false end

	file.CreateDir("bloodshed")
	file.CreateDir(SPAWN_DIR)
	file.Write(SpawnFile(), json)

	return true
end

hook.Add("InitPostEntity", "MuR.LoadSpawns", function()
	local n = MuR:LoadSpawns()
	if n > 0 then MsgN("[bloodshed] точек спавна загружено: " .. n) end
end)

hook.Add("PostCleanupMap", "MuR.LoadSpawns", function() MuR:LoadSpawns() end)

--------------------------------------------------------------------------------
-- Доступ
--------------------------------------------------------------------------------

function MuR:GetSpawnPoints(kind)
	return MuR.Spawns[kind] or {}
end

function MuR:HasSpawns(kind)
	return #self:GetSpawnPoints(kind) > 0
end

--
-- Занятые в этом раунде точки игроков.
--
-- Без учёта занятости двое игроков встают в одну точку и расталкиваются, а на
-- карте с четырьмя спавнами это происходит каждый раунд.
--
MuR.SpawnTaken = MuR.SpawnTaken or {}

function MuR:ResetSpawnTaken()
	MuR.SpawnTaken = {}
end

--
-- Какой набор командных точек достаётся команде.
--
-- Монетка на раунд, а не постоянная привязка: наборы равноправны, и без обмена
-- одна и та же сторона всю карту начинала бы в выгодном месте.
--
function MuR:RollTeamSpawnSwap()
	MuR.TeamSpawnSwap = math.random(2) == 1
end

function MuR:GetTeamSpawnKind(teamNum)
	local first = MuR.TeamSpawnSwap and "team2" or "team1"
	local second = MuR.TeamSpawnSwap and "team1" or "team2"

	return teamNum == 2 and second or first
end

--------------------------------------------------------------------------------
-- Выдача позиций
--------------------------------------------------------------------------------

-- Свободна ли точка под габарит прямо сейчас. MuR.IsSpotFree ловит и живых:
-- точка, на которой уже стоит игрок, не годится, даже если расставлена верно.
local function Usable(point)
	return MuR.IsSpotFree and MuR.IsSpotFree(point.pos) or false
end

--
-- Взять точку игрока. nil — расставленных не хватило, и вызывающий обязан
-- откатиться на навмеш.
--
-- Перебор идёт в случайном порядке: по списку подряд первые четверо всегда
-- вставали бы в одни и те же четыре точки.
--
function MuR:TakeSpawnPoint(kind)
	local list = self:GetSpawnPoints(kind)
	if #list == 0 then return nil end

	local taken = MuR.SpawnTaken[kind]
	if not taken then
		taken = {}
		MuR.SpawnTaken[kind] = taken
	end

	local free = {}

	for i = 1, #list do
		if not taken[i] then free[#free + 1] = i end
	end

	-- Точек меньше, чем игроков: занятость сбрасываем и пускаем по второму
	-- кругу. Двое в одной точке всё же лучше, чем спавн в случайном углу карты,
	-- когда автор карты явно указал, где начинать.
	if #free == 0 then
		for i = 1, #list do free[i] = i end
		MuR.SpawnTaken[kind] = {}
		taken = MuR.SpawnTaken[kind]
	end

	while #free > 0 do
		local slot = math.random(#free)
		local idx = free[slot]
		table.remove(free, slot)

		local point = list[idx]

		if Usable(point) then
			taken[idx] = true

			return point.pos, point.ang
		end
	end

	return nil
end

--
-- Позиция для игрока. Ровно то правило, которое и просили: расставленные точки
-- в приоритете, не хватило — добираем навмешем.
--
function MuR:GetPlayerSpawnPos(kind)
	kind = kind or "players"

	local pos, ang = self:TakeSpawnPoint(kind)
	if pos then return pos, ang end

	return MuR:GetRandomPos(false) or MuR:GetRandomPos(true) or MuR:GetRandomPos()
end

-- Позиция для игрока команды. Сторона набора определяется монеткой раунда.
function MuR:GetTeamSpawnPos(teamNum)
	local kind = self:GetTeamSpawnKind(teamNum)

	local pos, ang = self:TakeSpawnPoint(kind)
	if pos then return pos, ang end

	-- Командных точек нет вовсе — общие спавны игроков ближе по смыслу, чем
	-- случайная точка навмеша.
	if self:HasSpawns("players") then
		pos, ang = self:TakeSpawnPoint("players")
		if pos then return pos, ang end
	end

	return MuR:GetRandomPos(false) or MuR:GetRandomPos(true)
end

--
-- Поставить игрока на позицию. Угол выставляем только если точка расставлена
-- вручную: у случайной точки навмеша осмысленного направления нет.
--
function MuR:PlaceAtSpawn(ply, pos, ang)
	if not IsValid(ply) or not isvector(pos) then return false end

	ply:SetPos(pos)

	if ang then
		ply:SetEyeAngles(Angle(0, ang, 0))
	end

	return true
end

--
-- Позиция для НПС.
--
-- Правило: есть хотя бы одна точка НПС — спавним ТОЛЬКО по ним, навмеш в этом
-- случае не трогаем вовсе. Но фильтры остаются те же самые, что были у
-- случайного выбора, иначе волна в mode18 полезет вплотную к игроку: точка,
-- не прошедшая проверку, просто пропускается.
--
--   frompos/mindist/maxdist — как у MuR:GetRandomPos
--   withoutply              — не отсеивать точки, которые видят игроки
--
-- nil означает, что ни одна точка сейчас не годится. Вызывающий сам решает,
-- ждать ли следующего тика: подсовывать ему случайную точку нельзя, иначе
-- смысл расставленных спавнов теряется ровно в тот момент, когда они нужны.
--
function MuR:GetNPCSpawnPos(frompos, mindist, maxdist, withoutply)
	local list = self:GetSpawnPoints("npc")
	if #list == 0 then return nil end

	local minSq = mindist and mindist * mindist or nil
	local maxSq = maxdist and maxdist * maxdist or nil

	local candidates = {}

	for i = 1, #list do
		local point = list[i]

		if frompos then
			local d = frompos:DistToSqr(point.pos)
			if minSq and d < minSq then continue end
			if maxSq and d > maxSq then continue end
		end

		candidates[#candidates + 1] = point
	end

	local fallback = nil

	while #candidates > 0 do
		local idx = math.random(#candidates)
		local point = candidates[idx]
		table.remove(candidates, idx)

		if Usable(point) then
			if withoutply or not MuR:IsSpawnVisible(point.pos) then
				return point.pos, point.ang
			end

			-- Годная, но на виду: держим про запас, как это делает выбор
			-- случайной точки.
			fallback = fallback or point
		end
	end

	if fallback then return fallback.pos, fallback.ang end

	return nil
end

--
-- Точки вещей, сработавшие в этом раунде.
--
-- Шанс разыгрывается ОДИН раз на раунд и на точку, а не при каждом обращении:
-- иначе предмет мигал бы, появляясь и исчезая между вызовами.
--
function MuR:RollItemSpawns()
	local out = {}

	for _, point in ipairs(self:GetSpawnPoints("items")) do
		if math.random(100) <= point.chance then
			out[#out + 1] = {pos = point.pos, ang = point.ang}
		end
	end

	return out
end

--------------------------------------------------------------------------------
-- Правка из редактора
--------------------------------------------------------------------------------

local function SyncTo(target)
	local payload = {}

	for _, kind in ipairs(MuR.SpawnKinds) do
		local list = {}

		for _, point in ipairs(MuR.Spawns[kind.id] or {}) do
			list[#list + 1] = {pos = point.pos, ang = point.ang, chance = point.chance}
		end

		payload[kind.id] = list
	end

	net.Start("MuR.SpawnEditor.Sync")
	net.WriteTable(payload)

	if target then net.Send(target) else net.Broadcast() end
end

MuR.SyncSpawnsTo = SyncTo

-- Кто сейчас держит редактор открытым. Правки принимаем только от них, а не от
-- всякого, кто сумел послать сообщение.
MuR.SpawnEditors = MuR.SpawnEditors or {}

local function CanEdit(ply)
	return IsValid(ply) and ply:IsSuperAdmin() and MuR.SpawnEditors[ply] == true
end

net.Receive("MuR.SpawnEditor.Toggle", function(_, ply)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end

	local on = net.ReadBool()
	MuR.SpawnEditors[ply] = on or nil

	if on then
		SyncTo(ply)
		if MuR.SyncEditorObjectsTo then MuR:SyncEditorObjectsTo(ply) end
	end
end)

net.Receive("MuR.SpawnEditor.Edit", function(_, ply)
	if not CanEdit(ply) then return end

	local action = net.ReadString()
	local kindID = net.ReadString()
	if not MuR.IsSpawnKind(kindID) then return end

	local list = MuR.Spawns[kindID]
	if not list then return end

	if action == "add" then
		local pos = net.ReadVector()
		local ang = net.ReadFloat()
		local chance = net.ReadUInt(7)

		list[#list + 1] = {
			pos = pos,
			ang = math.NormalizeAngle(ang),
			chance = math.Clamp(chance, 0, 100),
		}
	elseif action == "remove" then
		local pos = net.ReadVector()

		-- Удаляем ближайшую в радиусе, а не по индексу: у клиента свой порядок
		-- списка, и после чужой правки индекс означал бы другую точку.
		local bestIdx, bestDist = nil, MuR.SpawnPickRadius * MuR.SpawnPickRadius

		for i, point in ipairs(list) do
			local d = point.pos:DistToSqr(pos)
			if d <= bestDist then bestIdx, bestDist = i, d end
		end

		if not bestIdx then return end
		table.remove(list, bestIdx)
	elseif action == "clear" then
		MuR.Spawns[kindID] = {}
	else
		return
	end

	SyncTo()
end)

net.Receive("MuR.SpawnEditor.Save", function(_, ply)
	if not CanEdit(ply) then return end

	local spawnsSaved = MuR:SaveSpawns()
	local objectsSaved = not MuR.SaveEditorObjects or MuR:SaveEditorObjects()

	if spawnsSaved and objectsSaved then
		local message = MuR.Language and MuR.Language.editor_saved or "Map editor saved for "
		ply:ChatPrint("[bloodshed] " .. message .. game.GetMap())
	else
		local message = MuR.Language and MuR.Language.editor_save_failed or "Could not save the map editor."
		ply:ChatPrint("[bloodshed] " .. message)
	end
end)

hook.Add("PlayerDisconnected", "MuR.SpawnEditorLeave", function(ply)
	MuR.SpawnEditors[ply] = nil
end)

--
-- Сама команда mur_spawneditor живёт на КЛИЕНТЕ (cl_spawneditor.lua): панель и
-- рисование там же. Сервер узнаёт о включении из Toggle и там же проверяет
-- права — открыть панель может кто угодно, но без прав она не получит ни
-- списка точек, ни возможности что-либо изменить.
