local meta = FindMetaTable('Player')
local meta2 = FindMetaTable('Entity')

function meta:CanBecomeWanted()
	local mode = MuR.Mode and MuR.Mode(SERVER and MuR.Gamemode or MuR.GamemodeCount) or {}
	if mode.no_wanted_until_assault then
		local state = SERVER and MuR.PoliceState or (MuR.Data and MuR.Data["PoliceState"]) or 0
		if state < 4 then return false end
	end
	return true
end

function meta:IsCuffed()
	return self:GetNW2Bool("MuR.Cuffed", false)
end

function meta:IsZipTied()
	return self:GetNW2Bool("MuR.Zipped", false)
end

function meta:IsRestrained()
	return self:IsCuffed() or self:IsZipTied()
end

function meta:IsExecuting()
    return tobool(string.find(self:GetSVAnim(), "executions")) or tobool(string.find(self:GetSVAnim(), "hatred"))
end

function meta2:GetSVAnim()
	if self:IsPlayer() then
		return self:GetNW2String('SVAnim', '')
	else
		return self:GetNW2String('SVAnim', '')
	end
end

function meta2:IsProp()
	return self:GetClass() == "prop_dynamic" or self:GetClass() == "prop_physics" or self:GetClass() == "prop_physics_multiplayer" or self:GetClass() == "prop_physics_override"
end

function meta2:IsRolePolice()
    local class = self:GetNW2String('Class')
    local roleData = MuR:GetRole(class)
    if roleData and roleData.group == "police" then return true end
	if self:IsPlayer() then
		return self:GetNW2String('Class') == "Riot" or self:GetNW2String('Class') == "Officer" or self:GetNW2String('Class') == "ArmoredOfficer" or self:GetNW2String('Class') == "FBI"
	else
		return self:GetNW2String('Class') == "Riot" or self:GetNW2String('Class') == "Officer" or self:GetNW2String('Class') == "ArmoredOfficer" or self:GetNW2String('Class') == "FBI"
	end
end

function meta:IsRoleWithoutOrgans()
	if !IsValid(self) then return false end
	return self:GetNW2String('Class') == "Zombie" or self:GetNW2String('Class') == "Maniac" or self:GetNW2String('Class') == "Entity"
end

function meta2:HaveStability()
	if self:IsPlayer() then
		return self:GetNW2String('Class') == "Killer" or self:GetNW2String('Class') == "Traitor"
	else
		return self:GetNW2String('Class') == "Killer" or self:GetNW2String('Class') == "Traitor"
	end
end

function meta2:IsKiller()
    local class = self:GetNW2String('Class')
    local roleData = MuR:GetRole(class)
	return roleData and roleData.killer or false
end

function meta2:IsActiveKiller()
	return roleData and roleData.killer == "active"
end

function MuR:CheckCollision(pos, ply)
	if !isvector(pos) and IsValid(ply) then
		pos = ply:GetPos()
	end
	local tr = util.TraceHull({
		start = pos,
		endpos = pos,
		filter = function(ent)
			return ent:GetClass() != "prop_ragdoll" and (IsValid(ply) and ent != ply or !IsValid(ply))
		end,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		mask = MASK_PLAYERSOLID,
	})
	return tr.Hit, tr.Entity
end

function MuR:GetAlivePlayers()
	local tab, tab2 = {}, player.GetAll()

	for i = 1, #tab2 do
		if tab2[i]:Alive() then
			tab[#tab + 1] = tab2[i]
		end
	end

	return tab
end

function MuR:VisibleByNPCs(pos)
	for _, ent in ipairs(ents.FindByClass("npc_combine_s")) do
		local tr = util.TraceLine({
			start = ent:EyePos(),
			endpos = pos,
			filter = function(ent)
				if ent:IsPlayer() or MuR.IsAI(ent) then
					return false
				else
					return true
				end
			end,
			mask = MASK_SHOT,
		})

		if not tr.Hit and pos:DistToSqr(ent:GetPos()) <= 500 ^ 2 then return true end
	end

	return false
end

function MuR:VisibleByPlayers(ply, ent1)
	local tab = MuR:GetAlivePlayers()

	for i = 1, #tab do
		local ent = tab[i]
		if ent == ply or ent == ent1 then continue end

		local tr = util.TraceLine({
			start = ent:EyePos(),
			endpos = ply:WorldSpaceCenter(),
			filter = function(ent)
				if ent:IsPlayer() or MuR.IsAI(ent) then
					return false
				else
					return true
				end
			end,
			mask = MASK_SHOT,
		})

		if not tr.Hit then return true end
	end

	return false
end

function MuR:DisablesGamemode()
	local def = MuR.Mode(MuR.Gamemode)
	if def.disables ~= nil then return def.disables end
	return false
end

function MuR:DisableWeaponLoot()
	local def = MuR.Mode(MuR.Gamemode)
	if def.disable_loot ~= nil then return def.disable_loot end
	return false
end

function MuR:CountNPCPolice(alive)
	local count = MuR.NPC_To_Spawn
	if alive then
		count = 0
	end
	-- Все свои NPC давно под одним префиксом: маска npc_vj_bloodshed_* осталась
	-- от миграции с VJ Base и не могла совпасть ни с чем — классов нет.
	return count + #ents.FindByClass("npc_bs_*")
end

function MuR:CountPlayerPolice()
	local tab = player.GetAll()
	local alive = 0
	local dead = 0
	for i=1,#tab do
		local ply = tab[i]
		if ply:GetNW2String('Class') == "ArmoredOfficer" or ply:GetNW2String('Class') == 'Officer' then
			if ply:Alive() then
				alive = alive + 1
			else
				dead = dead + 1
			end
		end
	end
	return alive, dead
end

hook.Add("SetupMove", "MuR.AimSpeed", function(ply, mvd, cmd)
	local wep = ply:GetActiveWeapon()

	if IsValid(wep) and wep:GetNW2Bool('Aiming') then
		mvd:SetMaxSpeed(50)
		mvd:SetMaxClientSpeed(50)
	end
	if string.match(ply:GetSVAnim(), "sequence_ron_") then
		mvd:SetMaxSpeed(1)
		mvd:SetMaxClientSpeed(1)
	end
end)

hook.Add("EntityEmitSound", "MuR.BlockPickupSound", function(t)
	if t.SoundName == "items/ammo_pickup.wav" then
		return false
	end
end)

local function FindModelsRecursive(path)
    local models = {}
    local files, folders = file.Find(path .. "/*", "WORKSHOP")
    files = files or {}
    folders = folders or {}
    for _, f in ipairs(files) do
        if string.EndsWith(f, ".mdl") then
            table.insert(models, path .. "/" .. f)
        end
    end
    for _, folder in ipairs(folders) do
        local subModels = FindModelsRecursive(path .. "/" .. folder)
        for _, m in ipairs(subModels) do
            table.insert(models, m)
        end
    end
    return models
end

local precachedModels = 0
local allModels = FindModelsRecursive("models")
for _, mdl in ipairs(allModels) do
    if precachedModels > 4096 then break end
    util.PrecacheModel(mdl)
    precachedModels = precachedModels + 1
end
print("[Bloodshed: Redux] Precached " .. precachedModels .. " models.")

game.AddParticles("particles/blood_impact.pcf")
PrecacheParticleSystem("blood_advisor_pierce_spray")
PrecacheParticleSystem("blood_impact_red_01_droplets")
PrecacheParticleSystem("vomit_barnacle")

MuR.CreateParticleSystemOld = MuR.CreateParticleSystemOld or nil
if not MuR.CreateParticleSystemOld then
	MuR.CreateParticleSystemOld = CreateParticleSystem
	function CreateParticleSystem(ent, eff, attachtype, attachment, offset)
		MuR.CreateParticleSystemOld(ent, eff, attachtype, attachment)
	end
end
