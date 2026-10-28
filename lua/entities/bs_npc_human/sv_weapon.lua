-- Оружие в руках NPC: выдача, стрельба, перезарядка.
--
-- Заменяет weapon_vj_base. Оружие описано данными в lua/autorun/bs_npc_weapons.lua,
-- в руке висит bs_npc_weapon, а вся логика здесь.

--------------------------------------------------------------------------------
-- Выдача
--------------------------------------------------------------------------------

-- Имя оставлено как у движкового NPC: Give зовут режимы и sv_npc.
function ENT:Give(class)
	if not isstring(class) then return NULL end

	local data = MuR.NPC.BuildWeapon(class)
	if not data then return NULL end

	if IsValid(self.BSWeapon) then self.BSWeapon:Remove() end

	local wep = ents.Create("bs_npc_weapon")
	if not IsValid(wep) then return NULL end

	wep:SetPos(self:GetPos())
	wep:Spawn()
	wep:Setup(self, data)

	self.BSWeapon = wep
	self.NextWeaponFire = 0
	self.WeaponReloadEnd = 0

	-- Ближний бой берёт параметры у оружия: одна и та же база обслуживает и
	-- нож, и пустые руки.
	if data.melee then
		self.MeleeAttackDamage = data.damage or self.MeleeAttackDamage
		self.MeleeAttackDistance = data.range or self.MeleeAttackDistance
		self.MeleeAttackDamageDistance = (data.range or self.MeleeAttackDistance) + 10
		self.NextMeleeAttackTime = data.delay or self.NextMeleeAttackTime
		if data.meleeAnims then self.AnimTbl_MeleeAttack = data.meleeAnims end
		self.SoundTbl_MeleeAttack = data.hitSound
		self.SoundTbl_MeleeAttackMiss = data.missSound
	end

	return wep
end

function ENT:GetActiveWeapon()
	return IsValid(self.BSWeapon) and self.BSWeapon or NULL
end

function ENT:HasRangedWeapon()
	local wep = self:GetActiveWeapon()

	return IsValid(wep) and not wep:IsMelee()
end

--
-- Позы текущего оружия для ЭТОЙ модели: один и тот же ствол держится по-разному
-- гражданской моделью и комбайновской.
--
function ENT:GetWeaponAnims()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return nil end

	local data = wep:GetData()
	if not data then return nil end

	return MuR.NPC.GetAnimSet(self.AnimSet, data.animSet)
end

-- Играет ли этот NPC стрельбу и перезарядку жестом.
function ENT:WeaponAnimsAreGestures()
	return MuR.NPC.AnimSetUsesGestures(self.AnimSet)
end

--
-- Выбросить оружие. Зовут sh_kicks (разоружение пинком) и режим 22.
-- Кладём world-модель физпропом, чтобы выпавшее было видно.
--
function ENT:DropWeapon()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return end

	local data = wep:GetData()
	local pos, ang = wep:GetPos(), wep:GetAngles()

	self.BSWeapon = nil
	wep:Remove()

	if not data or not data.model then return end

	local drop = ents.Create("prop_physics")
	if not IsValid(drop) then return end

	drop:SetModel(data.model)
	drop:SetPos(pos)
	drop:SetAngles(ang)
	drop:Spawn()
	drop:Activate()

	local phys = drop:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(self:GetForward() * 100 + Vector(0, 0, 80))
	end

	SafeRemoveEntityDelayed(drop, 60)
end

--------------------------------------------------------------------------------
-- Стрельба
--------------------------------------------------------------------------------

function ENT:GetFiringRange()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return 0 end

	local data = wep:GetData()

	return self.Weapon_Range * (data.rangeScale or 1)
end

function ENT:IsReloading()
	return CurTime() < (self.WeaponReloadEnd or 0)
end

function ENT:CanFireWeapon()
	if not self:HasRangedWeapon() then return false end
	if not self:CanAttack() then return false end
	if self:IsReloading() then return false end
	if CurTime() < (self.NextWeaponFire or 0) then return false end

	local wep = self:GetActiveWeapon()
	if wep:GetClip() <= 0 then return false end

	-- Хук NPC: полиция им запрещает огонь, пока цель сдаётся.
	if self.OnWeaponCanFire and self:OnWeaponCanFire() == false then return false end

	return true
end

-- Куда целиться. Аргументом принимается и сущность, и точка: подавление
-- стреляет по месту, где врага видели, а не по нему самому.
local function AimPos(target)
	if isvector(target) then return target end
	if IsValid(target) then return target:WorldSpaceCenter() end

	return nil
end

--
-- Номер attachment дула: сначала именованный, потом номер из описания SWEP (TFA
-- держит его в MuzzleAttachment).
--
function ENT:GetMuzzleAttachment()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return nil end

	local id = wep:LookupAttachment("muzzle")

	if not id or id <= 0 then
		local data = wep:GetData()
		id = data and data.muzzleAttachment
	end

	return (id and id > 0) and id or nil
end

-- Откуда вылетает пуля. Без дула стреляем от плеча: иначе точка вылета уезжает
-- в пол. Перекрывает заглушку базы, по ней же считается коридор огня.
function ENT:GetMuzzlePos()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return self:GetEyeOrigin() end

	local id = self:GetMuzzleAttachment()
	local att = id and wep:GetAttachment(id)

	return att and att.Pos or self:GetEyeOrigin()
end

--
-- Откуда вылетает пуля.
--
-- Обычно это дуло. Но в позе укрытия боец прижат спиной к стене и высовывает
-- ствол за край: дуло тогда запросто оказывается ВНУТРИ преграды, и очередь
-- уходит в неё же. Система укрытий для игрока решает это подменой источника на
-- attachment "eyes" — здесь то же самое.
--
function ENT:GetFirePos()
	if self.CoverPose then
		local eyes = self:GetEyeOrigin()
		if isvector(eyes) then return eyes end
	end

	return self:GetMuzzlePos()
end

-- Свободен ли коридор до цели. Ложь означает «свой на линии».
function ENT:HasClearShot(target)
	if not self.CheckLineOfFire then return true end

	local aim = AimPos(target)
	if not aim then return false end

	return self:AllyInLineOfFire(self:GetFirePos(), aim) == nil
end

function ENT:FireOnce(target)
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return end

	local aim = AimPos(target)
	if not aim then return end

	local data = wep:GetData()

	local muzzle = self:GetMuzzleAttachment()
	local src = self:GetFirePos()

	local dir = aim - src
	dir:Normalize()

	-- spreadRaw приходит из SWEP уже в единицах FireBullets; spread — наш
	-- человекочитаемый вариант, его надо пересчитать.
	local spread = (data.spreadRaw or (data.spread or 1) * 0.01) * self.Weapon_Accuracy

	self:FireBullets({
		Src = src,
		Dir = dir,
		Spread = Vector(spread, spread, 0),
		Num = data.shots or 1,
		Damage = (data.damage or 10) * (self.Weapon_DamageScale or 1),
		Force = 2,
		Attacker = self,
		Tracer = 1,
		TracerName = "Tracer",
	})

	wep:EmitSound(MuR.Pick(data.fireSound) or "", 85, math.random(97, 103))

	if muzzle and muzzle > 0 then
		local ef = EffectData()
		ef:SetOrigin(src)
		ef:SetEntity(wep)
		ef:SetAttachment(muzzle)
		ef:SetScale(1)
		util.Effect("MuzzleFlash", ef)
	end

	wep:SetClip(wep:GetClip() - 1)
	self.NextWeaponFire = CurTime() + (data.delay or 0.3)
end

-- Позы стрельбы: у игроцкого скелета это жест поверх ходьбы, у остальных —
-- активити на всё тело.
function ENT:PlayFireAnim(anims, delay)
	if self:WeaponAnimsAreGestures() then
		self:PlayGesture(anims and anims.fire or ACT_HL2MP_GESTURE_RANGE_ATTACK_SMG1)

		return
	end

	self:PlayAnim(anims and anims.fire or ACT_RANGE_ATTACK_SMG1, true, delay)
end

--
-- Выстрел без остановки, для FollowPath с fire = true.
--
-- Доступен только скелетам, у которых выстрел — жест поверх ходьбы
-- (WeaponAnimsAreGestures): у citizen/combine выстрел ставится активити на всё
-- тело и ноги встали бы. Пули летят честно в цель, а корпус доворачивают
-- поз-параметры (aim_yaw/head_yaw), поэтому стрелять можно и на бегу не в лоб.
--
-- Темп задаёт FireOnce через NextWeaponFire: вызов каждый тик пути не
-- превращается в очередь быстрее паспортной.
--
function ENT:TryFireWhileMoving()
	if not self.CanShootWhileMoving then return end
	if not self:WeaponAnimsAreGestures() then return end

	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return end

	local dist = self:GetPos():Distance(enemy:GetPos())
	if dist < self.Weapon_MeleeDistance or dist > self:GetFiringRange() then return end

	if not self:HasLOS(enemy) then return end
	if not self:CanFireWeapon() then return end
	-- Свой мог войти в коридор: не стреляем сквозь своих даже на ходу.
	if not self:HasClearShot(enemy) then return end

	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return end

	self:PlayFireAnim(self:GetWeaponAnims(), wep:GetData().delay)
	self:FireOnce(enemy)
end

--
-- Очередь. Только из корутины поведения: между выстрелами она ждёт.
--
function ENT:ShootBurst(target)
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return end

	local data = wep:GetData()

	local anims = self:GetWeaponAnims()

	self:FaceTowards(target:GetPos())
	self:PlayFireAnim(anims, data.delay)

	if data.timeUntilFire then coroutine.wait(data.timeUntilFire) end
	-- Оружие могли выбить прямо во время wait (сдача, разоружение): корутина
	-- держит ссылку на уже удалённую сущность, её методы nil.
	if not IsValid(self) or not IsValid(target) or not IsValid(wep) then return end

	local shots = data.burst and math.random(data.burst[1], data.burst[2]) or 1

	for i = 1, shots do
		if not IsValid(self) or not IsValid(target) then return end
		if not IsValid(wep) or wep:GetClip() <= 0 then break end
		if self:GetEnemy() ~= target then break end
		-- Свой мог войти в коридор посреди очереди: дострелять её ему в спину
		-- ничем не лучше, чем начать очередь сквозь него.
		if not self:HasClearShot(target) then break end

		self:FaceTowards(target:GetPos())
		self:FireOnce(target)

		if data.extraSound then
			timer.Simple(data.extraSoundDelay or 0.4, function()
				if IsValid(wep) then MuR.EmitSound(wep, data.extraSound, 70, 100) end
			end)
		end

		coroutine.wait(data.delay or 0.3)
	end

	coroutine.wait(MuR.Roll(self.Weapon_RestTime, 0.5))
end

--
-- Подавление: короткая очередь по точке, а не по цели.
--
-- Нужна ровно затем, чтобы боец не выбегал на открытое место, потеряв цель за
-- углом: раньше единственной реакцией на пропавшую видимость было сближение, и
-- вся группа поочерёдно выбегала под ствол.
--
-- Очередь вдвое короче боевой: это работа по площади, магазин на неё не жгут.
--
function ENT:SuppressBurst(pos)
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) or not isvector(pos) then return end

	local data = wep:GetData()

	self:FaceTowards(pos)
	self:PlayFireAnim(self:GetWeaponAnims(), data.delay)

	if data.timeUntilFire then coroutine.wait(data.timeUntilFire) end
	if not IsValid(self) or not IsValid(wep) then return end

	local shots = data.burst and math.random(data.burst[1], data.burst[2]) or 1
	shots = math.max(1, math.floor(shots * 0.5))

	for _ = 1, shots do
		if not IsValid(self) then return end
		if not IsValid(wep) or wep:GetClip() <= 0 then break end
		-- Цель показалась — дальше это уже прицельный огонь, а не подавление.
		if self:HasLOS(self:GetEnemy()) then break end
		if not self:HasClearShot(pos) then break end

		self:FaceTowards(pos)
		self:FireOnce(pos)

		coroutine.wait(data.delay or 0.3)
	end

	coroutine.wait(MuR.Roll(self.Weapon_RestTime, 0.5))
end

--------------------------------------------------------------------------------
-- Перезарядка
--------------------------------------------------------------------------------

function ENT:NeedsReload()
	local wep = self:GetActiveWeapon()

	return IsValid(wep) and not wep:IsMelee() and wep:GetClip() <= 0
end

function ENT:ReloadWeapon()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return end

	local data = wep:GetData()
	local dur = data.reloadTime or 2

	self.WeaponReloadEnd = CurTime() + dur

	local anims = self:GetWeaponAnims()

	MuR.EmitSound(self, data.reloadSound, 70, 100)
	if self:WeaponAnimsAreGestures() then
		self:PlayGesture(anims and anims.reload or ACT_HL2MP_GESTURE_RELOAD_SMG1)
	else
		self:PlayAnim(anims and anims.reload or ACT_RELOAD, true, dur)
	end

	coroutine.wait(dur)

	if IsValid(wep) then wep:SetClip(wep:GetMaxClip()) end
end

--------------------------------------------------------------------------------
-- Прицеливание корпусом
--------------------------------------------------------------------------------

--
-- Поз-параметры вместо одного разворота корпуса.
--
-- Без них стрелок целится строго по горизонту: цель на балконе или под ногами,
-- а ствол смотрит в стену напротив — попадания при этом честные, потому что
-- пуля летит из FireOnce в реальную точку, а картинка им противоречит.
-- Разворачивать ради этого весь корпус нельзя: по тому же вектору NPC идёт.
--
-- Наборы у моделей разные, замерено:
--   игроцкий скелет — aim_yaw[-63..71], aim_pitch[-84..82], head_yaw, head_pitch;
--   гражданские     — aim_yaw[-60..60], aim_pitch[-89..50], head_yaw, head_pitch;
--   комбайн         — только aim_pitch и aim_yaw.
--
-- Поэтому пишем в то, что есть, и в пределах СВОЕГО диапазона у каждой модели:
-- выход за границу параметр не расширяет, а заворачивает позу.
--
-- body_yaw и spine_yaw намеренно не трогаем: их ведёт слой передвижения
-- (BodyMoveXY), и вмешательство в них ломает разворот на ходу.
--
local AIM_POSES = {"aim_yaw", "aim_pitch", "head_yaw", "head_pitch"}

function ENT:CacheAimPoses()
	local t = {}

	for _, name in ipairs(AIM_POSES) do
		local id = self:LookupPoseParameter(name)

		if id and id >= 0 then
			local mn, mx = self:GetPoseParameterRange(id)
			-- Имя, а не номер: SetPoseParameter принимает ИМЯ, номер он
			-- молча не находит. Номер держим только для чтения диапазона.
			t[name] = {min = mn, max = mx}
		end
	end

	self.AimPoses = t

	return t
end

--
-- Куда смотрит ствол. Врага держим на прицеле и в паузах между очередями, а
-- потерянного — ещё AimHoldTime секунд по последнему месту: мгновенно
-- выпрямляться, стоило цели зайти за угол, выглядит как потеря интереса.
--
function ENT:GetAimPos()
	local enemy = self:GetEnemy()

	if IsValid(enemy) then
		if enemy:IsPlayer() then return enemy:EyePos() end
		if enemy.GetEyeOrigin then return enemy:GetEyeOrigin() end

		return enemy:WorldSpaceCenter()
	end

	if isvector(self.LastLOSPos) and CurTime() - (self.LastLOSTime or 0) < self.AimHoldTime then
		return self.LastLOSPos + Vector(0, 0, self.CoverEyeHeight)
	end

	return nil
end

function ENT:UpdateAimPose()
	local poses = self.AimPoses or self:CacheAimPoses()
	if not next(poses) then return end

	local yaw, pitch = 0, 0
	local aim = self:GetAimPos()

	if aim then
		local ang = (aim - self:GetMuzzlePos()):Angle()

		yaw = math.NormalizeAngle(ang.y - self:GetAngles().y)
		-- В Source положительный pitch смотрит ВНИЗ, у aim_pitch знак тот же.
		pitch = math.NormalizeAngle(ang.p)
	end

	--
	-- Сглаживание обязательно: цель дёргается по экрану на десятки градусов за
	-- кадр (особенно игрок в прыжке), и без него голова и плечи трясутся.
	-- Через FrameTime, а не константой на кадр: BodyUpdate зовётся с частотой
	-- отрисовки, и на разном фреймрейте иначе разная скорость доводки.
	--
	local rate = math.Clamp(FrameTime() * self.AimPoseRate, 0, 1)

	self.AimYaw = Lerp(rate, self.AimYaw or 0, yaw)
	self.AimPitch = Lerp(rate, self.AimPitch or 0, pitch)

	local function set(name, value)
		local p = poses[name]
		if not p then return end

		self:SetPoseParameter(name, math.Clamp(value, p.min, p.max))
	end

	set("aim_yaw", self.AimYaw)
	set("aim_pitch", self.AimPitch)

	-- Голова ведёт корпус: доворачивается чуть дальше, чем плечи. На моделях без
	-- head_* просто ничего не произойдёт.
	set("head_yaw", self.AimYaw * self.AimHeadLead)
	set("head_pitch", self.AimPitch * self.AimHeadLead)
end
