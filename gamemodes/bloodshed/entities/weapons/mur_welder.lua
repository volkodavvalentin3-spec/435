AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
SWEP.DisableSuicide = true

SWEP.PrintName = "Welder"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 4
SWEP.SlotPos = 6
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.HoldType = "revolver"
SWEP.WorldModelPosition = Vector(3, -2, -2)
SWEP.WorldModelAngle = Angle(180, 0, 0)
SWEP.ViewModelPos = Vector(0, 0, 0)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 70
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/murdered/weapons/v_tool_welder.mdl"
SWEP.WorldModel = "models/murdered/weapons/w_tool_welder.mdl"
SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(-8, -2, 6)

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "Thumper"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

local WELD_RANGE = 80
local FUEL_COST = 1
local DAMAGE_AMOUNT = 5
local DAMAGE_AMOUNT_RAGDOLL = 2
local IGNITE_TIME = 3

local WELDABLE_MATERIALS = {
    [MAT_METAL] = true,
    [MAT_VENT] = true,
    [MAT_GRATE] = true,
    [MAT_COMPUTER] = true,
    [MAT_CONCRETE] = true,
    [MAT_TILE] = true,
}

local WeldSound = Sound("ambient/energy/electric_loop.wav")
local SparkSound = Sound("ambient/energy/spark1.wav")
local IgniteSound = Sound("ambient/fire/mtov_flame2.wav")

function SWEP:CustomInit()
    self:SetHoldType(self.HoldType)
    self.Welding = false
    self.WeldLoop = nil
    self.LastWeldTarget = nil
    self.WeldStartTime = 0
    self.LastSparkTime = 0
    self.LastWeldAnimState = false
    self.LastDoorTarget = nil
    self.DoorWeldStartTime = 0
end

function SWEP:PlayAnim(name)
    local vm = self:GetOwner():GetViewModel()
    if not IsValid(vm) then return end

    local seq = vm:LookupSequence(name)
    if seq and seq > 0 then
        vm:SendViewModelMatchingSequence(seq)
    end
end

function SWEP:Deploy()
    self:PlayAnim("draw")
    self:SetHoldType(self.HoldType)
    self:SetNextPrimaryFire(CurTime() + 0.5)
    self:SetNextSecondaryFire(CurTime() + 0.5)
    return true
end

function SWEP:CustomPrimaryAttack()
    if self:Clip1() <= 0 then
        if SERVER and (not self.LastEmptySound or self.LastEmptySound < CurTime()) then
            self.Owner:EmitSound("weapons/ar2/ar2_empty.wav", 60, 100)
            self.LastEmptySound = CurTime() + 0.5
        end
        return
    end

    self:SetNextPrimaryFire(CurTime() + 0.1)
    self:TakePrimaryAmmo(FUEL_COST)

    if SERVER then
        self.WeldLoop = self.WeldLoop or CreateSound(self, WeldSound)
        if not self.WeldLoop:IsPlaying() then
            self.WeldLoop:Play()
            self.WeldLoop:ChangeVolume(0.5)
            self.WeldLoop:ChangePitch(100)
        end
    end

    if not self.LastWeldAnimState then
        self:PlayAnim("weld")
        self.LastWeldAnimState = true
    end

    self.Welding = true

    local owner = self:GetOwner()
    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * WELD_RANGE,
        filter = owner
    })

    if tr.Hit then
        local effectData = EffectData()
        effectData:SetOrigin(tr.HitPos)
        effectData:SetNormal(tr.HitNormal)
        effectData:SetMagnitude(2)
        effectData:SetScale(1)
        util.Effect("MetalSpark", effectData)

        if CurTime() > self.LastSparkTime + 0.3 then
            self.LastSparkTime = CurTime()
            if SERVER then
                sound.Play("ambient/energy/spark" .. math.random(1, 6) .. ".wav", tr.HitPos, 60, math.random(90, 110))
            end
        end
    end

    if CLIENT then return end

    local hitEnt = tr.Entity

    if IsValid(hitEnt) then
        local isDoor = string.match(hitEnt:GetClass(), "_door")

        if hitEnt == self.LastWeldTarget then
            local weldTime = CurTime() - self.WeldStartTime

            if isDoor and weldTime >= IGNITE_TIME then
                hitEnt:Fire("Unlock")
                self.WeldStartTime = CurTime()
            elseif not isDoor and weldTime >= IGNITE_TIME and not hitEnt:IsOnFire() then
                hitEnt:Ignite(5)
                sound.Play(IgniteSound, tr.HitPos, 70, 100)
            end
        else
            self.LastWeldTarget = hitEnt
            self.WeldStartTime = CurTime()
        end
    else
        self.LastWeldTarget = nil
        self.WeldStartTime = CurTime()
    end

    if IsValid(hitEnt) then
        if hitEnt:IsPlayer() and hitEnt:Alive() then
            local dmg = DamageInfo()
            dmg:SetDamage(DAMAGE_AMOUNT_RAGDOLL)
            dmg:SetDamageType(DMG_ENERGYBEAM)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamagePosition(tr.HitPos)
            hitEnt:TakeDamageInfo(dmg)
        elseif MuR.IsAI(hitEnt) then
            local dmg = DamageInfo()
            dmg:SetDamage(DAMAGE_AMOUNT_RAGDOLL)
            dmg:SetDamageType(DMG_ENERGYBEAM)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamagePosition(tr.HitPos)
            hitEnt:TakeDamageInfo(dmg)
        elseif hitEnt:GetClass() == "prop_ragdoll" then
            local dmg = DamageInfo()
            dmg:SetDamage(DAMAGE_AMOUNT_RAGDOLL)
            dmg:SetDamageType(DMG_ENERGYBEAM)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamagePosition(tr.HitPos)
            hitEnt:TakeDamageInfo(dmg)
        else
            local dmg = DamageInfo()
            dmg:SetDamage(DAMAGE_AMOUNT)
            dmg:SetDamageType(DMG_ENERGYBEAM)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamagePosition(tr.HitPos)
            hitEnt:TakeDamageInfo(dmg)
            print(1)
        end
    end
end

function SWEP:CustomSecondaryAttack()
    if self:Clip1() <= 0 then
        if SERVER and (not self.LastEmptySound or self.LastEmptySound < CurTime()) then
            self.Owner:EmitSound("weapons/ar2/ar2_empty.wav", 60, 100)
            self.LastEmptySound = CurTime() + 0.5
        end
        return
    end

    self:SetNextSecondaryFire(CurTime() + 0.1)
    self:TakePrimaryAmmo(FUEL_COST)

    if SERVER then
        self.WeldLoop = self.WeldLoop or CreateSound(self, WeldSound)
        if not self.WeldLoop:IsPlaying() then
            self.WeldLoop:Play()
            self.WeldLoop:ChangeVolume(0.5)
            self.WeldLoop:ChangePitch(100)
        end
    end

    if not self.LastWeldAnimState then
        self:PlayAnim("weld")
        self.LastWeldAnimState = true
    end

    self.Welding = true

    local owner = self:GetOwner()
    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * WELD_RANGE,
        filter = owner
    })

    if tr.Hit then
        local effectData = EffectData()
        effectData:SetOrigin(tr.HitPos)
        effectData:SetNormal(tr.HitNormal)
        effectData:SetMagnitude(2)
        effectData:SetScale(1)
        util.Effect("MetalSpark", effectData)

        if CurTime() > self.LastSparkTime + 0.3 then
            self.LastSparkTime = CurTime()
            if SERVER then
                sound.Play("ambient/energy/spark" .. math.random(1, 6) .. ".wav", tr.HitPos, 60, math.random(90, 110))
            end
        end
    end

    if CLIENT then return end

    local hitEnt = tr.Entity

    if IsValid(hitEnt) then
        local isDoor = string.match(hitEnt:GetClass(), "_door")

        if isDoor then
            if hitEnt == self.LastDoorTarget then
                local weldTime = CurTime() - self.DoorWeldStartTime

                if weldTime >= IGNITE_TIME then
                    hitEnt:Fire("Lock")
                    self.DoorWeldStartTime = CurTime()
                end
            else
                self.LastDoorTarget = hitEnt
                self.DoorWeldStartTime = CurTime()
            end
        end
    else
        self.LastDoorTarget = nil
        self.DoorWeldStartTime = CurTime()
    end

    if IsValid(hitEnt) then
        if hitEnt:IsPlayer() then return end

        local isDoor = string.match(hitEnt:GetClass(), "_door")
        if isDoor then
            self:MakeHealth(hitEnt)
            self:ApplyRepair(hitEnt, 5)
            return
        end

        if hitEnt:GetNW2Bool("BreakableThing") or hitEnt:GetClass() == "prop_physics" or hitEnt:GetClass() == "func_physbox" then
            self:MakeHealth(hitEnt)
            if self:CanRepair(hitEnt) then
                self:ApplyRepair(hitEnt, 5)
            end
        end

        local isWeldable = WELDABLE_MATERIALS[tr.MatType]
        if isWeldable and (hitEnt:GetClass() == "prop_physics" or hitEnt:GetClass() == "func_physbox") then
            local tr2 = nil
            for i = 1, 20 do
                local testTr = util.TraceLine({
                    start = owner:GetShootPos(),
                    endpos = owner:GetShootPos() + owner:GetAimVector() * WELD_RANGE + VectorRand() * 10,
                    filter = owner
                })

                if testTr.Hit and testTr.Entity ~= hitEnt then
                    tr2 = testTr
                    break
                end
            end

            if tr2 then
                local ent2 = tr2.Entity

                if not IsValid(ent2) or ent2:IsWorld() then
                    if not constraint.Find(hitEnt, game.GetWorld(), "Weld", 0, 0) then
                        constraint.Weld(hitEnt, game.GetWorld(), tr.PhysicsBone or 0, 0, 0, false)
                        owner:ViewPunch(Angle(1, 0, 0))
                        self:MakeHealth(hitEnt)
                    end
                elseif not ent2:IsPlayer() then
                    if not constraint.Find(hitEnt, ent2, "Weld", 0, 0) then
                        constraint.Weld(hitEnt, ent2, tr.PhysicsBone or 0, tr2.PhysicsBone or 0, 0, true)
                        owner:ViewPunch(Angle(1, 0, 0))
                        self:MakeHealth(hitEnt)
                        self:MakeHealth(ent2)
                    end
                end
            else
                if not constraint.Find(hitEnt, game.GetWorld(), "Weld", 0, 0) then
                    constraint.Weld(hitEnt, game.GetWorld(), tr.PhysicsBone or 0, 0, 0, false)
                    owner:ViewPunch(Angle(1, 0, 0))
                    self:MakeHealth(hitEnt)
                end
            end
        end
    end
end

function SWEP:MakeHealth(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() then return end

    local health = math.Clamp(math.floor(ent:OBBMaxs():Length() * 15), 10, 2500)

    if not ent:GetNW2Bool("BreakableThing") then
        ent:SetNW2Bool("BreakableThing", true)
        ent:SetMaxHealth(health)
        ent:SetHealth(health)
        ent.FixMaxHP = health
    end
end

function SWEP:CanRepair(ent)
    if not ent:GetNW2Bool("BreakableThing") then
        return true
    end

    if (ent.FixMaxHP or 0) <= 0 then
        MuR:GiveMessage("nofix", self:GetOwner())
        return false
    end

    return true
end

function SWEP:ApplyRepair(ent, amount)
    if not ent:GetNW2Bool("BreakableThing") then
        local health = math.Clamp(math.floor(ent:OBBMaxs():Length() * 15), 10, 2500)
        ent:SetNW2Bool("BreakableThing", true)
        ent:SetMaxHealth(health)
        ent:SetHealth(health)
        ent.FixMaxHP = health
    else
        ent:SetHealth(ent:Health() + amount)
        ent.FixMaxHP = ent.FixMaxHP - amount
    end
end

function SWEP:Think()
    local isWelding = (self.Owner:KeyDown(IN_ATTACK) or self.Owner:KeyDown(IN_ATTACK2)) and self:Clip1() > 0

    if SERVER and self.WeldLoop then
        if not isWelding then
            self.WeldLoop:Stop()
            self.LastWeldTarget = nil
        end
    end

    if self.LastWeldAnimState and not isWelding then
        self:PlayAnim("idle")
        self.LastWeldAnimState = false
    end

    self.Welding = isWelding
end

function SWEP:Holster()
    self:PlayAnim("holster")
    if SERVER and self.WeldLoop then
        self.WeldLoop:Stop()
    end
    self.Welding = false
    self.LastWeldTarget = nil
    self.LastWeldAnimState = false
    return true
end

function SWEP:OnRemove()
    if SERVER and self.WeldLoop then
        self.WeldLoop:Stop()
    end
end

if CLIENT then
    hook.Add("PostDrawOpaqueRenderables", "WelderEffect", function()
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end

            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) or wep:GetClass() ~= "mur_welder" then continue end
            if not wep.Welding then continue end

            local tr = util.TraceLine({
                start = ply:GetShootPos(),
                endpos = ply:GetShootPos() + ply:GetAimVector() * WELD_RANGE,
                filter = ply
            })

            if not tr.Hit then continue end

            local dlight = DynamicLight(ply:EntIndex())
            if dlight then
                local flicker = math.sin(CurTime() * 30) * 0.3 + 0.7
                dlight.pos = tr.HitPos
                dlight.r = 100
                dlight.g = 150
                dlight.b = 255
                dlight.brightness = 3 * flicker
                dlight.decay = 1000
                dlight.size = 100
                dlight.dietime = CurTime() + 0.05
            end
        end
    end)
end

function SWEP:DrawHUD()
    local ply = self:GetOwner()
    local ammo = self:Clip1()
    local maxAmmo = self.Primary.ClipSize

    local w, h = ScrW(), ScrH()
    local barW = w * 0.15
    local barH = h * 0.012
    local barX = w - barW - 20
    local barY = h - barH - 20

    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(barX - 2, barY - 2, barW + 4, barH + 4)

    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawOutlinedRect(barX - 2, barY - 2, barW + 4, barH + 4)

    local fillW = (ammo / maxAmmo) * barW
    surface.SetDrawColor(255, 150, 50, 255)
    surface.DrawRect(barX, barY, fillW, barH)

    draw.SimpleText(math.floor(ammo) .. "%", "MuR_Font1", barX + barW / 2, barY - 5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

    draw.SimpleText(MuR.Language["mur_welder_hint"] or "LMB: Weld/Damage | RMB: Weld Objects/Repair Door", "MuR_Font1", w / 2, h - He(75), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
