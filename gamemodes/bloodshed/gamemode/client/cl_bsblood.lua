-- Мост к необязательному нативному модулю жидкой крови gmcl_bsblood.
-- Модуль ставит сам игрок в garrysmod/lua/bin; без него этот файл ничего не делает,
-- а кровь идёт по старым эффектам. Сервер о модуле не знает и ничего не шлёт сверх обычного.

MuR.BSBlood = MuR.BSBlood or {}
local B = MuR.BSBlood
B.tiles = B.tiles or {}

local API_VERSION = 4
local REQUIRED = { "LoadMapData", "Ready", "Error", "SetQuality", "SetGravity", "Emit", "SetColliders", "Step",
	"Take", "Particles", "BodyDrops", "Decals", "Removed", "Films", "Clear", "Stats" }

local KIND = { impact = 1, spray = 2, pool = 3, organ = 4, gib = 5, stream = 6 }

local cvEnable = CreateClientConVar("cl_mur_bsblood", "1", true, false,
	"Жидкая кровь из модуля gmcl_bsblood, если он установлен", 0, 1)
local cvBodyStains = CreateClientConVar("cl_mur_bsblood_bodystains", "1", true, false,
	"Пятна крови на одежде и коже по пути стекающих капель", 0, 1)
local cvDebug = CreateClientConVar("cl_mur_bsblood_debug", "0", false, false, "Счётчики модуля крови", 0, 1)

local function Log(msg) MsgC(Color(200, 40, 40), "[Bloodshed blood] ", color_white, msg, "\n") end

local function ModuleInstalled(name)
	if util.IsBinaryModuleInstalled then return util.IsBinaryModuleInstalled(name) end
	return file.Exists("lua/bin/gmcl_" .. name .. "_win" .. (jit.arch == "x64" and "64" or "32") .. ".dll", "GAME")
end

local function LoadModule()
	if B.tried then return B.mod ~= nil end
	B.tried = true
	if not ModuleInstalled("bsblood") then return false end

	local ok, err = pcall(require, "bsblood")
	if not ok or not istable(bsblood) or not isfunction(bsblood.Version) then
		Log("модуль не загрузился: " .. tostring(err))
		return false
	end
	local ver, api = bsblood.Version()
	if api ~= API_VERSION then
		Log("версия модуля " .. tostring(ver) .. " не подходит (API " .. tostring(api) .. ", нужен " .. API_VERSION .. ")")
		return false
	end
	for _, name in ipairs(REQUIRED) do
		if not isfunction(bsblood[name]) then
			Log("в модуле нет функции " .. name .. ", обновите gmcl_bsblood")
			return false
		end
	end
	B.mod = bsblood
	Log("нативная кровь " .. ver)
	return true
end

-- Модуль работает, только когда карта прочитана: до этого всё уходит в старые эффекты.
function B:Active()
	return self.mod ~= nil and not self.failed and cvEnable:GetBool() and self.mapReady == true
end

local function Fail(err)
	B.failed = true
	Log("ошибка, возвращаюсь к обычной крови: " .. tostring(err))
end

local function QualityLevel()
	local cv = GetConVar("cl_mur_gore_quality")
	return cv and cv:GetInt() or 1
end

local function LoadMap()
	if not B.mod then return end
	B.mapReady = false
	B.mapPending = true
	B.tiles = {}
	B.mod.SetQuality(QualityLevel())
	local g = GetConVar("sv_gravity")
	B.mod.SetGravity(-(g and g:GetFloat() or 600))
	-- Карты из Workshop лежат внутри .gma, поэтому читаем через файловую систему игры.
	local data = file.Read("maps/" .. game.GetMap() .. ".bsp", "GAME")
	if not data or #data == 0 then
		B.mapPending = false
		Log("не удалось прочитать карту, модуль выключен до смены карты")
		return
	end
	B.mod.LoadMapData(data)
end

-- Один и тот же удар у всех игроков даёт одинаковый seed: кровь похожа по форме.
local function SeedOf(kind, pos)
	local x, y, z = math.floor(pos.x / 4), math.floor(pos.y / 4), math.floor(pos.z / 4)
	return bit.band(bit.bxor(x * 73856093, y * 19349663, z * 83492791, kind * 2654435), 0x7fffffff)
end

local function IsRedBlood(ent)
	if not IsValid(ent) or not ent.GetBloodColor then return true end
	local c = ent:GetBloodColor()
	return c == BLOOD_COLOR_RED or c == DONT_BLEED or c == -1
end

local function Emit(kind, pos, dir, mag, radius)
	if not isvector(pos) then return false end
	dir = isvector(dir) and dir or vector_up
	B.mod.Emit(kind, pos.x, pos.y, pos.z, dir.x, dir.y, dir.z, mag or 1, radius or 0, SeedOf(kind, pos))
	return true
end

-- Объём и длительность истечения по флагам MuR.BLOOD_POOL.
local POOL = {
	[0] = { 3.0, 12 },   -- LARGE
	[1] = { 0.5, 4 },    -- DROPS
	[2] = { 5.0, 20 },   -- HUGE
	[3] = { 2.0, 8 },    -- MEDIUM
	[10] = { 5.0, 6 },   -- GUSH
	[11] = { 0.8, 5 },   -- SMALL
}

local handlers = {}

function handlers.splatter(ent, pos, normal, magnitude)
	if not IsRedBlood(ent) then return false end
	return Emit(KIND.impact, pos, normal, math.max(magnitude or 1, 0.3))
end

function handlers.spray(ent, pos, normal, magnitude)
	if not IsRedBlood(ent) then return false end
	return Emit(KIND.spray, pos, normal, math.Clamp(magnitude or 1, 0.5, 3))
end

function handlers.organ(ent, pos, magnitude)
	if not IsRedBlood(ent) then return false end
	return Emit(KIND.organ, pos, vector_up * -1, math.Clamp(magnitude or 1, 0.3, 3))
end

function handlers.pool(ent, origin, flags)
	if not IsRedBlood(ent) then return false end
	local p = POOL[flags or 0] or POOL[0]
	return Emit(KIND.pool, origin, vector_up * -1, p[1], p[2])
end

function handlers.gib(ent, posMin, posMax, bloodColor)
	if bloodColor and bloodColor ~= BLOOD_COLOR_RED then return false end
	local center = (posMin + posMax) * 0.5
	local size = math.Clamp(posMin:Distance(posMax) / 24, 0.4, 3)
	return Emit(KIND.gib, center, vector_up, size)
end

-- Точка входа для врезок: true — событие забрал модуль, старый эффект не нужен.
function B:Handle(kind, ...)
	if not self:Active() then return false end
	local fn = handlers[kind]
	if not fn then return false end
	local ok, res = pcall(fn, ...)
	if not ok then Fail(res) return false end
	return res == true
end

-- Врезка в EFFECT:Init: переводит EffectData эффекта в событие модуля.
local effectMap = {
	mur_blood_splatter_effect = function(data)
		if data:GetFlags() == 2 then return false end
		return B:Handle("splatter", data:GetEntity(), data:GetOrigin(), data:GetNormal(), data:GetMagnitude())
	end,
	bloodshed_blood_pool = function(data)
		return B:Handle("pool", data:GetEntity(), data:GetOrigin(), data:GetFlags())
	end,
	mur_organ_bleed = function(data)
		return B:Handle("organ", data:GetEntity(), data:GetOrigin(), data:GetMagnitude())
	end,
	zippygore3_ongib = function(data)
		return B:Handle("gib", data:GetEntity(), data:GetOrigin(), data:GetStart(), data:GetFlags())
	end,
}

function B:Effect(name, data)
	if not self:Active() then return false end
	local fn = effectMap[name]
	return fn ~= nil and fn(data) == true
end

------------------------------------------------------------------------------------------
-- Коллайдеры: кости рэгдоллов (капсулы) и ступни игроков.

local BONE_SHAPE = {
	["ValveBiped.Bip01_Pelvis"] = { 6, "ValveBiped.Bip01_Spine2" },
	["ValveBiped.Bip01_Spine2"] = { 7, "ValveBiped.Bip01_Neck1" },
	["ValveBiped.Bip01_Head1"] = { 4.5, nil, 7 },
	["ValveBiped.Bip01_L_UpperArm"] = { 2.8, "ValveBiped.Bip01_L_Forearm" },
	["ValveBiped.Bip01_R_UpperArm"] = { 2.8, "ValveBiped.Bip01_R_Forearm" },
	["ValveBiped.Bip01_L_Forearm"] = { 2.3, "ValveBiped.Bip01_L_Hand" },
	["ValveBiped.Bip01_R_Forearm"] = { 2.3, "ValveBiped.Bip01_R_Hand" },
	["ValveBiped.Bip01_L_Hand"] = { 1.8, nil, 4 },
	["ValveBiped.Bip01_R_Hand"] = { 1.8, nil, 4 },
	["ValveBiped.Bip01_L_Thigh"] = { 4, "ValveBiped.Bip01_L_Calf" },
	["ValveBiped.Bip01_R_Thigh"] = { 4, "ValveBiped.Bip01_R_Calf" },
	["ValveBiped.Bip01_L_Calf"] = { 3, "ValveBiped.Bip01_L_Foot" },
	["ValveBiped.Bip01_R_Calf"] = { 3, "ValveBiped.Bip01_R_Foot" },
	["ValveBiped.Bip01_L_Foot"] = { 2.2, nil, 6 },
	["ValveBiped.Bip01_R_Foot"] = { 2.2, nil, 6 },
}
local FEET = { "ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_R_Foot" }
local FLAG_SMEARS, FLAG_HOLDS = 1, 2
local COLLIDER_RANGE = 1500 * 1500
local MAX_COLLIDERS = 256

-- Кешируем индексы костей на модель: имена искать каждый кадр дорого.
local shapeCache = {}
local function ShapesFor(ent)
	local mdl = ent:GetModel()
	if not mdl then return nil end
	local cached = shapeCache[mdl]
	if cached ~= nil then return cached or nil end
	local list = {}
	for name, s in pairs(BONE_SHAPE) do
		local b = ent:LookupBone(name)
		if b then
			list[#list + 1] = { bone = b, radius = s[1], child = s[2] and ent:LookupBone(s[2]), len = s[3] or 0 }
		end
	end
	table.sort(list, function(a, b) return a.bone < b.bone end)
	shapeCache[mdl] = #list > 0 and list or false
	return #list > 0 and list or nil
end

local colliderBuf, lastPos = {}, {}
local function Finite(v) return v.x == v.x and v.y == v.y and v.z == v.z and math.abs(v.x) < 1e6 end

local function PushCollider(n, id, flags, a, b, r, dt)
	local key = id
	local prev = lastPos[key]
	local vel = prev and dt > 0 and (a - prev) / dt or vector_origin
	lastPos[key] = a
	local i = n * 13
	local t = colliderBuf
	t[i + 1], t[i + 2], t[i + 3] = id, 0, flags
	t[i + 4], t[i + 5], t[i + 6] = a.x, a.y, a.z
	t[i + 7], t[i + 8], t[i + 9] = b.x, b.y, b.z
	t[i + 10], t[i + 11], t[i + 12] = vel.x, vel.y, vel.z
	t[i + 13] = r
	return n + 1
end

local function GatherColliders(eye, dt)
	local n = 0
	for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
		if n >= MAX_COLLIDERS then break end
		if ent:IsDormant() or ent:GetPos():DistToSqr(eye) > COLLIDER_RANGE then continue end
		local shapes = ShapesFor(ent)
		if not shapes then continue end
		ent:SetupBones()
		local base = ent:EntIndex() * 128
		for _, s in ipairs(shapes) do
			-- Отстреленная кость сжата в ноль: на ней крови быть не может.
			local sc = ent:GetManipulateBoneScale(s.bone)
			if sc.x < 0.05 then continue end
			local m = ent:GetBoneMatrix(s.bone)
			if not m then continue end
			local a = m:GetTranslation()
			local b
			if s.child then
				local cm = ent:GetBoneMatrix(s.child)
				b = cm and cm:GetTranslation()
			end
			b = b or a + m:GetForward() * s.len
			if Finite(a) and Finite(b) then
				n = PushCollider(n, base + s.bone, FLAG_SMEARS + FLAG_HOLDS, a, b, s.radius, dt)
				if n >= MAX_COLLIDERS then break end
			end
		end
	end
	-- Ступни живых игроков: топчут лужи и разносят их, но кровь на себе не держат.
	for _, ply in ipairs(player.GetAll()) do
		if n >= MAX_COLLIDERS then break end
		if not ply:Alive() or ply:IsDormant() or ply:GetPos():DistToSqr(eye) > COLLIDER_RANGE then continue end
		for _, name in ipairs(FEET) do
			local b = ply:LookupBone(name)
			local m = b and ply:GetBoneMatrix(b)
			if m then
				local a = m:GetTranslation()
				if Finite(a) then
					n = PushCollider(n, -(ply:EntIndex() * 4 + (name == FEET[1] and 1 or 2)), FLAG_SMEARS, a, a + m:GetForward() * 6, 2.5, dt)
				end
			end
		end
	end
	return n
end

------------------------------------------------------------------------------------------
-- Отрисовка.

-- $nocull обязателен: порядок вершин у плёнки и капель против часовой, а Source
-- отбрасывает такие грани как задние — без него не видно было вообще ничего.
local matFilm = CreateMaterial("bsblood_film2", "UnlitGeneric", {
	["$nocull"] = 1,
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
})
-- Запасной вариант капель без шейдера: сплошные вытянутые квады с цветом из вершин.
local matDrop = CreateMaterial("bsblood_drop3", "UnlitGeneric", {
	["$nocull"] = 1,
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
})

-- Свои шейдеры (исходники в репозитории bsblood, папка shaders). Если файлов .vcs нет —
-- запасная простая заливка цветом вершин. Имена шейдеров с номером версии: GMod держит
-- загруженный шейдер в памяти и обновлённый файл с тем же именем не перечитывает.
local function HasShader(name)
	return file.Exists("shaders/fxc/" .. name .. "_ps30.vcs", "GAME")
		and file.Exists("shaders/fxc/" .. name .. "_vs30.vcs", "GAME")
end
local FILM_SHADER = HasShader("bsblood_film8")
local DROP_SHADER = HasShader("bsblood_drop2")
local FILM_THICKNESS = 0.5  -- модуль отдаёт a = sqrt(h / 0.5)
local matFilmShader = CreateMaterial("bsblood_film_ss9", "screenspace_general", {
	["$basetexture"] = "_rt_FullFrameFB",  -- шейдер пропускает картинку под лужей через слой крови
	["$pixshader"] = "bsblood_film8_ps30",
	["$vertexshader"] = "bsblood_film8_vs30",
	["$cull"] = 0,
	["$depthtest"] = 1,
	["$vertexcolor"] = 1,
	["$alpha_blend"] = 1,
	["$translucent"] = 1,
	["$c2_w"] = FILM_THICKNESS,
})
local matDropShader = CreateMaterial("bsblood_drop_ss2", "screenspace_general", {
	["$basetexture"] = "_rt_FullFrameFB",  -- капля поглощает и чуть преломляет то, что за ней
	["$pixshader"] = "bsblood_drop2_ps30",
	["$vertexshader"] = "bsblood_drop2_vs30",
	["$cull"] = 0,
	["$depthtest"] = 1,
	["$vertexcolor"] = 1,
	["$alpha_blend"] = 1,
	["$translucent"] = 1,
})

local FRESH = Vector(92, 3, 3)
local DRY = Vector(38, 6, 4)

local filmBuf, removedBuf, particleBuf, bodyBuf = {}, {}, {}, {}
local nParticles, nBody = 0, 0
local DrawFilmShaded, DrawDropsShaded

local function BuildTile(buf, i)
	local key = buf[i]
	local n = Vector(buf[i + 1], buf[i + 2], buf[i + 3])
	local nverts = buf[i + 4]
	i = i + 5
	local tile = B.tiles[key]
	if tile and IsValid(tile.mesh) then tile.mesh:Destroy() end
	if nverts <= 0 then
		B.tiles[key] = nil
		return i
	end
	local m = Mesh(FILM_SHADER and matFilmShader or matFilm)
	local cx, cy, cz = 0, 0, 0
	local pos = Vector()
	-- Модуль отдаёт квады: 4 вершины на клетку.
	mesh.Begin(m, MATERIAL_QUADS, nverts / 4)
	for _ = 1, nverts do
		local x, y, z, a, d = buf[i], buf[i + 1], buf[i + 2], buf[i + 3], buf[i + 4]
		cx, cy, cz = cx + x, cy + y, cz + z
		pos:SetUnpacked(x, y, z)
		mesh.Position(pos)
		if FILM_SHADER then
			-- Шейдеру нужны сырые величины: r — сухость, a — толщина; нормаль плитки — в
			-- текстурной координате и знаке g (для экранных отражений в вершинном шейдере).
			mesh.Color(d * 255, n.z >= 0 and 255 or 0, 0, a * 255)
			mesh.TexCoord(0, n.x, n.y)
		else
			local col = LerpVector(d, FRESH, DRY)
			-- Модуль отдаёт a = sqrt(h / 0.5). Глаз видит кровь уже в сотых долях миллиметра,
			-- поэтому непрозрачность насыщается по корню и почти полная уже на тонком слое.
			local vis = math.min(1, math.sqrt(a * a * FILM_THICKNESS / 0.002))
			vis = vis * vis * (3 - 2 * vis)
			mesh.Color(col.x, col.y, col.z, vis * (250 - 30 * d))
		end
		if not FILM_SHADER then mesh.TexCoord(0, 0, 0) end
		mesh.AdvanceVertex()
		i = i + 5
	end
	mesh.End()
	B.tiles[key] = { mesh = m, normal = n, center = Vector(cx, cy, cz) / nverts, light = nil, lightAt = 0 }
	return i
end

-- Тайлы плёнки пересобираются не все разом: при растекании лужи их меняются десятки,
-- и сборка меша в Lua дала бы рывок кадра. Берём новые данные, только когда старые разобраны,
-- и тратим на сборку не больше FILM_BUILD_MS за кадр.
local FILM_BUILD_MS = 1.5
local filmLeft, filmAt = 0, 1

local function PullFilms()
	local nr = B.mod.Removed(removedBuf)
	for i = 1, nr do
		local tile = B.tiles[removedBuf[i]]
		if tile and IsValid(tile.mesh) then tile.mesh:Destroy() end
		B.tiles[removedBuf[i]] = nil
	end
	filmLeft = B.mod.Films(filmBuf)
	filmAt = 1
end

local function BuildPendingFilms()
	local deadline = SysTime() + FILM_BUILD_MS / 1000
	while filmLeft > 0 and SysTime() < deadline do
		filmAt = BuildTile(filmBuf, filmAt)
		filmLeft = filmLeft - 1
	end
end

-- Пятна на теле. Капля на теле — физика модуля: стекает и впитывается. Сама модель при этом
-- не пачкается, а нарисовать пятно на скиннутой модели в GMod можно только декалью движка
-- (она ложится на одежду и кожу, а не висит перед моделью). Ставим её по пути капли.
local BODY_STAMP_STEP = 3
local BODY_STAMPS_PER_FRAME = 4
local BODY_STAMPS_PER_BONE = 24
local bodyStamps = setmetatable({}, { __mode = "k" })

local function StampBody()
	if not cvBodyStains:GetBool() then return end
	local budget = BODY_STAMPS_PER_FRAME
	for i = 1, nBody, 8 do
		if budget <= 0 then break end
		local id = bodyBuf[i]
		if id < 0 then continue end
		local ent = Entity(math.floor(id / 128))
		if not IsValid(ent) then continue end
		local bone = id % 128
		local m = ent:GetBoneMatrix(bone)
		if not m then continue end
		local head = Vector(bodyBuf[i + 1], bodyBuf[i + 2], bodyBuf[i + 3])
		local bpos, bang = m:GetTranslation(), m:GetAngles()
		-- Следы помним в координатах кости: тело двигается, а пятно на нём — нет.
		local lpos = WorldToLocal(head, angle_zero, bpos, bang)
		local perEnt = bodyStamps[ent]
		if not perEnt then perEnt = {} bodyStamps[ent] = perEnt end
		local list = perEnt[bone]
		if not list then list = {} perEnt[bone] = list end
		if #list >= BODY_STAMPS_PER_BONE then continue end
		local near = false
		for _, q in ipairs(list) do
			if q:DistToSqr(lpos) < BODY_STAMP_STEP * BODY_STAMP_STEP then near = true break end
		end
		if near then continue end
		list[#list + 1] = lpos
		budget = budget - 1
		-- Луч к поверхности модели: от точки капли внутрь, к оси кости.
		local out = head - bpos
		local axis = m:GetForward()
		out = out - axis * out:Dot(axis)
		if out:LengthSqr() < 0.01 then out = Vector(0, 0, 1) end
		out:Normalize()
		util.Decal("Blood", head + out * 4, head - out * 6, nil)
	end
end

local nextFilmPull, lastStep = 0, SysTime()

hook.Add("Think", "MuR.BSBlood.Step", function()
	if not B:Active() then
		if B.mod and B.mapPending and B.mod.Ready() then
			B.mapPending = false
			B.mapReady = true
			Log("карта загружена")
		elseif B.mod and B.mapPending and B.mod.Error() ~= "" then
			B.mapPending = false
			Log("карта не поддерживается: " .. B.mod.Error())
		end
		return
	end
	local ok, err = pcall(function()
		local now = SysTime()
		local dt = math.min(now - lastStep, 0.1)
		lastStep = now
		local eye = EyePos()
		local n = GatherColliders(eye, dt)
		B.mod.SetColliders(colliderBuf, n)
		B.mod.Step(dt, eye.x, eye.y, eye.z)
		if B.mod.Take() then
			nParticles = B.mod.Particles(particleBuf)
			nBody = B.mod.BodyDrops(bodyBuf)
			StampBody()
		end
		if filmLeft > 0 then
			BuildPendingFilms()
		elseif now >= nextFilmPull then
			nextFilmPull = now + 0.1
			PullFilms()
			BuildPendingFilms()
		end
	end)
	if not ok then Fail(err) end
end)

-- Свет для шейдера плёнки: рассеянный в точке плитки и солнце, если плитка под открытым небом.
local function TileLighting(tile, now)
	if tile.light and now < tile.lightAt then return end
	tile.lightAt = now + 0.5
	tile.light = render.ComputeLighting(tile.center + tile.normal * 2, tile.normal)
	local sun = util.GetSunInfo()
	tile.sunDir, tile.sun = vector_up, 0
	if sun and sun.direction then
		local tr = util.TraceLine({ start = tile.center + tile.normal * 2, endpos = tile.center + sun.direction * 16384, mask = MASK_SOLID_BRUSHONLY })
		if tr.HitSky then tile.sunDir, tile.sun = sun.direction, 1.2 * (1 - (sun.obstruction or 0)) end
	end
	-- Отражение: небо снаружи, рассеянный свет внутри.
	tile.env = tile.sun > 0 and Vector(0.32, 0.35, 0.42) or tile.light * 0.9
end

DrawFilmShaded = function(now)
	local mat = matFilmShader
	if not next(B.tiles) then return end
	render.UpdateScreenEffectTexture()
	mat:SetFloat("$c0_w", 1 / ScrW())
	mat:SetFloat("$c3_w", 1 / ScrH())
	render.SetMaterial(mat)
	render.OverrideDepthEnable(true, false)
	for _, tile in pairs(B.tiles) do
		TileLighting(tile, now)
		local l, sd, env, n = tile.light, tile.sunDir, tile.env, tile.normal
		mat:SetFloat("$c0_x", l.x) mat:SetFloat("$c0_y", l.y) mat:SetFloat("$c0_z", l.z)
		mat:SetFloat("$c1_x", sd.x) mat:SetFloat("$c1_y", sd.y) mat:SetFloat("$c1_z", sd.z) mat:SetFloat("$c1_w", tile.sun)
		mat:SetFloat("$c2_x", n.x) mat:SetFloat("$c2_y", n.y) mat:SetFloat("$c2_z", n.z)
		mat:SetFloat("$c3_x", env.x) mat:SetFloat("$c3_y", env.y) mat:SetFloat("$c3_z", env.z)
		tile.mesh:Draw()
	end
	render.OverrideDepthEnable(false)
end

local function DrawStreak(a, b, width, eye, r, g, bl, alpha)
	local dir = b - a
	local side = dir:Cross(eye - a)
	side:Normalize()
	side:Mul(width)
	mesh.Position(a - side) mesh.TexCoord(0, 0, 0) mesh.Color(r, g, bl, alpha) mesh.AdvanceVertex()
	mesh.Position(a + side) mesh.TexCoord(0, 1, 0) mesh.Color(r, g, bl, alpha) mesh.AdvanceVertex()
	mesh.Position(b + side) mesh.TexCoord(0, 1, 1) mesh.Color(r, g, bl, alpha) mesh.AdvanceVertex()
	mesh.Position(b - side) mesh.TexCoord(0, 0, 1) mesh.Color(r, g, bl, alpha) mesh.AdvanceVertex()
end

-- Капсула для шейдера капли: отрезок a-b радиуса radius, всегда повёрнута к камере.
-- В текстурных координатах — поперёк [-1, 1] и вдоль [-1-k, 1+k], где k — полудлина в радиусах:
-- концы получаются круглыми, а не квадратными.
local MAX_STRETCH = 8
local function DrawCapsule(a, b, radius, eye, alpha)
	local axis = b - a
	local len = axis:Length()
	if len < 1e-3 then
		axis = Vector(0, 0, 1)
		len = 0
	else
		axis:Div(len)
	end
	local k = math.min(len * 0.5 / radius, MAX_STRETCH)
	local mid = (a + b) * 0.5
	local half = axis * (radius * (1 + k))
	local side = axis:Cross(eye - mid)
	if side:LengthSqr() < 1e-6 then side = axis:Cross(Vector(1, 0, 0)) end
	side:Normalize()
	side:Mul(radius)
	local cr, cb, ca = k / MAX_STRETCH * 255, math.min(radius * 0.5, 1) * 255, alpha * 255
	local y = 1 + k
	mesh.Position(mid - half - side) mesh.TexCoord(0, -1, -y) mesh.Color(cr, 0, cb, ca) mesh.AdvanceVertex()
	mesh.Position(mid - half + side) mesh.TexCoord(0, 1, -y) mesh.Color(cr, 0, cb, ca) mesh.AdvanceVertex()
	mesh.Position(mid + half + side) mesh.TexCoord(0, 1, y) mesh.Color(cr, 0, cb, ca) mesh.AdvanceVertex()
	mesh.Position(mid + half - side) mesh.TexCoord(0, -1, y) mesh.Color(cr, 0, cb, ca) mesh.AdvanceVertex()
end

local BODY_TRAIL_MAX = 4  -- подтёк на теле длиннее нескольких юнитов выглядел палкой

DrawDropsShaded = function(quads)
	local mat = matDropShader
	local eye = EyePos()
	local lit = render.ComputeLighting(eye, vector_up)
	-- Капли поглощают то, что за ними, в том числе только что нарисованную плёнку.
	render.UpdateScreenEffectTexture()
	mat:SetFloat("$c0_x", lit.x) mat:SetFloat("$c0_y", lit.y) mat:SetFloat("$c0_z", lit.z)
	mat:SetFloat("$c0_w", 1 / ScrW())
	mat:SetFloat("$c3_w", 1 / ScrH())
	render.SetMaterial(mat)
	render.OverrideDepthEnable(true, false)
	-- Ошибка внутри mesh.Begin роняет игру, поэтому всё тело — под pcall, а mesh.End — всегда.
	mesh.Begin(MATERIAL_QUADS, quads)
	local ok, err = pcall(function()
		for i = 1, nParticles, 7 do
			local p = Vector(particleBuf[i], particleBuf[i + 1], particleBuf[i + 2])
			local v = Vector(particleBuf[i + 3], particleBuf[i + 4], particleBuf[i + 5])
			-- Капля чуть размазана по пути за кадр: так видно движение, но это капля, а не штрих.
			DrawCapsule(p - v * 0.012, p, math.max(particleBuf[i + 6] * 1.2, 0.35), eye, 1)
		end
		for i = 1, nBody, 8 do
			local head = Vector(bodyBuf[i + 1], bodyBuf[i + 2], bodyBuf[i + 3])
			local tail = Vector(bodyBuf[i + 4], bodyBuf[i + 5], bodyBuf[i + 6])
			local d = tail - head
			local l = d:Length()
			if l > BODY_TRAIL_MAX then tail = head + d * (BODY_TRAIL_MAX / l) end
			DrawCapsule(tail, head, bodyBuf[i + 7] * 0.6, eye, 0.95)
		end
	end)
	mesh.End()
	render.OverrideDepthEnable(false)
	if not ok then Fail(err) end
end

hook.Add("PostDrawTranslucentRenderables", "MuR.BSBlood.Draw", function(_, skybox, skybox3d)
	if skybox or skybox3d or not B:Active() then return end
	local now = CurTime()

	if FILM_SHADER then
		DrawFilmShaded(now)
	else
		render.SetMaterial(matFilm)
		for _, tile in pairs(B.tiles) do
			-- Освещение пересчитываем редко: плёнка неподвижна, свет тоже почти.
			if not tile.light or now > tile.lightAt then
				tile.light = render.ComputeLighting(tile.center + tile.normal * 2, tile.normal)
				tile.lightAt = now + 0.5
			end
			local l = tile.light
			render.SetColorModulation(math.min(l.x * 2, 1), math.min(l.y * 2, 1), math.min(l.z * 2, 1))
			tile.mesh:Draw()
		end
		render.SetColorModulation(1, 1, 1)
	end

	local quads = math.floor(nParticles / 7) + math.floor(nBody / 8)
	if quads <= 0 then return end
	if DROP_SHADER then
		DrawDropsShaded(quads)
		return
	end
	local eye = EyePos()
	local lit = render.ComputeLighting(eye, vector_up)
	local k = math.Clamp((lit.x + lit.y + lit.z) * 0.9, 0.15, 1)
	render.SetMaterial(matDrop)
	mesh.Begin(MATERIAL_QUADS, quads)
	for i = 1, nParticles, 7 do
		local p = Vector(particleBuf[i], particleBuf[i + 1], particleBuf[i + 2])
		local v = Vector(particleBuf[i + 3], particleBuf[i + 4], particleBuf[i + 5])
		local w = math.max(particleBuf[i + 6] * 1.2, 0.45)
		DrawStreak(p - v * 0.035 - v:GetNormalized() * w, p + v:GetNormalized() * w, w, eye, 105 * k, 4 * k, 4 * k, 245)
	end
	for i = 1, nBody, 8 do
		local head = Vector(bodyBuf[i + 1], bodyBuf[i + 2], bodyBuf[i + 3])
		local tail = Vector(bodyBuf[i + 4], bodyBuf[i + 5], bodyBuf[i + 6])
		if head:DistToSqr(tail) < 0.01 then tail = head + Vector(0, 0, 0.6) end
		DrawStreak(tail, head, bodyBuf[i + 7], eye, 85 * k, 3 * k, 3 * k, 235)
	end
	mesh.End()
end)

hook.Add("HUDPaint", "MuR.BSBlood.Debug", function()
	if not cvDebug:GetBool() or not B.mod then return end
	local s = B.mod.Stats()
	draw.SimpleText(string.format("bsblood %s | sim %.2f ms | particles %d | tiles %d | crawlers %d | streams %d",
		B:Active() and "on" or "off", s.simMs, s.particles, s.tiles, s.crawlers, s.streams),
		"DermaDefault", 10, 10, color_white)
end)

------------------------------------------------------------------------------------------
-- Жизненный цикл.

local function Start()
	if not LoadModule() then return end
	local ok, err = pcall(LoadMap)
	if not ok then Fail(err) end
end

hook.Add("InitPostEntity", "MuR.BSBlood.Init", Start)

hook.Add("PostCleanupMap", "MuR.BSBlood.Cleanup", function()
	if B.mod then B.mod.Clear() end
end)

cvars.AddChangeCallback("cl_mur_gore_quality", function(_, _, new)
	if B.mod then B.mod.SetQuality(tonumber(new) or 1) end
end, "MuR.BSBlood")

-- Перезагрузка файла посреди игры (autorefresh): модуль уже загружен, карту читаем заново.
if IsValid(LocalPlayer()) then
	B.tried = B.mod ~= nil and B.tried
	Start()
end
