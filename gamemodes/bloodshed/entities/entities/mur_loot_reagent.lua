AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Chemical Reagent"
ENT.Category = "Bloodshed - Loot"
ENT.Spawnable = true
ENT.IsLoot = true

if SERVER then
    function ENT:Initialize()
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        self:SetUseType(SIMPLE_USE)

        local ingredient = self:PickRandomIngredient()
        if ingredient then
            self:SetIngredient(ingredient)
        else
            self:Remove()
        end
    end

    function ENT:PickRandomIngredient()
        local totalChance = 0
        local candidates = {}

        for id, data in pairs(MuR.Crafting.Ingredients) do
            if data.lootChance and data.lootChance > 0 then
                totalChance = totalChance + data.lootChance
                table.insert(candidates, {id = id, chance = data.lootChance})
            end
        end

        if totalChance <= 0 then return nil end

        local roll = math.random() * totalChance
        local current = 0

        for _, item in ipairs(candidates) do
            current = current + item.chance
            if roll <= current then
                return item.id
            end
        end

        return candidates[#candidates].id
    end

    function ENT:SetIngredient(id)
        local data = MuR.Crafting.Ingredients[id]
        if not data then return end

        self.IngredientID = id
        self.IsCraftingIngredient = true
        self:SetModel(data.model or "models/props_lab/jar01a.mdl")

        self:PhysicsInit(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self:SetNWString("PrintName", data.name)
    end

    function ENT:Use(activator, caller)
        if IsValid(activator) and activator:IsPlayer() then
            MuR.Crafting:PickupIngredient(activator, self)
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end

    function ENT:GetOverlayText()
        return self:GetNWString("PrintName", "Reagent")
    end
end
