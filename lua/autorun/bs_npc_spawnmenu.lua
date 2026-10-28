-- Регистрация своих NPC в Q-меню и общие звуки.
-- Заменяет lua/vj_base/plugins/vj_base_bloodshed_remastered.lua: VJ Base с его
-- VJ.AddNPC / VJ.AddNPCWeapon больше не нужен.

local CAT = "Bloodshed"
local CAT_NZ = "Bloodshed: Dark Aether"
local CAT_PMC = "Bloodshed: PMC"

MuR.NPC.Register("npc_bs_zombie", "Zombie", CAT)
MuR.NPC.Register("npc_bs_ptichki", "PTICHKI", CAT)

MuR.NPC.Register("npc_bs_police", "Police Officer", CAT, {"tfa_bs_glock", "tfa_bs_m9", "tfa_bs_p320", "tfa_bs_walther", "tfa_bs_m590", "tfa_bs_badger"})
MuR.NPC.Register("npc_bs_swat", "SWAT", CAT, {"tfa_bs_m1014", "tfa_bs_nova", "tfa_bs_mp5a5", "tfa_bs_sr25", "tfa_bs_m24", "tfa_bs_hk416", "tfa_bs_m4a1", "tfa_bs_acr"})

local PMC_WEAPONS = {"tfa_bs_acr", "tfa_bs_hk416", "tfa_bs_m4a1", "tfa_bs_mp5a5", "tfa_bs_sr25", "tfa_bs_m1014"}

MuR.NPC.Register("npc_bs_pmc", "PMC Grunt", CAT_PMC, PMC_WEAPONS)
MuR.NPC.Register("npc_bs_pmc_armored", "PMC Armored Grunt", CAT_PMC, PMC_WEAPONS)
MuR.NPC.Register("npc_bs_pmc_explosive", "PMC Explosive Unit", CAT_PMC, PMC_WEAPONS)
MuR.NPC.Register("npc_bs_pmc_juggernaut", "PMC Juggernaut", CAT_PMC, PMC_WEAPONS)
MuR.NPC.Register("npc_bs_pmc_flame", "PMC Flame Unit", CAT_PMC, PMC_WEAPONS)
MuR.NPC.Register("npc_bs_pmc_gas", "PMC Gas Unit", CAT_PMC, PMC_WEAPONS)

MuR.NPC.Register("npc_bs_nz_vermin", "Vermin", CAT_NZ)
MuR.NPC.Register("npc_bs_nz_mangler", "Mangler", CAT_NZ)
MuR.NPC.Register("npc_bs_nz_amalgam", "Amalgam", CAT_NZ)
MuR.NPC.Register("npc_bs_nz_mimic", "Shock Mimic", CAT_NZ)

--------------------------------------------------------------------------------
-- Звуки, которые раньше объявлял плагин VJ Base
--------------------------------------------------------------------------------

local deathSounds = {}
for i = 1, 104 do
	deathSounds[#deathSounds + 1] = ")murdered/player/deathmale/bullet/death_bullet" .. i .. ".ogg"
end

local gearSounds = {}
for i = 1, 6 do
	gearSounds[#gearSounds + 1] = "npc/combine_soldier/gear" .. i .. ".wav"
end

sound.Add({
	name = "BloodshedNPC_HumanDeath",
	level = 60,
	pitch = {90, 110},
	sound = deathSounds,
})

sound.Add({
	name = "BloodshedNPC_HumanFootstep",
	level = 60,
	pitch = {90, 110},
	sound = gearSounds,
	volume = 0.6,
})
