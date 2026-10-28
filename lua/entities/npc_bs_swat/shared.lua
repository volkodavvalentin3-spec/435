AddCSLuaFile()

ENT.Base = "npc_bs_police"
ENT.Type = "nextbot"
ENT.PrintName = "SWAT"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {
	"models/murdered/npc/swat/male_01.mdl",
	"models/murdered/npc/swat/male_02.mdl",
	"models/murdered/npc/swat/male_03.mdl",
	"models/murdered/npc/swat/male_04.mdl",
	"models/murdered/npc/swat/male_05.mdl",
	"models/murdered/npc/swat/male_06.mdl",
	"models/murdered/npc/swat/male_07.mdl",
	"models/murdered/npc/swat/male_08.mdl",
	"models/murdered/npc/swat/male_09.mdl",
}
ENT.StartHealth = 125

-- Модель штурма — комбайновский набор. Пистолетных поз у неё нет вовсе, как и
-- обычных ACT_WALK/ACT_RUN, поэтому и набор анимаций другой, и трансляции ниже
-- нужны на случай, когда оружия в руках нет.
ENT.AnimSet = "combine"

ENT.AnimationTranslations = {
	[ACT_WALK] = ACT_WALK_RIFLE,
	[ACT_RUN] = ACT_RUN_RIFLE,
	[ACT_IDLE] = ACT_IDLE_ANGRY,
}

ENT.DefaultWeapons = {
	"tfa_bs_m1014", "tfa_bs_nova", "tfa_bs_mp5a5", "tfa_bs_sr25",
	"tfa_bs_m24", "tfa_bs_hk416", "tfa_bs_m4a1", "tfa_bs_acr",
}

ENT.AnimTbl_MeleeAttack = {"melee_gunhit"}
ENT.DoorKickAnim = "melee_gunhit"
ENT.DoorKickSetBack = false

-- Штурм не уговаривает и не возит тазер.
ENT.HaveTaser = false
