AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.Category = "Bloodshed - Police"
SWEP.Spawnable = true

SWEP.PrintName = "Flashbang"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.TPIKForce = true

SWEP.HoldType = "grenade"
SWEP.WorldModelPosition = Vector(3.5, -2, -1)
SWEP.WorldModelAngle = Angle(0, 60, 180)
SWEP.ViewModelPos = Vector(0, 0, 0)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 90
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/simpnades/v_m84.mdl"
SWEP.WorldModel = "models/simpnades/w_m84.mdl"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "grenade"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local ThrowSound = Sound("murdered/weapons/universal/uni_ads_in_02.wav")
local PinSound = Sound("murdered/weapons/grenade/f1_pinpull.wav")

function SWEP:CustomInit()
    self:SetHoldType(self.HoldType)
    self.PinPulled = false
    self.IsHolding = false
    self.ThrowTime = 0
end

function SWEP:CustomPrimaryAttack()
    local vm = self:GetOwner():GetViewModel()
    self:SetNextPrimaryFire(CurTime() + 0.5)

    if self.PinPulled then return end

    vm:SendViewModelMatchingSequence(vm:LookupSequence("pullbackhigh"))

    self.IsHolding = true
    self.PinPulled = true
    self.ThrowTime = CurTime()+0.85

    timer.Simple(0.5, function()
        if !IsValid(self) or !IsValid(self.Owner) then return end
        self.Owner:ViewPunch(Angle(2,2,0))
        self.Owner:EmitSound(PinSound, 50)
    end)
end

function SWEP:CustomSecondaryAttack() end

function SWEP:Think()
    if self.PinPulled and not self.IsHolding and not self.ThrowTime then
        self.ThrowTime = CurTime() + 0.5
    end

    if IsValid(self.Owner) and self.Owner:KeyDown(IN_ATTACK) then
        if not self.ThrowTime then
            self.ThrowTime = CurTime()+0.1
        end
        self.ThrowTime = self.ThrowTime < CurTime()+0.1 and CurTime()+0.1 or self.ThrowTime
    end

    if self.PinPulled and self.ThrowTime and self.ThrowTime < CurTime() then
        self:ThrowFlashbang()
        self.ThrowTime = nil
    end
end

function SWEP:ThrowGrenade()
    if CLIENT then return end

    local grenade = ents.Create("bloodshed_flashbang")
    if not IsValid(grenade) then return end
    grenade:SetPos(self.Owner:EyePos() + self.Owner:GetAimVector() * 16)
    grenade:SetAngles(self.Owner:EyeAngles())
    grenade:SetOwner(self.Owner)
    grenade:Spawn()
    grenade:Activate()

    local phys = grenade:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(self.Owner:GetAimVector() * 800 + self.Owner:GetVelocity())
        phys:AddAngleVelocity(Vector(math.random(-500, 500), math.random(-500, 500), math.random(-500, 500)))
    end
end

function SWEP:ThrowFlashbang()
    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence("throw"))
    self.Owner:EmitSound(ThrowSound, 50)

    timer.Simple(0.3, function()
        if not IsValid(self) or not IsValid(self:GetOwner()) then return end

        self:GetOwner():ViewPunch(Angle(5,0,0))

        if SERVER then
            self:ThrowGrenade()
            self:GetOwner():StripWeapon(self:GetClass())
        end

        self.PinPulled = false
    end)
end

function SWEP:Holster()
    self.PinPulled = false
    self.IsHolding = false
    self.ThrowTime = nil
    return true
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:SetNextPrimaryFire(CurTime() + self:SequenceDuration())
    return true
end

function SWEP:DrawHUD()
	local ply = self:GetOwner()
	draw.SimpleText(MuR.Language["loot_grenade_1"], "MuR_Font1", ScrW()/2, ScrH()-He(75), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
