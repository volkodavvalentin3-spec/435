AddCSLuaFile()

ENT.Base = "bs_npc_human"
ENT.Type = "nextbot"
ENT.PrintName = "RoR Suspect"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

--
-- Подозреваемый/гражданский режима «Розыск» (RoR). Порт
-- npc_vj_bloodshed_suspect на bs_npc_human. Роль — гражданский или
-- подозреваемый, включая скрытого гражданского с оружием — разыгрывается в
-- CustomOnInitialize (sv_profile.lua).
--
ENT.IsRoNSuspect = true

-- Синоним VJ-метода: mode14 по имени секвенции отличает убитого сдавшегося
-- (score «suspect_killed_surrendering»). GetSequenceName есть у всех.
function ENT:GetSVAnim()
	return self:GetSequenceName(self:GetSequence()) or ""
end

-- До розыгрыша роли фракция не выставляется: её задаст профиль. Подозреваемые
-- воюют с полицией и игроками, гражданские не воюют ни с кем, кроме зомби.
ENT.Faction = "suspect"

ENT.Model = {
	"models/murdered/pm/citizen/male_01.mdl",
	"models/murdered/pm/citizen/male_02.mdl",
	"models/murdered/pm/citizen/male_03.mdl",
	"models/murdered/pm/citizen/male_04.mdl",
	"models/murdered/pm/citizen/male_05.mdl",
	"models/murdered/pm/citizen/male_06.mdl",
	"models/murdered/pm/citizen/male_07.mdl",
	"models/murdered/pm/citizen/male_08.mdl",
	"models/murdered/pm/citizen/male_09.mdl",
	"models/murdered/pm/citizen/male_10.mdl",
	"models/murdered/pm/citizen/male_11.mdl",
}

ENT.StartHealth = 50
ENT.SightDistance = 2000

--
-- Модели собраны на скелете ИГРОКА: как и у ЧВК, обычных NPC-активити у них
-- нет, всё лежит в ACT_HL2MP_*. См. npc_bs_pmc/shared.lua — наборы идентичны.
--
ENT.AnimSet = "player"

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

ENT.VaultAnim = ACT_HL2MP_JUMP_SMG1
ENT.LadderActivity = ACT_HL2MP_JUMP_SMG1

--------------------------------------------------------------------------------
-- Оружие
--------------------------------------------------------------------------------

--
-- Чем вооружаться при спавне из Q-меню. Режим (mode14) выдаёт стволы сам,
-- СИНХРОННО сразу после Spawn — до отложенной выдачи PostInitialize.
-- Гражданским профиль обнуляет таблицу в CustomOnInitialize.
--
ENT.DefaultWeapons = {"bswep_sus_primary", "bswep_sus_secondary", "bswep_sus_melee"}

-- Подозреваемый стреляет в полную силу (в отличие от ЧВК, у которых 0.5).
ENT.Weapon_DamageScale = 1

-- Точность задаёт личность (sv_profile.lua). Напоминание: БОЛЬШЕ = ХУЖЕ.
ENT.Weapon_Accuracy = 1

ENT.AnimTbl_MeleeAttack = {"seq_meleeattack01", "seq_throw", "mur_legsweep"}
ENT.MeleeAttackDamage = 20
ENT.NextMeleeAttackTime = MuR.Range(2, 4)

--------------------------------------------------------------------------------
-- Тактика
--------------------------------------------------------------------------------

-- Подозреваемые попроще ЧВК: наступают прямо, укрытиями пользуются умеренно.
ENT.AdvanceStyle = "rush"
ENT.CanWander = true

--------------------------------------------------------------------------------
-- Флинтч
--------------------------------------------------------------------------------

ENT.CanFlinch = true
-- Шанс в процентах: подозреваемый вздрагивает от попаданий редко.
ENT.FlinchChance = 1
ENT.FlinchCooldown = 8
-- Жесты на скелете игрока; если у модели секвенции нет, PlayAnim молча
-- пропустит флинтч.
ENT.AnimTbl_Flinch = {"vjges_flinch_phys_01", "vjges_flinch_phys_02"}

--------------------------------------------------------------------------------
-- Гранаты
--------------------------------------------------------------------------------

-- Бросают только агрессивные; флаг выставляет профиль. Механика портирована
-- с ЧВК, но общий откат СВОЙ: подозреваемые и наёмники не должны делить окно.
ENT.GrenadeChance = 25
ENT.GrenadeEntity = "murwep_grenade"
ENT.GrenadeMinDistance = 350
ENT.GrenadeMaxDistance = 1200
ENT.GrenadeSpeed = 900
ENT.GrenadeOffset = Vector(0, 0, 48)
ENT.GrenadeTryInterval = 3
ENT.GrenadeSharedKey = "susfrag"
ENT.GrenadeSharedCooldown = 10
ENT.GrenadeFlushTime = 3
ENT.GrenadeFlushClearance = 0.65
ENT.GrenadeFleeTime = {1.5, 2.2}

--------------------------------------------------------------------------------
-- Звуки
--------------------------------------------------------------------------------

-- Выстрелы, шаги, урон — стандартные для людей.
ENT.SoundTbl_Death = "BloodshedNPC_HumanDeath"
ENT.SoundTbl_FootStep = {
	"player/footsteps/concrete1.wav", "player/footsteps/concrete2.wav",
	"player/footsteps/concrete3.wav", "player/footsteps/concrete4.wav",
}
ENT.SoundTbl_Damage = {
	"vo/npc/male01/pain01.wav", "vo/npc/male01/pain02.wav", "vo/npc/male01/pain03.wav",
	"vo/npc/male01/pain04.wav", "vo/npc/male01/pain05.wav", "vo/npc/male01/pain06.wav",
	"vo/npc/male01/pain07.wav", "vo/npc/male01/pain08.wav", "vo/npc/male01/pain09.wav",
}

-- Увидел цель: SetEnemy проигрывает таблицу сам.
ENT.SoundTbl_Alert = {
	"vo/npc/male01/watchout.wav",
	"vo/npc/male01/overhere01.wav",
	"vo/npc/male01/headsup01.wav",
	"vo/npc/male01/cps01.wav",
	"vo/npc/male01/cps02.wav",
	"vo/npc/male01/gethellout.wav",
	"vo/npc/male01/getdown02.wav",
	"vo/npc/male01/civilprotection01.wav",
	"vo/npc/male01/civilprotection02.wav",
	"vo/npc/male01/headsup02.wav",
}

-- Бормотание без цели.
ENT.SoundTbl_Idle = {
	"vo/npc/male01/question02.wav",
	"vo/npc/male01/question05.wav",
}

-- Сдача. Подменяется гражданской у мирных в sv_profile.lua.
ENT.SoundTbl_Surrender = {
	"vo/npc/male01/goodgod.wav",
	"vo/npc/male01/ohno.wav",
	"vo/npc/male01/pleaseno.wav",
	"vo/npc/male01/gordead_ans01.wav",
	"vo/npc/male01/gordead_ans04.wav",
	"vo/npc/male01/gordead_ans03.wav",
	"vo/npc/male01/onyourside.wav",
	"vo/npc/male01/gordead_ans19.wav",
	"vo/npc/male01/gordead_ans15.wav",
	"vo/npc/male01/gordead_ans12.wav",
	"vo/npc/male01/gordead_ans11.wav",
	"vo/npc/male01/gordead_ans10.wav",
	"vo/npc/male01/gordead_ans06.wav",
	"vo/npc/male01/gordead_ans05.wav",
}

-- Страх гражданских.
ENT.SoundTbl_Fear = {
	"vo/npc/male01/ohno.wav",
	"vo/npc/male01/help01.wav",
	"vo/npc/male01/runforyourlife01.wav",
	"vo/npc/male01/runforyourlife02.wav",
	"vo/npc/male01/runforyourlife03.wav",
}

-- Добил цель.
ENT.SoundTbl_Kill = {
	"vo/npc/male01/gotone.wav",
	"vo/npc/male01/yeah02.wav",
	"vo/npc/male01/likethat.wav",
}

-- Предупреждение о своей гранате.
ENT.SoundTbl_Grenade = {
	"vo/npc/male01/overthere01.wav",
	"vo/npc/male01/overthere02.wav",
	"vo/npc/male01/takecover02.wav",
}

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
end
