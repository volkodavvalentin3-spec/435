MuR = MuR or {}
MuR.Traps = MuR.Traps or {}

local T = MuR.Traps

T.Sensors, T.SensorList = {}, {}
T.Vectors, T.VectorList = {}, {}
T.Payloads, T.PayloadList = {}, {}
T.Mods, T.ModList = {}, {}

-- Таблицы выше пересоздаются при каждом включении файла, поэтому флаг
-- построения химии обязан сбрасываться вместе с ними: иначе автообновление
-- лua на лету оставит список начинок без всех тридцати трёх веществ.
T.ChemBuilt = false

-- Два режима: облегчённый для обычного убийцы, полный для предателя.
T.Profiles = {
	basic = {budget = 5, maxActive = 1, chem = false, mods = false},
	advanced = {budget = 8, maxActive = 3, chem = true, mods = true},
}

local TIER_ORDER = {basic = 1, advanced = 2}

function T:TierAllows(playerTier, moduleTier)
	return (TIER_ORDER[playerTier] or 1) >= (TIER_ORDER[moduleTier] or 1)
end

function T:GetTier(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return "basic" end

	local class = ply:GetNW2String("Class", "")
	local role = MuR.Roles and MuR.Roles[class]
	if role and role.trapTier then return role.trapTier end

	return class == "Traitor" and "advanced" or "basic"
end

function T:GetProfile(ply)
	return self.Profiles[self:GetTier(ply)] or self.Profiles.basic
end

local function register(store, list, id, data)
	data.id = id
	data.tier = data.tier or "basic"
	data.cost = data.cost or 1
	store[id] = data
	list[#list + 1] = id
end

function T:RegisterSensor(id, data) register(self.Sensors, self.SensorList, id, data) end
function T:RegisterVector(id, data) register(self.Vectors, self.VectorList, id, data) end
function T:RegisterPayload(id, data) register(self.Payloads, self.PayloadList, id, data) end
function T:RegisterMod(id, data) register(self.Mods, self.ModList, id, data) end

--[[ ------------------------------------------------------------------
	Общие помощники
------------------------------------------------------------------ ]]--

function T:IsValidVictim(trap, ent)
	if not IsValid(trap) or not IsValid(ent) then return false end
	if not ent:IsPlayer() or not ent:Alive() then return false end

	local owner = trap.TrapOwner
	if ent == owner then return false end
	if IsValid(owner) and owner:IsPlayer() and ent:IsKiller() and owner:IsKiller() then return false end

	return true
end

function T:HasLOS(trap, ent)
	local tr = util.TraceLine({
		start = trap:WorldSpaceCenter(),
		endpos = ent:WorldSpaceCenter(),
		filter = {trap, ent},
		mask = MASK_SOLID_BRUSHONLY
	})

	return not tr.Hit
end

--[[ ------------------------------------------------------------------
	Срабатывание от предметов

	Нить рвётся от брошенной банки, а плита продавливается ящиком. Это не
	только реализм: так у невиновных появляется способ обезвредить ловушку
	чужими руками, не подставляя свои ноги.
------------------------------------------------------------------ ]]--

T.ObjectMinMass = 3
T.ObjectMinSpeed = 45
T.PlateMinMass = 20

function T:IsTriggeringObject(trap, ent, minMass, needMotion)
	if not IsValid(ent) or ent == trap then return false end
	if ent:IsPlayer() or MuR.IsAI(ent) or ent:IsWeapon() then return false end
	if ent:GetClass() == "mur_trap" then return false end
	if ent:GetParent() == trap or ent:GetOwner() == trap then return false end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return false end
	if phys:GetMass() < (minMass or self.ObjectMinMass) then return false end

	if needMotion and phys:GetVelocity():LengthSqr() < self.ObjectMinSpeed * self.ObjectMinSpeed then
		return false
	end

	return true
end

-- Датчик опрашивается пять раз в секунду, а брошенный предмет за это время
-- пролетает десятки юнитов и проскакивает нить насквозь. Поэтому проверяем
-- не точку, а весь отрезок, пройденный предметом с прошлого опроса.
function T:SweptDistanceToLine(ent, from, to, tickTime)
	local pos = ent:WorldSpaceCenter()
	local phys = ent:GetPhysicsObject()

	local best = util.DistanceToLine(from, to, pos)
	if not IsValid(phys) then return best end

	local travel = phys:GetVelocity() * (tickTime or 0.2)
	if travel:LengthSqr() < 1 then return best end

	for i = 1, 4 do
		local sample = pos - travel * (i / 4)
		local dist = util.DistanceToLine(from, to, sample)

		if dist < best then best = dist end
	end

	return best
end

function T:FindVictim(trap, radius, needLOS)
	for _, ent in ipairs(ents.FindInSphere(trap:WorldSpaceCenter(), radius)) do
		if self:IsValidVictim(trap, ent) then
			if not needLOS or self:HasLOS(trap, ent) then
				return ent
			end
		end
	end
end

--[[ ------------------------------------------------------------------
	ДАТЧИКИ
------------------------------------------------------------------ ]]--

-- needsAnchor: второй конец проволоки игрок закрепляет сам, и до этого
-- устройство не взведено. Срабатывает не радиус, а пересечение самой нити.
T:RegisterSensor("tripwire", {
	cost = 1, tier = "basic", contact = true, needsAnchor = true,
	Poll = function(trap)
		local anchor = trap:GetAnchorPos()
		if anchor == vector_origin then return end

		local origin = trap:TripOrigin()

		local fallback

		-- Коробка поиска расширена на путь, который предмет успевает пролететь.
		local pad = 96

		for _, ent in ipairs(ents.FindInBox(
			Vector(math.min(origin.x, anchor.x) - pad, math.min(origin.y, anchor.y) - pad, math.min(origin.z, anchor.z) - 24),
			Vector(math.max(origin.x, anchor.x) + pad, math.max(origin.y, anchor.y) + pad, math.max(origin.z, anchor.z) + 72))) do

			if T:IsValidVictim(trap, ent) then
				if util.DistanceToLine(origin, anchor, ent:WorldSpaceCenter()) < 30 then return ent end

			-- Летящий предмет рвёт нить не хуже ноги, но человек важнее.
			elseif not fallback and T:IsTriggeringObject(trap, ent, nil, true) then
				if T:SweptDistanceToLine(ent, origin, anchor, 0.25) < 24 then fallback = ent end
			end
		end

		return fallback
	end
})

T:RegisterSensor("door", {
	cost = 1, tier = "basic", attach = true, contact = true,
	Setup = function(trap)
		local host = trap.TrapHost
		if IsValid(host) then
			trap.HostAngles = host:GetAngles()
			trap.HostPos = host:GetPos()
		end
	end,
	Poll = function(trap)
		local host = trap.TrapHost
		if not IsValid(host) or not trap.HostAngles then return end

		local moved = math.abs(math.AngleDifference(host:GetAngles().y, trap.HostAngles.y)) > 6
			or host:GetPos():DistToSqr(trap.HostPos) > 64

		if not moved then return end

		return T:FindVictim(trap, 160, false)
	end
})

T:RegisterSensor("bait", {
	cost = 2, tier = "basic", usable = true, contact = true,
	Poll = function(trap)
		local victim = trap.PendingVictim
		trap.PendingVictim = nil
		if T:IsValidVictim(trap, victim) then return victim end
	end
})

T:RegisterSensor("pressure", {
	cost = 2, tier = "advanced", contact = true,
	Poll = function(trap)
		local fallback

		for _, ent in ipairs(ents.FindInSphere(trap:WorldSpaceCenter(), 48)) do
			if T:IsValidVictim(trap, ent) then
				if ent:IsOnGround() and math.abs(ent:GetPos().z - trap:GetPos().z) < 32 then return ent end

			-- Плиту продавит и тяжёлый ящик, поставленный сверху.
			elseif not fallback and T:IsTriggeringObject(trap, ent, T.PlateMinMass, false) then
				if ent:GetPos().z > trap:GetPos().z - 8 then fallback = ent end
			end
		end

		return fallback
	end
})

T:RegisterSensor("motion", {
	cost = 2, tier = "advanced",
	Poll = function(trap)
		for _, ent in ipairs(ents.FindInSphere(trap:WorldSpaceCenter(), 320)) do
			if T:IsValidVictim(trap, ent) and ent:GetVelocity():LengthSqr() > 6400 then
				if T:HasLOS(trap, ent) then return ent end
			end
		end
	end
})

T:RegisterSensor("remote", {
	cost = 1, tier = "advanced", remote = true,
	Poll = function(trap)
		local victim = trap.PendingVictim
		trap.PendingVictim = nil
		return victim
	end
})

--[[ ------------------------------------------------------------------
	ВЕКТОРЫ ДОСТАВКИ
------------------------------------------------------------------ ]]--

T:RegisterVector("contact", {
	cost = 1, tier = "basic", route = "contact",
	accepts = {mech = true, pyro = true, chem = true}, needsContactSensor = true,
	Fire = function(trap, victim, payload)
		trap:ApplyPayload(payload, victim, 1)
	end
})

T:RegisterVector("cloud", {
	cost = 2, tier = "advanced", route = "inhaled",
	accepts = {chem = true},
	Fire = function(trap, victim, payload)
		if payload.chem then
			local cloud = ents.Create("mur_gas_cloud")
			if IsValid(cloud) then
				cloud:SetPos(trap:GetPos() + Vector(0, 0, 4))
				cloud.PlayerOwner = trap.TrapOwner
				cloud.Substance = payload.chem
				cloud.Radius = 280
				cloud.Lifetime = 12
				cloud.FuseTime = 0.1
				cloud.SmokeColor = "200 255 100"
				cloud.Visible = true
				cloud:Spawn()
			end

			return
		end

		for _, ent in ipairs(ents.FindInSphere(trap:WorldSpaceCenter(), 240)) do
			if T:IsValidVictim(trap, ent) then
				trap:ApplyPayload(payload, ent, 0.75)
			end
		end
	end
})

T:RegisterVector("inject", {
	cost = 2, tier = "advanced", route = "injection",
	accepts = {chem = true}, needsContactSensor = true,
	quiet = true,
	Fire = function(trap, victim, payload)
		if not T:IsValidVictim(trap, victim) then return end

		trap:ApplyPayload(payload, victim, 1.25)
		victim:EmitSound("murdered/items/syringe_inject.wav", 45)
	end
})

T:RegisterVector("blast", {
	cost = 3, tier = "advanced", route = "contact",
	accepts = {pyro = true, chem = true},
	Fire = function(trap, victim, payload)
		for _, ent in ipairs(ents.FindInSphere(trap:WorldSpaceCenter(), 200)) do
			if T:IsValidVictim(trap, ent) then
				trap:ApplyPayload(payload, ent, 0.6)
			end
		end

		local charge = ents.Create("murwep_ied")
		if not IsValid(charge) then return end

		charge:SetPos(trap:GetPos())
		charge.PlayerOwner = trap.TrapOwner
		charge:Spawn()
		charge:SetNotSolid(true)
		charge.ExplosionDamageMult = 0.7
		charge:Explode()
	end
})

--[[ ------------------------------------------------------------------
	НАЧИНКА (механическая; химия добавляется автоматически ниже)
------------------------------------------------------------------ ]]--

-- Оглушение повторяет логику полицейского тазера, чтобы ощущалось так же.
T:RegisterPayload("shock", {
	cost = 2, tier = "basic", form = "mech",
	Apply = function(trap, victim, potency)
		local attacker = trap:GetAttacker()
		local id = victim:EntIndex()
		local ticks = math.floor(math.Clamp(3 * potency, 1.5, 5) * 100)
		local tick = 0

		victim:EmitSound("murdered/other/taser.mp3", 70, 100)
		victim:StartRagdolling()

		timer.Create("MuR_TrapShock_" .. id, 0.01, ticks, function()
			tick = tick + 1

			if not IsValid(victim) or not victim:Alive() then
				timer.Remove("MuR_TrapShock_" .. id)
				return
			end

			local rag = victim:GetRD()
			local effectEnt = IsValid(rag) and rag or victim

			if IsValid(rag) and rag.StruggleBone then
				rag:StruggleBone()
				victim.IsRagStanding = false
			end

			if tick % 3 == 0 then
				local fx = EffectData()
				fx:SetOrigin(effectEnt:WorldSpaceCenter())
				fx:SetMagnitude(1)
				fx:SetEntity(effectEnt)
				util.Effect("TeslaHitboxes", fx)
			end

			if tick % 50 == 0 then
				victim:TakeDamage(5, attacker, trap)
			end
		end)
	end
})

T:RegisterPayload("snare", {
	cost = 2, tier = "basic", form = "mech",
	Apply = function(trap, victim, potency)
		victim:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 65)

		local rag = victim:GetRD()

		if IsValid(rag) then
			victim.DeathBlowBone = {"ValveBiped.Bip01_R_Foot", true}
			victim:BreakRagdollBone()
			return
		end

		local new = victim:StartRagdolling()

		if IsValid(new) then
			victim.DeathBlowBone = {"ValveBiped.Bip01_R_Foot", true}
		else
			victim:TakeDamage(35 * potency, trap:GetAttacker(), trap)
		end
	end
})

T:RegisterPayload("noise", {
	cost = 1, tier = "basic", form = "pyro", nonLethal = true, areaOnly = true,
	Apply = function(trap, victim, potency)
		-- Шум сам по себе не бьёт: он стягивает людей в нужную точку.
		trap:EmitSound("physics/glass/glass_largesheet_break" .. math.random(1, 3) .. ".wav", 100)
	end
})

-- Ослепление идёт через штатное сообщение светошумовой гранаты, поэтому
-- игрок видит ровно тот же эффект, что и от обычной флешки.
T:RegisterPayload("flash", {
	cost = 1, tier = "basic", form = "pyro", nonLethal = true,
	Apply = function(trap, victim, potency)
		if not IsValid(victim) then return end

		local intensity = math.Clamp(potency, 0.25, 1)
		local duration = 4 * intensity

		net.Start("FlashbangEffect")
		net.WriteBool(true)
		net.WriteFloat(intensity)
		net.WriteFloat(duration)
		net.Send(victim)

		victim:EmitSound("weapons/flashbang/flashbang_explode1.wav", 80)
		victim:SetDSP(31)

		timer.Simple(duration, function()
			if not IsValid(victim) then return end
			if (victim.MuR_ConcussionEnd or 0) > CurTime() then return end
			victim:SetDSP(0)
		end)
	end
})

--[[ ------------------------------------------------------------------
	МОДИФИКАТОРЫ (только предатель)
------------------------------------------------------------------ ]]--

T:RegisterMod("delay_short", {cost = 1, tier = "advanced", delay = 3, group = "delay"})
T:RegisterMod("delay_long", {cost = 1, tier = "advanced", delay = 8, group = "delay"})
T:RegisterMod("rearm", {cost = 2, tier = "advanced", uses = 3})
T:RegisterMod("silent", {cost = 1, tier = "advanced"})
T:RegisterMod("selfdestruct", {cost = 2, tier = "advanced"})

-- Сцепка: сработавшая ловушка поджигает следующую вашу в радиусе.
T:RegisterMod("link", {cost = 2, tier = "advanced", chain = true})

T:RegisterMod("filter_alone", {
	cost = 1, tier = "advanced",
	Allows = function(trap, victim)
		for _, ent in ipairs(ents.FindInSphere(victim:GetPos(), 420)) do
			if ent ~= victim and ent:IsPlayer() and ent:Alive() and ent ~= trap.TrapOwner then
				return false
			end
		end

		return true
	end
})

T:RegisterMod("filter_armed", {
	cost = 1, tier = "advanced",
	Allows = function(trap, victim)
		local wep = victim:GetActiveWeapon()
		if not IsValid(wep) then return false end

		local class = wep:GetClass()
		return class ~= "mur_hands" and class ~= "weapon_bs_hands"
	end
})

--[[ ------------------------------------------------------------------
	Химическая начинка строится из зарегистрированного оружия, поэтому
	каждое новое вещество автоматически становится начинкой ловушки.
------------------------------------------------------------------ ]]--

-- Пять предметов применяют вещество напрямую и поля SWEP.Substance не имеют,
-- поэтому их приходится сопоставлять вручную. Всё остальное определяется само.
T.ManualCarriers = {
	mur_cyanide = "cyanide",
	mur_poisoncanister = "tetrodotoxin",
	mur_bredogen = "pcp",
	mur_tranq = "midazolam",
	mur_loot_heroin = "heroin",
}

function T:BuildChemPayloads()
	if self.ChemBuilt then return end
	if not MuR.Substances or table.IsEmpty(MuR.Substances) then return end

	local list = weapons.GetList()
	if not list or #list == 0 then return end

	self.ChemBuilt = true

	for _, wep in ipairs(list) do
		local class = wep.ClassName
		local sub = wep.Substance or (class and self.ManualCarriers[class])

		if sub and class then
			local def = MuR.Substances[sub]
			local id = "chem_" .. sub

			if def and not self.Payloads[id] then
				-- Внутрь ловушки видно ровно тот предмет, который туда заложили.
				local visual
				local world = wep.WorldModel

				if world and world ~= "" then
					local slot = self.ChemPartSlot
					visual = {{model = world, pos = slot.pos, ang = slot.ang, scale = slot.scale}}
				end

				self:RegisterPayload(id, {
					parts = visual,
					form = "chem",
					cost = def.lethal and 3 or 2,
					tier = "advanced",
					chem = sub,
					weapon = class,
					route = def.route,
					lethal = def.lethal or false,
					wikiKey = string.gsub(class, "^mur_", ""),
					Apply = function(trap, victim, potency)
						if not MuR.Chem then return end
						MuR.Chem:Apply(victim, sub, potency, trap.TrapOwner)
					end
				})
			end
		end
	end
end

function T:GetPayload(id)
	self:BuildChemPayloads()
	return self.Payloads[id]
end

--[[ ------------------------------------------------------------------
	Чертёж: стоимость и валидация
------------------------------------------------------------------ ]]--

function T:BlueprintCost(bp)
	if not istable(bp) then return 0 end

	self:BuildChemPayloads()

	local sensor = self.Sensors[bp.sensor]
	local vector = self.Vectors[bp.vector]
	local payload = self.Payloads[bp.payload]

	local cost = (sensor and sensor.cost or 0)
		+ (vector and vector.cost or 0)
		+ (payload and payload.cost or 0)

	for _, modID in ipairs(bp.mods or {}) do
		local mod = self.Mods[modID]
		cost = cost + (mod and mod.cost or 0)
	end

	return cost
end

--[[ ------------------------------------------------------------------
	Совместимость

	Капкан газовым облаком не доставишь, а иглой не воткнёшь пиротехнику.
	У начинки есть форма, у вектора — список форм, которые он умеет нести.
	Отдельно: контактный вброс и инжектор бьют по тому, кто стоит вплотную,
	поэтому им нужен ближний датчик, а не радио и не датчик движения.
------------------------------------------------------------------ ]]--

-- Куда встанет устройство. Трейс возвращается всегда, даже когда ставить
-- нельзя: клиент по нему рисует красного призрака, сервер смотрит на причину.
T.PlaceRange = 96

function T:PlantTrace(ply, bp)
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * self.PlaceRange,
		filter = ply,
		mask = MASK_SOLID
	})

	if not bp then return tr, nil, "trap_err_nodevice" end
	if not tr.Hit then return tr, nil, "trap_err_surface" end

	local sensor = self.Sensors[bp.sensor]

	-- Датчику двери нужна именно дверь.
	if sensor and sensor.attach then
		local host = tr.Entity

		if not IsValid(host) or not string.find(host:GetClass(), "door") then
			return tr, nil, "trap_err_nodoor"
		end

		return tr, host
	end

	return tr, nil
end

-- Положение и поворот собранного устройства для этого трейса.
function T:PlantTransform(tr)
	return tr.HitPos + tr.HitNormal * 2, tr.HitNormal:Angle() + Angle(90, 0, 0)
end

-- Крепление второго конца растяжки. Живёт в общем файле, потому что сервер
-- по нему ставит якорь, а клиент теми же правилами рисует превью нити.
T.AnchorRange = 260

-- Возвращает точку и, если закрепить нельзя, ключ причины.
function T:AnchorTrace(ply, origin)
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * self.AnchorRange,
		filter = ply,
		mask = MASK_SOLID
	})

	if not tr.Hit then return tr.HitPos, "trap_err_anchor_surface" end

	local reach = origin:Distance(tr.HitPos)
	if reach > self.AnchorRange then return tr.HitPos, "trap_err_anchor_far" end
	if reach < 40 then return tr.HitPos, "trap_err_anchor_near" end

	-- Нить не должна проходить сквозь стену.
	local clear = util.TraceLine({
		start = origin,
		endpos = tr.HitPos,
		filter = ply,
		mask = MASK_SOLID_BRUSHONLY
	})

	if clear.Fraction < 0.92 then return tr.HitPos, "trap_err_anchor_blocked" end

	return tr.HitPos
end

function T:VectorTakesPayload(vector, payload)
	if not vector or not payload then return false end
	if not vector.accepts then return true end

	return vector.accepts[payload.form or "mech"] == true
end

function T:VectorTakesSensor(vector, sensor)
	if not vector or not sensor then return false end
	if not vector.needsContactSensor then return true end

	return sensor.contact == true
end

-- Возвращает: ok, ключ локализации ошибки, стоимость
function T:Validate(ply, bp)
	if not istable(bp) then return false, "trap_err_broken" end

	self:BuildChemPayloads()

	local tier = self:GetTier(ply)
	local profile = self:GetProfile(ply)

	local sensor = self.Sensors[bp.sensor]
	local vector = self.Vectors[bp.vector]
	local payload = self.Payloads[bp.payload]

	if not sensor or not vector or not payload then return false, "trap_err_broken" end

	if not self:TierAllows(tier, sensor.tier) then return false, "trap_err_locked" end
	if not self:TierAllows(tier, vector.tier) then return false, "trap_err_locked" end
	if not self:TierAllows(tier, payload.tier) then return false, "trap_err_locked" end
	if payload.chem and not profile.chem then return false, "trap_err_locked" end

	if not self:VectorTakesPayload(vector, payload) then return false, "trap_err_form" end
	if not self:VectorTakesSensor(vector, sensor) then return false, "trap_err_reach" end

	local seenGroups = {}

	for _, modID in ipairs(bp.mods or {}) do
		local mod = self.Mods[modID]

		if not mod then return false, "trap_err_broken" end
		if not profile.mods then return false, "trap_err_locked" end
		if not self:TierAllows(tier, mod.tier) then return false, "trap_err_locked" end

		if mod.group then
			if seenGroups[mod.group] then return false, "trap_err_conflict" end
			seenGroups[mod.group] = true
		end
	end

	local cost = self:BlueprintCost(bp)
	if cost > profile.budget then return false, "trap_err_budget" end

	return true, nil, cost
end

--[[ ------------------------------------------------------------------
	ВНЕШНИЙ ВИД

	Устройство не один проп, а сборка: картонка-шасси, моток скотча, деталь
	датчика, деталь доставки и сама начинка — соединённые проводами. По виду
	вблизи должно читаться, что именно вам подложили.

	Три посадочных места вдоль шасси: датчик спереди, доставка в центре,
	начинка сзади.
------------------------------------------------------------------ ]]--

T.ChassisModel = "models/props_junk/garbage_carboard002a.mdl"
T.ChassisScale = 0.65

T.ChassisParts = {
	{model = "models/murdered/props_tape/duct_tape.mdl", pos = Vector(6, -14, 2), ang = Angle(0, 25, 0), scale = 1},
}

-- Точка, из которой расходятся провода.
T.WireHub = Vector(0, 0, 3)

local function setParts(store, id, list)
	if store[id] then store[id].parts = list end
end

-- Классическая растяжка: граната примотана к опоре, проволока идёт от кольца.
setParts(T.Sensors, "tripwire", {
	{model = "models/weapons/w_grenade.mdl", pos = Vector(0, 11, 1), ang = Angle(0, 0, 0), scale = 1},
	{model = "models/props_c17/TrapPropeller_Lever.mdl", pos = Vector(4, 9, 1), ang = Angle(0, 90, 0), scale = 0.8},
})

-- Откуда тянуть проволоку: от кольца гранаты, а не от центра шасси.
T.Sensors["tripwire"].tripOrigin = Vector(0, 11, 8)
setParts(T.Sensors, "door", {
	{model = "models/weapons/w_slam.mdl", pos = Vector(0, 11, 4), ang = Angle(0, 0, 0), scale = 0.8},
})
setParts(T.Sensors, "bait", {
	{model = "models/props_c17/BriefCase001a.mdl", pos = Vector(0, 13, 6), ang = Angle(0, 90, 0), scale = 0.55},
})
setParts(T.Sensors, "pressure", {
	{model = "models/props_junk/CinderBlock01a.mdl", pos = Vector(0, 12, 6), ang = Angle(0, 0, 0), scale = 0.55},
})
setParts(T.Sensors, "motion", {
	{model = "models/props_wasteland/prison_lamp001c.mdl", pos = Vector(0, 12, 4), ang = Angle(0, 0, 0), scale = 0.45},
})
setParts(T.Sensors, "remote", {
	{model = "models/murdered/weapons/w_dp4800.mdl", pos = Vector(0, 11, 2), ang = Angle(0, 0, 0), scale = 1},
})

setParts(T.Vectors, "contact", {
	{model = "models/props_c17/tools_wrench01a.mdl", pos = Vector(0, 1, 1), ang = Angle(0, 0, 0), scale = 0.9},
})
setParts(T.Vectors, "cloud", {
	{model = "models/props_junk/PropaneCanister001a.mdl", pos = Vector(0, 1, 6), ang = Angle(0, 0, 0), scale = 0.55},
})
setParts(T.Vectors, "inject", {
	{model = "models/murdered/heroin/syringe_out/syringe_out.mdl", pos = Vector(0, 1, 2), ang = Angle(0, 0, 0), scale = 1.2},
})
setParts(T.Vectors, "blast", {
	{model = "models/murdered/weapons/insurgency/w_ied.mdl", pos = Vector(0, 1, 5), ang = Angle(0, 0, 0), scale = 0.9},
})

setParts(T.Payloads, "shock", {
	{model = "models/murdered/weapons/w_taser.mdl", pos = Vector(0, -8, 4), ang = Angle(0, 0, 0), scale = 0.8},
})
setParts(T.Payloads, "snare", {
	{model = "models/murdered/traps/trap.mdl", pos = Vector(0, -9, 1), ang = Angle(0, 0, 0), scale = 1},
})
setParts(T.Payloads, "noise", {
	{model = "models/Items/BoxSRounds.mdl", pos = Vector(0, -8, 3), ang = Angle(0, 90, 0), scale = 0.8},
})
setParts(T.Payloads, "flash", {
	{model = "models/simpnades/w_m84.mdl", pos = Vector(0, -8, 3), ang = Angle(0, 0, 0), scale = 1},
})

-- Куда садится химическая начинка: модель берётся у самого предмета.
T.ChemPartSlot = {pos = Vector(0, -8, 3), ang = Angle(0, 0, 0), scale = 0.9}

-- Все детали устройства одним списком, в порядке шасси -> датчик -> доставка -> начинка.
function T:CollectParts(sensorID, vectorID, payloadID)
	local out = {}

	for _, part in ipairs(self.ChassisParts) do out[#out + 1] = part end

	for _, def in ipairs({self.Sensors[sensorID], self.Vectors[vectorID], self:GetPayload(payloadID)}) do
		if def and def.parts then
			for _, part in ipairs(def.parts) do out[#out + 1] = part end
		end
	end

	return out
end

-- Сколько секунд собирается устройство: чем сложнее схема, тем дольше вы
-- стоите с планшетом в руках и тем заметнее.
function T:AssembleTime(bp)
	return math.Clamp(3 + self:BlueprintCost(bp) * 1.1, 4, 14)
end

-- Радиус, в котором сработавшая ловушка ищет следующую в цепи.
T.ChainRadius = 700

-- Совпадение маршрута введения даёт полную дозу, несовпадение — половину.
function T:RouteEfficiency(vector, payload)
	if not payload or not payload.chem then return 1 end
	if not vector or not vector.route then return 1 end
	if payload.route == vector.route then return 1 end

	return 0.5
end

-- Имя начинки: у химии переиспользуем существующую вики-локализацию крафта.
function T:PayloadName(payload)
	if not payload then return "?" end

	local lang = MuR.Language or {}

	if payload.chem then
		local wiki = payload.wikiKey and lang["craft_wiki_" .. payload.wikiKey .. "_name"]
		if wiki then return wiki end

		local swep = weapons.Get(payload.weapon)
		if swep and swep.PrintName then return swep.PrintName end

		return payload.chem
	end

	return lang["trap_payload_" .. payload.id] or payload.id
end

function T:ModuleName(kind, id)
	local lang = MuR.Language or {}
	return lang["trap_" .. kind .. "_" .. id] or id
end

function T:ModuleDesc(kind, id)
	local lang = MuR.Language or {}
	return lang["trap_" .. kind .. "_" .. id .. "_desc"] or ""
end
