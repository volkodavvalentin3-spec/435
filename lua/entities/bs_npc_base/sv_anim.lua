-- Анимации: замена VJ:PlayAnim, трансляции активити, события анимаций.

-- Описания NPC переехали от VJ вместе с именами вида "vjseq_slumprise_a" и
-- "vjges_flinch_phys_01". Префикс у VJ означал "играть как последовательность"
-- или "как жест"; у нас это решает сам PlayAnim, поэтому префикс просто снимаем.
local function StripPrefix(name)
	if not isstring(name) then return name end

	local stripped = string.match(name, "^vjseq_(.+)$") or string.match(name, "^vjges_(.+)$")

	return stripped or name
end

-- Трансляция активити. AnimationTranslations задают сами NPC, формат от VJ:
-- self.AnimationTranslations[ACT_CLIMB_UP] = ACT_JUMP
function ENT:TranslateActivity(act)
	local t = self.AnimationTranslations
	if t and t[act] then return t[act] end

	return act
end

--
-- Есть ли у модели анимация под эту активити.
--
-- Сравнение именно с нулём, а не «больше нуля»: SelectWeightedSequence отдаёт
-- -1, когда активити нет, а НОЛЬ — это валидная последовательность. У зомби
-- ACT_IDLE лежит ровно под нулём, и проверка «> 0» объявила бы её отсутствующей.
--
function ENT:HasActivity(act)
	if not act then return false end

	local seq = self:SelectWeightedSequence(act)

	return seq ~= nil and seq >= 0
end

--
-- Чем заменить активити, которой у модели нет. nil — заменить нечем.
--
-- Замерено на четырёх моделях сразу: ACT_CLIMB_UP и ACT_CLIMB_DOWN нет НИ У
-- КОГО — ни у гражданских, ни у комбайна, ни у зомби, ни у ЧВК. У зомби вдобавок
-- нет ни ACT_RUN, ни ACT_JUMP.
--
-- Цена ошибки тут не «анимация не та», а бинд-поза. Замерено на модели ЧВК:
-- StartActivity с активити, которой у модели нет, ставит последовательность
-- НОЛЬ, а нулевая у этих моделей называется "ragdoll" — это и есть буква Т.
-- Поэтому дойти до StartActivity имеет право только заведомо существующая
-- активити, а если такой не нашлось, позу лучше не трогать вовсе.
--
-- Каждый шаг цепочки прогоняется через трансляцию: у моделей на игроцком
-- скелете обычных ACT_* нет ни одной, и запасной вариант вроде ACT_IDLE без
-- перевода в ACT_HL2MP_IDLE_* так же не существует, как и исходный.
--
-- Результат кэшируется на сущности: цепочка разворачивается один раз на
-- активити, дальше это чтение таблицы.
--
function ENT:ResolveActivity(act)
	local cache = self.ActivityCache

	if not cache then
		cache = {}
		self.ActivityCache = cache
	end

	local hit = cache[act]
	if hit ~= nil then return hit or nil end

	local found = nil
	local cur, guard = act, 0

	while cur and guard < 8 do
		if self:HasActivity(cur) then
			found = cur

			break
		end

		local next = self.ActivityFallbacks[cur]
		cur = next and self:TranslateActivity(next) or nil
		guard = guard + 1
	end

	-- Последний рубеж — обычная стойка. Она есть почти у всего, что ходит.
	if not found then
		local idle = self:TranslateActivity(ACT_IDLE)
		if self:HasActivity(idle) then found = idle end
	end

	cache[act] = found or false

	return found
end

-- Активити для передвижения. Не перебивает залоченную анимацию.
--
-- Сверяемся со СВОИМ полем, а не с GetActivity(). PlayAnim ставит
-- последовательность напрямую через SetSequence и активити не трогает, поэтому
-- после удара GetActivity() всё ещё возвращает ACT_RUN — и проверка "уже бежим"
-- отсекала возврат к анимации бега. NPC оставался стоять в позе удара.
function ENT:PlayActivity(act)
	if not act then return end
	if CurTime() < (self.AnimLockUntil or 0) then return end

	--
	-- Поза укрытия держится до явного снятия. Без этой строки её сбивал бы
	-- каждый тик цикла перехода: FollowPath ставит активити передвижения на
	-- каждой итерации, и прижатый к стене боец мгновенно возвращался в стойку.
	--
	if self.CoverPose then return end

	act = self:TranslateActivity(act)

	--
	-- Ни одной подходящей анимации у модели нет — позу НЕ трогаем. Голый
	-- StartActivity в этом случае ставит последовательность 0, у большинства
	-- моделей это "ragdoll", то есть бинд-поза (замерено). Оставить как было
	-- всегда лучше, чем свалить модель в букву Т.
	--
	local resolved = self:ResolveActivity(act)
	if not resolved then return end

	--
	-- Подменённая активити обязана попасть в набор движения вместе с исходной.
	-- У зомби нет ACT_RUN, бег играется через ACT_WALK — и без этой строки
	-- BodyUpdate считал бы такую анимацию неподвижной, а зомби ездил бы по
	-- земле, не перебирая ногами. Набор скопирован на сущность в Initialize,
	-- так что пишем не в общую таблицу класса.
	--
	if resolved ~= act and self.MoveActivities[act] then
		self.MoveActivities[resolved] = true
	end

	if self.BSActivity == resolved then return end

	self.BSActivity = resolved
	self:StartActivity(resolved)
end

-- Совместимость с описаниями NPC: SetMovementActivity(ACT_WALK/ACT_RUN).
function ENT:SetMovementActivity(act)
	self.MovementActivity = act
	self:PlayActivity(act)
end

--
-- PlayAnim(anim, lockAnim, playTime, faceEnemy, delay, opts)
--
--   anim     — имя последовательности, таблица имён или ACT_*
--   lockAnim — запретить перебивать анимацию передвижением
--   playTime — false/nil: длительность самой последовательности, число: столько секунд
--   faceEnemy— доворачивать корпус к врагу на время анимации
--   delay    — отложить запуск
--   opts     — {PlayBackRate = n}
--
-- Возвращает длительность.
--
function ENT:PlayAnim(anim, lockAnim, playTime, faceEnemy, delay, opts)
	if delay and delay > 0 then
		timer.Simple(delay, function()
			if IsValid(self) then self:PlayAnim(anim, lockAnim, playTime, faceEnemy, 0, opts) end
		end)

		return 0
	end

	anim = MuR.Pick(anim)
	if anim == nil or anim == "" then return 0 end

	-- Разовая анимация (удар, флинч, смерть) перебивает укрытие: держать позу
	-- дальше некому, а её флаг заблокировал бы возврат к ходьбе.
	self:ClearCoverPose()

	opts = opts or {}
	local rate = opts.PlayBackRate or 1

	-- ACT_*: отдаём активити, длительность считать неоткуда.
	if isnumber(anim) then
		self.BSActivity = nil
		self:PlayActivity(anim)
		local dur = isnumber(playTime) and playTime or 0
		if lockAnim and dur > 0 then self.AnimLockUntil = CurTime() + dur end
		if faceEnemy then self.FaceEnemyUntil = CurTime() + dur end

		return dur
	end

	local seq = self:LookupSequence(StripPrefix(anim))
	if not seq or seq < 0 then return 0 end

	local dur = isnumber(playTime) and playTime or (self:SequenceDuration(seq) / rate)

	self:SetSequence(seq)
	self:ResetSequenceInfo()
	self:SetCycle(0)
	self:SetPlaybackRate(rate)

	-- Последовательность подменена в обход активити: сбрасываем запись, чтобы
	-- следующий PlayActivity гарантированно переставил анимацию передвижения.
	self.BSActivity = nil

	if lockAnim then self.AnimLockUntil = CurTime() + dur end
	if faceEnemy then self.FaceEnemyUntil = CurTime() + dur end

	return dur
end

-- Проиграть анимацию и подождать её конца. Только из корутины поведения.
function ENT:PlayAnimAndWait(anim, rate)
	local dur = self:PlayAnim(anim, true, nil, false, 0, {PlayBackRate = rate or 1})
	if dur <= 0 then return end

	coroutine.wait(dur)
end

function ENT:BodyUpdate()
	-- Пока анимация залочена (атака, флинч, сдача, смерть) — только
	-- прокручиваем кадры, иначе BodyMoveXY подменит последовательность
	-- активити передвижения.
	if CurTime() < (self.AnimLockUntil or 0) then
		self:FrameAdvance()
		self:UpdateAimPose()

		return
	end

	--
	-- Поза укрытия проигрывается как есть. BodyMoveXY тут звать нельзя: он
	-- подменяет последовательность по активити передвижения, а у поз укрытия
	-- активити нет вовсе (-1 у всех). Шаг вдоль стены тоже идёт отсюда —
	-- корпус в нём ведёт loco, а ноги отыгрывает сама анимация.
	--
	if self.CoverPose then
		self:FrameAdvance()
		self:UpdateAimPose()

		return
	end

	-- Набором, а не сравнением с ACT_RUN/ACT_WALK: у моделей с игроцкими
	-- анимациями этих активити нет вовсе, и ходьба лежит в ACT_HL2MP_*.
	-- Без этого такой NPC ездит по земле, не перебирая ногами.
	if self.MoveActivities[self:GetActivity()] then
		self:BodyMoveXY()
		self:UpdateAimPose()

		return
	end

	self:FrameAdvance()
	self:UpdateAimPose()
end

-- Прицеливание поз-параметрами. База не целится ничем; стрелкам это ставит
-- bs_npc_human.
function ENT:UpdateAimPose()
end

--
-- Жест поверх текущей анимации: верх тела играет своё, ноги продолжают идти.
--
-- Нужен моделям с игроцкими анимациями: стрельба и перезарядка у них лежат в
-- ACT_HL2MP_GESTURE_*, а это именно жесты — сыгранные как основная
-- последовательность, они обнуляют позу ног, и боец стреляет стоя по стойке
-- смирно посреди перебежки.
--
function ENT:PlayGesture(act)
	if not act then return 0 end

	act = self:TranslateActivity(act)

	-- Ноль — валидный номер последовательности, «нет такой» это -1.
	local seq = self:SelectWeightedSequence(act)
	if not seq or seq < 0 then return 0 end

	self:AddGestureSequence(seq, true)

	return self:SequenceDuration(seq)
end

-- Серверные события анимаций. VJ отдавал их в OnAnimEvent, NPC на них
-- вешают удары, шаги и выстрелы.
function ENT:HandleAnimEvent(event, eventTime, cycle, evType, options)
	if self.OnAnimEvent then
		self:OnAnimEvent(event, eventTime, cycle, evType, options)
	end
end

function ENT:FootStepSound()
	if not self.HasFootstepSounds then return end
	if not self.SoundTbl_FootStep then return end
	if CurTime() < self.NextFootStep then return end

	self.NextFootStep = CurTime() + self.FootStepInterval
	MuR.EmitSound(self, self.SoundTbl_FootStep, 70, math.random(90, 110))
end
