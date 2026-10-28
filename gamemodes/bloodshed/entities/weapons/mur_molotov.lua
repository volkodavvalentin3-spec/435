AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true

SWEP.PrintName = "Cocktail Molotov"
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
SWEP.ViewModelFOV = 75
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/murdered/weapons/v_molotov.mdl"
SWEP.WorldModel = "models/murdered/weapons/w_molotov.mdl"

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

local ThrowSound = Sound("nades/molotov/molotov_throw_burning.wav")
local PinSound = Sound("nades/molotov/molotov_lighter_strike.wav")

SWEP.MaxTripwireDistance = 250

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "TripwireMode")
    self:NetworkVar("Int", 0, "TripwireStage")
    self:NetworkVar("Vector", 0, "StakePosition")
    self:NetworkVar("Vector", 1, "StakeNormal")
end

function SWEP:CustomInit()
    self:SetHoldType(self.HoldType)
    self.PinPulled = false
    self.IsHolding = false
    self.ThrowTime = 0
    self:SetTripwireMode(false)
    self:SetTripwireStage(0)
end

function SWEP:GetPlacementTrace()
    local owner = self:GetOwner()
    return util.TraceLine({
        start = owner:EyePos(),
        endpos = owner:EyePos() + owner:GetAimVector() * 100,
        filter = function(ent) return ent != owner and !ent:IsPlayer() and !MuR.IsAI(ent) and ent:GetClass() != "prop_ragdoll" end
    })
end

function SWEP:CustomPrimaryAttack()
    local vm = self:GetOwner():GetViewModel()
    self:SetNextPrimaryFire(CurTime() + 0.5)

    if self:GetTripwireMode() then return end
    if self.PinPulled then return end

    vm:SendViewModelMatchingSequence(vm:LookupSequence("pullback_high"))

    self.IsHolding = true
    self.PinPulled = true
    self.ThrowTime = CurTime()+1

    timer.Simple(0.5, function()
        if !IsValid(self) or !IsValid(self.Owner) then return end
        self.Owner:ViewPunch(Angle(2,2,0))
        self.Owner:EmitSound(PinSound, 50)
    end)
end

function SWEP:CustomSecondaryAttack()
    if self.PinPulled then return end

    self:SetNextSecondaryFire(CurTime() + 0.5)
    if CLIENT then return end

    if not self:GetTripwireMode() then
        self:SetTripwireMode(true)
        self:SetTripwireStage(1)
        return
    end

    local tr = self:GetPlacementTrace()
    if not tr.Hit then return end

    local owner = self:GetOwner()

    if self:GetTripwireStage() == 1 then
        self:SetStakePosition(tr.HitPos)
        self:SetStakeNormal(tr.HitNormal)
        self:SetTripwireStage(2)

        local stake = ents.Create("prop_physics")
        stake:SetModel("models/props_c17/TrapPropeller_Lever.mdl")
        if game.GetWorld() != tr.Entity then
            stake:SetParent(tr.Entity)
        end
        stake:SetPos(tr.HitPos + tr.HitNormal * 2)
        stake:SetAngles(Angle(0, 0, 90))
        stake:Spawn()
        stake:GetPhysicsObject():EnableMotion(false)
        stake:SetNotSolid(true)
        self.StakeEnt = stake

        owner:EmitSound("physics/metal/metal_solid_impact_bullet1.wav", 50, 100)
        owner:ViewPunch(Angle(8, 0, 0))
        return
    end

    if self:GetTripwireStage() != 2 then return end

    local stakePos = self:GetStakePosition()
    if not stakePos then return end

    local distance = tr.HitPos:Distance(stakePos)
    if distance > self.MaxTripwireDistance or distance < 10 then return end

    local traceCheck = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 5),
        endpos = stakePos + Vector(0, 0, 5),
        filter = {owner, tr.Entity},
        mask = MASK_SOLID
    })

    if traceCheck.Hit then
        local act = traceCheck.Entity
        if not IsValid(act) then return end

        local alive = MuR.IsAI(act) or act:IsPlayer()
        local passable = act == owner
            or (not alive and (not IsValid(act:GetPhysicsObject()) or not act:GetPhysicsObject():IsMotionEnabled()))
            or (alive and act:Health() <= 0)
            or (act:IsKiller() and owner:IsKiller())

        if not passable then return end
    end

    local ent = ents.Create("murwep_molotov_trap")
    if not IsValid(ent) then return end

    ent:SetPos(tr.HitPos + tr.HitNormal * 2)
    if game.GetWorld() != tr.Entity then
        ent:SetParent(tr.Entity)
    end
    ent.PlayerOwner = owner
    ent.OwnerTrap = owner
    ent.StakeEnt = self.StakeEnt
    ent.StakeLimit = distance + 10
    ent:Spawn()

    MuR:SetTrapOwner(ent, owner)

    ent.StakeConst = constraint.Rope(ent, self.StakeEnt, 0, 0, Vector(0, 0, 3),
        self.StakeEnt:GetUp() * -5, distance, 0, 0, 0.3, "cable/cable", false)

    owner:EmitSound("physics/metal/weapon_impact_soft2.wav", 50, 100)
    owner:ViewPunch(Angle(4, 0, 0))
    self:Remove()
end

function SWEP:Reload()
    if not self:GetTripwireMode() then return end
    if CLIENT then return end

    self:SetTripwireMode(false)
    self:SetTripwireStage(0)
    self:SetStakePosition(Vector(0, 0, 0))
    self:SetStakeNormal(Vector(0, 0, 0))

    if IsValid(self.StakeEnt) then
        self.StakeEnt:Remove()
        self.StakeEnt = nil
    end
end

function SWEP:OnRemove()
    if SERVER and IsValid(self.StakeEnt) and self:GetTripwireStage() < 2 then
        self.StakeEnt:Remove()
    end
end

function SWEP:Think()
    if self:GetTripwireMode() then
        if CLIENT then self:UpdateGhostPreview() end
        return
    end

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
        self:ThrowMolotov()
        self.ThrowTime = nil
    end
end

function SWEP:ThrowGrenade()
    if CLIENT then return end

    local grenade = ents.Create("bloodshed_molotov")
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

function SWEP:ThrowMolotov()
    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence("throw"))
    self.Owner:EmitSound(ThrowSound, 50)

    timer.Simple(0.2, function()
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

    if SERVER and IsValid(self.StakeEnt) and self:GetTripwireStage() <= 2 then
        self.StakeEnt:Remove()
        self.StakeEnt = nil
        self:SetTripwireMode(false)
        self:SetTripwireStage(0)
    end

    return true
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:SetNextPrimaryFire(CurTime() + self:SequenceDuration())
    return true
end

if CLIENT then
    local mat_laser = Material("sprites/bluelaser1")
    local color_valid = Color(0, 255, 0, 200)
    local color_invalid = Color(255, 0, 0, 200)

    function SWEP:UpdateGhostPreview()
        if not self:GetTripwireMode() then return end

        local tr = self:GetPlacementTrace()
        if not tr.Hit then return end

        if self:GetTripwireStage() == 1 then
            self.PreviewStakePos = tr.HitPos
            self.PreviewStakeValid = true
            return
        end

        if self:GetTripwireStage() != 2 then return end

        self.PreviewBottlePos = tr.HitPos + tr.HitNormal * 2

        local stakePos = self:GetStakePosition()
        if not stakePos then return end

        local distance = tr.HitPos:Distance(stakePos)
        local distanceValid = distance >= 10 and distance <= self.MaxTripwireDistance

        local traceCheck = util.TraceLine({
            start = tr.HitPos + Vector(0, 0, 5),
            endpos = stakePos + Vector(0, 0, 5),
            filter = {LocalPlayer()},
            mask = MASK_SOLID
        })

        local pathClear = true
        if traceCheck.Hit then
            local act = traceCheck.Entity
            if IsValid(act) then
                local alive = MuR.IsAI(act) or act:IsPlayer()
                pathClear = act == LocalPlayer()
                    or (not alive and (not IsValid(act:GetPhysicsObject()) or not act:GetPhysicsObject():IsMotionEnabled()))
                    or (alive and act:Health() <= 0)
                    or (act:IsKiller() and LocalPlayer():IsKiller())
            else
                pathClear = false
            end
        end

        self.PreviewBottleValid = distanceValid and pathClear
        self.PreviewDistance = distance
    end

    function SWEP:DrawHUD()
        if not self:GetTripwireMode() then
            draw.SimpleText(MuR.Language["loot_grenade_1"], "MuR_Font1", ScrW()/2, ScrH()-He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(MuR.Language["loot_molotov_trap_hint"], "MuR_Font1", ScrW()/2, ScrH()-He(85), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local stage = self:GetTripwireStage()
        local text1 = stage == 1 and MuR.Language["loot_grenade_trap_stake"] or MuR.Language["loot_molotov_trap_bottle"]
        local valid = stage == 1 and self.PreviewStakeValid or self.PreviewBottleValid
        local statusColor = valid == nil and color_white or (valid and color_valid or color_invalid)

        draw.SimpleText(text1, "MuR_Font1", ScrW()/2, ScrH()-He(100), statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(MuR.Language["loot_grenade_trap_controls"], "MuR_Font1", ScrW()/2, ScrH()-He(85), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if stage == 2 and self.PreviewDistance then
            local distText = MuR.Language["loot_grenade_trap_dist"] .. math.Round(self.PreviewDistance) .. " / " .. self.MaxTripwireDistance
            draw.SimpleText(distText, "MuR_Font1", ScrW()/2, ScrH()-He(70), statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local stake_model = ClientsideModel("models/props_c17/TrapPropeller_Lever.mdl")
    stake_model:SetNoDraw(true)
    local bottle_model = ClientsideModel("models/murdered/weapons/w_molotov.mdl")
    bottle_model:SetNoDraw(true)

    hook.Add("PostDrawTranslucentRenderables", "DrawTripwirePreviewMolotov", function()
        local wep = LocalPlayer():GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mur_molotov" then return end
        if not wep:GetTripwireMode() then return end

        render.SetBlend(0.7)

        local stage = wep:GetTripwireStage()

        if stage == 1 and wep.PreviewStakePos then
            stake_model:SetPos(wep.PreviewStakePos)
            stake_model:SetAngles(Angle(0, 0, 90))
            stake_model:SetColor(wep.PreviewStakeValid and Color(100, 255, 100, 255) or Color(255, 100, 100, 255))
            stake_model:DrawModel()
        end

        if stage == 2 then
            local stakePos = wep:GetStakePosition()
            if stakePos and stakePos ~= Vector(0, 0, 0) then
                stake_model:SetPos(stakePos + wep:GetStakeNormal() * 2)
                stake_model:SetAngles(Angle(0, 0, 90))
                stake_model:SetColor(Color(150, 150, 150, 255))
                stake_model:DrawModel()
            end

            if wep.PreviewBottlePos then
                bottle_model:SetPos(wep.PreviewBottlePos)
                bottle_model:SetAngles(Angle(0, 0, 0))
                bottle_model:SetColor(wep.PreviewBottleValid and Color(100, 255, 100, 255) or Color(255, 100, 100, 255))
                bottle_model:DrawModel()

                if stakePos and stakePos ~= Vector(0, 0, 0) then
                    render.SetMaterial(mat_laser)
                    render.DrawBeam(stakePos + Vector(0, 0, 5), wep.PreviewBottlePos + Vector(0, 0, 5), 3, 0, 1,
                        wep.PreviewBottleValid and Color(255, 200, 0, 200) or Color(255, 100, 100, 200))
                end
            end
        end

        render.SetBlend(1)
    end)
end
