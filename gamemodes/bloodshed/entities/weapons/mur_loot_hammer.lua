AddCSLuaFile()
SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Hammer"
SWEP.Slot = 0
SWEP.WorldModel = "models/murdered/weapons/w_barricadeswep.mdl"
SWEP.ViewModel = "models/murdered/weapons/c_barricadeswep.mdl"
SWEP.WorldModelPosition = Vector(4, -3, 3)
SWEP.WorldModelAngle = Angle(180, 10, 0)
SWEP.ViewModelPos = Vector(0, -1, -1)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 70
SWEP.HoldType = "melee"

SWEP.MatBlock = {MAT_SAND, MAT_SLOSH, MAT_SNOW,}

function SWEP:Deploy(wep)
    self:SetHoldType(self.HoldType)
end

function SWEP:FindObjects()
    local pos, vec = self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector()
    local gotOne, tries = false, 0
    local trOne, trTwo = nil, nil

    while not gotOne and tries < 100 do
        local tr = util.QuickTrace(pos, vec * 72 + VectorRand() * 2, {self:GetOwner()})

        if tr.Hit and not tr.HitSky and not table.HasValue(self.MatBlock, tr.MatType) then
            gotOne = true
            trOne = tr
        end

        tries = tries + 1
    end

    if gotOne then
        gotOne = false
        tries = 0

        while not gotOne and tries < 100 do
            local tr = util.QuickTrace(pos, vec * 72 + VectorRand() * 2, {self:GetOwner()})

            if tr.Hit and not tr.HitSky and not table.HasValue(self.MatBlock, tr.MatType) and not (tr.Entity == trOne.Entity) then
                gotOne = true
                trTwo = tr
            end

            tries = tries + 1
        end
    end

    if trOne and trTwo then
        return true, trOne, trTwo
    else
        return false, nil, nil
    end
end

function SWEP:MakeBolt(ent2)
    local tr = util.QuickTrace(self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector() * 70, {self:GetOwner()})

    local ent = ents.Create("prop_dynamic")
    ent:SetPos(tr.HitPos - self:GetOwner():EyeAngles():Forward() * 4)
    ent:SetModel("models/crossbow_bolt.mdl")
    ent:SetAngles(self:GetOwner():EyeAngles())
    ent:SetParent(ent2)
    ent:Spawn()
    ent2:DeleteOnRemove(ent)
end

if SERVER then
    function SWEP:CustomPrimaryAttack()
        local ply = self:GetOwner()
        local possible, tr1, tr2 = self:FindObjects()

        ply:SetAnimation(PLAYER_ATTACK1)
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

        if possible then
            self:SetNextPrimaryFire(CurTime() + 1)
            local ent1, ent2 = tr1.Entity, tr2.Entity

            if ent1:IsPlayer() or ent2:IsPlayer() then return end

            if ent1:GetClass() == "prop_ragdoll" or ent2:GetClass() == "prop_ragdoll" then
                local rag, other, ragBone, otherBone
                if ent1:GetClass() == "prop_ragdoll" then
                    rag = ent1
                    other = ent2
                    ragBone = tr1.PhysicsBone
                    otherBone = tr2.PhysicsBone
                else
                    rag = ent2
                    other = ent1
                    ragBone = tr2.PhysicsBone
                    otherBone = tr1.PhysicsBone
                end

                local noCollide = ent1:GetClass() != "prop_ragdoll" and ent2:GetClass() != "prop_ragdoll"
                local weld = constraint.Weld(rag, other, ragBone, otherBone, 0, noCollide, false)

                ply:ViewPunch(Angle(5, 0, 0))
                ply:EmitSound("physics/metal/metal_computer_impact_hard" .. math.random(1, 3) .. ".wav")
                self:MakeBolt(ent2)

                local dmg = DamageInfo()
                dmg:SetDamage(25)
                dmg:SetDamageType(DMG_SLASH)
                dmg:SetDamageForce(self:GetOwner():GetAimVector() * 64)
                dmg:SetAttacker(ply)
                dmg:SetInflictor(self)

                if rag == ent1 then
                    dmg:SetDamagePosition(tr1.HitPos)
                else
                    dmg:SetDamagePosition(tr2.HitPos)
                end

                rag:TakeDamageInfo(dmg)

                rag.IsNailed = true
                rag.NailConstraint = weld
                self:RemoveMe()
                return
            end

            if string.match(ent1:GetClass(), "_door") then
                if not self:CanRepair(ent1) then return end
                ply:ViewPunch(Angle(5, 0, 0))
                ply:EmitSound("physics/metal/metal_computer_impact_hard" .. math.random(1, 3) .. ".wav")
                ent1:Fire("Lock")
                self:MakeBolt(ent1)
                self:ApplyRepair(ent1, 200)
                self:RemoveMe()
                return
            end

            if string.match(ent2:GetClass(), "_door") then
                if not self:CanRepair(ent2) then return end
                ply:ViewPunch(Angle(5, 0, 0))
                ply:EmitSound("physics/metal/metal_computer_impact_hard" .. math.random(1, 3) .. ".wav")
                ent2:Fire("Lock")
                self:MakeBolt(ent2)
                self:ApplyRepair(ent2, 200)
                self:RemoveMe()
                return
            end

            if string.match(ent1:GetClass(), "prop_physics") or ent1:GetClass() == "func_physbox" then
                if not self:CanRepair(ent1) then return end
                constraint.Weld(ent1, ent2, 0, 0)
                ply:ViewPunch(Angle(5, 0, 0))
                ply:EmitSound("physics/metal/metal_computer_impact_hard" .. math.random(1, 3) .. ".wav")
                self:MakeBolt(ent1)
                self:ApplyRepair(ent1, 200)
                self:RemoveMe()
                return
            end

            if string.match(ent2:GetClass(), "prop_physics") or ent2:GetClass() == "func_physbox" then
                if not self:CanRepair(ent2) then return end
                constraint.Weld(ent2, ent1, 0, 0)
                ply:ViewPunch(Angle(5, 0, 0))
                ply:EmitSound("physics/metal/metal_computer_impact_hard" .. math.random(1, 3) .. ".wav")
                self:MakeBolt(ent2)
                self:ApplyRepair(ent2, 200)
                self:RemoveMe()
                return
            end
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

    function SWEP:MakeHealth(ent)
        local health = math.Clamp(math.floor(ent:OBBMaxs():Length() * 15), 10, 2500)

        if not ent:GetNW2Bool("BreakableThing") then
            ent:SetNW2Bool("BreakableThing", true)
            ent:SetMaxHealth(health)
            ent:SetHealth(health)
            ent.FixMaxHP = health
        else
            if ent.FixMaxHP > 0 then
                ent:SetHealth(ent:Health() + 200)
                ent.FixMaxHP = ent.FixMaxHP - 200
                if ent.FixMaxHP <= 0 then
                    MuR:GiveMessage("nofix", self:GetOwner())
                end
            else
                MuR:GiveMessage("nofix", self:GetOwner())
            end
        end
    end

    function SWEP:RemoveMe()
        local fl = self:GetNW2Float("Uses")

        if fl > 1 then
            self:SetNW2Float("Uses", fl - 1)
        else
            self:Remove()
        end
    end
end

function SWEP:DrawHUD()
    local ply = self:GetOwner()
    draw.SimpleText(MuR.Language["loot_hammer_1"], "MuR_Font1", ScrW() / 2, ScrH() - He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(MuR.Language["loot_hammer_2"] .. self:GetNW2Float("Uses"), "MuR_Font2", ScrW() / 2, ScrH() - He(120), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function SWEP:CustomInit()
    self:SetNW2Float("Uses", math.random(4, 6))
end

function SWEP:CustomSecondaryAttack()
    local ply = self:GetOwner()
    local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 72, {ply})

    if tr.Hit and IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_ragdoll" and tr.Entity.IsNailed then
        ply:SetAnimation(PLAYER_ATTACK1)
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

        if SERVER then
            if IsValid(tr.Entity.NailConstraint) then
                tr.Entity.NailConstraint:Remove()
            end
            tr.Entity.IsNailed = false
            tr.Entity.NailConstraint = nil
            ply:EmitSound("physics/metal/metal_computer_impact_hard" .. math.random(1, 3) .. ".wav")
        end
        self:SetNextSecondaryFire(CurTime() + 1)
    end
end
SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
