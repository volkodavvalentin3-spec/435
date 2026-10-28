AddCSLuaFile()

-- Заглушки под методы движковых NPC.
--
-- Геймдмод местами проверяет MuR.IsAI(ent), а внутри ветки дёргает метод,
-- который есть только у NPC движка. Раньше эти ветки видели VJ-NPC и всё
-- работало; теперь туда попадают и наши nextbot. Ветки перечислены по месту
-- вызова, чтобы было видно, зачем каждая заглушка нужна.
--
-- Файл общий, а не серверный: клиентский cl_litewounds.lua тоже дёргает
-- GetActiveWeapon на том, кто нанёс урон.

-- sv_deathragdoll.lua: выбор анимации смерти "на бегу".
function ENT:GetIdealMoveSpeed()
	if not self.loco then return 0 end

	return self.loco:GetDesiredSpeed()
end

-- sv_functions.lua: направление отброса, когда урон пришёл без силы.
-- Для nextbot прицел совпадает с направлением корпуса.
function ENT:GetAimVector()
	return self:GetForward()
end

-- Player:Alive() метод игрока, но проверку живости зовут и на цели вообще.
function ENT:Alive()
	return self:Health() > 0
end

-- sv_reverb.lua (EntityFireBullets), mur_handcuffs.lua, sh_kicks.lua.
-- Своей оружейной системы у твари нет; людям её вернёт этап 3, переопределив
-- этот метод в bs_npc_human.
function ENT:GetActiveWeapon()
	return NULL
end

function ENT:DropWeapon()
end

-- Тасков движка у nextbot нет: способности задаются полями базы. Заглушки
-- нужны только чтобы чужой код не падал на вызове.
function ENT:CapabilitiesAdd()
end

function ENT:CapabilitiesClear()
end

function ENT:CapabilitiesGet()
	return 0
end
