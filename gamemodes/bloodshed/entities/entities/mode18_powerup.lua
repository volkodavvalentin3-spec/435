AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Mode 18 Powerup"
ENT.Spawnable = false

if SERVER then
    function ENT:Initialize()
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        self:SetTrigger(true)
        self:UseTriggerBounds(true, 24)
        self:EmitSound("murdered/nz/powerup_spawn.mp3", 70)

        self.SpawnTime = CurTime()

        timer.Simple(30, function()
            if IsValid(self) then self:Remove() end
        end)
    end

    function ENT:SetPowerupType(t)
        self:SetNWString("PowerupType", t)
        if t == "Max Ammo" then
            self:SetModel("models/murdered/nz/w_maxammo.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Nuke" then
            self:SetModel("models/murdered/nz/w_nuke.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Double Points" then
            self:SetModel("models/murdered/nz/w_double.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Insta-Kill" then
            self:SetModel("models/murdered/nz/w_insta.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Bonus Points" then
            self:SetModel("models/murdered/nz/w_zmoney.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Full Power" then
            self:SetModel("models/murdered/nz/w_deathmachine.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Fire Sale" then
            self:SetModel("models/murdered/nz/w_firesale.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        elseif t == "Max Armor" then
            self:SetModel("models/murdered/nz/w_carpenter.mdl")
            self:SetMaterial("models/debug/debugwhite")
            self:SetColor(Color(255, 215, 0))
        end
        self:PhysicsInit(SOLID_VPHYSICS)
    end

    function ENT:Think()
        local ang = self:GetAngles()
        ang:RotateAroundAxis(Vector(0,0,1), 90 * FrameTime())
        self:SetAngles(ang)

        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 20)) do
            if IsValid(ent) and ent:IsPlayer() and ent:Alive() then
                self:OnPickup(ent)
                self:Remove()
                return
            end
        end

        self:NextThink(CurTime())
        return true
    end

    function ENT:OnPickup(ply)
        local type = self:GetNWString("PowerupType", "Max Ammo")

        local soundPath = ""
        if type == "Max Ammo" then soundPath = "murdered/nz/announce_maxammo.mp3"
        elseif type == "Nuke" then soundPath = "murdered/nz/announce_nuke.mp3"
        elseif type == "Double Points" then soundPath = "murdered/nz/announce_2x.mp3"
        elseif type == "Insta-Kill" then soundPath = "murdered/nz/announce_killjoy.mp3"
        elseif type == "Bonus Points" then soundPath = "murdered/nz/announce_bonus.mp3"
        elseif type == "Full Power" then soundPath = "murdered/nz/announce_fullpower.mp3"
        elseif type == "Fire Sale" then soundPath = "murdered/nz/announce_firesale.mp3"
        elseif type == "Max Armor" then soundPath = "murdered/nz/announce_maxarmor.mp3"
        end

        self:EmitSound("murdered/nz/powerup_pickup.mp3", 70)
        MuR:PlaySoundOnClient(soundPath)

        if type == "Max Ammo" then
            for _, p in player.Iterator() do
                if p:Alive() then
                    for _, wep in ipairs(p:GetWeapons()) do
                        local primary = wep:GetPrimaryAmmoType()
                        if primary != -1 then
                            p:GiveAmmo(wep:GetMaxClip1() * 8, primary)
                        end
                    end
                    p:EmitSound("items/ammo_pickup.wav")
                end
            end
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Max Ammo")
            net.WriteFloat(CurTime() + 5)
            net.Broadcast()

        elseif type == "Nuke" then
            local zombies = {}
            for _, z in ents.Iterator() do
                if z.IsMode18Zombie then
                    table.insert(zombies, z)
                end
            end

            local count = #zombies
            local delayPerZombie = 4 / math.max(count, 1)

            for i, z in ipairs(zombies) do
                timer.Simple(i * delayPerZombie, function()
                    if IsValid(z) then
                        z:TakeDamage(999999)
                    end
                end)
            end

             for _, p in player.Iterator() do
                if p:Alive() then
                    local pts = p:GetNWInt("MuR_ZombiesPoints", 0)
                    p:SetNWInt("MuR_ZombiesPoints", pts + 400)
                end
            end

            net.Start("MuR.Mode18NukeEffect")
            net.Broadcast()

            net.Start("MuR.Mode18Powerup")
            net.WriteString("Nuke")
            net.WriteFloat(CurTime() + 5)
            net.Broadcast()

        elseif type == "Double Points" then
            MuR.Mode18.DoublePointsEnd = CurTime() + 30
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Double Points")
            net.WriteFloat(CurTime() + 30)
            net.Broadcast()

        elseif type == "Insta-Kill" then
            MuR.Mode18.InstaKillEnd = CurTime() + 30
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Insta-Kill")
            net.WriteFloat(CurTime() + 30)
            net.Broadcast()

        elseif type == "Bonus Points" then
            for _, p in player.Iterator() do
                if p:Alive() then
                    local pts = p:GetNWInt("MuR_ZombiesPoints", 0)
                    p:SetNWInt("MuR_ZombiesPoints", pts + 500)
                end
            end
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Bonus Points")
            net.WriteFloat(CurTime() + 5)
            net.Broadcast()

        elseif type == "Full Power" then
            for _, p in player.Iterator() do
                if p:Alive() then
                    local name = "Mode18GiveFullPower"..p:EntIndex()
                    timer.Create(name, 0.1, 300, function()
                        if IsValid(p) and p:Alive() then
                            for _, wep in ipairs(p:GetWeapons()) do
                                wep:SetClip1(wep:GetMaxClip1())
                            end
                        else
                            timer.Remove(name)
                        end
                    end)
                end
            end
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Full Power")
            net.WriteFloat(CurTime() + 30)
            net.Broadcast()

        elseif type == "Fire Sale" then
            MuR.Mode18.FireSaleEnd = CurTime() + 30
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Fire Sale")
            net.WriteFloat(CurTime() + 30)
            net.Broadcast()

        elseif type == "Max Armor" then
            for _, p in player.Iterator() do
                if p:Alive() then
                    p:SetArmor(100)
                    p:SetHealth(p:GetMaxHealth())
                end
            end
            net.Start("MuR.Mode18Powerup")
            net.WriteString("Max Armor")
            net.WriteFloat(CurTime() + 5)
            net.Broadcast()
        end
    end
end

if CLIENT then
    local glowMat = Material("sprites/glow04_noz")

    function ENT:Draw()
        local dlight = DynamicLight(self:EntIndex())
        if (dlight) then
            dlight.Pos = self:GetPos()
            dlight.r = 50
            dlight.g = 255
            dlight.b = 50
            dlight.Brightness = 1
            dlight.Decay = 1000
            dlight.Size = 128
            dlight.DieTime = CurTime() + 1
        end

        render.SetMaterial(glowMat)
        local color = Color(0, 255, 0, 150)
        local size = 70 + math.sin(CurTime() * 4) * 10
        render.DrawSprite(self:GetPos(), size, size, color)

        self:DrawModel()
    end
end
