-- Ловушки: капканы и растяжки. Упрощённый порт VJ sv_traps.lua.
--
-- Ставят только осторожные/агрессивные подозреваемые (флаг CanSetTraps из
-- sv_profile.lua), когда враг уже известен, но не виден: минуют подходы,
-- пока полиция идёт на контакт. Бюджет общий на раунд: MuR.Mode14.TrapBudget.

local function TraceFloor(pos)
	return util.TraceLine({
		start = pos + Vector(0, 0, 8),
		endpos = pos - Vector(0, 0, 64),
		mask = MASK_SOLID_BRUSHONLY,
	})
end

--------------------------------------------------------------------------------
-- Выбор места
--------------------------------------------------------------------------------

--
-- Кандидаты: двери в радиусе 100..600 и узлы навмеша в 150..600. Двери
-- дороже — за ними чаще всего и заходят. Из тройки лучших берём случайную,
-- чтобы два минера не заперли одну точку.
--
function ENT:FindOptimalTrapPosition()
	local candidates = {}
	local myPos = self:GetPos()

	for _, ent in ipairs(ents.FindInSphere(myPos, 600)) do
		if IsValid(ent) and string.find(ent:GetClass(), "door") then
			local d = ent:GetPos():Distance(myPos)

			if d >= 100 and d <= 600 then
				local score = 70 - d * 0.05 + math.random(0, 15)

				if score > 40 then
					candidates[#candidates + 1] = {pos = ent:GetPos(), door = ent, score = score}
				end
			end
		end
	end

	if istable(MuR.AI_Nodes) then
		local total = #MuR.AI_Nodes

		if total > 0 then
			local step = math.max(1, math.floor(total / 64))
			local start = math.random(1, total)
			local found = 0

			for i = start, start + total - 1, step do
				local node = MuR.AI_Nodes[(i - 1) % total + 1]
				local pos = istable(node) and node.pos or node

				if isvector(pos) then
					local d = pos:Distance(myPos)

					if d >= 150 and d <= 600 then
						local score = 45 - d * 0.04 + math.random(0, 15)

						if score > 40 then
							candidates[#candidates + 1] = {pos = pos, score = score}
							found = found + 1

							if found >= 6 then break end
						end
					end
				end
			end
		end
	end

	if #candidates == 0 then return nil end

	table.sort(candidates, function(a, b) return a.score > b.score end)

	return candidates[math.random(1, math.min(3, #candidates))]
end

--------------------------------------------------------------------------------
-- Капкан
--------------------------------------------------------------------------------

function ENT:PlaceBeartrap(pos)
	local tr = TraceFloor(pos)
	if not tr.Hit then return false end

	local trap = ents.Create("trap_entity")
	if not IsValid(trap) then return false end

	trap:SetPos(tr.HitPos)
	trap:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
	trap:SetOwner(self)

	-- Хозяин ловушки нужен, чтобы она не сработала на своих и на нём самом.
	if isfunction(MuR.SetTrapOwner) then MuR:SetTrapOwner(trap, self) end

	trap:Spawn()

	if IsValid(tr.Entity) then
		constraint.Weld(trap, tr.Entity, 0, tr.PhysicsBone or 0, 0, true, false)
	end

	trap:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)

	return true
end

--------------------------------------------------------------------------------
-- Растяжка
--------------------------------------------------------------------------------

--
-- Две стены напротив друг друга: колышек на одной, граната на верёвке у
-- другой. Ширина проёма 60..150 — дверной; шире — уже не перегородить.
--
local function FindTripwireAnchors(center)
	local best

	for i = 0, 7 do
		local dir = Angle(0, i * 45, 0):Forward()
		local origin = center + Vector(0, 0, 8)

		local a = util.TraceLine({start = origin, endpos = origin + dir * 400, mask = MASK_SOLID_BRUSHONLY})
		if not a.Hit or a.HitPos:Distance(center) < 50 then continue end

		local b = util.TraceLine({start = origin, endpos = origin - dir * 400, mask = MASK_SOLID_BRUSHONLY})
		if not b.Hit or b.HitPos:Distance(center) < 50 then continue end

		local width = a.HitPos:Distance(b.HitPos)
		if width < 60 or width > 400 then continue end

		local score = (width <= 150) and 100 or 50

		if not best or score > best.score then
			best = {a = a, b = b, width = width, score = score}
		end
	end

	return best
end

function ENT:PlaceTripwireTrap(center)
	local anchors = FindTripwireAnchors(center)
	if not anchors then return false end

	local stake = ents.Create("prop_physics")
	if not IsValid(stake) then return false end

	stake:SetModel("models/props_c17/TrapPropeller_Lever.mdl")
	stake:SetPos(anchors.a.HitPos + anchors.a.HitNormal * 2)
	stake:SetAngles(anchors.a.HitNormal:Angle())
	stake:Spawn()

	local phys = stake:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	stake:SetCollisionGroup(COLLISION_GROUP_WORLD)

	local gren = ents.Create("murwep_grenade")
	if not IsValid(gren) then
		stake:Remove()
		return false
	end

	gren:SetPos(anchors.b.HitPos + anchors.b.HitNormal * 6)
	gren.PlayerOwner = self
	gren.OwnerTrap = self

	if isfunction(MuR.SetTrapOwner) then MuR:SetTrapOwner(gren, self) end

	-- Те же поля, что выставляет mur_f1: по ним граната сама дёргает чеку,
	-- когда верёвку натягивают дальше StakeLimit.
	gren.StakeEnt = stake
	gren.F1 = true
	gren.StakeLimit = anchors.width + 10
	gren:Spawn()

	local dist = gren:GetPos():Distance(stake:GetPos())
	local const = constraint.Rope(gren, stake, 0, 0, Vector(0, 0, 3), stake:GetUp() * -5, dist, 0, 0, 0.3, "cable/cable", false)

	gren.StakeConst = const
	gren:CallOnRemove("CleanStake", function()
		if IsValid(stake) then stake:Remove() end
	end)

	return true
end

--------------------------------------------------------------------------------
-- Попытка постановки
--------------------------------------------------------------------------------

--
-- 70% — растяжка, иначе капкан; если растяжке негде натянуться, ставим
-- капкан в ту же точку.
--
function ENT:PlaceTrapAt(spot)
	local pos = spot.pos

	if spot.door then
		-- Перед дверью: открывший её наступает.
		pos = pos + spot.door:GetForward() * 60
	end

	if math.random(100) <= 70 and self:PlaceTripwireTrap(pos) then return true end

	return self:PlaceBeartrap(pos)
end

function ENT:TryPlaceTrap()
	if not self.CanSetTraps then return end
	if self:Health() <= 0 or self.Surrendering then return end
	if (self.TrapsPlaced or 0) >= (self.MaxTraps or 5) then return end
	if CurTime() < (self.NextTrapTime or 0) then return end

	-- Общий бюджет раунда: когда лимит выбран, нечего и примеряться.
	if MuR.Gamemode == 14 and istable(MuR.Mode14) and MuR.Mode14.TrapBudget then
		if (MuR.Mode14.TrapsPlaced or 0) >= MuR.Mode14.TrapBudget then
			self.NextTrapTime = CurTime() + 30
			return
		end
	end

	-- Ставят только на тревоге и только пока враг не смотрит.
	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return end
	if self:HasLOS(enemy) then return end

	local spot = self:FindOptimalTrapPosition()
	if not spot then
		self.NextTrapTime = CurTime() + math.random(15, 30)
		return
	end

	-- Две ловушки в одной точке не учат ничему.
	if isvector(self.LastTrapPos) and spot.pos:DistToSqr(self.LastTrapPos) < 400 * 400 then
		self.NextTrapTime = CurTime() + math.random(10, 20)
		return
	end

	if not self:PlaceTrapAt(spot) then
		self.NextTrapTime = CurTime() + math.random(10, 20)
		return
	end

	self.TrapsPlaced = (self.TrapsPlaced or 0) + 1
	self.LastTrapPos = spot.pos
	self.NextTrapTime = CurTime() + math.random(30, 60)

	if MuR.Gamemode == 14 and istable(MuR.Mode14) then
		MuR.Mode14.TrapsPlaced = (MuR.Mode14.TrapsPlaced or 0) + 1
	end

	self:EmitSound("weapons/slam/buttonclick.wav", 60)
end
