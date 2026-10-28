-- Урон, флинч, смерть, гибы.

--------------------------------------------------------------------------------
-- Хитгруппы
--------------------------------------------------------------------------------

-- Пулевой урон приходит сюда раньше EntityTakeDamage, поэтому хитгруппу
-- запоминаем здесь и читаем ниже: EntityTakeDamage её не передаёт.
function ENT:OnTraceAttack(dmginfo, dir, trace)
	self.BSLastHitGroup = trace.HitGroup or HITGROUP_GENERIC
	self.BSLastHitGroupTime = CurTime()

	hook.Run("ScaleNPCDamage", self, self.BSLastHitGroup, dmginfo)
end

function ENT:GetBSLastHitGroup()
	-- Хитгруппа живёт один кадр: взрыв или огонь придут без TraceAttack, и
	-- тогда брать хитгруппу от прошлого попадания нельзя.
	if (self.BSLastHitGroupTime or 0) < CurTime() - 0.1 then return HITGROUP_GENERIC end

	return self.BSLastHitGroup or HITGROUP_GENERIC
end

-- Интерфейс, который ждёт sv_litewounds.lua: там `ent.LastHitGroup and
-- ent:LastHitGroup()`. Раньше это поле у нас было числом, и litewounds падал,
-- пытаясь его вызвать.
function ENT:LastHitGroup()
	return self:GetBSLastHitGroup()
end

-- Вызывается из общего хука EntityTakeDamage ДО применения урона: только здесь
-- NPC может его отмасштабировать (броня манглера) или отменить.
function ENT:PreTakeDamage(dmginfo)
	local hitgroup = self:GetBSLastHitGroup()

	--
	-- Своя пуля бьёт вполсилы.
	--
	-- Проверка коридора огня (sv_squad.lua) снимает прицельные попадания по
	-- своим, но остаётся разброс, рикошет и осколки собственных гранат — а
	-- отряд из шести стволов вокруг одной цели рано или поздно сходится сам на
	-- себе. Без этого множителя волна выкашивала себя быстрее, чем игрок.
	--
	local att = dmginfo:GetAttacker()

	if IsValid(att) and att ~= self and self:IsAlly(att) then
		dmginfo:ScaleDamage(self.FriendlyFireScale)
	end

	if self.CustomOnTakeDamage_BeforeDamage then
		if self:CustomOnTakeDamage_BeforeDamage(dmginfo, hitgroup) == true then return true end
	end

	if self.OnDamaged then
		self:OnDamaged(dmginfo, hitgroup, "Damaged")
	end
end

hook.Add("EntityTakeDamage", "BS_NPC_PreTakeDamage", function(ent, dmginfo)
	if not MuR.IsBSNPC(ent) then return end
	if not ent.PreTakeDamage then return end

	return ent:PreTakeDamage(dmginfo)
end)

--------------------------------------------------------------------------------
-- Реакция на урон
--------------------------------------------------------------------------------

function ENT:OnInjured(dmginfo)
	MuR.EmitSound(self, self.SoundTbl_Pain or self.SoundTbl_Damage, 75, math.random(95, 105))

	--
	-- В нас попали — значит там, где мы стоим, нас достают, и держаться этого
	-- места незачем. Сбрасываем троттлинг поиска укрытия, чтобы новое место
	-- подобралось на ближайшем же тике, а не через полторы секунды.
	--
	-- Само укрытие тут НЕ снимаем: годность угла решает IsCoverStillGood по
	-- трассе, а не факт попадания — зацепить могут и в хорошем укрытии, шагнув
	-- на позицию для выстрела.
	--
	self.LastHurtTime = CurTime()
	self.NextCoverSearch = 0

	local att = dmginfo:GetAttacker()
	if IsValid(att) and att ~= self and self:IsValidEnemy(att) then
		-- Выстрел в спину обязан переключить цель: иначе NPC продолжит идти
		-- на прежнего врага, пока его добивают сзади.
		if not IsValid(self:GetEnemy()) then
			self:ForceSetEnemy(att)
		else
			-- Стреляют откуда-то ещё: цель не меняем, но место запоминаем —
			-- будет куда идти, когда текущий враг кончится или потеряется.
			self:RememberEnemyAt(att:GetPos(), att)
		end
	end

	self:TryFlinch()

	if self.CustomOnTakeDamage_AfterDamage then
		self:CustomOnTakeDamage_AfterDamage(dmginfo, self:GetBSLastHitGroup())
	end
end

function ENT:TryFlinch()
	if not self.CanFlinch then return end
	if not self.AnimTbl_Flinch then return end
	if CurTime() < (self.NextFlinchT or 0) then return end
	if math.random(1, 100) > (self.FlinchChance or 0) then return end

	self.NextFlinchT = CurTime() + (self.FlinchCooldown or 0)

	local dur = self:PlayAnim(self.AnimTbl_Flinch, true)
	if dur > 0 then self:SetState(BS_STATE_ANIM, dur) end
end

--------------------------------------------------------------------------------
-- Смерть
--------------------------------------------------------------------------------

function ENT:OnKilled(dmginfo)
	if self.BSDying then return end
	self.BSDying = true

	local hitgroup = self:GetBSLastHitGroup()

	self:ClearGoal()
	self:SetState(BS_STATE_ANIM_HOLD)
	self.loco:SetVelocity(vector_origin)

	MuR.EmitSound(self, self.SoundTbl_Death, 80, math.random(95, 105))

	hook.Run("OnNPCKilled", self, dmginfo:GetAttacker(), dmginfo:GetInflictor())

	local att = dmginfo:GetAttacker()
	if IsValid(att) and att ~= self and att.OnEnemyKilled then
		att:OnEnemyKilled(dmginfo, hitgroup)
	end

	local dur = 0

	if self.HasDeathAnimation and self.AnimTbl_Death then
		dur = self:PlayAnim(self.AnimTbl_Death, true)
	end

	local status = dur > 0 and "DeathAnim" or "Ragdoll"
	if self.OnDeath then self:OnDeath(dmginfo, hitgroup, status) end

	-- CTakeDamageInfo живёт только на время самого события урона: движок его
	-- переиспользует, и в таймере он приходит как NULL ("Tried to use a NULL
	-- CTakeDamageInfo!"). Именно на этом падала сборка трупа после анимации
	-- смерти. Поэтому снимаем нужные значения здесь и дальше носим таблицу.
	local death = {
		force = dmginfo:GetDamageForce(),
		pos = dmginfo:GetDamagePosition(),
		attacker = dmginfo:GetAttacker(),
		inflictor = dmginfo:GetInflictor(),
		dmgtype = dmginfo:GetDamageType(),
	}

	local delay = dur + (self.DeathRemoveDelay or 0)

	if delay <= 0 then
		self:FinishDeath(death)
		return
	end

	timer.Simple(delay, function()
		if IsValid(self) then self:FinishDeath(death) end
	end)
end

-- death — плоская таблица из OnKilled, а не CTakeDamageInfo.
function ENT:FinishDeath(death)
	if self.HasDeathCorpse then
		self:CreateCorpse(death)
	end

	self:Remove()
end

--
-- Труп собирается вручную.
--
-- Entity:BecomeRagdoll на nextbot НЕ РАБОТАЕТ: он не создаёт prop_ragdoll
-- (проверено — счётчик рэгдоллов не менялся) и роняет игру наглухо, без
-- Lua-ошибки. Симптом: вермин умирает, доигрывает анимацию смерти, вылет.
--
-- Ручная сборка заодно даёт то, чего у BecomeRagdoll нет: поза снимается с
-- костей самого NPC, поэтому труп падает из того положения, в котором его
-- застала смерть.
--
function ENT:CreateCorpse(death)
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return nil end

	rag:SetModel(self:GetModel())
	rag:SetPos(self:GetPos())
	rag:SetAngles(self:GetAngles())
	rag:SetSkin(self:GetSkin())
	rag:SetColor(self:GetColor())
	rag:SetMaterial(self:GetMaterial())

	for i = 0, self:GetNumBodyGroups() - 1 do
		rag:SetBodygroup(i, self:GetBodygroup(i))
	end

	rag:Spawn()
	rag:Activate()

	-- Труп не должен мешать ходить: DEBRIS сталкивается только с миром, но не
	-- с игроками, NPC и другими трупами.
	rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	death = death or {}

	local force = death.force or vector_origin
	local hitPos = death.pos
	-- У nextbot скорость держит loco, Entity:GetVelocity часто нулевая.
	local vel = self.loco and self.loco:GetVelocity() or self:GetVelocity()

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		-- TranslatePhysBoneToBone умеет вернуть -1; GetBonePosition с таким
		-- индексом лучше не звать.
		local bone = rag:TranslatePhysBoneToBone(i)
		if bone and bone >= 0 then
			local pos, ang = self:GetBonePosition(bone)
			if pos then
				phys:SetPos(pos)
				phys:SetAngles(ang)
			end
		end

		phys:SetVelocity(vel)
	end

	if not force:IsZero() then
		local phys = rag:GetPhysicsObjectNum(0)
		if IsValid(phys) then
			-- Позиция попадания бывает нулевой (взрыв, урон без трассы).
			-- ApplyForceOffset в мировой ноль дал бы дикий момент, поэтому
			-- принимаем её только если она реально рядом с телом.
			if hitPos and not hitPos:IsZero() and hitPos:DistToSqr(rag:GetPos()) < 160 * 160 then
				phys:ApplyForceOffset(force, hitPos)
			else
				phys:ApplyForceCenter(force)
			end
		end
	end

	-- Хук, на котором висит zippygore: он делает труп разрываемым.
	hook.Run("CreateEntityRagdoll", self, rag)

	local fade = self.CorpseFadeTime or 0

	if fade > 0 then
		-- Растворяем перед удалением, чтобы тело не исчезало рывком на глазах.
		timer.Simple(math.max(0, fade - 3), function()
			if not IsValid(rag) then return end
			-- Без TRANSALPHA сам RenderFX ничего не делает.
			rag:SetRenderMode(RENDERMODE_TRANSALPHA)
			rag:SetRenderFX(kRenderFxFadeSlow)
		end)

		SafeRemoveEntityDelayed(rag, fade)
	end

	return rag
end

--------------------------------------------------------------------------------
-- Гибы и звуки (замена VJ:CreateGibEntity / VJ:PlaySoundSystem)
--------------------------------------------------------------------------------

-- Первый аргумент был классом VJ-гиба ("obj_vj_gib") и больше не нужен: гибы
-- делает zippygore, он уже в аддоне. Модель принимается только если это путь
-- к .mdl — у VJ там встречались условные имена вида "UseHuman_Small".
function ENT:CreateGibEntity(_, model, opts)
	if not self.ZippyGoreMod3_CreateGib then return nil end

	opts = opts or {}

	local pos = opts.Pos or self:WorldSpaceCenter()
	local mdl = nil
	if isstring(model) and string.find(model, ".mdl", 1, true) and util.IsValidModel(model) then
		mdl = model
	end

	return self:ZippyGoreMod3_CreateGib(pos, false, mdl, opts.Angles, opts.Scale)
end

function ENT:PlaySoundSystem(_, snd, level, pitch)
	return MuR.EmitSound(self, snd, level or 75, pitch or math.random(95, 105))
end
