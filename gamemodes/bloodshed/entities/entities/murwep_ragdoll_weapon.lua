AddCSLuaFile()

ENT.Base = "base_anim"
ENT.PrintName = "Weapon"
ENT.Category = "BloodShed"
ENT.Spawnable = true

if SERVER then
    function ENT:ConnectHands(ent, wep)
        local rightHandBone = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_R_Hand"))
        local leftHandBone = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_L_Hand"))

        local bonerh1 = ent:GetPhysicsObjectNum(rightHandBone)
        local bonelh1 = ent:GetPhysicsObjectNum(leftHandBone)
        local rhold = bonerh1:GetAngles()

        if !IsValid(bonerh1) then return end

        local baseAngle = Angle(0, 0, 0)

        bonerh1:SetAngles(baseAngle)
        if IsValid(bonelh1) then
            bonelh1:SetAngles(baseAngle - Angle(0, 0, 180))
        end
        timer.Simple(0.0001, function()
            if !IsValid(self) or !IsValid(ent) or !IsValid(wep) then return end
            bonerh1:SetAngles(rhold)
        end)

        local pos, ang = bonerh1:GetPos(), bonerh1:GetAngles()

        local finalAngle = ang + self.data.offsetang

        if self.data.twohand and self.data.offsetang == Angle(0,0,180) then
            finalAngle = finalAngle + Angle(0, 0, 0)
        end

        finalAngle:Normalize()

        local finalPos = pos
        finalPos = finalPos + self.data.offsetpos.x * finalAngle:Right()
        finalPos = finalPos + self.data.offsetpos.y * finalAngle:Forward()
        finalPos = finalPos + self.data.offsetpos.z * finalAngle:Up()

        self:SetPos(finalPos)
        self:SetAngles(finalAngle)

        constraint.Weld(self, ent, 0, rightHandBone, 0, true, false)

        if self.data.twohand and IsValid(bonelh1) then
            local rightHandPos = bonerh1:GetPos()
            local rightHandAng = bonerh1:GetAngles()

            local leftHandOffset = Vector(8, -5, 0)

            leftHandOffset:Rotate(rightHandAng)

            bonelh1:SetPos(rightHandPos + leftHandOffset)
            bonelh1:SetAngles(rightHandAng - Angle(0, 0, 180))

            if !IsValid(ent.WepCons2) then
                local cons2 = constraint.Weld(self, ent, 0, leftHandBone, 0, true, false)
                if IsValid(cons2) then
                    ent.WepCons2 = cons2
                end
            end
        end
    end

    function ENT:CycleAction()
        local wep = self.Weapon
        local rag = self.Owner
        if !IsValid(wep) or !IsValid(rag) or !istable(wep.EventTable) then return end
        local ent = rag.Owner
        local tab = wep.EventTable[ACT_SHOTGUN_PUMP] or wep.EventTable[ACT_VM_PULLBACK_LOW]
        if istable(tab) then
            self.shootedtime = CurTime()+1
            timer.Simple(0.2, function()
                if !IsValid(self) then return end
                for k, v in pairs(tab) do
                    timer.Simple(v.time, function()
                        if !isstring(v.value) or !IsValid(rag) or !IsValid(self) then return end
                        rag:EmitSound(v.value, 60)
                        rag:FireHand(true)
                    end)
                    self.shootedtime = CurTime()+v.time+1
                end
            end)
        end
    end

    function ENT:Initialize()
        if not self.type then
            self.type = "Glock"
        end
        self.data = MuR.RagdollGunData[self.type]
        if !istable(self.data) then
            self:Remove()
            return
        end
        self:SetModel(self.data.model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetNotSolid(true)
        self.twohand = self.data.twohand
        self.clip = 0
        self.shooted = false
        self.shootedtime = CurTime()
        self.reloading = false
        local phys = self:GetPhysicsObject()
        phys:SetMass(0)

        if self.data.bonemerge then
            local bm = ents.Create("base_anim")
            bm:SetPos(self:GetPos())
            bm:SetModel(self.data.bonemerge)
            bm:Spawn()
            bm:SetParent(self.Owner)
            bm:AddEffects(1)
            self:DeleteOnRemove(bm)
            self:DrawShadow(false)
        end

        local ent, wep = self.Owner, self.Weapon
        if !IsValid(ent) or !IsValid(wep) then
            self:Remove()
        else
            self:ConnectHands(ent, wep)

            ent:DeleteOnRemove(self)

            self.clip = wep:Clip1()
            self.shootsound = wep.ShootSound
        end
    end

    function ENT:Think()
        local ent, wep = self.Owner, self.Weapon
        if !IsValid(ent) or !IsValid(wep) or IsValid(ent.Owner) and !ent.Owner:HasWeapon(wep:GetClass()) then
            self:Remove()
        else
            local handBone = ent:LookupBone("ValveBiped.Bip01_R_Hand")
            local bone1 = handBone and ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(handBone))
            if MuR.IsBoneScaleHidden(handBone and ent:GetManipulateBoneScale(handBone)) or !IsValid(bone1) then
                ent.Weapon = nil
                self:Remove()
                return
            else
                if IsValid(self:GetPhysicsObject()) then
                    self:GetPhysicsObject():SetVelocity(bone1:GetVelocity())
                end
            end
        end
    end

    function ENT:Reload()
        local rag, wep = self.Owner, self.Weapon
        if IsValid(rag) and IsValid(wep) and wep:Clip1() < wep:GetMaxClip1() and rag.Owner:GetAmmoCount(wep:GetPrimaryAmmoType()) > 0 and self.shootedtime < CurTime() then
            local ent = rag.Owner

            local maxclip = wep:GetMaxClip1()
            local clip = wep:Clip1()
            local ammo = ent:GetAmmoCount(wep:GetPrimaryAmmoType())
            local needed = maxclip - clip
            local toload = math.min(ammo, needed)

            wep:SetClip1(clip + toload)
            ent:RemoveAmmo(toload, wep:GetPrimaryAmmoType())

            self.shootedtime = CurTime()+2
            local count = 0
            if istable(wep.EventTable) then
                local tab = wep.EventTable[ACT_VM_RELOAD_EMPTY] or wep.EventTable[ACT_VM_RELOAD]
                if istable(tab) then
                    for k, v in pairs(tab) do
                        count = count + 1
                        timer.Simple(v.time, function()
                            print(rag, v.value)
                            if !IsValid(rag) or !IsValid(self) or !isstring(v.value) then return end
                            rag:EmitSound(v.value, 60)
                            rag:FireHand(true)
                        end)
                        self.shootedtime = CurTime()+v.time+1
                    end
                end
            end
            if count == 0 then
                local tab = {
                    {
                        t = 0.5,
                        s = "murdered/weapons/m9/handling/m9_magout.wav",
                    },
                    {
                        t = 1.5,
                        s = "murdered/weapons/m9/handling/m9_magin.wav",
                    },
                    {
                        t = 2,
                        s = "murdered/weapons/m9/handling/m9_maghit.wav",
                    },
                }
                for k, v in pairs(tab) do
                    timer.Simple(v.t, function()
                        if !IsValid(ent) or !IsValid(self) then return end
                        rag:EmitSound(v.s, 60)
                        rag:FireHand(true)
                    end)
                    self.shootedtime = CurTime()+v.t+1
                end
            end
            self.reloading = self.shootedtime
        end
    end

    function ENT:IsReloading()
        return self.reloading and self.reloading > CurTime()
    end

    function ENT:LookupMuzzle()
        local muz = self:LookupAttachment('muzzle')
        if muz < 1 then
            muz = self:LookupAttachment('1')
            if muz < 1 then
                return 0
            else
                return muz
            end
        else
            return muz
        end
    end

    function ENT:Shoot(bool)
        local ent, wep = self.Owner, self.Weapon
        if bool then
            if wep:Clip1() > 0 then
                if self.shootedtime > CurTime() or !self.data.automatic and self.shooted or self:LookupMuzzle() < 1 then return end

                local att = self:GetAttachment(self:LookupMuzzle())
                local spr = wep.Primary.Spread
                if string.match(wep.Category, "Sniper Rifles") then
                    spr = 0
                end
                if wep.Primary.NumShots > 1 then
                    spr = spr*2
                end
                local data = {
                    Attacker = ent,
                    Damage = wep.Primary.Damage/wep.Primary.NumShots,
                    Dir = att.Ang:Forward(),
                    Src = att.Pos-att.Ang:Forward()*4,
                    Force = 1,
                    Tracer = 1,
                    AmmoType = wep.Ammo,
                    Num = wep.Primary.NumShots,
                    Spread = Vector( 1*spr, 1*spr, 1*spr ),
                    IgnoreEntity = ent,
                }
                self:FireBullets(data)
                wep:SetClip1(wep:Clip1()-1)
                self.shooted = true
                self.shootedtime = CurTime()+(60/wep.Primary.RPM)+(self.data.extradelay or 0)
                self:CycleAction()
                ent:EmitSound(wep.Primary.Sound, 90, 100, 1, CHAN_WEAPON)
                ent:FireHand()
                if wep:Clip1() == 0 then
                    self.shooted = false
                end

                local effectdata = EffectData()
                effectdata:SetOrigin(att.Pos)
                effectdata:SetAngles(att.Ang)
                effectdata:SetScale( 1 )
                util.Effect("MuzzleEffect", effectdata)
            else
                if self.shooted then return end

                self.shooted = true
                self.shootedtime = CurTime()+(60/wep.Primary.RPM)
                ent:EmitSound("weapons/pistol/pistol_empty.wav", 60)
            end
        else
            self.shooted = false
        end
    end
else

end
