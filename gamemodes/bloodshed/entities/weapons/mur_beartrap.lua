AddCSLuaFile()
SWEP.Base = "mur_loot_base"

SWEP.PrintName = "Bear Trap"
SWEP.Author = "Hari"
SWEP.Category = "Bloodshed - Illegal"

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

SWEP.Slot = 5
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/c_grenade.mdl"
SWEP.WorldModel = "models/murdered/traps/trap_close.mdl"

SWEP.HoldType = "slam"
SWEP.VElements = {
	["trap"] = { type = "Model", model = "models/murdered/traps/trap_close.mdl", bone = "ValveBiped.Grenade_body", rel = "", pos = Vector(0, 5, 0), angle = Angle(0, 0, 180), size = Vector(1, 1, 1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}
SWEP.ViewModelBoneMods = {
	["ValveBiped.Grenade_body"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}

SWEP.WorldModelPosition = Vector(8, -6, 1)
SWEP.WorldModelAngle =  Angle(-10, 90, 180)

SWEP.ViewModelPos = Vector(1.399, 2, 2)
SWEP.ViewModelAng = Angle(0, 0, 20)

SWEP.ViewModelFOV = 65
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:CustomInit()
    self:SetWeaponHoldType("slam")
    self.PlacingTrap = false
    self.GhostTrap = nil
end

function SWEP:Deploy()
    return true
end

function SWEP:Think()
    if CLIENT and self.PlacingTrap then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local tr = owner:GetEyeTrace()

        if IsValid(self.GhostTrap) then
            if tr.Hit and tr.HitPos:Distance(owner:GetPos()) <= 72 then
                self.GhostTrap:SetPos(tr.HitPos)
                self.GhostTrap:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
                self.GhostTrap:SetColor(Color(255, 255, 255, 100))
                self.GhostTrap:SetRenderMode(RENDERMODE_TRANSALPHA)
            else
                self.GhostTrap:SetColor(Color(255, 0, 0, 100))
            end
        end
    end
end

function SWEP:CustomPrimaryAttack()
end

function SWEP:CustomSecondaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = owner:GetEyeTrace()

    if not tr.Hit or tr.HitPos:Distance(owner:GetPos()) > 72 then
        return
    end

    local trap = ents.Create("trap_entity")
    if not IsValid(trap) then return end

    trap:SetPos(tr.HitPos)
    trap:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
    trap:SetOwner(owner)
    MuR:SetTrapOwner(trap, owner)
    trap:Spawn()

    constraint.Weld(trap, tr.Entity, 0, tr.PhysicsBone, 0, true, false)

    trap:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
    owner:ViewPunch(Angle(5, 0, 0))

    self:Remove()
end

function SWEP:Holster()
    if CLIENT and IsValid(self.GhostTrap) then
        self.GhostTrap:Remove()
        self.GhostTrap = nil
    end
    self.PlacingTrap = false
    return true
end

function SWEP:OnRemove()
    if CLIENT and IsValid(self.GhostTrap) then
        self.GhostTrap:Remove()
        self.GhostTrap = nil
    end
end

if CLIENT then
    function SWEP:DrawHUD()
        local ply = self:GetOwner()
        draw.SimpleText(MuR.Language["loot_grenade_2"], "MuR_Font1", ScrW()/2, ScrH()-He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    function SWEP:Deploy()
        self.PlacingTrap = true

        if IsValid(self.GhostTrap) then
            self.GhostTrap:Remove()
        end

        self.GhostTrap = ClientsideModel("models/murdered/traps/trap.mdl")
        if IsValid(self.GhostTrap) then
            self.GhostTrap:SetNoDraw(false)
            self.GhostTrap:SetColor(Color(255, 255, 255, 100))
            self.GhostTrap:SetRenderMode(RENDERMODE_TRANSALPHA)
        end

        return true
    end
end
