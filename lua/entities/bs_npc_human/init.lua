AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

include("sv_weapon.lua")

--------------------------------------------------------------------------------
-- Спавн
--------------------------------------------------------------------------------

-- Спавнер песочницы кладёт выбранное оружие в keyvalue: движковый NPC читает
-- его сам, nextbot — нет.
function ENT:KeyValue(key, value)
	if string.lower(key) == "additionalequipment" then
		self.PendingWeapon = value
	end
end

--
-- Оружие выдаём кадром позже собственными силами. Спавнер песочницы для
-- nextbot Give не зовёт вообще, поэтому из Q-меню NPC выходил с пустыми руками.
--
-- Хук от базы, а НЕ переопределение Initialize: при трёх уровнях наследования
-- self.BaseClass.Initialize указывает на эту же функцию и уходит в рекурсию.
--
function ENT:PostInitialize()
	timer.Simple(0, function()
		if not IsValid(self) then return end
		if IsValid(self:GetActiveWeapon()) then return end

		local class = self.PendingWeapon or MuR.Pick(self.DefaultWeapons)
		if class then self:Give(class) end
	end)
end

--------------------------------------------------------------------------------
-- Анимации под оружие
--------------------------------------------------------------------------------

--
-- Позы берём из набора текущего оружия. Боевой idle ставим только когда есть
-- враг: иначе патрульный полицейский ходил бы с вечно вскинутым пистолетом.
--
function ENT:TranslateActivity(act)
	local anims = self:GetWeaponAnims()

	if anims then
		if act == ACT_WALK and anims.walk then return anims.walk end
		if act == ACT_RUN and anims.run then return anims.run end
		if act == ACT_IDLE and anims.idle and IsValid(self:GetEnemy()) then return anims.idle end
	end

	local t = self.AnimationTranslations
	if t and t[act] then return t[act] end

	return act
end

--------------------------------------------------------------------------------
-- Поведение
--------------------------------------------------------------------------------

function ENT:RunIdle()
	local enemy = self:GetEnemy()

	if IsValid(enemy) then
		self:CombatBehaviour(enemy)

		return
	end

	-- Гранату кидают и до того, как завяжется бой: под окно закатывают заранее.
	if self.AvoidsGrenades then
		local danger = self:FindNearbyDanger()

		if danger and self:FleeDanger(danger) then return end
	end

	-- Врага не видно, но есть свежая наводка — проверить её, а не уходить
	-- патрулировать как ни в чём не бывало.
	if self:SearchBehaviour() then return end

	-- Своё мирное поведение вместо патруля. Этим наёмник-засадник занимает
	-- точку с обзором и ждёт, вместо того чтобы бродить по кругу.
	if self.CustomPeaceBehaviour and self:CustomPeaceBehaviour() then return end

	self:PeaceBehaviour()
end

--
-- Врага не стало: всё, что относилось к нему, обнуляется здесь.
--
-- Особенно габарит: уйти из боя пригнувшимся означает застрять под первым же
-- проёмом, в который NPC потом не пролезет в полный рост.
--
function ENT:OnResetEnemy()
	self:ClearCover()
	self:ClearCoverPose()
	self:SetCrouching(false)

	self.LastLOSPos = nil
	self.LastLOSTime = nil
	self.NextReposition = nil
	self.NextBound = nil
	self.NextSuppress = nil
	self.NextBackAway = nil
	self.BlindPressCount = nil
	self.LastPressDist = nil
end

--
-- Бой с огнестрелом.
--
-- Порядок веток — это порядок приоритетов, и он важен: пустой ствол решается
-- раньше позиции, позиция раньше стрельбы, и только потом сама стрельба.
--
function ENT:CombatBehaviour(enemy)
	--
	-- Граната под ногами решается раньше всего остального: любая другая ветка
	-- займёт такт корутины, а это примерно секунда — ровно столько, сколько
	-- граната и лежит. Раньше боец её просто не замечал и умирал на месте.
	--
	if self.AvoidsGrenades then
		local danger = self:FindNearbyDanger()

		if danger and self:FleeDanger(danger) then return end
	end

	-- Своя ветка боя вместо обычной. Полиция так уводит цель в арест, не
	-- перекрывая CombatBehaviour целиком: перестрелка ей всё ещё нужна для тех,
	-- кого брать живым не приказано.
	if self.CustomCombatBehaviour and self:CustomCombatBehaviour(enemy) then return end

	if not self:HasRangedWeapon() then
		self:MeleeBehaviour(enemy)

		return
	end

	-- Перезарядка идёт первой и только из укрытия: пустой ствол посреди
	-- простреливаемого пространства — это смерть, а раньше именно так и было.
	--
	-- Магазин добивается заранее, не дожидаясь щелчка: если мы уже сидим за
	-- углом и патронов осталось меньше трети, перезарядиться сейчас дешевле,
	-- чем через десять секунд посреди перебежки.
	if self:NeedsReload() or (self:IsLowOnAmmo() and self:IsInCover(enemy)) then
		self:ReloadBehaviour(enemy)

		return
	end

	-- Цель за укрытием или ушла за угол.
	if not self:HasLOS(enemy) then
		--
		-- Уже стоим за углом — значит из него и работаем: выглянуть, ударить
		-- вслепую, сместиться вдоль стены. Бросать занятую позицию и бежать
		-- вперёд только потому, что цель скрылась, — худшее из решений.
		--
		-- Замерено: без этой ветки бой уходил в сближение почти целиком (20
		-- вызовов PressAttack против 12 FireFight на ближней дистанции и 17
		-- против 4 на дальней), а вся система укрытий живёт внутри FireFight,
		-- куда попадают только при наличии видимости. Она просто не включалась.
		--
		if self:CoverFight(enemy) then return end

		-- Сначала прижать огнём место, где она скрылась, и только потом лезть
		-- следом. Раньше единственной реакцией на пропавшую видимость было
		-- сближение, и группа поочерёдно выбегала под ствол.
		if self:SuppressBehaviour(enemy) then return end

		self:PressAttack(enemy)

		return
	end

	--
	-- Место, откуда цель видно СВОИМИ глазами.
	--
	-- Отдельно от LastEnemyPos: у наёмников включено сквозное чутьё, и штатная
	-- наводка у них всегда равна текущей позиции врага — подавлять по ней
	-- означало бы стрелять сквозь стены.
	--
	self.LastLOSPos = enemy:GetPos()
	self.LastLOSTime = CurTime()

	local dist = self:GetPos():Distance(enemy:GetPos())

	-- Вплотную стрелять неудобно — бьём прикладом.
	if dist < self.Weapon_MeleeDistance and self:CanMeleeAttack() then
		coroutine.wait(self:StartMeleeAttack())

		return
	end

	if dist > self:GetFiringRange() then
		self:PressAttack(enemy)

		return
	end

	self:FireFight(enemy, dist)
end

--------------------------------------------------------------------------------
-- Перестрелка
--------------------------------------------------------------------------------

--
-- Стоим на дистанции огня и видим цель.
--
function ENT:FireFight(enemy, dist)
	-- Обходящему в перестрелку вставать не положено — он за тем и обходит.
	if self:GetCombatRole() == "flank" and self:FlankBehaviour(enemy) then return end

	--
	-- Вплотную: сначала очередь, и только потом разрыв дистанции. Раньше боец
	-- пятился молча, и вблизи от него не было огня вовсе.
	--
	-- Порог отхода НИЖЕ дистанции сближения, и это главное. Раньше оба стояли
	-- на Weapon_RetreatDistance: PressAttack подводил ровно на неё, FireFight с
	-- неё же начинал пятиться, отход возвращал дистанцию за порог, и всё
	-- начиналось заново. Боец дёргался вперёд-назад вместо боя. Между двумя
	-- порогами он теперь просто стоит и стреляет.
	--
	if dist < self.Weapon_RetreatDistance * self.RetreatHysteresis then
		self:TryShoot(enemy)

		-- Очередь идёт через coroutine.wait, и цель за это время вполне может
		-- кончиться — вплотную это обычное дело. Отходить тогда не от кого.
		if not IsValid(enemy) or self:GetEnemy() ~= enemy then return end

		if not self.Weapon_HoldsGround then self:BackAwayFrom(enemy) end

		return
	end

	--
	-- Позиция для выстрела рядом (needPeek) нужна только старой механике, где
	-- боец ВЫХОДИЛ из-за угла шагом вбок. С анимациями look_wall* он выглядывает
	-- не сходя с места, и требовать сверх этого ещё и свободный шаг — значит не
	-- найти ничего: у стены, к которой надо прижаться, шагать обычно некуда.
	--
	-- Замерено: с needPeek поиск не находил укрытие вовсе, без него находит за
	-- 1.9 мс вместо 6.5.
	--
	if self:ShouldSeekCover(enemy, dist) and self:GoToCover(enemy, not self:HasCoverAnims(), true) then return end

	-- Простоявший всю перестрелку в одной точке стрелок — это мишень, и ровно
	-- это читается как тупость.
	if self:ShouldReposition() and self:CombatReposition(enemy) then return end

	--
	-- Бой за укрытием на анимациях cover_system. Он же решает, когда выглянуть,
	-- когда бить вслепую, когда сместиться вдоль стены и когда рвануть дальше.
	--
	-- Возвращает false, если анимаций у модели нет либо мы не в укрытии — тогда
	-- работают ветки ниже, то самое поведение, что было до них.
	--
	-- Выше проверки CanFireWeapon намеренно: свои действия она проверяет сама, а
	-- боец с закрытым кулдауном обязан пересиживать его ЗА укрытием. Иначе он
	-- уходил в HoldAim и разворачивался к врагу, оставаясь в позе прижатого к
	-- стене — поза и направление расходились.
	--
	if self:CoverFight(enemy) then return end

	if not self:CanFireWeapon() then
		-- Стрелять нельзя (кулдаун, запрет от NPC) — держим на прицеле, а не
		-- убегаем и не лезем в упор.
		self:HoldAim(enemy)

		return
	end

	-- За низким укрытием сидят пригнувшись и привстают на очередь.
	if self:IsAtLowCover() then
		self:PopUpAndShoot(enemy)

		return
	end

	-- Сидим за углом, откуда цель не простреливается — надо выглянуть.
	if self:HasCover() and not self:HasLOS(enemy) then
		if self:PeekAndShoot(enemy) then return end
	end

	-- Свой на линии огня: сместиться и стрелять, а не стоять с опущенным стволом.
	if not self:HasClearShot(enemy) then
		if self:StepOutOfFireLane(enemy) then return end

		self:HoldAim(enemy)

		return
	end

	self:ShootBurst(enemy)
	self:AfterBurst(enemy)
end

-- Держать на прицеле: стрелять нельзя, но и уходить незачем. Целью может быть и
-- точка — держащий позицию смотрит туда, где врага видели.
function ENT:HoldAim(target)
	-- Держащий позу укрытия смотрит на стену, а не на цель: анимации сделаны от
	-- стены, и разворот к врагу ломает силуэт.
	if self:IsHoldingCoverPose() and isvector(self.CoverNormal) then
		self:FaceCoverWall(self.CoverNormal)
		coroutine.wait(0.15)

		return
	end

	self:FaceTowards(isvector(target) and target or (IsValid(target) and target:GetPos()))
	self:PlayActivity(ACT_IDLE)
	coroutine.wait(0.15)
end

-- Очередь, если можно и если коридор чист. Возвращает, стреляли ли.
function ENT:TryShoot(enemy)
	if not self:CanFireWeapon() then return false end
	if not self:HasClearShot(enemy) then return false end

	self:ShootBurst(enemy)

	return true
end

-- После очереди иногда сместиться. Держащегося за угол это не касается: он там
-- стоит не просто так.
function ENT:AfterBurst(enemy)
	if self:HasCover() then return end
	if math.random(1, 100) > self.StrafeChance then return end

	self:StrafeStep(enemy)
end

--------------------------------------------------------------------------------
-- Подавление
--------------------------------------------------------------------------------

--
-- Прижать огнём то место, где цель скрылась.
--
-- false — подавлять нечем или незачем; тогда вызывающий сближается, как раньше.
-- Именно чередование «очередь по углу — рывок вперёд» и делает наступление
-- похожим на наступление, а не на забег.
--
function ENT:SuppressBehaviour(enemy)
	if not self.CanSuppress then return false end
	if not self:CanFireWeapon() then return false end
	-- С последним магазином по площадям не работают.
	if self:IsLowOnAmmo() then return false end

	-- Взявшийся прикрывать бьёт вне очереди: пока свой перезаряжается, пауза
	-- подавления обессмысливает само обязательство.
	if not self:IsCoveringAlly() and CurTime() < (self.NextSuppress or 0) then return false end

	local pos = self.LastLOSPos
	if not isvector(pos) then return false end
	if CurTime() - (self.LastLOSTime or 0) > self.SuppressMemoryTime then return false end

	local range = self:GetFiringRange()
	if self:GetPos():DistToSqr(pos) > range * range then return false end

	-- В стену не стреляем: точка обязана простреливаться отсюда.
	local height = self.CoverCrouchEyeHeight
	if not self:IsSpotVisibleFrom(self:GetFirePos(), pos, height, enemy) then return false end

	local aim = pos + Vector(0, 0, height)
	if not self:HasClearShot(aim) then return false end

	self.NextSuppress = CurTime() + MuR.Roll(self.SuppressInterval, 3)
	self:SuppressBurst(aim)

	return true
end

--
-- Выстрел из-за укрытия: шаг на позицию, откуда цель видно, очередь, шаг назад.
--
-- Настоящего leaning у nextbot нет, а короткий выход из-за края и возврат
-- читаются ровно как он.
--
function ENT:PeekAndShoot(enemy)
	local cover = self.CoverPos
	local peek = self:FindPeekSpot(cover, enemy)
	if not peek then return false end

	self:FollowPath(peek, {
		run = true,
		face = "enemy",
		tolerance = 24,
		maxage = 2,
		abort = function() return self:GetEnemy() ~= enemy end,
	})

	if IsValid(enemy) and self:HasLOS(enemy) and self:CanFireWeapon() then
		self:ShootBurst(enemy)
	end

	-- Обратно за край. Укрытие могло стать негодным, пока мы стреляли.
	if self:HasCover() and self:IsCoverStillGood(enemy) then
		self:FollowPath(cover, {
			run = true,
			tolerance = 24,
			maxage = 2,
			abort = function() return not self:HasCover() end,
		})
	end

	return true
end

--------------------------------------------------------------------------------
-- Укрытия
--------------------------------------------------------------------------------

-- Патронов осталось мало: пора думать об укрытии заранее, а не когда щёлкнет.
function ENT:IsLowOnAmmo()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) or wep:IsMelee() then return false end

	local max = wep:GetMaxClip()
	if not max or max <= 0 then return false end

	return wep:GetClip() <= max * self.LowAmmoFraction
end

--
-- Пора ли прятаться.
--
-- Условие — «меня видно», а НЕ «в меня попали». Сначала было по попаданиям, и в
-- игре это не сработало: на дистанции боя противники попадают друг в друга
-- редко, отметка о ранении не ставилась, и за укрытие никто не вставал вовсе
-- (замерено в перестрелке 3х3 на 1188 юнитов — ноль укрытий за бой). За угол
-- встают, когда бой начался, а не когда уже ранили.
--
-- От бесконечной беготни защищает не это условие, а то, что занятое укрытие
-- перестаёт быть поводом двигаться: дошёл — стой и стреляй.
--
function ENT:ShouldSeekCover(enemy, dist)
	if not self.CanUseCover then return false end

	-- В рукопашной угол не ищут: там бьют прикладом.
	if not self:HasCover() then
		dist = dist or self:GetPos():Distance(enemy:GetPos())

		if dist < self.CoverMinEngageDistance then return false end
	end

	if self:HasCover() then
		-- Угол, за которым сидим, обошли — забыть его и искать новый.
		if not self:IsCoverStillGood(enemy) then
			self:ClearCover()
		elseif self:GetPos():DistToSqr(self.CoverPos) < self.CoverReachedDist ^ 2 then
			return false
		else
			return true
		end
	end

	-- Там, где стоим, нас и так не достают — незачем никуда идти.
	return not self:IsInCover(enemy)
end

--
-- Занять укрытие. true — значит этим и заняли кадр.
--
--
-- Занять укрытие. true — значит этим и заняли кадр.
--
--   keepDistance — не брать угол, который дальше от цели, чем мы стоим сейчас.
--
-- Раньше вместо этого стоял порог CoverMinEngageDistance: ближе 260 юнитов
-- укрытие не искалось вовсе. Он решал правильную задачу — не пятиться под ствол
-- спиной, — но слишком грубо. Замерено в бою: на дистанции около 200 юнитов
-- ShouldSeekCover отказывал 10 раз из 11, и вся система укрытий не включалась,
-- потому что перестрелки как раз и идут на такой дистанции.
--
-- Теперь ограничение прямое: угол годится, только если он НЕ дальше от врага,
-- чем текущее место. Отойти вбок за ближайший выступ вплотную к противнику
-- можно и нужно, а отбегать от него — нет.
--
function ENT:GoToCover(enemy, needPeek, keepDistance)
	local spot = self:HasCover() and self.CoverPos or nil

	if not spot then
		if not self:CanSearchCover() then return false end
		self:MarkCoverSearched()

		--
		-- Запас обязателен. Требование «не дальше от цели, чем сейчас» оставляет
		-- только узкую дугу вокруг врага, а укрытия почти всегда лежат чуть
		-- позади — за угол от огня уходят назад-вбок, а не строго вбок. Замерено:
		-- без запаса FindCoverSpot не нашёл НИ ОДНОГО угла за 11 вызовов, тогда
		-- как без ограничения вовсе находил 4 из 13.
		--
		-- Полшага назад за выступ — это укрытие. Отбежать на два корпуса — это
		-- уже отход спиной под ствол, и вот его запас и отсекает.
		--
		local maxThreat = nil

		if keepDistance and IsValid(enemy) then
			maxThreat = self:GetPos():Distance(enemy:GetPos()) + self.CoverBackstepAllowance
		end

		local kind
		spot, kind = self:FindCoverSpot(enemy, nil, {
			needPeek = needPeek,
			maxThreat = maxThreat,
			-- Анимации укрытия рисуют прижатого к преграде, так что и точка
			-- обязана быть у преграды, а не просто в непростреливаемом месте.
			needWall = self:HasCoverAnims(),
		})

		if not spot then
			self:ClearCover()

			return false
		end

		self:RememberCover(spot, kind, enemy)
	end

	if self:GetPos():DistToSqr(spot) < self.CoverReachedDist ^ 2 then return false end

	-- Идём — значит позу держать некому: она заблокировала бы анимацию бега.
	self:ClearCoverPose()

	local status = self:FollowPath(spot, {
		run = true,
		fire = true,
		tolerance = self.CoverReachedDist,
		maxage = 6,
		abort = function() return self:GetEnemy() ~= enemy end,
	})

	-- До угла не добежали — он больше не наш, на следующем поиске возьмём другой.
	if status ~= "ok" then self:ClearCover() end

	return true
end

--
-- Запомнить укрытие вместе с геометрией: где стена и с какой стороны из-за неё
-- выглядывать. Без этого анимации выбрать нечем.
--
function ENT:RememberCover(spot, kind, enemy)
	local normal, _, wallPos = self:CoverWallNormal(spot, enemy)

	-- Встаём вплотную к преграде, а не «где-то рядом»: точка навмеша лежит в
	-- метре от стены, и без притирки боец и простреливается, и выглядит так,
	-- будто просто остановился неподалёку.
	if isvector(wallPos) then
		spot = self:HugCover(spot, normal, wallPos)
	end

	--
	-- Сторону здесь НЕ считаем: её определит щуп в CoverFight, когда боец
	-- реально встанет к укрытию и развернётся. FindPeekSpot тут стоил шести
	-- трасс на каждое запоминание и отвечал про другое место.
	--
	self:SetCurrentCover(spot, kind, normal, nil)
end

--------------------------------------------------------------------------------
-- Бой из укрытия
--------------------------------------------------------------------------------

--
-- Веса действий за укрытием. Функция, а не таблица на классе: табличные поля ENT
-- при наследовании сливаются поэлементно, и веса наследника склеились бы с
-- базовыми — ровно так список стволов джаггернаута однажды получил хвостом
-- стволы обычного наёмника.
--
function ENT:GetCoverStyle()
	return {peek = 45, blind = 20, slide = 20, advance = 8, hold = 15}
end

--
-- Выбрать действие по весам.
--
-- Роль в группе СМЕЩАЕТ выбор, но не подменяет его. Раньше взявший лобовое
-- давление получал безусловный advance — и замеры показали, во что это
-- обходится: из двух срабатываний боя оба дали advance, то есть боец занимал
-- укрытие и в тот же такт его бросал. Система укрытий выключалась сама собой
-- ровно у того, кому она нужнее всего, а в малых группах роль assault берут
-- почти все.
--
-- Теперь роль просто добавляет веса наступлению и вдвое режет «сидеть и ждать»:
-- боец по-прежнему идёт вперёд чаще остальных, но по дороге выглядывает и
-- стреляет, а не бежит по прямой.
--
function ENT:PickCoverAction(enemy)
	local style = self:GetCoverStyle()

	if self:GetCombatRole() == "assault" then
		local boosted = {}
		for k, v in pairs(style) do boosted[k] = v end

		boosted.advance = (boosted.advance or 0) + self.AssaultAdvanceBoost
		boosted.hold = math.floor((boosted.hold or 0) * 0.5)

		style = boosted
	end

	local total = 0
	for _, w in pairs(style) do total = total + w end
	if total <= 0 then return "hold" end

	local roll, acc = math.random() * total, 0

	for action, w in pairs(style) do
		acc = acc + w
		if roll <= acc then return action end
	end

	return "hold"
end

--
-- Бой за укрытием на анимациях cover_system.
--
-- true — кадр обслужен. false означает «анимаций нет» либо «мы не в укрытии»;
-- тогда вызывающий работает по-старому, через приседание и шаг вбок.
--
-- Устройство: прижаться к стене, разыграть одно действие, вернуться в прижатие.
-- Один такт — одно действие, потому что боевая корутина и так крутится примерно
-- раз в секунду: разыгрывать по несколько действий подряд значит потерять
-- управление на несколько секунд, за которые бой успевает измениться.
--
function ENT:CoverFight(enemy)
	if not self:HasCoverAnims() then return false end
	if not self:HasCover() then return false end
	if self:GetPos():DistToSqr(self.CoverPos) > self.CoverReachedDist ^ 2 then return false end

	--
	-- Разворачиваемся ДО щупов: они идут от корпуса назад, и на неразвёрнутом
	-- бойце показали бы не ту стену.
	--
	self:FaceCoverWall(self.CoverNormal)

	--
	-- К укрытию надо иметь возможность ПРИЖАТЬСЯ. Поиск отвечает только на
	-- вопрос «простреливается ли точка», а скрытой её может делать рельеф,
	-- дальняя машина или угол дома в двадцати метрах — прятаться там не за что.
	--
	-- Без этой проверки боец вставал в позу прижатого к стене посреди открытой
	-- дороги. В системе укрытий для игрока ровно здесь стоит SetCovering(false):
	-- нет преграды за спиной — нет и режима укрытия.
	--
	-- Точку при этом НЕ бросаем: от огня она всё-таки прикрывает. Отказываемся
	-- только от анимации, и бой идёт обычным путём.
	--
	local normal = self.CoverNormal

	if not self:CoverProbe("low", normal).Hit then
		self:ClearCoverPose()

		return false
	end

	--
	-- Высоту и сторону спрашиваем у геометрии, а не у поиска укрытий. Поиск
	-- отвечает про точку, щуп — про то, что реально стоит за спиной, и именно
	-- это рисует анимация.
	--
	local high = self:ProbeCoverHigh(normal)
	local kind = high and "full" or "low"
	local side = self:ProbeCoverSide(high, normal)

	self.CoverKind = kind
	if side ~= "" then self.CoverSide = side end

	-- За низким укрытием сидят, за высоким стоят.
	self:SetCrouching(not high)
	self:SetCoverPose(self:CoverSeqName("idle", kind, side ~= "" and side or nil))

	local action = self:PickCoverAction(enemy)

	if action == "peek" then return self:CoverPeek(enemy, kind, side) end
	if action == "blind" then return self:CoverBlindFire(enemy, kind, side) end
	if action == "slide" then return self:CoverSlide(enemy, kind, side) end

	if action == "advance" then
		self:ClearCoverPose()
		self:SetCrouching(false)

		if self:BoundingAdvance(enemy) then return true end

		return self:CoverHold(enemy, kind, side)
	end

	return self:CoverHold(enemy, kind, side)
end

-- Сидеть и ждать. Не безделье: пока боец не показывается, попасть в него нечем,
-- а огонь по его углу тратит чужой магазин.
function ENT:CoverHold(enemy, kind, side)
	self:SetCoverPose(self:CoverSeqName("idle", kind, side))
	coroutine.wait(MuR.Roll(self.CoverHoldTime, 1))

	return true
end

--
-- Выглянуть, отстреляться, вернуться.
--
-- Корпус не переставляем: раньше это был настоящий переход на позицию для
-- выстрела и обратно (PeekAndShoot), и боец на две секунды выходил из укрытия
-- целиком. Анимация выглядывания делает то же самое, не вынося габарит из-за
-- угла — то есть выглядывание наконец стало дешевле, чем выход.
--
function ENT:CoverPeek(enemy, kind, side)
	local pose = self:CoverSeqName("look", kind, side)
	if not pose then return self:CoverHold(enemy, kind, side) end

	--
	-- Из-за края смотрят в полный рост даже за низким укрытием: сидя виден
	-- только потолок напротив.
	--
	-- Корпус при этом остаётся СПИНОЙ к укрытию — разворачиваться к цели
	-- нельзя. Анимация look_wall* уже отыгрывает выглядывание: боец прижат к
	-- стене и высовывает из-за края ствол и голову. Довороты доделывают
	-- поз-параметры прицеливания, а сам выстрел летит от дула точно в цель
	-- (FireOnce считает направление как aim - muzzle, от угла корпуса оно не
	-- зависит).
	--
	self:SetCrouching(false)
	self:SetCoverPose(pose)
	self:FaceCoverWall(self.CoverNormal)
	coroutine.wait(self.CoverPopUpDelay)

	if IsValid(enemy) and self:GetEnemy() == enemy and self:HasLOS(enemy) then
		self:TryShoot(enemy)
	end

	if not self:HasCover() then return true end

	self:SetCrouching(kind == "low")
	self:FaceCoverWall(self.CoverNormal)
	self:SetCoverPose(self:CoverSeqName("idle", kind, side))
	coroutine.wait(MuR.Roll(self.CoverDuckTime, 1))

	return true
end

--
-- Огонь вслепую: ствол за край, очередь, не показываясь.
--
-- Точность нарочно плохая (CoverBlindSpread), задача не убить, а не дать
-- поднять голову. Проверка коридора обязательна и здесь: вслепую попасть в
-- своего проще всего, а трасса ловит только то, что ровно на луче — поэтому
-- работает цилиндр из AllyInLineOfFire.
--
function ENT:CoverBlindFire(enemy, kind, side)
	if not self.CanBlindFire then return self:CoverHold(enemy, kind, side) end
	if not self:CanFireWeapon() then return self:CoverHold(enemy, kind, side) end
	if self:IsLowOnAmmo() then return self:CoverHold(enemy, kind, side) end

	local aim = self.LastLOSPos or self:GetLastEnemyPos()
	if not isvector(aim) then return self:CoverHold(enemy, kind, side) end

	aim = aim + Vector(0, 0, self.CoverEyeHeight)

	if not self:HasClearShot(aim) then return self:CoverHold(enemy, kind, side) end

	self:SetCoverPose(self:CoverSeqName("look", kind, side))
	self:FaceCoverWall(self.CoverNormal)

	local saved = self.Weapon_Accuracy
	self.Weapon_Accuracy = saved * self.CoverBlindSpread
	self:SuppressBurst(aim)
	self.Weapon_Accuracy = saved

	return true
end

--
-- Приставной шаг вдоль укрытия.
--
-- Смысл в том, чтобы сменить угол обстрела, не бросая стену. Раньше сменой
-- позиции занимался CombatReposition, а он бросает укрытие целиком и ищет
-- новое — то есть выходит под огонь ради того, за чем и так стоял.
--
function ENT:CoverSlide(enemy, kind, side)
	local normal = self.CoverNormal
	if not isvector(normal) then return self:CoverHold(enemy, kind, side) end

	local pose = self:CoverSeqName("move", kind, side)
	if not pose then return self:CoverHold(enemy, kind, side) end

	-- Вдоль стены, а не от неё: направление берётся поперёк нормали.
	local along = normal:Cross(vector_up)
	along.z = 0
	if along:LengthSqr() < 1 then return self:CoverHold(enemy, kind, side) end
	along:Normalize()

	local sign = side == "l" and 1 or -1
	local target = self.CoverPos + along * (MuR.Roll(self.CoverSlideDistance, 64) * sign)

	local area = MuR.NPC.GetArea(target)
	if not IsValid(area) then return self:CoverHold(enemy, kind, side) end

	target = area:GetClosestPointOnArea(target) + Vector(0, 0, 2)

	-- Новая точка обязана оставаться укрытием: шаг вдоль стены, который выводит
	-- под огонь, это не смена позиции, а выход.
	if not self:CanStandAt(target) then return self:CoverHold(enemy, kind, side) end
	if self:RateSpot(self:ThreatEyePos(enemy), target, enemy) == "open" then
		return self:CoverHold(enemy, kind, side)
	end

	self:SetCoverPose(pose)
	self:FaceCoverWall(normal)

	-- Корпус ведёт loco, ноги отыгрывает анимация. FollowPath тут не годится:
	-- он поставил бы активити ходьбы и сбил бы позу.
	local deadline = CurTime() + self.CoverSlideTime

	while CurTime() < deadline and self:GetPos():DistToSqr(target) > 16 * 16 do
		if self:GetEnemy() ~= enemy then break end

		self.loco:SetDesiredSpeed(self:GetWalkSpeed())
		self.loco:Approach(target, 1)
		coroutine.yield()
	end

	--
	-- Укрытием становится то место, где боец ОКАЗАЛСЯ, а не то, куда шёл. Шаг
	-- упирается в геометрию чаще, чем кажется, и запись цели вместо факта
	-- выбрасывала бы бойца из системы укрытий: CoverFight на следующем такте
	-- видит, что до "своего" угла далеко, и возвращает false.
	--
	local reached = self:GetPos():DistToSqr(target) <= 48 * 48

	self:SetCurrentCover(self:GetPos(), self.CoverKind, normal,
		reached and (side == "l" and "r" or "l") or side)

	self:SetCoverPose(self:CoverSeqName("idle", kind, self.CoverSide))

	return true
end

--
-- Стоим ли мы прямо сейчас за низким укрытием.
--
-- Низкое — это то, из-за чего можно привставать: сидя оно закрывает, стоя нет.
-- Поиск укрытий эту разницу считает (RateSpot), но до сих пор её никто не
-- использовал, и боец стоял за парапетом в полный рост.
--
function ENT:IsAtLowCover()
	if self.CoverKind ~= "low" then return false end
	if not self:HasCover() then return false end

	return self:GetPos():DistToSqr(self.CoverPos) < self.CoverReachedDist ^ 2
end

--
-- Огонь из-за низкого укрытия: привстать, отстреляться, сесть обратно.
--
-- Приседание тут не для вида: пока NPC сидит, простреливаемость его точки
-- считается по CoverCrouchEyeHeight, и укрытие работает ровно так, как обещал
-- поиск. Габарит на это время тоже ужимается, иначе пуля находит торчащую
-- голову, которой на экране нет.
--
function ENT:PopUpAndShoot(enemy)
	self:SetCrouching(false)
	self:FaceTowards(enemy:GetPos())
	self:PlayActivity(ACT_IDLE)
	coroutine.wait(self.CoverPopUpDelay)

	if IsValid(enemy) and self:GetEnemy() == enemy and self:HasLOS(enemy) then
		self:TryShoot(enemy)
	end

	if not self:HasCover() then return end

	self:SetCrouching(true)
	self:PlayActivity(ACT_COVER_LOW)
	coroutine.wait(MuR.Roll(self.CoverDuckTime, 1))

	-- Габарит возвращаем сразу: следующий кадр может увести бойца с места, а
	-- ужатая коробка по дороге застревает под тем, подо что не пролезает.
	self:SetCrouching(false)
end

--------------------------------------------------------------------------------
-- Гранаты под ногами
--------------------------------------------------------------------------------

--
-- Что считается прилетевшим взрывоопасным. Молотов сюда входит намеренно: гореть
-- на месте боец умеет не лучше, чем взрываться.
--
local DANGER_CLASSES = {
	["murwep_grenade"] = true,
	["bloodshed_flashbang"] = true,
	["bloodshed_molotov"] = true,
	["murwep_ied"] = true,
	["mur_gas_cloud"] = true,
}

--
-- Лежит ли рядом граната. Возвращает саму сущность.
--
-- Сканируется на своём интервале, а не каждый тик: Think зовётся около
-- шестидесяти раз в секунду, а FindInSphere на каждого бойца в такой частоте —
-- заметная трата на ровном месте.
--
function ENT:FindNearbyDanger()
	if CurTime() < (self.NextDangerScan or 0) then return nil end
	self.NextDangerScan = CurTime() + self.DangerScanInterval

	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.DangerRadius)) do
		if IsValid(ent) and DANGER_CLASSES[ent:GetClass()] then return ent end
	end

	return nil
end

--
-- Уйти от гранаты.
--
-- Бежим НЕ просто в противоположную сторону: за спиной может быть стена, и
-- отход в неё означает смерть на месте. Ищем точку навмеша, которая дальше
-- опасного радиуса, и идём туда — короткий переход с жёстким потолком времени,
-- потому что граната ждать не станет.
--
function ENT:FleeDanger(danger)
	if not IsValid(danger) then return false end

	local myPos = self:GetPos()
	local dangerPos = danger:GetPos()

	local away = myPos - dangerPos
	away.z = 0
	if away:LengthSqr() < 1 then away = self:GetAngles():Forward() end
	away:Normalize()

	-- Укрытие сейчас не помощь: взрыв достаёт за тем же углом, за которым мы сидим.
	self:ClearCover()
	self:ClearCoverPose()
	self:SetCrouching(false)

	local safeSqr = (self.DangerRadius * 1.5) ^ 2

	-- Прямо от гранаты, потом веером в стороны: первое же направление часто
	-- упирается в ту самую стену, к которой боец и прижимался.
	for _, deg in ipairs({0, 40, -40, 80, -80}) do
		local dir = Vector(away)
		dir:Rotate(Angle(0, deg, 0))

		local target = myPos + dir * (self.DangerRadius * 1.5)
		local area = MuR.NPC.GetArea(target)
		if not IsValid(area) then continue end

		target = area:GetClosestPointOnArea(target) + Vector(0, 0, 2)
		if target:DistToSqr(dangerPos) < safeSqr then continue end
		if not self:CanStandAt(target) then continue end

		self:FollowPath(target, {
			run = true,
			tolerance = 32,
			maxage = self.DangerFleeTime,
			abort = function() return not IsValid(danger) end,
		})

		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- Смена огневой позиции
--------------------------------------------------------------------------------

function ENT:ShouldReposition()
	local now = CurTime()

	-- Первый вызов только заводит таймер: сразу с началом боя бегать некуда.
	if not self.NextReposition then
		self.NextReposition = now + MuR.Roll(self.RepositionInterval, 9)

		return false
	end

	if now < self.NextReposition then return false end

	self.NextReposition = now + MuR.Roll(self.RepositionInterval, 9)

	return true
end

--
-- Уйти с насиженного места.
--
-- Кто прячется — бросает занятый угол и ищет другой, кто не прячется (тяжёлые)
-- — просто смещается вбок, не теряя цель из вида.
--
function ENT:CombatReposition(enemy)
	if not self.CanUseCover then return self:StrafeStep(enemy) end

	self:ClearCover()
	self:ClearCoverPose()
	self:SetCrouching(false)
	-- Троттлинг сбрасываем: новое место нужно сейчас, иначе смена позиции
	-- просто пропустится и боец останется стоять там же.
	self.NextCoverSearch = 0

	if self:GoToCover(enemy, not self:HasCoverAnims(), true) then return true end

	return self:StrafeStep(enemy)
end

--
-- Короткий шаг вбок. Не тактика, а «не стоять столбом»: сместившийся на шаг
-- стрелок сбивает игроку прицел и выглядит живым.
--
function ENT:StrafeStep(enemy)
	if not IsValid(enemy) then return false end

	local myPos = self:GetPos()

	local dir = enemy:GetPos() - myPos
	dir.z = 0
	if dir:LengthSqr() < 1 then return false end
	dir:Normalize()

	local side = dir:Cross(vector_up)
	side.z = 0
	side:Normalize()

	local dist = MuR.Roll(self.StrafeDistance, 120)
	local sign = math.random(2) == 1 and 1 or -1

	for _ = 1, 2 do
		local p = myPos + side * (dist * sign)
		local area = MuR.NPC.GetArea(p)

		if IsValid(area) then
			p = area:GetClosestPointOnArea(p) + Vector(0, 0, 2)

			-- С новой точки цель обязана простреливаться, иначе шаг вбок
			-- превращается в уход из боя.
			if self:CanStandAt(p) and self:IsSpotVisibleFrom(enemy:WorldSpaceCenter(), p, self.CoverEyeHeight, enemy) then
				self:FollowPath(p, {
					run = true,
					face = "enemy",
					tolerance = 24,
					maxage = 1.5,
					abort = function() return self:GetEnemy() ~= enemy end,
				})

				return true
			end
		end

		sign = -sign
	end

	return false
end

--------------------------------------------------------------------------------
-- Перезарядка
--------------------------------------------------------------------------------

function ENT:ReloadBehaviour(enemy)
	if self.CanUseCover and not self:IsInCover(enemy) then
		if self:GoToCover(enemy, false) then return end
	end

	-- Просим прикрыть: несколько секунд мы гарантированно не отвечаем, и это
	-- единственный момент боя, когда чужой огонь по нашей цели нужен буквально.
	self:RequestCover(enemy)

	self:FaceTowards(enemy:GetPos())
	self:ReloadWeapon()
end

function ENT:MeleeBehaviour(enemy)
	if self:CanMeleeAttack() then
		coroutine.wait(self:StartMeleeAttack())

		return
	end

	self:PressAttack(enemy)
end

--
-- Сблизиться с целью.
--
-- Стрелку доходить вплотную не надо: сближение прекращается, как только цель
-- видно с дистанции огня. Раньше этим занимался ChaseEnemy, а он прерывается
-- только по CanMeleeAttack/CanLeapAttack/CanRangeAttack — у человека с
-- огнестрелом HasRangeAttack = false, так что срабатывал один ближний бой, и
-- боец с винтовкой добегал до цели на 36 юнитов, чтобы там начать стрелять.
--
function ENT:PressAttack(enemy)
	-- Обходящий сближается по дуге, а не в лоб.
	if self:GetCombatRole() == "flank" and self:FlankBehaviour(enemy) then return end

	if not self:HasRangedWeapon() then
		local status = self:ChaseEnemy(enemy)

		if status == "throttled" then
			self:ApproachDirectly(enemy:GetPos(), true)
			coroutine.wait(0.1)

			return
		end

		if status == "unreachable" or status == "failed" then
			self:ApproachDirectly(enemy:GetPos(), true)
			coroutine.wait(self.UnreachablePause)
		end

		return
	end

	-- Держащий позицию на цель не бежит вовсе, пока она хоть иногда
	-- показывается: он для того и сидит, где сидит.
	if self.AdvanceStyle == "hold" and self:HoldPosition(enemy) then return end

	-- Перебежками: рывок до следующего угла, а не галоп через всё открытое место.
	if self.AdvanceStyle == "bound" and self:BoundingAdvance(enemy) then return end

	if not self:CanComputePath() then
		self:ApproachDirectly(enemy:GetPos(), true)
		coroutine.wait(0.1)

		return
	end

	-- Цель не видно — идём не к ней, а туда, откуда её будет видно.
	if not self:HasLOS(enemy) and self:MoveToFiringSpot(enemy) then return end

	local range = self:GetFiringRange()

	local status = self:FollowPath(enemy:GetPos(), {
		run = self:ShouldRunToEnemy(enemy),
		fire = true,
		tolerance = math.max(self.Weapon_RetreatDistance, 64),
		lookahead = 200,
		repath = 0.5,
		maxage = 12,
		target = function()
			local e = self:GetEnemy()

			return IsValid(e) and e:GetPos() or enemy:GetPos()
		end,
		abort = function()
			if self:GetEnemy() ~= enemy then return true end

			-- Цель видно и она в пределах огня — дальше не идём, стреляем.
			return self:HasLOS(enemy) and self:GetPos():DistToSqr(enemy:GetPos()) <= range * range
		end,
	})

	if status == "unreachable" or status == "failed" then
		self:ApproachDirectly(enemy:GetPos(), true)
		coroutine.wait(self.UnreachablePause)
	end
end

--
-- Сблизиться до места, откуда цель ВИДНО. true — кадр обслужен.
--
-- Это лечение того самого «NPC тупит, когда игрок за углом». Обычное сближение
-- идёт к позиции врага с tolerance = Weapon_RetreatDistance, и стоя в этом
-- радиусе от угла NPC уже «дошёл»: FollowPath возвращает "ok" немедленно,
-- видимость так и не появляется, и следующий такт корутины повторяет то же
-- самое. Снаружи это ровно бесконечный цикл, хотя формально всё отработало.
--
-- Точка ищется тем же перебором площадей, что и укрытия (FindFiringSpot), и по
-- тому же троттлингу: два поиска в одном такте нам не нужны, а бюджет у них
-- общий.
--
function ENT:MoveToFiringSpot(enemy)
	if not self:CanSearchCover() then return false end
	self:MarkCoverSearched()

	local spot = self:FindFiringSpot(enemy)

	--
	-- Точки с обзором нет вовсе (цель на крыше, в запертой комнате). Тогда
	-- проверяем последнее известное место — и обязательно с МАЛЫМ допуском,
	-- иначе вернёмся ровно к тому холостому циклу, от которого уходим.
	--
	if not spot then
		spot = self:GetLastEnemyPos()
		if not isvector(spot) then return false end
	end

	if self:GetPos():DistToSqr(spot) < 48 * 48 then return false end

	local status = self:FollowPath(spot, {
		run = self:ShouldRunToEnemy(enemy),
		fire = true,
		tolerance = 32,
		lookahead = 200,
		repath = 1,
		maxage = 8,
		abort = function()
			if self:GetEnemy() ~= enemy then return true end

			return self:HasLOS(enemy)
		end,
	})

	self:NotePressResult(enemy, status)

	return true
end

--
-- Счётчик холостых заходов.
--
-- Страховка от любого нового цикла того же рода: если сближение несколько раз
-- подряд закончилось ничем и дистанция при этом не изменилась, значит мы упёрлись
-- во что-то, чего маршрут не видит. Площадь под ногами уходит в объезд, и
-- следующий путь строится вокруг неё.
--
function ENT:NotePressResult(enemy, status)
	if status == "interrupted" then
		self.BlindPressCount = 0

		return
	end

	local dist = self:GetPos():Distance(enemy:GetPos())
	local moved = math.abs(dist - (self.LastPressDist or 0)) > self.PressProgressEpsilon

	self.LastPressDist = dist

	if moved then
		self.BlindPressCount = 0

		return
	end

	self.BlindPressCount = (self.BlindPressCount or 0) + 1

	if self.BlindPressCount < self.PressIdleLimit then return end

	self.BlindPressCount = 0

	local area = MuR.NPC.GetArea(self:GetPos())
	if IsValid(area) then self:AvoidArea(area, self.NavAvoidDuration) end
end

--
-- Бежать к цели или подходить шагом.
--
-- Бегут те, кому положено давить, и все, кого только что задело: под огнём
-- прогулочный шаг — это смерть. Остальные подходят к невидимой цели шагом.
-- Этого и не хватало, чтобы группа перестала выглядеть одной сплошной атакой.
--
function ENT:ShouldRunToEnemy(enemy)
	if self.AdvanceStyle == "rush" then return true end
	if self:GetCombatRole() == "assault" then return true end
	if CurTime() - (self.LastHurtTime or 0) < self.HurtRunTime then return true end

	-- Цель на виду — дальше уже не подкрадёшься.
	return self:HasLOS(enemy)
end

--
-- Держать позицию вместо сближения.
--
-- false — ждать больше нечего: цель не показывается слишком долго либо группе
-- нужен кто-то, кто пойдёт вперёд.
--
function ENT:HoldPosition(enemy)
	-- Взявший на себя лобовое давление обязан идти, какая бы у него ни была
	-- манера: иначе вся группа садится в оборону и бой встаёт.
	if self:GetCombatRole() == "assault" then return false end
	if CurTime() - (self.LastLOSTime or 0) > self.HoldPatience then return false end

	self:HoldAim(self.LastLOSPos or enemy)

	return true
end

--
-- Наступление перебежками: рывок до следующего угла в сторону цели, пауза,
-- следующий рывок.
--
-- false — впереди нет угла, до которого стоит бежать; тогда вызывающий
-- сближается обычным путём.
--
function ENT:BoundingAdvance(enemy)
	if CurTime() < (self.NextBound or 0) then
		-- Между рывками боец стоит и смотрит на цель, а не топчется на бегу.
		-- Огонь по этой паузе даёт ветка подавления в CombatBehaviour.
		self:HoldAim(enemy)

		return true
	end

	if not self:CanSearchCover() then return false end
	self:MarkCoverSearched()

	-- Следующий угол обязан быть заметно ближе к цели, чем тот, где мы стоим,
	-- иначе это не наступление, а метание вдоль фронта.
	local gain = self:GetPos():Distance(enemy:GetPos()) - self.BoundMinGain
	if gain < self.CoverMinDistance then return false end

	local spot, kind = self:FindCoverSpot(enemy, nil, {
		needPeek = true,
		radius = self.BoundDistance,
		maxThreat = gain,
	})

	if not spot then return false end

	self.NextBound = CurTime() + MuR.Roll(self.BoundPause, 2)
	self:RememberCover(spot, kind, enemy)

	local status = self:FollowPath(spot, {
		run = true,
		fire = true,
		tolerance = self.CoverReachedDist,
		maxage = 6,
		abort = function() return self:GetEnemy() ~= enemy end,
	})

	if status ~= "ok" then self:ClearCover() end

	return true
end

--
-- Отойти от цели, продолжая смотреть на неё.
--
-- Откат обязателен. Ветка вызывается из боевой корутины, а та крутится примерно
-- раз в секунду: без отката отход начинался заново каждый такт, и NPC пятился
-- непрерывно, пока цель оставалась близко.
--
-- Из укрытия не пятятся вовсе: за угол вставали не для того, чтобы его бросить,
-- едва цель подошла.
--
function ENT:BackAwayFrom(enemy)
	if not IsValid(enemy) then return end
	if self:HasCover() then return end
	if CurTime() < (self.NextBackAway or 0) then return end

	self.NextBackAway = CurTime() + MuR.Roll(self.BackAwayInterval, 4)

	local away = self:GetPos() - enemy:GetPos()
	away.z = 0
	if away:LengthSqr() < 1 then return end
	away:Normalize()

	local target = self:GetPos() + away * self.Weapon_RetreatDistance
	local area = MuR.NPC.GetArea(target)
	if IsValid(area) then target = area:GetClosestPointOnArea(target) + Vector(0, 0, 4) end

	local status = self:FollowPath(target, {
		run = true,
		face = "enemy",
		fire = true,
		tolerance = 32,
		maxage = 3,
		abort = function() return self:GetEnemy() ~= enemy end,
	})

	-- Отходить некуда — значит стоим и отстреливаемся, а не пятимся в стену.
	if status == "failed" or status == "unreachable" then
		self:FaceTowards(enemy:GetPos())
		coroutine.wait(0.3)
	end
end

function ENT:PeaceBehaviour()
	-- Приказ следовать за игроком (полиция принимает его по Use).
	if IsValid(self.FollowTarget) then
		local dist = self:GetPos():Distance(self.FollowTarget:GetPos())

		if dist > self.FollowDistance then
			self:FollowPath(self.FollowTarget:GetPos(), {
				run = dist > self.FollowDistance * 2,
				tolerance = self.FollowDistance * 0.7,
				repath = 0.5,
				maxage = 10,
				target = function()
					return IsValid(self.FollowTarget) and self.FollowTarget:GetPos() or self:GetPos()
				end,
				abort = function() return not IsValid(self.FollowTarget) end,
			})

			return
		end

		self:PlayActivity(ACT_IDLE)

		return
	end

	if not self.CanWander then
		self:PlayActivity(ACT_IDLE)

		return
	end

	if CurTime() < (self.NextWander or 0) then
		self:PlayActivity(ACT_IDLE)

		return
	end

	self.NextWander = CurTime() + MuR.Roll(self.WanderInterval, 6)
	self:WanderOnce(self.WanderRadius)
end

--------------------------------------------------------------------------------
-- Следование
--------------------------------------------------------------------------------

function ENT:Follow(ent, announce)
	if not IsValid(ent) then
		self.FollowTarget = nil

		return false
	end

	-- Повторный Use снимает приказ: так же вёл себя NPC на VJ.
	if self.FollowTarget == ent then
		self.FollowTarget = nil

		return false
	end

	self.FollowTarget = ent
	self:ClearGoal()

	return true
end

function ENT:IsFollowing()
	return IsValid(self.FollowTarget)
end
