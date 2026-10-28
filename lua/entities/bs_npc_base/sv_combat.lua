-- Атаки: ближний бой, снаряд, прыжок.

-- Двери и ломаемое живут в MuR.NPC.IsBreakable: тот же список нужен логике
-- застревания. Режим 18 прямо рассчитывает на такие удары — там урон зомби по
-- prop_physics и дверям умножается на 10.

-- Кого вообще можно ударить. Возвращает вторым значением признак "это не
-- живая цель, а прop" — его ждёт колбэк CustomOnDamageByTarget.
--
-- Ragdoll с isRDRag — это сбитый с ног игрок, и добивать его NPC обязан:
-- иначе лежачий неуязвим.
local function IsMeleeTarget(self, ent)
	if not IsValid(ent) or ent == self then return false end

	if ent:IsPlayer() then
		return ent:Alive() and MuR.NPC.IsHostile(self, ent), false
	end

	if MuR.IsAI(ent) then
		return ent:Health() > 0 and MuR.NPC.IsHostile(self, ent), false
	end

	if ent:GetClass() == "prop_ragdoll" and ent.isRDRag and not ent.IsDead then
		return IsValid(ent.Owner) and MuR.NPC.IsHostile(self, ent.Owner), false
	end

	-- Только то, у чего реально есть здоровье: у дверей на картах оно нулевое,
	-- и урон по ним лишь зря гоняет хуки урона.
	if self.MeleeAttackDamageProps and MuR.NPC.IsBreakable(ent) and MuR.NPC.IsDamageable(ent) then
		return true, true
	end

	return false
end

--------------------------------------------------------------------------------
-- Ближний бой
--------------------------------------------------------------------------------

function ENT:CanMeleeAttack()
	if not self.HasMeleeAttack then return false end
	if not self:CanAttack() then return false end
	if CurTime() < self.NextMeleeAttackT then return false end

	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return false end

	local d = self.MeleeAttackDistance

	return self:GetPos():DistToSqr(enemy:GetPos()) <= d * d
end

-- target необязателен: без него бьём текущего врага. Явная цель нужна, чтобы
-- ударить преграду, когда врага не видно вовсе.
function ENT:StartMeleeAttack(target)
	target = target or self:GetEnemy()
	if not IsValid(target) then return 0 end

	self.IsAttacking = true
	self.NextMeleeAttackT = CurTime() + MuR.Roll(self.NextMeleeAttackTime, 1)

	self:FaceTowards(target:GetPos())

	-- Замереть на время замаха. Без этого NPC доезжает удар по инерции и
	-- выглядит так, будто скользит. Скорость вернёт следующий FollowPath.
	self.loco:SetDesiredSpeed(0)

	MuR.EmitSound(self, self.SoundTbl_BeforeMeleeAttack, 75, math.random(95, 105))

	local dur = self:PlayAnim(self.AnimTbl_MeleeAttack, true)
	if dur <= 0 then dur = 0.6 end

	-- TimeUntilMeleeAttackDamage == false означает, что урон навешен на событие
	-- анимации: NPC сам позовёт ExecuteMeleeAttack из OnAnimEvent.
	if self.TimeUntilMeleeAttackDamage ~= false then
		timer.Simple(math.min(self.TimeUntilMeleeAttackDamage, dur), function()
			if IsValid(self) and self:Health() > 0 then self:ExecuteMeleeAttack() end
		end)
	end

	timer.Simple(dur, function()
		if IsValid(self) then self.IsAttacking = false end
	end)

	return dur
end

function ENT:ExecuteMeleeAttack()
	local center = self:WorldSpaceCenter()
	local range = self.MeleeAttackDamageDistance
	local fwd = self:GetForward()
	local hitAny = false

	for _, ent in ipairs(ents.FindInSphere(center, range)) do
		local valid, isProp = IsMeleeTarget(self, ent)
		if not valid then continue end

		local dir = ent:WorldSpaceCenter() - center
		dir.z = 0
		if dir:LengthSqr() > 1 then
			dir:Normalize()
			if fwd:Dot(dir) < self.MeleeAttackDamageAngle then continue end
		end

		-- Перехват до урона: полиция этим подменяет удар арестом.
		-- Имя от VJ, чтобы порт описаний NPC читался один в один.
		if self.CustomOnMeleeAttack_AfterChecks and self:CustomOnMeleeAttack_AfterChecks(ent) == true then
			hitAny = true
			continue
		end

		local dmg = DamageInfo()
		dmg:SetDamage(self.MeleeAttackDamage)
		dmg:SetDamageType(self.MeleeAttackDamageType)
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamagePosition(ent:WorldSpaceCenter())
		dmg:SetDamageForce(fwd * self.MeleeAttackKnockBackForce)

		ent:TakeDamageInfo(dmg)
		hitAny = true

		if isProp then
			-- Живой цели удар засчитан, а по пропу отдельный колбэк и никакого
			-- отбрасывания: дверь от толчка улетать не должна.
			if self.CustomOnDamageByTarget then
				self:CustomOnDamageByTarget(dmg, ent, true)
			end

			continue
		end

		if self.HasMeleeAttackKnockBack or self.MeleeAttackPlayerSpeed then
			local push = fwd * self.MeleeAttackKnockBackForce
			push.z = math.max(push.z, 100)

			if ent:IsPlayer() then
				ent:SetVelocity(push)
			else
				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then phys:ApplyForceCenter(push * 10) end
			end
		end

		if self.CustomOnDamageByTarget then
			self:CustomOnDamageByTarget(dmg, ent, false)
		end
	end

	if hitAny then
		MuR.EmitSound(self, self.SoundTbl_MeleeAttack, 75, math.random(95, 105))
	else
		MuR.EmitSound(self, self.SoundTbl_MeleeAttackMiss, 70, math.random(95, 105))
	end

	return hitAny
end

--------------------------------------------------------------------------------
-- Снаряд
--------------------------------------------------------------------------------

function ENT:CanRangeAttack()
	if not self.HasRangeAttack then return false end
	if not self:CanAttack() then return false end
	if CurTime() < self.NextRangeAttackT then return false end

	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return false end

	local dist = self:GetPos():Distance(enemy:GetPos())
	if dist > self.RangeDistance or dist < self.RangeToMeleeDistance then return false end

	return self:HasLOS(enemy)
end

function ENT:StartRangeAttack()
	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return 0 end

	self.IsAttacking = true
	self.NextRangeAttackT = CurTime() + MuR.Roll(self.NextRangeAttackTime, 12)

	self:FaceTowards(enemy:GetPos())

	local dur = self:PlayAnim(self.AnimTbl_RangeAttack, true)
	if dur <= 0 then dur = 1 end

	if self.TimeUntilRangeAttackProjectileRelease ~= false then
		timer.Simple(math.min(self.TimeUntilRangeAttackProjectileRelease, dur), function()
			if IsValid(self) and self:Health() > 0 then self:ExecuteRangeAttack() end
		end)
	end

	timer.Simple(dur, function()
		if IsValid(self) then self.IsAttacking = false end
	end)

	return dur
end

function ENT:ExecuteRangeAttack()
	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return end

	local src = self:LocalToWorld(self.RangeAttackOffset)
	local proj = ents.Create(self.RangeAttackEntityToSpawn)
	if not IsValid(proj) then return end

	proj:SetPos(src)
	proj:SetAngles(self:GetAngles())
	proj:SetOwner(self)
	proj.Owner = self
	proj.BSOwner = self
	proj:Spawn()
	proj:Activate()

	local dir = (enemy:WorldSpaceCenter() - src):GetNormalized()
	local phys = proj:GetPhysicsObject()

	if IsValid(phys) then
		phys:SetVelocity(dir * self.RangeAttackSpeed)
	else
		proj:SetVelocity(dir * self.RangeAttackSpeed)
	end

	return proj
end

--------------------------------------------------------------------------------
-- Прыжковая атака
--------------------------------------------------------------------------------

function ENT:CanLeapAttack()
	if not self.HasLeapAttack then return false end
	if not self:CanAttack() then return false end
	if CurTime() < self.NextLeapAttackT then return false end
	if not self.loco:IsOnGround() then return false end

	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return false end

	local dist = self:GetPos():Distance(enemy:GetPos())
	local min, max = self.LeapAttackDistance[1], self.LeapAttackDistance[2]
	if dist < min or dist > max then return false end
	if not self:HasLOS(enemy) then return false end

	-- OnLeapAttack оставлен как у VJ: NPC возвращает false, чтобы запретить
	-- прыжок (зомби и PTICHKI так отсекают цели на другой высоте).
	if self.OnLeapAttack and self:OnLeapAttack("Init", enemy) == false then return false end

	return true
end

function ENT:StartLeapAttack()
	local enemy = self:GetEnemy()
	if not IsValid(enemy) then return 0 end

	self.IsAttacking = true
	self.NextLeapAttackT = CurTime() + MuR.Roll(self.NextLeapAttackTime, 6)

	self:FaceTowards(enemy:GetPos())
	MuR.EmitSound(self, self.SoundTbl_LeapAttackJump, 80, math.random(95, 105))

	-- AnimTbl_LeapAttack часто задан как ACT_*, а у активити длительности нет,
	-- поэтому есть отдельный LeapAttackDuration: на это время корутина
	-- поведения замирает и не мешает полёту.
	local dur = self:PlayAnim(self.AnimTbl_LeapAttack, true)
	if dur <= 0 then dur = self.LeapAttackDuration end

	timer.Simple(self.TimeUntilLeapAttackVelocity, function()
		if not IsValid(self) or self:Health() <= 0 then return end

		local target = self:GetEnemy()
		if not IsValid(target) then return end

		local dir = target:GetPos() - self:GetPos()
		dir.z = 0
		local dist = dir:Length()
		if dist < 1 then return end
		dir:Normalize()

		-- loco:Jump() + SetVelocity даёт всего ~100 юнитов: прыжок низкий и
		-- горизонтальную скорость тут же съедает торможение (замерено в игре).
		-- JumpAcrossGap строит настоящую дугу — те же вводные дают ~300 юнитов.
		local land = self:GetPos() + dir * math.min(dist, self.LeapAttackDistance[2])
		self.loco:JumpAcrossGap(land, dir)
	end)

	timer.Simple(math.min(self.TimeUntilLeapAttackDamage, dur), function()
		if not IsValid(self) or self:Health() <= 0 then return end

		-- Прыжковый урон отличается только числом и типом, зона поражения та же,
		-- поэтому подменяем поля на один вызов вместо копии ExecuteMeleeAttack.
		local saveDmg, saveType = self.MeleeAttackDamage, self.MeleeAttackDamageType
		self.MeleeAttackDamage = self.LeapAttackDamage
		self.MeleeAttackDamageType = self.LeapAttackDamageType
		self:ExecuteMeleeAttack()
		self.MeleeAttackDamage, self.MeleeAttackDamageType = saveDmg, saveType
	end)

	timer.Simple(dur, function()
		if IsValid(self) then self.IsAttacking = false end
	end)

	return dur
end
