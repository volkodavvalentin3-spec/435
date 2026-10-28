AddCSLuaFile()

ENT.Base = "bs_npc_human"
ENT.Type = "nextbot"
ENT.PrintName = "PMC Grunt"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.IsPMCEnemy = true

ENT.Model = {"models/murdered/npc/amb/epsilon6_village_idiots.mdl"}
ENT.StartHealth = 50
ENT.Faction = "pmc"

ENT.RandomSkins = true
ENT.RandomBodygroups = true

--
-- Модели ЧВК собраны на скелете ИГРОКА. Замерено на всех шести: обычных
-- NPC-активити у них нет НИ ОДНОЙ, включая ACT_IDLE, ACT_WALK и ACT_RUN —
-- всё лежит в ACT_HL2MP_*.
--
ENT.AnimSet = "player"

--
-- Поэтому же переводятся активити, которые база зовёт по именам напрямую.
-- Без трансляции такой NPC стоит в референс-позе: запрошенной активити в
-- модели просто нет, и StartActivity ничего не находит.
--
ENT.AnimationTranslations = {
	[ACT_IDLE] = ACT_HL2MP_IDLE_SMG1,
	[ACT_IDLE_ANGRY] = ACT_HL2MP_IDLE_SMG1,
	[ACT_WALK] = ACT_HL2MP_WALK_SMG1,
	[ACT_RUN] = ACT_HL2MP_RUN_SMG1,
	[ACT_JUMP] = ACT_HL2MP_JUMP_SMG1,
	[ACT_GLIDE] = ACT_HL2MP_JUMP_SMG1,
	[ACT_CLIMB_UP] = ACT_HL2MP_JUMP_SMG1,
	[ACT_CLIMB_DOWN] = ACT_HL2MP_JUMP_SMG1,
	[ACT_COVER_LOW] = ACT_HL2MP_IDLE_CROUCH_SMG1,
	[ACT_RUN_CROUCH] = ACT_HL2MP_WALK_CROUCH_SMG1,
}

-- Ноги перебирает BodyMoveXY только на этих активити.
ENT.MoveActivities = {
	[ACT_HL2MP_WALK_SMG1] = true,
	[ACT_HL2MP_RUN_SMG1] = true,
	[ACT_HL2MP_WALK_PISTOL] = true,
	[ACT_HL2MP_RUN_PISTOL] = true,
	[ACT_HL2MP_WALK_SHOTGUN] = true,
	[ACT_HL2MP_RUN_SHOTGUN] = true,
	[ACT_HL2MP_WALK_MELEE] = true,
	[ACT_HL2MP_RUN_MELEE] = true,
	[ACT_HL2MP_WALK_CROUCH_SMG1] = true,
}

-- Перелаз играется прыжком игрока: ACT_JUMP у этих моделей нет.
ENT.VaultAnim = ACT_HL2MP_JUMP_SMG1
ENT.LadderActivity = ACT_HL2MP_JUMP_SMG1

--
-- Список стволов — ФУНКЦИЯ, а не таблица, и это важно. GMod при наследовании
-- сливает табличные поля поэлементно, а не заменяет: у джаггернаута с одним
-- пулемётом в списке оставались хвостом стволы базового наёмника, и он
-- выходил с УМП. Функции заменяются целиком.
--
function ENT:GetSpawnWeapons()
	return {"tfa_bs_mp5a5", "tfa_bs_ump", "tfa_bs_vector", "tfa_bs_badger", "tfa_bs_spas"}
end

-- Сквозное чутьё и дальность теперь общие для всех NPC, см. bs_npc_base.

ENT.CanFlinch = true
ENT.FlinchChance = 2
ENT.FlinchCooldown = 8
ENT.AnimTbl_Flinch = {"mur_getup1", "mur_getup2", "mur_getup3", "zombie_slump_rise_02_fast"}

ENT.AnimTbl_MeleeAttack = {"seq_meleeattack01", "seq_throw", "mur_legsweep"}
ENT.MeleeAttackDamage = 40

ENT.Weapon_Accuracy = 2
-- ЧВК бьют вдвое слабее паспортного урона ствола: те же TFA-данные делит SWAT,
-- а режиму нужен более мягкий противник. Все варианты (armored, juggernaut и
-- далее) наследуют поле через ENT.Base. Ближний бой не режем.
ENT.Weapon_DamageScale = 0.5
ENT.Weapon_RetreatDistance = 150

ENT.SoundTbl_FootStep = {
	"player/footsteps/concrete1.wav", "player/footsteps/concrete2.wav",
	"player/footsteps/concrete3.wav", "player/footsteps/concrete4.wav",
}
ENT.SoundTbl_Damage = {
	"vo/npc/male01/pain01.wav", "vo/npc/male01/pain02.wav", "vo/npc/male01/pain03.wav",
	"vo/npc/male01/pain04.wav", "vo/npc/male01/pain05.wav", "vo/npc/male01/pain06.wav",
	"vo/npc/male01/pain07.wav", "vo/npc/male01/pain08.wav", "vo/npc/male01/pain09.wav",
}

--------------------------------------------------------------------------------
-- Броня
--------------------------------------------------------------------------------

-- Ломаемая броня поверх здоровья: поглощает долю урона, пока цела.
ENT.ArmorMaxHP = 0
ENT.ArmorReduction = 0

--------------------------------------------------------------------------------
-- Гранаты
--------------------------------------------------------------------------------

--
-- Шанс броска на попытку, в процентах. 0 отключает.
--
-- Считать надо вместе с GrenadeTryInterval и общим откатом: 5% раз в три
-- секунды — это одна граната в минуту с человека, то есть на глаз их нет вовсе.
-- Ограничивает частоту именно общий откат отряда, а не персональный шанс,
-- поэтому шанс высокий, а откат длинный.
--
ENT.GrenadeChance = 30
ENT.GrenadeEntity = "murwep_grenade"
ENT.GrenadeMinDistance = 350
ENT.GrenadeMaxDistance = 1200
ENT.GrenadeSpeed = 900
ENT.GrenadeOffset = Vector(0, 0, 48)
-- Как часто ОДИН NPC вообще пробует бросить.
ENT.GrenadeTryInterval = 2
-- Общий на всех откат по типу гранаты: иначе отряд закидывает игрока десятком
-- разом. Ключ и длительность задаёт вариант.
ENT.GrenadeSharedKey = "frag"
ENT.GrenadeSharedCooldown = 8
-- Сколько цель должна просидеть вне видимости, прежде чем её начнут выкуривать
-- гранатой вслепую по последнему месту. Ради этого гранаты и нужны.
ENT.GrenadeFlushTime = 2.5
-- Какую долю пути до укрытия граната обязана пролететь, чтобы бросок вообще
-- имел смысл: иначе она отскакивает от стены перед носом бросающего.
ENT.GrenadeFlushClearance = 0.65
-- Сколько секунд после броска убегать от собственной гранаты.
ENT.GrenadeFleeTime = {1.8, 2.6}

--------------------------------------------------------------------------------
-- Пленение сбитых
--------------------------------------------------------------------------------

-- Сбитого с ног игрока наёмники не добивают, а связывают стяжкой.
ENT.CanCapture = true
ENT.CaptureRange = 85
--
-- true — вязать любого, до кого ДОТЯНУЛИСЬ ударом, а не только сбитого.
--
-- Именно «дотянулись»: погоня за пленным начинается только по сбитому. Пока
-- флаг означал «хочу связать вообще», джаггернаут не стрелял из пулемёта ни
-- разу — запрет огня по будущему пленному стоял на нём всё время боя, и он
-- просто бегал за игроком с намерением схватить.
--
ENT.CaptureAnyInMelee = false
ENT.CaptureRetryDelay = 0.4

-- Брать живым не только сбитого, но и добитого до предела одиночку: отряду
-- пленный ценнее трупа, а отбиться ему всё равно нечем.
ENT.CaptureHelpless = true
-- Ниже этой доли здоровья цель считается беспомощной.
ENT.CaptureWoundedFraction = 0.3
-- И в этом радиусе не должно быть живых напарников, способных вмешаться.
ENT.CaptureLonelyRadius = 900
-- Дальше этого за пленным не идут: запрет огня дистанции не знает, и наёмник с
-- другого конца карты просто стоял бы со стволом вниз.
ENT.CaptureHelplessRange = 1200

--------------------------------------------------------------------------------
-- Архетипы поведения
--------------------------------------------------------------------------------

--
-- Каждый наёмник при спавне получает манеру боя. Это дешёвый способ сделать
-- отряд неоднородным: одни лезут в упор, другие держат дистанцию.
--
-- ForcedArchetype у варианта перекрывает розыгрыш.
--
ENT.PMCArchetypes = {
	{id = "rusher", weight = 15},
	{id = "cautious", weight = 30},
	{id = "squad", weight = 30},
	{id = "ambusher", weight = 25},
}
ENT.ForcedArchetype = nil
-- Манера наступления в обход архетипа: бронированный держит позицию, каким бы
-- ни выпал архетип, потому что она у него от брони, а не от характера.
ENT.ForcedAdvanceStyle = nil

--------------------------------------------------------------------------------
-- Засада
--------------------------------------------------------------------------------

-- Где искать точку с обзором и сколько её потом держать.
ENT.AmbushSearchRadius = 900
ENT.AmbushHoldTime = {25, 50}
-- Сколько направлений щупать и с какой дальности точка считается «с обзором».
ENT.AmbushProbeCount = 8
ENT.AmbushProbeRange = 1100
-- Меньше стольких открытых направлений — это не позиция, а угол.
ENT.AmbushMinOpen = 3

-- Ниже этой доли здоровья наёмник переходит к осторожной манере независимо от
-- архетипа. У напористых порог ниже — они упрямее.
ENT.WoundedThreshold = 0.35
ENT.WoundedThresholdRusher = 0.2
ENT.WoundedRetreatDistance = 280

--------------------------------------------------------------------------------
-- Вышибание запертых дверей
--------------------------------------------------------------------------------

ENT.CanKickDoors = true
ENT.KickAnim = "kick_pistol_45"
ENT.KickReach = 42
ENT.KickCooldown = {6, 10}
ENT.KickDamage = {200, 300}
