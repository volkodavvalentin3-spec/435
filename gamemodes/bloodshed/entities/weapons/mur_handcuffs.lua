AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Handcuffs"
SWEP.Slot = 0

SWEP.WorldModel = "models/murdered/handcuffs/handcuffs.mdl"
SWEP.ViewModel = "models/murdered/handcuffs/c_hand_cuffs.mdl"

SWEP.WorldModelPosition = Vector(4, -2, 0)
SWEP.WorldModelAngle =  Angle(0, 0, 90)

SWEP.ViewModelPos = Vector(0, -1, -2)
SWEP.ViewModelAng = Angle(0, 0, 5)
SWEP.ViewModelFOV = 80

SWEP.HoldType = "slam"

function SWEP:Deploy( wep )
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:SetHoldType(self.HoldType)
end

function SWEP:CustomPrimaryAttack()
    local ow = self:GetOwner()

    if SERVER then
        local tr = util.TraceLine({
            start = ow:GetShootPos(),
            endpos = ow:GetShootPos() + ow:GetAimVector() * 64,
            filter = ow,
            mask = MASK_SHOT_HULL
        })

        local i = 0
        local tar = tr.Entity
        if IsValid(tar) and (tar:IsPlayer() and ow:IsAtBack(tar) or tar.isRDRag and IsValid(tar.Owner)) then
            local target = tar
            if tar.isRDRag then
                target = tar.Owner
            end
            local fucked = target:GetNW2Float('ArrestState') == 0
            if target:IsRestrained() then return end
            if not target:Alive() then return end
            target:StopRagdolling()
            timer.Simple(0.01, function()
                if !IsValid(target) or !IsValid(ow) then return end
                target:SetPos(ow:GetPos())
                target:SetEyeAngles(ow:EyeAngles())
            end)
            local id = math.random(1,6)
            local anim = "sequence_ron_arrest_start_player_0" .. id
            local _, dur = ow:LookupSequence(anim)
            timer.Simple(0.001, function()
                if not IsValid(target) then return end
                target:Surrender(true, true, id, dur)
            end)
            ow:EmitSound(")murdered/other/arrest_body.mp3", 60)
            ow:ViewPunch(Angle(5,0,0))
            ow:Freeze(true)
            ow:SetNotSolid(true)
            ow:SetSVAnimation(anim, true)
            ow:PlayVoiceLine("ror_police_arrestingsuspect", true)
            timer.Simple(dur, function()
                if !IsValid(ow) then return end
                ow:Freeze(false)
                ow:SetNotSolid(false)
                if fucked then
                    ow:ChangeGuilt(3)
                    MuR:GiveAnnounce("officerguilt2", ow)
                else
                    ow:PlayVoiceLine("ror_police_reportarrestedsuspect")
                end
            end)
        elseif IsValid(tar) and (MuR.IsAI(tar) and ow:IsAtBack(tar) and tar.Surrendering) then
            local target = tar
            local isSuspect = tar.IsSuspect
            if isSuspect == nil then isSuspect = IsValid(tar:GetActiveWeapon()) end
            local id = math.random(1,6)
            local anim = "sequence_ron_arrest_start_player_0" .. id
            local anim2 = "sequence_ron_arrest_start_npc_0" .. id
            local _, dur = ow:LookupSequence(anim)
            ow:EmitSound(")murdered/other/arrest_body.mp3", 60)
            ow:ViewPunch(Angle(5,0,0))
            ow:Freeze(true)
            ow:SetNotSolid(true)
            ow:SetSVAnimation(anim, true)
            ow:SetPos(tar:GetPos())
            ow:PlayVoiceLine("ror_police_arrestingsuspect")

            local rType = "suspect"
            if tar.IsCivilian or not isSuspect then
                rType = "civilian"
            end

            local ent = ents.Create("prop_dynamic")
			ent:TransferModelData(tar)
			ent:SetAngles(Angle(0, self:EyeAngles().y, 0))
            ent:SetPos(tar:GetPos())
			ent:Spawn()
			ent:DropToFloor()
			ent:ResetSequence(anim2)
			ent:SetRenderMode(RENDERMODE_TRANSALPHA)
            SafeRemoveEntityDelayed(ent, 60)
            tar:Remove()

            timer.Simple(dur, function()
                if !IsValid(ow) then return end
                ow:Freeze(false)
                ow:SetNotSolid(false)
                if !IsValid(ent) then return end
                ent:ResetSequence("sequence_ron_arrest_wiggleloop")

                if MuR.Gamemode == 14 and MuR.Mode14Score then
                    ent:SetNW2String("RoN_Type", rType)

                    MuR:Mode14Score(ow, rType == "suspect" and "suspect_arrested" or "civilian_secured", ent)

                    if MuR.Mode14 then
                        if rType == "suspect" then
                            MuR.Mode14.SuspectsResolved = (MuR.Mode14.SuspectsResolved or 0) + 1
                        else
                            MuR.Mode14.CiviliansResolved = (MuR.Mode14.CiviliansResolved or 0) + 1
                        end
                        MuR:Mode14RecountObjectives()
                    end

                    ow:PlayVoiceLine(rType == "suspect"
                        and "ror_police_reportarrestedsuspect"
                        or "ror_police_reportcivilianarrested")
                else
                    ow:AddMoney(50)
                    ow:PlayVoiceLine(isSuspect
                        and "ror_police_reportarrestedsuspect"
                        or "ror_police_reportcivilianarrested")
                end
            end)
        end

        self:SetNextPrimaryFire(CurTime() + 2)
    end
end

function SWEP:CustomSecondaryAttack()

end

function SWEP:CustomInit()

end
SWEP.Category = "Bloodshed - Police"
SWEP.Spawnable = true
