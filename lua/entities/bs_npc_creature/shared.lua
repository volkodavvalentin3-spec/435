AddCSLuaFile()

ENT.Base = "bs_npc_base"
ENT.Type = "nextbot"
ENT.PrintName = "Bloodshed Creature Base"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = false

ENT.IsBloodshedCreature = true

ENT.Faction = "zombie"

-- Твари не стреляют и лезут в упор, поэтому сектор обзора полный: иначе они
-- теряют игрока, который забежал им за спину в двух метрах.
ENT.SightAngle = 360
-- Дальность берём от базы: твари знают, где игроки, как и все остальные.

ENT.WalkSpeed = 65
ENT.RunSpeed = 220

ENT.HasMeleeAttack = true
ENT.CanWander = true
-- Пауза, когда до врага не дойти: тварь топчется в его сторону, но не жжёт
-- поиск пути каждый тик.
ENT.UnreachablePause = 1
ENT.WanderRadius = 1200
ENT.WanderInterval = {3, 8}

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
end
