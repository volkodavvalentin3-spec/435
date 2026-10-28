-- Зрение и выбор цели.

-- Своё имя, а НЕ переопределение EyePos: у scripted entity нативный метод
-- Entity всегда выигрывает у метода из таблицы ENT, так что ENT:EyePos просто
-- не вызвался бы. Нативный EyePos у nextbot даёт всего +33 по z (пояс), для
-- трасс видимости этого мало.
function ENT:GetEyeOrigin()
	local att = self.EyeAttachment

	if att == nil then
		local id = self:LookupAttachment("eyes")
		att = (id and id > 0) and id or false
		self.EyeAttachment = att
	end

	if att then
		local a = self:GetAttachment(att)
		if a then return a.Pos end
	end

	return self:GetPos() + Vector(0, 0, self.EyeHeight)
end

-- Откуда вылетает выстрел. У безоружного это те же глаза; стрелок подменяет
-- своей точкой дула (bs_npc_human/sv_weapon.lua).
function ENT:GetMuzzlePos()
	return self:GetEyeOrigin()
end

local function TargetPos(ent)
	if ent:IsPlayer() then return ent:EyePos() end
	if ent.GetEyeOrigin then return ent:GetEyeOrigin() end

	return ent:WorldSpaceCenter()
end

-- Прямая видимость. Нативный Entity:Visible для nextbot всегда возвращает
-- false (проверено в игре: false даже в 119 юнитах при чистой линии), а
-- перекрыть его из ENT нельзя — отсюда своё имя.
function ENT:HasLOS(ent)
	if not IsValid(ent) then return false end

	local tr = util.TraceLine({
		start = self:GetEyeOrigin(),
		endpos = TargetPos(ent),
		filter = {self, ent},
		mask = MASK_BLOCKLOS,
	})

	return not tr.Hit
end

-- Видимость с учётом дистанции и сектора обзора.
function ENT:CanSee(ent)
	if not IsValid(ent) then return false end

	local myPos = self:GetPos()
	local pos = ent:GetPos()

	if myPos:DistToSqr(pos) > self.SightDistance * self.SightDistance then return false end

	if self.SightAngle < 360 then
		local dir = (pos - myPos)
		dir.z = 0
		dir:Normalize()

		local fwd = self:GetForward()
		fwd.z = 0
		fwd:Normalize()

		-- SightAngle задан как полный сектор, поэтому сравниваем с половиной.
		if math.deg(math.acos(math.Clamp(fwd:Dot(dir), -1, 1))) > self.SightAngle * 0.5 then
			return false
		end
	end

	return self:HasLOS(ent)
end

--------------------------------------------------------------------------------
-- Враг
--------------------------------------------------------------------------------

function ENT:GetEnemy()
	return IsValid(self.Enemy) and self.Enemy or NULL
end

function ENT:IsValidEnemy(ent)
	if not IsValid(ent) or ent == self then return false end

	if ent:IsPlayer() then
		if MuR.NPC.IgnorePlayers() then return false end
		if not ent:Alive() then return false end
		-- Геттера GetNoTarget в GMod нет, SetNoTarget просто ставит флаг.
		if ent:IsFlagSet(FL_NOTARGET) then return false end
	elseif MuR.IsAI(ent) then
		if ent:Health() <= 0 then return false end
	else
		return false
	end

	return MuR.NPC.IsHostile(self, ent)
end

function ENT:SetEnemy(ent)
	local old = self:GetEnemy()

	if not IsValid(ent) then
		self.Enemy = NULL
		-- Роль держится за конкретного врага и вместе с ним отпускается, иначе
		-- слот в группе остаётся занятым мертвецом.
		MuR.NPC.ReleaseRole(self)
		if IsValid(old) and self.OnResetEnemy then self:OnResetEnemy() end
		return
	end

	self.Enemy = ent
	self.LastSawEnemy = CurTime()
	self:RememberEnemyAt(ent:GetPos(), ent)

	if old ~= ent then
		MuR.NPC.ReleaseRole(self)

		if self.SoundTbl_Alert then
			MuR.EmitSound(self, self.SoundTbl_Alert, 80, math.random(95, 105))
		end
		if self.OnAlert then self:OnAlert(ent) end

		self:AlertAllies(ent)
	end
end

--------------------------------------------------------------------------------
-- Память о цели
--------------------------------------------------------------------------------

--
-- Где врага видели в последний раз.
--
-- Без этого потеря контакта означала «забыть и стоять»: NPC терял цель за углом
-- и возвращался к патрулю, хотя в него только что стреляли с двух метров.
--
function ENT:RememberEnemyAt(pos, enemy)
	if not isvector(pos) then return end

	self.LastEnemyPos = pos
	self.LastEnemyTime = CurTime()
	self.SearchedLastPos = false

	if IsValid(enemy) then self.LastEnemyEnt = enemy end
end

-- Актуальна ли ещё наводка. Старая цена дороже денег: бежать через полкарты к
-- месту, где кого-то видели полминуты назад, — это не поиск, а глупость.
function ENT:GetLastEnemyPos()
	if not isvector(self.LastEnemyPos) then return nil end
	if CurTime() - (self.LastEnemyTime or 0) > self.EnemyMemoryTime then return nil end

	return self.LastEnemyPos
end

function ENT:ClearEnemyMemory()
	self.LastEnemyPos = nil
	self.LastEnemyTime = nil
	self.LastEnemyEnt = nil
	self.SearchedLastPos = false
end

-- Назначить врага в обход проверок видимости и, по желанию, снять текущий приказ.
--
-- Назначить цель в обход поиска: оповещение от своих, скрипты режимов, ответ на
-- выстрел в спину.
--
-- ai_ignoreplayers проверяем и здесь, а не только в IsValidEnemy: часть
-- вызывающих зовёт этот метод напрямую, и без проверки конвар обходился бы
-- через чужую наводку.
--
function ENT:ForceSetEnemy(ent, stopMoving)
	if IsValid(ent) and ent:IsPlayer() and MuR.NPC.IgnorePlayers() then return end

	if not IsValid(ent) then return end

	self:SetEnemy(ent)

	if stopMoving then self:ClearGoal() end
end

function ENT:ResetEnemy()
	self:SetEnemy(nil)
end

-- Раз в EnemyScanInterval: проверяем текущего врага и ищем нового.
function ENT:UpdateEnemy()
	local now = CurTime()
	local enemy = self:GetEnemy()

	if IsValid(enemy) then
		if not self:IsValidEnemy(enemy) then
			self:ResetEnemy()
		else
			-- Трасса видимости не нужна каждый тик: 67 раз в секунду на каждого
			-- NPC — это чистая трата. Четыре раза в секунду достаточно, чтобы
			-- уложиться в EnemyLoseTime.
			if now >= (self.NextEnemyLOS or 0) then
				self.NextEnemyLOS = now + 0.25

				if self.EnemyXRayDetection or self:HasLOS(enemy) then
					self.LastSawEnemy = now
					-- Пока видим — держим наводку свежей. Именно она останется,
					-- когда цель уйдёт за угол.
					self:RememberEnemyAt(enemy:GetPos(), enemy)
				elseif now - self.LastSawEnemy > self.EnemyLoseTime then
					self:ResetEnemy()
				end
			end

			return
		end
	end

	if now < self.NextEnemyScan then return end
	self.NextEnemyScan = now + self.EnemyScanInterval

	self:SetEnemy(self:FindEnemy())
end

function ENT:FindEnemy()
	local best, bestDist = nil, math.huge
	local myPos = self:GetPos()
	local sightSqr = self.SightDistance * self.SightDistance

	-- Игроки идут отдельно: их мало, и это основная цель.
	for _, ply in player.Iterator() do
		if not self:IsValidEnemy(ply) then continue end

		local d = myPos:DistToSqr(ply:GetPos())
		if d >= bestDist or d > sightSqr then continue end
		if not self.EnemyXRayDetection and not self:CanSee(ply) then continue end

		best, bestDist = ply, d
	end

	-- Остальной ИИ берём из реестра MuR.NPC.List, а не из ents.FindInSphere:
	-- сфера радиусом SightDistance отдавала тысячи сущностей на каждый вызов.
	for ent in pairs(MuR.NPC.List) do
		if not IsValid(ent) then MuR.NPC.List[ent] = nil continue end
		if ent == self then continue end

		local d = myPos:DistToSqr(ent:GetPos())
		if d >= bestDist or d > sightSqr then continue end
		if not self:IsValidEnemy(ent) then continue end
		if not self.EnemyXRayDetection and not self:CanSee(ent) then continue end

		best, bestDist = ent, d
	end

	return best
end

function ENT:OnEnemyKilled(dmginfo, hitgroup)
	if self.CustomOnEnemyKilled then self:CustomOnEnemyKilled(dmginfo, hitgroup) end
end
