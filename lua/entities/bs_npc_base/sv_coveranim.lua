-- Анимации боя из укрытия: подбор последовательностей из cover_system/pm_anim.mdl.
--
-- Набор устроен как восемь семейств по типу оружия (normal, pistol, revolver,
-- smg, ar2, shotgun, crossbow, melee), в каждом пятнадцать поз:
--
--   idle_wallH_<set>            прижат к высокой стене
--   idle_wallh_<l|r>_<set>      прижат у левого / правого края
--   look_wallh_<l|r>_<set>      выглянул из-за края
--   move_wallh_<l|r>_<set>      приставной шаг вдоль стены
--   idle_wallL_<set>            присел за низким укрытием
--   idle_wallL_<L|R>_<set>      присел у края
--   look_wallL_<L|R|U>_<set>    выглянул сбоку / поверх
--   move_wallL_<L|R>_<set>      шаг вдоль низкого укрытия
--
-- Три вещи, из-за которых это не подключается «просто по имени активити».
--
-- Первая: у ВСЕХ этих последовательностей активити равна -1. Через
-- StartActivity/SelectWeightedSequence они недоступны в принципе, только
-- LookupSequence по имени.
--
-- Вторая: регистр в именах внутри модели плавает. Рядом лежат idle_wallH_smg и
-- idle_wallh_l_smg, move_wallL_L_smg и move_wallL_r_smg. Собирать имя по одному
-- шаблону нельзя — половина набора не найдётся; поэтому каждый кандидат
-- пробуется ещё и в нижнем регистре.
--
-- Третья: анимаций может не быть вовсе. На момент написания модели NPC их не
-- содержат (LookupSequence отдаёт -1 на всех), и вся система укрытий обязана
-- это пережить: HasCoverAnims отвечает false, и бой идёт по-старому, через
-- приседание и шаг вбок.

--------------------------------------------------------------------------------
-- Имена последовательностей
--------------------------------------------------------------------------------

--
-- Семейство под текущее оружие.
--
-- MuR.NPC.ImportSWEP уже разложил стволы по animSet со значениями
-- pistol/smg/ar2/shotgun/melee — они совпадают с именами семейств модели один в
-- один, так что переводить нечего. Безоружный работает по набору normal.
--
function ENT:CoverAnimSet()
	-- GetActiveWeapon живёт в bs_npc_human: у nextbot нативного метода нет, а
	-- твари оружия не носят вовсе.
	if not self.GetActiveWeapon then return "normal" end

	local wep = self:GetActiveWeapon()
	if not IsValid(wep) then return "normal" end

	local data = wep.GetData and wep:GetData()
	if not data or not data.animSet then return "normal" end

	return data.animSet
end

-- Первая существующая последовательность из списка кандидатов. Возвращает имя,
-- а не номер: PlayAnim и SetCoverPose принимают имя.
-- Перебор через select, а не ipairs: кандидат бывает nil (позы без стороны),
-- а ipairs на первом же nil обрывается и молча теряет весь остаток списка.
function ENT:PickSequence(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)

		if isstring(name) then
			if self:LookupSequence(name) >= 0 then return name end

			local lower = string.lower(name)
			if lower ~= name and self:LookupSequence(lower) >= 0 then return lower end
		end
	end

	return nil
end

--
-- Имя позы укрытия. nil — такой у модели нет.
--
--   action — "idle" | "look" | "move"
--   kind   — "full" (высокая стена) | "low" (низкое укрытие)
--   side   — "l" | "r" | "u"; nil означает «по центру»
--
-- Результат кэшируется: разбор имён это чистая функция от модели и оружия, а
-- зовётся она в боевом цикле. Кэш сбрасывается при смене оружия.
--
function ENT:CoverSeqName(action, kind, side)
	local set = self:CoverAnimSet()
	local key = action .. "|" .. tostring(kind) .. "|" .. tostring(side) .. "|" .. set

	local cache = self.CoverSeqCache
	if not cache or self.CoverSeqCacheSet ~= set then
		cache = {}
		self.CoverSeqCache = cache
		self.CoverSeqCacheSet = set
	end

	local hit = cache[key]
	if hit ~= nil then return hit or nil end

	local wall = kind == "low" and "L" or "H"
	local found

	if side then
		--
		-- Сторона есть только у части поз. Запасной вариант — та же поза без
		-- стороны: стоять прижатым по центру всё равно лучше, чем свалиться в
		-- бинд-позу, а её ставит любая попытка проиграть несуществующую анимацию.
		--
		found = self:PickSequence(
			string.format("%s_wall%s_%s_%s", action, wall, side, set),
			string.format("%s_wall%s_%s_%s", action, wall, string.upper(side), set),
			string.format("%s_wall%s_%s", action, wall, set)
		)
	else
		found = self:PickSequence(string.format("%s_wall%s_%s", action, wall, set))
	end

	-- Набор под оружие может быть неполным, а normal есть всегда.
	if not found and set ~= "normal" then
		found = self:PickSequence(
			side and string.format("%s_wall%s_%s_normal", action, wall, side) or nil,
			string.format("%s_wall%s_normal", action, wall)
		)
	end

	cache[key] = found or false

	return found
end

--
-- Есть ли у этой модели анимации укрытий вообще.
--
-- Проверяется самая базовая поза набора: если нет её, нет и остальных.
-- Результат держится на сущности до смены оружия — LookupSequence по имени
-- стоит недёшево, а спрашивают это каждый боевой такт.
--
function ENT:HasCoverAnims()
	if not self.CanUseCover then return false end

	return self:CoverSeqName("idle", "full") ~= nil
end

--------------------------------------------------------------------------------
-- Щупы укрытия
--------------------------------------------------------------------------------

--
-- Трассы к преграде, у которой стоим. Боец развёрнут СПИНОЙ к укрытию, поэтому
-- все щупы идут назад, против его взгляда.
--
-- Перенесено из системы укрытий для игрока, которая на этих же анимациях
-- отработана: там высота и сторона берутся именно так, а не из поиска точки для
-- выстрела. Разница принципиальная — щуп отвечает про то место, где боец УЖЕ
-- стоит, и потому не расходится с тем, что видно на экране.
--
--   "low"        есть ли преграда вообще
--   "high"       достаёт ли она до груди (иначе укрытие низкое)
--   "left"/"right"  где кончается край, из-за которого выглядывать
--
--
--   normal — нормаль укрытия (от стены к бойцу). Если передана, направления
--            считаются от НЕЁ, а не от текущего взгляда.
--
-- Это обязательно: FaceTowards у nextbot доворачивает корпус ПЛАВНО, за
-- несколько тиков. Щуп, пущенный сразу после разворота, смотрел бы совсем не
-- туда — и укрытие за спиной «пропадало» ровно в тот момент, когда его
-- проверяют.
--
function ENT:CoverProbe(kind, normal)
	local pos = self:GetPos()

	local back, right

	if isvector(normal) then
		back = -normal
		right = normal:Cross(vector_up)
		right.z = 0
		if right:LengthSqr() > 0.01 then right:Normalize() else right = self:GetRight() end
	else
		back = -self:GetForward()
		right = self:GetRight()
	end

	local from, dist

	if kind == "high" then
		from, dist = pos + Vector(0, 0, 64), 40
	elseif kind == "left" then
		from, dist = pos + right * 16 + Vector(0, 0, 56), 32
	elseif kind == "right" then
		from, dist = pos - right * 16 + Vector(0, 0, 56), 32
	elseif kind == "lowleft" then
		from, dist = pos + right * 16 + Vector(0, 0, 16), 32
	elseif kind == "lowright" then
		from, dist = pos - right * 16 + Vector(0, 0, 16), 32
	else
		from, dist = pos + Vector(0, 0, 32), 64
	end

	return util.TraceLine({
		start = from,
		endpos = from + back * dist,
		mask = MASK_SHOT_HULL,
		filter = self,
	})
end

--
-- Высокое ли укрытие за спиной. Решает щуп по груди, а не оценка простреливаемости:
-- анимацию выбирают по тому, что реально стоит за бойцом.
--
function ENT:ProbeCoverHigh(normal)
	return self:CoverProbe("high", normal).Hit
end

--
-- С какой стороны край укрытия. "" — края нет, укрытие шире бойца.
--
-- Сторона там, где щуп НЕ упёрся: значит стена там кончилась, и именно оттуда
-- можно высунуться. Ровно это и рисуют анимации look_wall*_l / _r.
--
function ENT:ProbeCoverSide(high, normal)
	if high == nil then high = self:ProbeCoverHigh(normal) end

	local l = self:CoverProbe(high and "left" or "lowleft", normal)
	local r = self:CoverProbe(high and "right" or "lowright", normal)

	if not r.Hit and l.Hit then return "l" end
	if r.Hit and not l.Hit then return "r" end

	return ""
end

--------------------------------------------------------------------------------
-- Удержание позы
--------------------------------------------------------------------------------

--
-- Встать в позу укрытия и держать её.
--
-- Отдельный слой, а не PlayAnim: PlayAnim рассчитан на разовую анимацию с
-- длительностью, а позы укрытия зациклены и длятся 0.03 секунды. Держать их
-- нужно до явного снятия, и при этом не дать PlayActivity их перебить — а он
-- зовётся каждый тик из цикла перехода.
--
function ENT:SetCoverPose(name)
	if not isstring(name) then return false end

	local seq = self:LookupSequence(name)
	if seq < 0 then return false end

	if self.CoverPose == name then return true end

	self.CoverPose = name
	self:SetSequence(seq)
	self:ResetSequenceInfo()
	self:SetCycle(0)
	self:SetPlaybackRate(1)

	return true
end

function ENT:ClearCoverPose()
	if not self.CoverPose then return end

	self.CoverPose = nil

	-- Последовательность меняли в обход активити, поэтому запись о текущей
	-- активити врёт. Без сброса следующий PlayActivity решит, что нужная поза
	-- уже стоит, и NPC доиграет бой в позе прижатого к стене.
	self.BSActivity = nil
end

function ENT:IsHoldingCoverPose()
	return self.CoverPose ~= nil
end

--
-- Развернуть бойца так, как этого ждёт анимация укрытия: СПИНОЙ к стене.
--
-- Замерено прямо на pm_anim.mdl: в позах idle_wall* и look_wall* кости Spine2 и
-- Head1 смотрят вдоль yaw самой сущности (отклонение 0 и 1 градус). То есть
-- анимация рисует бойца, который прижался к укрытию и смотрит ОТ него наружу —
-- стена у него за спиной, а не перед лицом.
--
-- Знак здесь стоял обратный, и получалось ровно то, что видно в игре: боец
-- утыкается лицом в укрытие, а голова вывернута на противника.
--
-- HitNormal указывает ОТ поверхности в нашу сторону, значит смотреть надо ПО
-- нормали.
--
function ENT:FaceCoverWall(normal)
	if not isvector(normal) then return end

	self:FaceTowards(self:GetPos() + normal * 64)
end
