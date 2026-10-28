AddCSLuaFile()

game.AddParticles("particles/burning_fx.pcf")
PrecacheParticleSystem("explosion_huge")

SWEP.PrintName = "Wall-Piercing C4"
SWEP.Category = "Bloodshed - Illegal"
SWEP.DrawWeaponInfoBox = false

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_c4.mdl"
SWEP.WorldModel = "models/weapons/w_c4.mdl"

SWEP.TimerDuration = 5
SWEP.PlacedBombs = {}

function SWEP:Initialize()
    self:SetHoldType("slam")
    self.TimerDuration = 5
end

function SWEP:Deploy()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:ChatPrint("C4 timer is " .. self.TimerDuration .. " seconds")
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if self.TimerDuration == 30 then
        self.TimerDuration = 0
    end
    self.TimerDuration = math.Clamp((self.TimerDuration or 30) + 5, 5, 30)
    owner:ChatPrint("C4 timer set to " .. self.TimerDuration .. " seconds")

    self:SetNextSecondaryFire(CurTime() + 0.1)
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local trace = {}
    trace.start = owner:EyePos()
    trace.endpos = trace.start + owner:GetAimVector() * 100
    trace.filter = owner

    local tr = util.TraceLine(trace)

    if tr.Hit and !tr.Entity:IsPlayer() then
        local bomb = ents.Create("prop_physics")
        if !IsValid(bomb) then return end

        bomb:SetModel("models/weapons/w_c4.mdl")
        bomb:SetPos(tr.HitPos + tr.HitNormal * 2)
        local ang = tr.HitNormal:Angle()
        ang:RotateAroundAxis(ang:Right(), -90)
        bomb:SetAngles(ang)

        bomb:Spawn()
        bomb:SetUseType(SIMPLE_USE)
        bomb:SetParent(tr.Entity)
        bomb:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
        bomb.Timer = CurTime()+self.TimerDuration
        bomb.BeepInterval = 1
        bomb.LastBeep = CurTime()
        bomb.Owner = owner

        table.insert(self.PlacedBombs, bomb)

        hook.Add("Think", "C4_Think_" .. bomb:EntIndex(), function()
            if not IsValid(bomb) then
                hook.Remove("Think", "C4_Think_" .. bomb:EntIndex())
                return
            end

            if CurTime() > bomb.LastBeep + bomb.BeepInterval then
                bomb:EmitSound(")weapons/c4/c4_beep1.wav", 70, 100)
                bomb.LastBeep = CurTime()
                bomb.BeepInterval = 1
            end

            if bomb.Timer-CurTime() <= 0 then
                local radius = 250
                local count = 20
                local effectName = "Explosion"

                local centerEffect = EffectData()
                centerEffect:SetOrigin(tr.HitPos)
                centerEffect:SetFlags(4)
                util.Effect(effectName, centerEffect, true, true)

                for i = 1, count do
                    local angle = (2 * math.pi / count) * i
                    local x = math.cos(angle) * radius
                    local y = math.sin(angle) * radius
                    local explosionPos = tr.HitPos + Vector(x, y, 0)

                    local effect = EffectData()
                    effect:SetOrigin(explosionPos)
                    effect:SetFlags(4)
                    util.Effect(effectName, effect, true, true)
                end
                util.ScreenShake(bomb:GetPos(), 20, 40, 4, 2000)
                bomb:EmitSound(")ambient/explosions/explode_3.wav", 110, 90)

                MuR:ApplyConcussion(bomb:GetPos(), "c4", IsValid(bomb.Owner) and bomb.Owner or bomb)

                local explodeRadius = 300
                for _, ent in pairs(ents.FindInSphere(bomb:GetPos(), explodeRadius)) do
                    local distance = ent:GetPos():Distance(bomb:GetPos())
                    local damage = math.max(2000, 4000 * (1 - distance / explodeRadius))

                    if ent:IsWeapon() or ent:IsPlayer() or MuR.IsAI(ent) or ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "prop_physics" or string.find(ent:GetClass(), "_door") or string.find(ent:GetClass(), "breakable") then
                        local dmginfo = DamageInfo()
                        dmginfo:SetDamage(damage)
                        dmginfo:SetDamageType(DMG_BLAST)
                        dmginfo:SetAttacker(IsValid(bomb.Owner) and bomb.Owner or bomb)
                        dmginfo:SetInflictor(IsValid(bomb.Owner) and bomb.Owner or bomb)
                        dmginfo:SetDamageForce((ent:GetPos() - bomb:GetPos()):GetNormalized() * damage * 5)
                        ent:TakeDamageInfo(dmginfo)

                        local phys = ent:GetPhysicsObject()
                        if IsValid(phys) then
                            local pushDir = (ent:GetPos() - bomb:GetPos()):GetNormalized()
                            phys:ApplyForceCenter(pushDir * damage * 5)
                        elseif ent:IsPlayer() then
                            ent:SetVelocity((ent:GetPos() - bomb:GetPos()):GetNormalized() * damage * 10)
                        end
                    end
                end

                bomb:Remove()
                hook.Remove("Think", "C4_Think_" .. bomb:EntIndex())
            end
        end)

        bomb:EmitSound("weapons/c4/c4_plant.wav")
        self:Remove()
    end

    self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:Holster()
    return true
end

if SERVER then
    util.AddNetworkString("C4_UpdateTimer")

    function SWEP:SetTimerDuration(time)
        self.TimerDuration = time
        net.Start("C4_UpdateTimer")
        net.WriteFloat(time)
        net.Send(self:GetOwner())
    end
else
    net.Receive("C4_UpdateTimer", function()
        local wep = LocalPlayer():GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "mur_c4" then
            wep.TimerDuration = net.ReadFloat()
        end
    end)
end

if CLIENT then
    killicon.Add("mur_c4", "vgui/killicons/weapon_c4", Color(255, 80, 0, 255))
end
