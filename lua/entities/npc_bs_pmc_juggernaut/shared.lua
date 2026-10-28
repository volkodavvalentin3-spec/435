AddCSLuaFile()

ENT.Base = "npc_bs_pmc"
ENT.Type = "nextbot"
ENT.PrintName = "PMC Juggernaut"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/npc/amb/grunt_pm.mdl"}

ENT.StartHealth = 500

function ENT:GetSpawnWeapons()
	return {"tfa_bs_m249"}
end

ENT.ArmorMaxHP = 500
ENT.ArmorReduction = 0.5

-- Гранат нет: он и есть штурмовое средство.
ENT.GrenadeChance = 0

-- Хватает любого, до кого дотянулся, а не только сбитого с ног.
ENT.CaptureAnyInMelee = true
ENT.CaptureRange = 95

-- Всегда прёт вперёд, розыгрыш архетипа не применяется.
ENT.ForcedArchetype = "rusher"

-- Такую тушу с ног не сбить.
ENT.CanFlinch = false

-- Тяжёлый: ходит медленнее обычного наёмника, но и не останавливается.
ENT.WalkSpeed = 50
ENT.RunSpeed = 150

--
-- И не пятится: пулемёт бьёт в упор не хуже, чем издали, а отход спиной вперёд
-- у самого медленного бойца отряда — это просто подставленная спина.
--
ENT.Weapon_HoldsGround = true

-- В укрытия не играет — идёт напролом.
ENT.CanUseCover = false
