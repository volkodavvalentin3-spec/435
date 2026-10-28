AddCSLuaFile()
SWEP.Base = "mur_loot_base"

SWEP.PrintName = "Hydrofluoric Acid"
SWEP.Author = "Hari"
SWEP.Category = "Bloodshed - Agents"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/c_grenade.mdl"
SWEP.WorldModel = "models/murdered/loot/clorox.mdl"

SWEP.WorldModelPosition = Vector(3, -6, 11)
SWEP.WorldModelAngle =  Angle(-10, 90, 180)

SWEP.ViewModelPos = Vector(1.399, 2, 2)
SWEP.ViewModelAng = Angle(0, 0, 20)
SWEP.ViewModelFOV = 60

SWEP.HoldType = "slam"
SWEP.VElements = {
	["acid"] = { type = "Model", model = "models/murdered/loot/clorox.mdl", bone = "ValveBiped.Grenade_body", rel = "", pos = Vector(0, 0, 9.5), angle = Angle(0, 90, 180), size = Vector(1, 1, 1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}
SWEP.ViewModelBoneMods = {
	["ValveBiped.Grenade_body"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}

SWEP.AllowedClasses = {
    ["prop_physics"] = true,
    ["prop_ragdoll"] = true,
    ["murwep_grenade"] = true,
    ["murwep_ied"] = true,
    ["func_breakable"] = true,
    ["func_breakable_surf"] = true,
    ["func_physbox"] = true
}

function SWEP:CustomInit()
    self:SetWeaponHoldType("slam")
end

function SWEP:CustomPrimaryAttack()
    if not IsValid(self:GetOwner()) then return end

    local tr = self:GetOwner():GetEyeTrace()
    local ent = tr.Entity
    local canDissolve = false

    if not IsValid(ent) then return end
    if tr.HitPos:Distance(self:GetOwner():GetShootPos()) > 72 then return end

    if self.AllowedClasses[ent:GetClass()] ~= nil or ent:IsWeapon() then
        canDissolve = true
    end

    if not canDissolve then return end

    if SERVER then
        self:DissolveEntity(ent)
        self:Remove()
    end

    self:SetNextPrimaryFire(CurTime() + 1)
end

local function TransferBones(base, ragdoll)
    if not IsValid(base) or not IsValid(ragdoll) then return end

    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local bone = ragdoll:GetPhysicsObjectNum(i)

        if IsValid(bone) then
            local pos, ang = base:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))

            if pos then
                bone:SetPos(pos)
            end

            if ang then
                bone:SetAngles(ang)
            end
        end
    end
end

local function ReplaceWithBurntRagdoll(ragdoll)
    if !IsValid(ragdoll) then return end

    local pos = ragdoll:GetPos()
    local ang = ragdoll:GetAngles()

    local burntRagdoll = ents.Create("prop_ragdoll")
    burntRagdoll:SetPos(pos)
    burntRagdoll:SetAngles(ang)
    burntRagdoll:SetModel("models/Humans/Charple02.mdl")
    burntRagdoll:Spawn()
    burntRagdoll:SetNWString("Name", MuR.UNIDENTIFIED_NAME)
    burntRagdoll.IsDead = true
    burntRagdoll.isRDRag = true
    burntRagdoll.Burned = true
    burntRagdoll.MaxBlood = 0
    burntRagdoll:ZippyGoreMod3_BecomeGibbableRagdoll(BLOOD_COLOR_RED)
    burntRagdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    TransferBones(ragdoll, burntRagdoll)

    ragdoll:Remove()
end

function SWEP:DissolveEntity(ent)
    if not SERVER then return end

    local mins, maxs = ent:GetModelBounds()
    local size = (maxs - mins):Length()
    local dissolveTime = math.Clamp(size / 10, 5, 20)

    timer.Create("dissolve_" .. ent:EntIndex(), 0.1, dissolveTime * 10, function()
        if not IsValid(ent) then return end

        ent:EmitSound("ambient/levels/canals/toxic_slime_sizzle" .. math.random(2, 4) .. ".wav", 45, math.random(90, 110))

        if math.random(1, 100) <= 20 then
            local pos = ent:WorldSpaceCenter() + VectorRand() * 30
            local tr = util.TraceLine({
                start = pos + Vector(0, 0, 50),
                endpos = pos + Vector(0, 0, -250),
                filter = ent
            })
            util.Decal("YellowBlood", ent:WorldSpaceCenter()+Vector(0,0,50), tr.HitPos-Vector(0,0,4), ent)
        end

        local p = EffectData()
        p:SetOrigin(ent:WorldSpaceCenter()+VectorRand() * 16)
        p:SetFlags(3)
        p:SetColor(2)
        p:SetScale(6)
        p:SetNormal(VectorRand(-1,1))
        util.Effect("bloodspray", p)
    end)

    timer.Simple(dissolveTime, function()
        if IsValid(ent) then
            if ent:IsRagdoll() then
                ReplaceWithBurntRagdoll(ent)
            else
                if size > 100 then
                    ent:TakeDamage(250)
                else
                    ent:Remove()
                end
            end
        end
    end)
end

function SWEP:CustomSecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:DrawHUD()
	local ply = self:GetOwner()
	draw.SimpleText(MuR.Language["loot_acid"], "MuR_Font1", ScrW()/2, ScrH()-He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(MuR.Language["loot_acid2"], "MuR_Font1", ScrW()/2, ScrH()-He(85), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
