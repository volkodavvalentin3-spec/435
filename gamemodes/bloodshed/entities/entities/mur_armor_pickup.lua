AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Armor Pickup"
ENT.Spawnable = false

ENT.ArmorId = ""

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ArmorId")
end

function ENT:Initialize()
    if SERVER then
        local armorId = self.ArmorId
        if armorId and armorId ~= "" then
            self:SetArmorId(armorId)
        else
            armorId = self:GetArmorId()
        end

        local item = MuR.Armor.GetItem(armorId)

        if item and item.model then
            self:SetModel(item.model)
            self:SetModelScale(item.scale or 1)
        else
            self:SetModel("models/props_junk/garbage_metalcan002a.mdl")
        end

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(5)
            phys:Wake()
        end

        if self.MuR_Temporary then
            timer.Simple(300, function()
                if IsValid(self) then
                    self:Remove()
                end
            end)
        end
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local armorId = self:GetArmorId()
    if armorId == "" then return end

    local item = MuR.Armor.GetItem(armorId)
    if not item then return end

    local existingArmor = activator:GetArmorOnPart(item.bodypart)
    if existingArmor and existingArmor ~= "" then
        MuR:SpawnArmorPickup(activator:GetPos() + Vector(0, 0, 20), existingArmor)
    end

    if activator:EquipArmor(armorId) then
        if item.equip_sound then
            activator:EmitSound(item.equip_sound, 60, 100)
        else
            activator:EmitSound("items/ammo_pickup.wav", 50)
        end
        self:Remove()
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end

if SERVER then
    function MuR:SpawnArmorPickup(pos, armorId)
        local ent = ents.Create("mur_armor_pickup")
        if not IsValid(ent) then return nil end

        ent.ArmorId = armorId
        ent.MuR_Temporary = true
        ent:SetArmorId(armorId)
        ent:SetPos(pos)
        ent:SetAngles(AngleRand())
        ent:Spawn()
        ent:Activate()

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(Vector(math.Rand(-50, 50), math.Rand(-50, 50), 100))
        end

        return ent
    end

    function MuR:DropArmorFromRagdoll(ragdoll, bodypart)
        if not IsValid(ragdoll) or not ragdoll.MuR_Armor then return end
        if ragdoll:GetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false) then return end

        local armorId = ragdoll.MuR_Armor[bodypart]
        if not armorId or armorId == "" then return end

        local pos = ragdoll:GetPos() + Vector(0, 0, 30)
        local pickup = MuR:SpawnArmorPickup(pos, armorId)

        ragdoll.MuR_Armor[bodypart] = nil
        ragdoll:SetNW2String("MuR_Armor_" .. bodypart, "")

        return pickup
    end
end
