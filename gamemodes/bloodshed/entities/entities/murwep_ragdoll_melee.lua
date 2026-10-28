AddCSLuaFile()

ENT.Base = "base_anim"
ENT.PrintName = "Weapon"
ENT.Category = "BloodShed"
ENT.Spawnable = true

local DataTable = {
    ["Knife"] = {
        model = "models/melee/w_jnife_j.mdl",
        offsetpos = Vector(1,-3,3),
        offsetang = Angle(-90,0,0),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/flesh/flesh_squishy_impact_hard1.wav", "physics/flesh/flesh_squishy_impact_hard2.wav", "physics/flesh/flesh_squishy_impact_hard3.wav", "physics/flesh/flesh_squishy_impact_hard4.wav"}
    },

    ["CombatKnife"] = {
        model = "models/melee/w_marinebayonet.mdl",
        offsetpos = Vector(1,-3,3),
        offsetang = Angle(-90,0,0),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/flesh/flesh_squishy_impact_hard1.wav", "physics/flesh/flesh_squishy_impact_hard2.wav", "physics/flesh/flesh_squishy_impact_hard3.wav", "physics/flesh/flesh_squishy_impact_hard4.wav"}
    },

    ["Hatchet"] = {
        model = "models/melee/w_me_hatchet.mdl",
        offsetpos = Vector(-1,4,6),
        offsetang = Angle(0,0,180),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav"}
    },

    ["Machete"] = {
        model = "models/melee/w_me_machete.mdl",
        offsetpos = Vector(-1,2.5,11),
        offsetang = Angle(0,0,180),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/flesh/flesh_squishy_impact_hard1.wav", "physics/flesh/flesh_squishy_impact_hard2.wav", "physics/flesh/flesh_squishy_impact_hard3.wav", "physics/flesh/flesh_squishy_impact_hard4.wav"}
    },

    ["Baton"] = {
        model = "models/murdered/weapons/tfa_l4d_mw2019/melee/w_baton.mdl",
        offsetpos = Vector(-2,3,7),
        offsetang = Angle(0,0,180),
        twohand = false,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/tonfa/melee_tonfa_01.wav", "murdered/weapons/tfa_l4d_mw2019/tonfa/melee_tonfa_02.wav"}
    },

    ["KitKnife"] = {
        model = "models/melee/w_me_kitknife.mdl",
        offsetpos = Vector(1,3,0),
        offsetang = Angle(0,0,0),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav"}
    },

    ["Pipe"] = {
        model = "models/melee/w_me_pipe_lead.mdl",
        offsetpos = Vector(-1,4,6),
        offsetang = Angle(0,0,180),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav"}
    },

    ["Cleaver"] = {
        model = "models/melee/w_me_cleaver.mdl",
        offsetpos = Vector(0,1,-1),
        offsetang = Angle(0,0,180),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav"}
    },

    ["Wrench"] = {
        model = "models/melee/w_me_wrench.mdl",
        offsetpos = Vector(-1,2,0),
        offsetang = Angle(0,0,180),
        twohand = false,
        canstuck = true,
        impactsound = {"physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav"}
    },

    ["Crowbar"] = {
        model = "models/melee/w_me_crowbar.mdl",
        offsetpos = Vector(-1,3,3),
        offsetang = Angle(0,0,180),
        twohand = true,
        canstuck = true,
        impactsound = {"weapons/crowbar/crowbar_impact1.wav", "weapons/crowbar/crowbar_impact2.wav"}
    },

    ["FireAxe"] = {
        model = "models/melee/w_me_axe_fire.mdl",
        offsetpos = Vector(-1,4,6),
        offsetang = Angle(0,0,180),
        twohand = true,
        canstuck = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/fire_axe/melee_axe_01.wav", "murdered/weapons/tfa_l4d_mw2019/fire_axe/melee_axe_02.wav", "murdered/weapons/tfa_l4d_mw2019/fire_axe/melee_axe_03.wav"}
    },

    ["Shovel"] = {
        model = "models/melee/w_me_spade.mdl",
        offsetpos = Vector(1,4,4),
        offsetang = Angle(0,20,180),
        twohand = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/shovel/melee_guitar_01.wav", "murdered/weapons/tfa_l4d_mw2019/shovel/melee_guitar_02.wav"}
    },

    ["Bat"] = {
        model = "models/melee/w_me_bat_metal.mdl",
        offsetpos = Vector(-1,3,4),
        offsetang = Angle(0,0,180),
        twohand = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_01.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_02.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_03.wav"}
    },

    ["Fubar"] = {
        model = "models/melee/w_me_fubar.mdl",
        offsetpos = Vector(0,1,4),
        offsetang = Angle(0,0,180),
        twohand = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_01.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_02.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_03.wav"}
    },

    ["Pickaxe"] = {
        model = "models/melee/w_me_pickaxe.mdl",
        offsetpos = Vector(0,1,4),
        offsetang = Angle(0,0,180),
        twohand = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_01.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_02.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_03.wav"}
    },

    ["Sledgehammer"] = {
        model = "models/melee/w_me_sledge.mdl",
        offsetpos = Vector(-1,3,1),
        offsetang = Angle(0,0,180),
        twohand = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_01.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_02.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_03.wav"}
    },

    ["Chainsaw"] = {
        model = "models/melee/w_me_chainsaw.mdl",
        offsetpos = Vector(-1,-7,-1),
        offsetang = Angle(0,0,180),
        twohand = true,
        impactsound = {"murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_01.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_02.wav", "murdered/weapons/tfa_l4d_mw2019/baseball_bat/melee_cricket_bat_03.wav"}
    },
}

if SERVER then
    function ENT:Initialize()
        if not self.type then
            self.type = "Knife"
        end
        self.data = DataTable[self.type]
        self:SetModel(self.data.model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self.twohand = self.data.twohand
        self.SwingSound = 0
        self.DamageWait = 0
        local phys = self:GetPhysicsObject()
        phys:SetMass(10)

        local ent, wep = self.Owner, self.Weapon
        if !IsValid(ent) or !IsValid(wep) or !istable(self.data) or false then
            self:Remove()
        else
            self:ConnectHands(ent, wep)
            ent:DeleteOnRemove(self)

            self.shootsound = wep.ShootSound
        end
    end

    function ENT:ConnectHands(ent, wep)
        local eang = ent.Owner:EyeAngles()
        local bonerh1 = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_R_Hand")))
        local bonelh1 = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_L_Hand")))

        local angle = ent.Owner:GetAimVector():Angle() + Angle(0, 0, 0)
        bonelh1:SetAngles(angle)
        angle = ent.Owner:GetAimVector():Angle() + Angle(0, 0, 180)
        bonerh1:SetAngles(angle)

        local boner = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_R_Hand")))
        local pos, ang = boner:GetPos(), boner:GetAngles()

        ang = ang+self.data.offsetang
        boner:SetPos(pos)
        ang:RotateAroundAxis(ang:Right(), self.data.offsetpos.x)
        ang:RotateAroundAxis(ang:Up(), self.data.offsetpos.y)
        ang:RotateAroundAxis(ang:Forward(), self.data.offsetpos.z)
        pos = pos + self.data.offsetpos.x * ang:Right()
        pos = pos + self.data.offsetpos.y * ang:Forward()
        pos = pos + self.data.offsetpos.z * ang:Up()

        self:SetPos(pos)
        self:SetAngles(ang)

        constraint.Weld(self, ent, 0, ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_R_Hand")), 0, true, false)
        if self.data.twohand then
            local vec1 = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetPos()
            local vec22 = Vector(0,0,0)
            vec22:Set(Vector(0,-1,6))
            vec22:Rotate(ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetAngles())
            ent:GetPhysicsObjectNum( ent:TranslateBoneToPhysBone(ent:LookupBone( "ValveBiped.Bip01_L_Hand" )) ):SetPos(vec1+vec22)
            ent:GetPhysicsObjectNum( ent:TranslateBoneToPhysBone(ent:LookupBone( "ValveBiped.Bip01_L_Hand" )) ):SetAngles(ent:GetPhysicsObjectNum( ent:TranslateBoneToPhysBone(ent:LookupBone( "ValveBiped.Bip01_R_Hand" )) ):GetAngles()-Angle(0,0,180))
            if !IsValid(ent.WepCons2) then
                local cons2 = constraint.Weld(self,ent,0,ent:TranslateBoneToPhysBone(ent:LookupBone( "ValveBiped.Bip01_L_Hand" )),0,true)
                if IsValid(cons2) then
                    ent.WepCons2 = cons2
                end
            end
        end
    end

    function ENT:Think()
        local ent, wep = self.Owner, self.Weapon
        if !IsValid(ent) or !IsValid(wep) or IsValid(ent.Owner) and !ent.Owner:HasWeapon(wep:GetClass()) then
            self:Remove()
        else
            if !IsValid(ent.Owner) then return end
            local handBone = ent:LookupBone("ValveBiped.Bip01_R_Hand")
            local bone1 = handBone and ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(handBone))
            if MuR.IsBoneScaleHidden(handBone and ent:GetManipulateBoneScale(handBone)) or !IsValid(bone1) then
                ent.Weapon = nil
                self:Remove()
                return
            else
                self:GetPhysicsObject():SetVelocity(bone1:GetVelocity())
                if self:GetPhysicsObject():GetVelocity():Length() > 150 and self.SwingSound < CurTime() and ent.Owner:KeyDown(IN_ATTACK2) then
                    self.SwingSound = CurTime()+0.2
                    if self.data.twohand then
                        ent:EmitSound("murdered/weapons/melee/crowbar_swing.mp3", 60, math.random(80,120))
                    else
                        ent:EmitSound("murdered/weapons/melee/axe_swing.mp3", 60, math.random(80,120))
                    end
                end
            end
            local tab = self.boneStuck
            if istable(tab) and IsValid(tab[1]) then
                tab[1]:SetPos(tab[2])
            end
        end
        self:NextThink(CurTime())
        return true
    end

    function ENT:PhysicsCollide(data, col)
        local ent, wep = self.Owner, self.Weapon
        local havespeed = data.Speed > 50
        local tar = data.HitEntity
        if !IsValid(ent.Owner) then return end
        local dnum = wep.Primary and wep.Primary.Damage
        if !isnumber(dnum) then
            dnum = 20
        end
        if havespeed and IsValid(tar) and self.DamageWait < CurTime() then
            self.DamageWait = CurTime()+0.5
            if MuR.IsAI(tar) or tar:IsPlayer() or tar:GetClass() == "prop_ragdoll" then
                ent:EmitSound(table.Random(self.data.impactsound), 60, math.random(80,100))
                local effectdata = EffectData()
                effectdata:SetEntity(tar)
                effectdata:SetOrigin(data.HitPos)
                util.Effect("BloodImpact", effectdata)

                local dm = DamageInfo()
				dm:SetDamage(math.Clamp(data.Speed/8, dnum/4, dnum))
				dm:SetDamagePosition(data.HitPos)
				dm:SetDamageType(DMG_SLASH)
				dm:SetAttacker(ent.Owner)
				dm:SetInflictor(self)
				tar:TakeDamageInfo(dm)
            else
                local dm = DamageInfo()
				dm:SetDamage(math.Clamp(data.Speed/2, dnum/4, dnum))
				dm:SetDamagePosition(data.HitPos)
				dm:SetDamageType(DMG_SLASH)
				dm:SetAttacker(ent.Owner)
				dm:SetInflictor(self)
				tar:TakeDamageInfo(dm)

                util.Decal("ManhackCut", data.HitPos, data.HitPos)
            end
            if math.random(1,10) == 1 and self.data.canstuck and not self.Stucked then
                local bonename = tar:GetNearestBoneFromPos(data.HitPos, data.OurOldVelocity)
                local bone = tar:GetPhysicsObjectNum(tar:TranslateBoneToPhysBone(tar:LookupBone(bonename)))
                self.boneStuck = {bone, data.HitPos}
                self:GetPhysicsObject():EnableMotion(false)
                self.Stucked = true
                timer.Simple(math.Rand(1,2), function()
                    if !IsValid(self) then return end
                    self.boneStuck = {nil, nil}
                    self:GetPhysicsObject():EnableMotion(true)
                    self.Stucked = false
                end)
            end
        end
    end

    function ENT:Shoot() end
    function ENT:Reload() end
else

end
