AddCSLuaFile()

ENT.Base = "npc_bs_pmc"
ENT.Type = "nextbot"
ENT.PrintName = "PMC Armored Grunt"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/npc/amb/opt_pm.mdl"}

ENT.StartHealth = 100

function ENT:GetSpawnWeapons()
	return {"tfa_bs_m1014", "tfa_bs_sr25", "tfa_bs_aug", "tfa_bs_g3", "tfa_bs_sg552", "tfa_bs_mk17", "tfa_bs_m4a1"}
end

ENT.ArmorMaxHP = 100
ENT.ArmorReduction = 0.25

--
-- Граната — его основной инструмент, а не редкость.
--
-- Он держит позицию и не бежит на цель, так что вскрывать чужое укрытие ему
-- больше нечем. При шансе 2% на попытку раз в две с половиной секунды бросок
-- случался в среднем раз в две минуты, то есть не случался вовсе.
--
ENT.GrenadeChance = 60
ENT.GrenadeMinDistance = 400
ENT.GrenadeMaxDistance = 1100

-- Держит позицию, откуда бьёт: за счёт брони может себе это позволить.
ENT.ForcedAdvanceStyle = "hold"

-- Осколочная без разброса типа: у бронированного всегда обычная граната.
function ENT:OnGrenadeAttackExecute(nade)
	if not IsValid(nade) then return end

	nade.F1 = false
end
