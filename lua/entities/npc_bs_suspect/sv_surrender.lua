-- Сдача: попытка, удержание, фальшивая сдача, выход из сдачи.
--
-- Механика уважения сдачи ИИ построена на фракциях: сдавшийся получает
-- BSFaction = "civilian", и полиция/ЧВК/другие подозревающие автоматически
-- сбрасывают его с прицела через UpdateEnemy → IsValidEnemy → ResetEnemy.
-- Обратный возврат фракции = возобновление боя.

--------------------------------------------------------------------------------
-- Вспомогательные
--------------------------------------------------------------------------------

-- Подавление накопленное: стрельба по нам и рядом с нами его поднимает,
-- тик в init.lua медленно гасит.
function ENT:AddSuppression(amount)
	self.SuppressionLevel = math.Clamp((self.SuppressionLevel or 0) + amount, 0, self.MaxSuppression or 100)
end

--
-- Сколько вооружённой силы рядом: живые игроки-полицейские и NPC-полиция.
-- Чем больше — тем охотнее сдача и тем дольше сдавшийся не дёргается.
--
function ENT:CountNearbyPolice(radius)
	local count = 0
	local pos = self:GetPos()
	local r2 = radius * radius

	for _, ply in player.Iterator() do
		if ply:Alive() and isfunction(ply.IsRolePolice) and ply:IsRolePolice()
			and ply:GetPos():DistToSqr(pos) < r2 then
			count = count + 1
		end
	end

	for npc in pairs(MuR.NPC.List) do
		if IsValid(npc) and npc ~= self and npc.IsPolice and npc:Health() > 0
			and npc:GetPos():DistToSqr(pos) < r2 then
			count = count + 1
		end
	end

	return count
end

-- Смотрит ли игрок прямо на нас (для фальшивой сдачи и ареста).
function ENT:IsPlayerLookingAtMe(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end

	local toMe = (self:GetPos() - ply:GetPos())
	if toMe:LengthSqr() < 1 then return true end
	toMe:Normalize()

	return ply:EyeAngles():Forward():Dot(toMe) > 0.7
end

-- Сколько живых подозреваемых рядом: сотоварищи придают смелости.
function ENT:CountNearbySuspects(radius)
	local count = 0
	local pos = self:GetPos()
	local r2 = radius * radius

	for npc in pairs(MuR.ActiveSuspects or {}) do
		if IsValid(npc) and npc ~= self and npc.IsSuspect and not npc.Surrendering
			and npc:Health() > 0 and npc:GetPos():DistToSqr(pos) < r2 then
			count = count + 1
		end
	end

	return count
end

--------------------------------------------------------------------------------
-- Попытка сдачи
--------------------------------------------------------------------------------

--
-- Розыгрыш сдачи. forced — сдача под давлением (выстрел вплотную, флешка,
-- команда голосом): добавляет самый большой бонус.
--
function ENT:TrySurrender(forced, attacker)
	if self:Health() <= 0 then return false end
	if self.Surrendering then return false end

	-- Скрытый подозреваемый под обстрелом не встаёт на колени, а раскрывается.
	if self.IsHiddenSuspect and not self.HasRevealed then
		self:RevealAsHostile(IsValid(attacker) and attacker or nil)

		return false
	end

	local chance = self.BaseSurrenderChance or 30

	if forced then chance = chance + 50 end

	local maxHP = self:GetMaxHealth()
	if maxHP > 0 then
		local hpFrac = self:Health() / maxHP

		if hpFrac < 0.3 then
			chance = chance + 30
		elseif hpFrac < 0.5 then
			chance = chance + 15
		end
	end

	if self:CountNearbySuspects(600) == 0 then chance = chance + 25 end

	local police = self:CountNearbyPolice(300)

	if police >= 2 then
		chance = chance + 25
	elseif police == 1 then
		chance = chance + 10
	end

	if (self.SuppressionLevel or 0) > 50 then chance = chance + 15 end

	chance = math.min(chance, 95)

	if math.random(100) > chance then return false end

	self:StartSurrender(attacker)

	return true
end

-- Полная сдача без розыгрыша: флешка и голосовая команда для гражданских.
function ENT:FullSurrender()
	if self:Health() <= 0 or self.Surrendering then return end

	self.PermanentSurrender = true
	self:StartSurrender(nil)
end

--------------------------------------------------------------------------------
-- Удержание сдачи
--------------------------------------------------------------------------------

--
-- Секвенция «руки за голову». Имя важно:
--   - mode14.TagRagdoll метит труп сдавшегося по имени секвенции;
--   - арест наручниками читает GetSequenceName.
-- Если у модели её нет, PlayAnim вернёт 0 и сдавшийся просто стоит.
--
function ENT:PlaySurrenderAnim()
	local seq = "sequence_ron_comply_start_0" .. math.random(1, 4)
	if self:LookupSequence(seq) < 0 then seq = "idle_all_scared" end

	self:PlayAnim(seq, true)
end

function ENT:StartSurrender(attacker)
	if self.Surrendering then return end

	self.Surrendering = true
	self.FakeSurrendering = nil

	-- Сдавшийся не цель: фракция мирного снимает его с прицела у всех ИИ.
	self.BSFaction = "civilian"
	self:SetNW2Float("ArrestState", 1)

	-- Помним, куда стреляли, — если сдача сорвётся, пойдём проверять место.
	if IsValid(attacker) then self:RememberEnemyAt(attacker:GetPos(), attacker) end

	-- Оружие на землю; класс помним, чтобы вернуть при срыве. GetClass() дал бы
	-- "bs_npc_weapon" — класс сущности-модели; настоящий класс ствола лежит в данных.
	local wep = self:GetActiveWeapon()

	if IsValid(wep) then
		local data = wep:GetData()
		self.LastWeaponClass = data and (data.class or data.importedFrom)
		self:DropWeapon()
	end

	-- Заморозка без длительности держится до явного SetState(NONE).
	self:SetState(BS_STATE_FREEZE)
	self:FaceTowards(IsValid(attacker) and attacker:GetPos() or self:GetPos() + self:GetForward())
	self:PlaySurrenderAnim()

	self.UnsurrenderTime = CurTime() + math.Rand(8, 20)
	self.NextSurrenderReview = CurTime() + 0.5

	MuR.EmitSound(self, MuR.Pick(self.SoundTbl_Surrender), 75, 100)

	-- Часть сдавшихся только ждёт момента (ShouldFakeSurrender ниже).
	if self:ShouldFakeSurrender() then
		self.FakeSurrendering = true
		self.FakeAttackAt = CurTime() + math.Rand(2, 6)
	end
end

--
-- Будет ли сдача фальшивой.
--
-- Трус почти никогда не рискует, агрессивный — часто. Союзники рядом и
-- далёкая цель добавляют смелости; полицейский вплотную — отнимают.
--
function ENT:ShouldFakeSurrender()
	-- Гражданский и перманентно сдавшийся (флешка, кризис страха) не атакуют.
	if self.IsCivilian and not self.IsHiddenSuspect then return false end
	if self.PermanentSurrender then return false end

	local chance = (self.FakeSurrenderChance or 15) + 15

	if self:CountNearbySuspects(600) > 0 then chance = chance + 15 end
	if self:CountNearbyPolice(200) >= 2 then chance = math.max(5, chance - 10) end

	return math.random(100) <= chance
end

--
-- Тик сдавшегося. Зовётся из CustomOnThink.
--
function ENT:SurrenderThink()
	if not self.Surrendering then return end

	--
	-- Держим анимацию и состояние. RunBehaviour каждый тик пытается поставить
	-- ACT_IDLE стоящему NPC, и только AnimLockUntil этому мешает; флешка или
	-- флинтч могли подменить состояние — возвращаем заморозку.
	--
	self.AnimLockUntil = CurTime() + 0.3

	if self:GetState() ~= BS_STATE_FREEZE then self:SetState(BS_STATE_FREEZE) end

	if CurTime() < (self.NextSurrenderReview or 0) then return end
	self.NextSurrenderReview = CurTime() + 0.5

	-- Стоим на коленях, пока нас видят.
	if self.PermanentSurrender or self:CountNearbyPolice(300) > 0 then
		self.UnsurrenderTime = CurTime() + math.Rand(5, 12)
	end

	if CurTime() > (self.UnsurrenderTime or 0) then self:EndSurrender() end
end

--------------------------------------------------------------------------------
-- Фальшивая сдача
--------------------------------------------------------------------------------

--
-- Тик фальшивой сдачи: выбираем момент напасть, когда за нами не следят.
--
function ENT:FakeSurrenderThink()
	if not self.FakeSurrendering then return end
	if CurTime() < (self.FakeAttackAt or 0) then return end

	local enemy = self:GetEnemy()
	local chance = 0

	if IsValid(enemy) then
		local dist = self:GetPos():Distance(enemy:GetPos())
		local watched = enemy:IsPlayer() and self:IsPlayerLookingAtMe(enemy) or false

		if dist < 100 and not watched then
			chance = 80
		elseif dist < 150 and not watched then
			chance = 50
		elseif dist > 400 then
			chance = 30
		elseif not watched then
			chance = 20
		end
	else
		-- Вокруг вообще никого — самое время.
		chance = 30
	end

	if self:CountNearbySuspects(600) > 0 then chance = chance + 15 end

	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then chance = chance + 30 end

	if math.random(100) <= chance then
		self:ExecuteFakeSurrender()
	else
		self.FakeAttackAt = CurTime() + math.Rand(0.8, 1.5)
	end
end

--
-- Вскочить и атаковать.
--
function ENT:ExecuteFakeSurrender()
	-- Скрытый гражданский становится подозреваемым прямо с колен.
	if self.IsHiddenSuspect and not self.HasRevealed then
		self:RevealAsHostile(self:GetEnemy())
	end

	self:StopSurrendering()

	-- Быстрый подъём: удвоенная скорость, старт с середины анимации.
	self:PlayAnim("zombie_slump_rise_02_fast", true, 0.5, true, 0, {PlayBackRate = 2})
	self:SetCycle(0.2)

	-- Скрытый ствол RevealAsHostile уже выдал; остальным возвращаем сброшенный.
	if not IsValid(self:GetActiveWeapon()) then
		local class = self.HiddenWeapon or self.LastWeaponClass

		if class then
			self:Give(class)
			self.LastWeaponClass = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Выход из сдачи
--------------------------------------------------------------------------------

-- Снять сдачу безусловно (внутренняя; публичный EndSurrender уважает перманент).
function ENT:StopSurrendering()
	if not self.Surrendering then return end

	self.Surrendering = nil
	self.FakeSurrendering = nil
	self.PermanentSurrender = nil

	-- Гражданский остаётся гражданским; подозреваемому возвращаем фракцию,
	-- и все ИИ снова считают его целью.
	if not self.IsCivilian then self.BSFaction = nil end

	self:SetNW2Float("ArrestState", 0)
	self:SetState(BS_STATE_NONE)
	self.AnimLockUntil = 0
end

-- Обычный выход из сдачи: таймаут, команда режима, срыв.
function ENT:EndSurrender()
	if not self.Surrendering then return end
	-- Перманентная сдача (флешка, ужас, спасение) кончается только арестом.
	if self.PermanentSurrender then return end

	self:StopSurrendering()

	local seq = "sequence_ron_comply_exit_0" .. math.random(1, 3)

	if self:LookupSequence(seq) >= 0 then self:PlayAnim(seq, true) end

	if self.LastWeaponClass then
		self:Give(self.LastWeaponClass)
		self.LastWeaponClass = nil
	end
end

-- Сдавшийся не вздрагивает от попаданий: анимацию comply ломать нельзя.
function ENT:TryFlinch()
	if self.Surrendering then return end

	return self.BaseClass.TryFlinch(self)
end
