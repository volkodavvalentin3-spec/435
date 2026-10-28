AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "Bloodshed NPC Base"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.IsBloodshedNPC = true

--------------------------------------------------------------------------------
-- Внешний вид
--------------------------------------------------------------------------------

ENT.Model = {"models/player/police.mdl"}
ENT.RandomSkins = false
ENT.RandomBodygroups = false
ENT.EyeHeight = 64

ENT.CollisionMins = Vector(-16, -16, 0)
ENT.CollisionMaxs = Vector(16, 16, 72)

ENT.BloodColorEngine = BLOOD_COLOR_RED
ENT.CustomBlood_Particle = nil

--------------------------------------------------------------------------------
-- Здоровье и фракция
--------------------------------------------------------------------------------

ENT.StartHealth = 50
ENT.Faction = "zombie"

--------------------------------------------------------------------------------
-- Передвижение
--------------------------------------------------------------------------------

ENT.WalkSpeed = 55
ENT.RunSpeed = 200
-- Множитель к обеим скоростям. Режимы меняют его, а не сами скорости.
ENT.SpeedScale = 1
-- Ниже этой скорости бег выглядит замедленной съёмкой, поэтому играем шаг.
ENT.RunActivityThreshold = 130
ENT.StepHeight = 18
-- Радиус и сила мягкого расталкивания своих. 0 отключает.
ENT.SeparationRadius = 40
ENT.SeparationForce = 45
-- Толчок в сторону, когда упёрлись в своего вплотную.
ENT.AllyPushForce = 130
-- С какого расстояния считаем, что стоим в союзнике, и на сколько сдвигаем
-- позицию за раз, когда loco бессилен.
ENT.SeparationTouch = 26
ENT.SeparationStep = 8
ENT.MaxYawRate = 250
ENT.Acceleration = 500
ENT.Deceleration = 500

-- Enabled/MaxRise/MaxDrop/MaxDistance — формат оставлен от VJ, чтобы описания
-- NPC переезжали без правок.
ENT.JumpParams = {
	Enabled = true,
	MaxRise = 240,
	MaxDrop = 320,
	MaxDistance = 400,
}

--------------------------------------------------------------------------------
-- Навигация: что NPC умеет проходить
--------------------------------------------------------------------------------

-- Забираться на уступы и перелетать разрывы (сегменты CLIMB_UP / JUMP_OVER_GAP).
-- Без этого NPC встаёт у любой ограды: loco сам на уступ не залезает.
ENT.CanJumpObstacles = true
ENT.CanUseLadders = true
ENT.CanCrouch = true
ENT.CanSwim = false

-- Высота габарита в приседе.
ENT.CrouchHeight = 40

-- Вертикальная скорость подъёма, юнитов в секунду.
ENT.LadderSpeed = 100
-- На сколько корпус отстоит от плоскости лестницы.
ENT.LadderHugDistance = 20
-- Насколько близко к подножию надо подойти, прежде чем цепляться: издалека
-- корпус потянуло бы к лестнице сквозь всё, что стоит между.
ENT.LadderMountDistance = 32
-- И насколько совпасть по высоте с нужным концом лестницы.
ENT.LadderMountHeight = 40
-- Насколько вглубь площадки отходить, если точка схода занята.
ENT.LadderExitInsets = {0, 16, 32}
-- С какой высоты щупать пол над точкой схода.
ENT.LadderExitProbe = 64
ENT.LadderActivity = nil

-- Множители стоимости пути. Считаются от длины участка, поэтому 6 означает
-- "этот участок в семь раз дороже обычного" — обойти почти всегда выгоднее.
ENT.NavObstaclePenalty = 6
ENT.NavAvoidPenalty = 8
ENT.NavJumpPenalty = 3
ENT.NavLadderPenalty = 4
ENT.NavCrouchPenalty = 1
-- Предел подъёма и спуска на стыке площадей теперь решается один раз при
-- построении сетки, см. MuR.NPC.MaxRise / MaxDrop и MuR.NPC.BuildLinks.

-- Сколько секунд объезжать площадь, на которой NPC застрял.
ENT.NavAvoidDuration = 15
-- Сколько раз подряд застрять, прежде чем объезжать.
ENT.NavStuckLimit = 2
-- Сколько раз перестраивать путь по одному приказу, прежде чем сдаться.
ENT.GoalRetries = 5
ENT.GoalRetryDelay = 0.5

-- Минимум между построениями пути. Защита от того, чтобы гонять A* каждый тик.
ENT.PathComputeInterval = 0.25

-- Свой детектор «упёрся»: сдвинулся меньше ProgressDistance за ProgressTimeout,
-- хотя пытался идти.
ENT.ProgressDistance = 24
ENT.ProgressTimeout = 1.2
-- Сколько не проверять прогресс после старта пути: разворот и разгон.
ENT.ProgressGrace = 1.5

-- Перелаз через преграду (ограда, парапет, ящик).
ENT.VaultReach = 40 -- на сколько вперёд щупать преграду
ENT.VaultMaxDistance = 96 -- насколько далеко искать место приземления
-- Обязан совпадать с MuR.NPC.MaxRise: генератор стоимости пути обещает ровно
-- то, что исполняет перелаз.
ENT.VaultMaxHeight = MuR.NPC.MaxRise -- максимальный перепад высот
ENT.VaultArc = 45 -- высота дуги перелаза
ENT.VaultTime = 0.45 -- длительность подъёма на VaultRefHeight
-- Высота, на которой перелаз длится ровно VaultTime. Более высокие занимают
-- пропорционально дольше: на 128 юнитов за те же 0.45 с NPC телепортируется
-- вверх, а не залезает.
ENT.VaultRefHeight = 72
ENT.VaultMaxTime = 0.9
ENT.VaultAnim = ACT_JUMP

-- Куда пробовать сдвинуть точку приземления, если габарит не встал ровно в неё:
-- {назад, вбок}. Назад — это к наружному краю карниза, откуда мы подходим.
ENT.VaultFitOffsets = {
	{0, 0},
	{6, 0}, {12, 0},
	{0, 10}, {0, -10},
	{6, 16}, {6, -16},
}

-- Как часто щупать подъём: одна хулл-трасса на интервал.
ENT.ClimbProbeInterval = 0.25
-- Насколько близко должен быть поднимающийся сегмент пути, чтобы считать, что
-- уступ прямо перед нами.
ENT.ClimbSegmentReach = 90

-- Щуп преграды по курсу (двери и пропы). Одна хулл-трасса на интервал.
ENT.ProbeInterval = 0.3
ENT.ProbeReach = 40

-- Расталкивание физпропов. Толчок считается от массы пропа.
ENT.CanPushProps = true
ENT.PropPushForce = 14
ENT.PropPushMaxMass = 300
ENT.PropPushMaxSpeed = 150

-- Аварийный перенос: сколько секунд подряд не сдвинуться, прежде чем NPC
-- переставят на новое место.
ENT.StuckRelocateTime = 10
ENT.StuckRelocateDistance = 32 -- сдвиг, который считается движением
ENT.StuckRelocateRadius = 1500 -- где искать новое место
ENT.StuckRelocateMinDist = 160 -- ближе не переставляем: тот же тупик
-- Ближе этого к живому игроку не переставляем НИКОГДА. Вылезший из воздуха в
-- трёх метрах за спиной ничем не лучше телепорта на глазах.
ENT.RelocateMinPlayerDist = 700
-- Дальше этого игрок точку всё равно не разглядит, и проверку взгляда можно
-- не делать.
ENT.RelocateSightRange = 2500
-- Во сколько раз расширять поиск, если рядом всё занято игроками или их взглядом.
ENT.RelocateWideFactor = 2.5

--------------------------------------------------------------------------------
-- Сенсоры
--------------------------------------------------------------------------------

--
-- Дальность, на которой NPC вообще замечает цель. Не «дистанция боя»: стрелять
-- он начнёт с Weapon_Range, а сюда попадает решение «есть ли вообще с кем
-- воевать».
--
ENT.SightDistance = 6000
-- Сектор обзора. При включённом EnemyXRayDetection на ПОИСК цели он не влияет —
-- только на CanSee, которым пользуются оповещение своих и поиск по наводке.
ENT.SightAngle = 150
ENT.HearingDistance = 3000
--
-- Знать, где игроки, без прямой видимости.
--
-- Включено для ВСЕХ: разница между NPC должна быть в тактике, а не в том,
-- заметил он или нет. Без этого бой распадался на «увидел — не увидел»: боец за
-- углом продолжал патрулировать в трёх метрах от перестрелки, а орда зомби
-- расползалась искать игрока по всей карте вместо того, чтобы давить.
--
-- Осведомлённость не означает всеведение в бою: LOS всё равно решает, можно ли
-- стрелять (HasLOS), а подавление и поиск работают по СВОЕЙ отметке
-- LastLOSPos — «где я видел его глазами», а не по этой наводке.
--
ENT.EnemyXRayDetection = true
ENT.EnemyScanInterval = 0.5
ENT.EnemyLoseTime = 8 -- через сколько секунд без контакта враг забывается
-- Сколько ещё держится наводка «его видели вон там» после потери цели. Дольше
-- бежать к месту получасовой давности смысла нет.
ENT.EnemyMemoryTime = 20
-- Насколько близко к наводке надо подойти, чтобы считать её проверенной, и
-- сколько раз обернуться на месте, не найдя никого.
ENT.SearchReachedDist = 100
ENT.SearchLookCount = 3

--------------------------------------------------------------------------------
-- Укрытия
--------------------------------------------------------------------------------

-- Твари не прячутся; людям это включает bs_npc_human.
ENT.CanUseCover = false
ENT.CoverSearchRadius = 900
-- Не чаще этого: поиск дешёвый, но не бесплатный.
ENT.CoverSearchInterval = 1.5
-- Потолок трасс на один поиск. 60 точек это ~0.25 мс (замерено).
ENT.CoverSampleBudget = 60
-- Шаг сетки по крупной площади: её центр может быть в совсем другой обстановке,
-- чем края (замерены площади 75x700).
ENT.CoverSampleStep = 100
ENT.CoverStepDown = 80
ENT.CoverStepUp = 80
-- Не прятаться вплотную к тому, от кого прячешься.
ENT.CoverMinDistance = 120
-- Высота головы стоя и в приседе — по ним и считается, простреливают ли точку.
ENT.CoverEyeHeight = 60
ENT.CoverCrouchEyeHeight = 34
-- Насколько полное укрытие предпочтительнее низкого. Это скидка к цене пути, а
-- не абсолютный приоритет: бежать за идеальным углом через полкарты не надо.
ENT.CoverFullBonus = 0.75
-- Куда шагать из укрытия, чтобы выстрелить.
ENT.CoverPeekOffsets = {48, 80, 120}
-- Как далеко щупать стену укрытия: дальше этого «укрытие» уже не укрытие, а
-- просто дом на горизонте.
ENT.CoverWallProbe = 96
-- На сколько разносить боковые лучи проверки укрытия. Половина ширины корпуса:
-- иначе боец «прячется» за фонарным столбом, который уже него самого.
ENT.CoverWidthProbe = 16
-- Насколько близко к преграде вставать. Точка навмеша лежит в метре от стены, и
-- без притирки боец укрывается «около» укрытия, а не за ним.
ENT.CoverHugDistance = 20
-- Веер направлений щупа относительно направления на угрозу. Один луч промахивался
-- мимо углов зданий примерно в половине укрытий.
ENT.CoverWallAngles = {0, 30, -30, 60, -60, 90, -90}
-- Где искать точку, откуда цель видно, когда видимость потеряна. Меньше радиуса
-- поиска укрытий: идти за угол надо ближайшим путём, а не через полкарты.
ENT.FiringSpotRadius = 700

--------------------------------------------------------------------------------
-- Группа
--------------------------------------------------------------------------------

ENT.AlertsAllies = true
ENT.AllyAlertRadius = 1200
ENT.AllyAlertInterval = 3
-- Прикрытие перезаряжающегося: общий на отряд откат и на сколько берётся
-- обязательство. Откат общий, чтобы прикрывал один, а не весь отряд разом.
ENT.CoverCallInterval = 6
ENT.CoverCallDuration = 2.5
-- Как часто роль в стычке пересматривается. Реже — группа костенеет, чаще — NPC
-- меняет решение на ходу и топчется.
ENT.RoleReviewTime = 8
-- Углы обхода вокруг врага, в порядке предпочтения.
ENT.FlankAngles = {50, 80, 110}
ENT.FlankMinRadius = 250
ENT.FlankMaxRadius = 700
ENT.FlankReachedDist = 100
ENT.FlankHoldTime = 6
-- Пауза между обходами: дошёл до фланга — дерись оттуда, а не иди по кругу.
ENT.FlankRestTime = 5

--------------------------------------------------------------------------------
-- Огонь по своим
--------------------------------------------------------------------------------

-- Смотреть, не стоит ли свой на линии огня. Тварям без стволов не нужно,
-- стрелкам это включает bs_npc_human.
ENT.CheckLineOfFire = false
-- Полуширина «коридора пули». Считается по цилиндру, а не трассой: трасса ловит
-- только то, что ровно на луче, а очередь уходит с разбросом.
ENT.FireLaneRadius = 26
-- Куда пробовать шагнуть, чтобы освободить коридор.
ENT.FireLaneStepOffsets = {56, 96, 140}

-- Во сколько раз слабее своя же пуля. Проверка коридора снимает основную массу
-- попаданий по своим, но разброс остаётся, а шесть стволов по одной цели с
-- разных сторон рано или поздно сходятся друг на друге.
ENT.FriendlyFireScale = 0.1

--------------------------------------------------------------------------------
-- Анимации
--------------------------------------------------------------------------------

ENT.AnimTbl_Idle = nil
ENT.AnimTbl_Death = nil
ENT.AnimTbl_Flinch = nil
ENT.AnimTbl_MeleeAttack = nil
ENT.AnimTbl_RangeAttack = nil
ENT.AnimTbl_LeapAttack = nil

--------------------------------------------------------------------------------
-- Ближний бой
--------------------------------------------------------------------------------

ENT.HasMeleeAttack = true
ENT.MeleeAttackDamage = 20
ENT.MeleeAttackDamageType = DMG_SLASH
ENT.MeleeAttackDistance = 60
ENT.MeleeAttackDamageDistance = 70
ENT.MeleeAttackDamageAngle = 0.4 -- минимальный dot между взглядом и целью
ENT.MeleeAttackPlayerSpeed = false
-- Бить двери, физпропы и ломаемое. Режим 18 на это рассчитывает.
ENT.MeleeAttackDamageProps = true
-- Открывать незапертые двери, упёршись в них.
ENT.CanOpenDoors = true
-- На сколько запоминать дверь, которая не поддалась.
ENT.LockedDoorMemory = 20
ENT.DoorClearDistance = 72
ENT.DoorOpenWaitTime = 4
ENT.DoorJammedMemory = 10
--
-- Сколько секунд NPC считается ЗАНЯТЫМ разбором преграды.
--
-- Пока считается — он не застрявший: он стоит на месте намеренно. Без этого
-- сторож застревания через десять секунд уносил вышибающего дверь в другой
-- конец карты, и со стороны это выглядело как «NPC исчез, не доломав».
--
-- По истечении срока дверь признаётся безнадёжной: NPC перестаёт быть занятым,
-- обычный разбор застревания заносит площадь в объезд и строит маршрут заново.
--
ENT.ObstacleBreakTimeout = 20
-- На сколько вперёд щупать преграду хулл-трассой.
ENT.ObstacleReach = 40
ENT.HasMeleeAttackKnockBack = false
ENT.MeleeAttackKnockBackForce = 250
-- false = урон вешает событие анимации (OnAnimEvent -> ExecuteMeleeAttack),
-- число = задержка в секундах от начала анимации.
ENT.TimeUntilMeleeAttackDamage = 0.3
ENT.NextMeleeAttackTime = 1

--------------------------------------------------------------------------------
-- Дальний бой (снаряд)
--------------------------------------------------------------------------------

ENT.HasRangeAttack = false
ENT.RangeAttackEntityToSpawn = "murwep_grenade"
ENT.RangeDistance = 600
ENT.RangeToMeleeDistance = 300
ENT.RangeAttackSpeed = 900
ENT.RangeAttackOffset = Vector(0, 0, 48)
ENT.TimeUntilRangeAttackProjectileRelease = false
ENT.NextRangeAttackTime = 12

--------------------------------------------------------------------------------
-- Прыжковая атака
--------------------------------------------------------------------------------

ENT.HasLeapAttack = false
ENT.LeapAttackDistance = {200, 600}
ENT.LeapAttackDamage = 15
ENT.LeapAttackDamageType = DMG_SLASH
ENT.LeapAttackVelocity = 500
-- Сколько корутина поведения ждёт после прыжка, когда анимация задана как ACT_*
-- и своей длительности не имеет.
ENT.LeapAttackDuration = 1.2
ENT.TimeUntilLeapAttackVelocity = 0.2
ENT.TimeUntilLeapAttackDamage = 0.8
ENT.NextLeapAttackTime = 6

--------------------------------------------------------------------------------
-- Реакции
--------------------------------------------------------------------------------

ENT.CanFlinch = false
ENT.FlinchChance = 2
ENT.FlinchCooldown = 4

ENT.HasDeathAnimation = false
ENT.HasDeathCorpse = true
ENT.HasFootstepSounds = false
ENT.FootStepInterval = 0.4

--------------------------------------------------------------------------------
-- Звуки
--------------------------------------------------------------------------------

ENT.SoundTbl_FootStep = nil
ENT.SoundTbl_Idle = nil
ENT.SoundTbl_CombatIdle = nil
ENT.SoundTbl_Alert = nil
ENT.SoundTbl_Pain = nil
ENT.SoundTbl_Damage = nil
ENT.SoundTbl_Death = nil
ENT.SoundTbl_MeleeAttack = nil
ENT.SoundTbl_MeleeAttackMiss = nil
ENT.SoundTbl_BeforeMeleeAttack = nil

ENT.IdleSoundInterval = {8, 20}

ENT.SoundTbl_MeleeAttackExtra = nil
ENT.SoundTbl_BeforeRangeAttack = nil
ENT.SoundTbl_LeapAttackJump = nil
ENT.SoundTbl_Breath = nil
ENT.SoundTbl_Enrage = nil
ENT.SoundTbl_Swing = nil
ENT.SoundTbl_Grab = nil
ENT.SoundTbl_Feeding = nil

--------------------------------------------------------------------------------
-- Прочее
--------------------------------------------------------------------------------

-- Задержка перед снятием тела ПОСЛЕ анимации смерти. Нужна тем NPC, у
-- которых OnDeath сам расставляет гибы по своим таймерам.
ENT.DeathRemoveDelay = 0

-- Через сколько секунд убрать труп. 0 — не убирать.
ENT.CorpseFadeTime = 30

-- ACT -> ACT. Формат оставлен от VJ: self.AnimationTranslations[ACT_CLIMB_UP] = ACT_JUMP
ENT.AnimationTranslations = nil

--
-- Активити, при которых ноги обязан двигать BodyMoveXY, а не FrameAdvance.
--
-- Списком, а не двумя константами: у моделей с игроцкими анимациями ACT_WALK и
-- ACT_RUN отсутствуют ВООБЩЕ, ходьба у них лежит в ACT_HL2MP_*. Замерено на
-- моделях ЧВК — из обычных NPC-активити у них нет ни одного, даже ACT_IDLE.
--
ENT.MoveActivities = {
	[ACT_WALK] = true,
	[ACT_RUN] = true,
}

--
-- Чем заменять активити, которой у модели нет.
--
-- Не украшение: StartActivity с отсутствующей активити молча оставляет модель в
-- референс-позе. Замерено сразу на четырёх моделях — ACT_CLIMB_UP и
-- ACT_CLIMB_DOWN нет НИ У КОГО: ни у гражданских, ни у комбайна, ни у зомби, ни
-- у ЧВК. У зомби вдобавок нет ни ACT_RUN, ни ACT_JUMP. Отсюда и Т-поза на
-- лестнице, и сломанная ходьба после прыжка.
--
-- Цепочка идёт от точного к общему и обязана заканчиваться на ACT_IDLE: она
-- есть у всех.
--
ENT.ActivityFallbacks = {
	[ACT_CLIMB_UP] = ACT_JUMP,
	[ACT_CLIMB_DOWN] = ACT_JUMP,
	[ACT_JUMP] = ACT_GLIDE,
	[ACT_GLIDE] = ACT_RUN,
	[ACT_RUN] = ACT_WALK,
	[ACT_WALK] = ACT_IDLE,
	[ACT_RUN_CROUCH] = ACT_WALK,
	[ACT_COVER_LOW] = ACT_CROUCHIDLE,
	[ACT_CROUCHIDLE] = ACT_IDLE,
	[ACT_IDLE_ANGRY] = ACT_IDLE,
}

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		self:Draw()
	end
end
