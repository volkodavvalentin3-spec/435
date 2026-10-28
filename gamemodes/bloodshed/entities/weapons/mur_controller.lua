AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Control Device"
SWEP.Slot = 2
SWEP.DisableSuicide = true
SWEP.WorldModel = "models/props_lab/w_slam.mdl"
SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModelPosition = Vector(2, -1, 0)
SWEP.WorldModelAngle = Angle(180, 80, 0)
SWEP.ViewModelPos = Vector(0, -2, -2)
SWEP.ViewModelAng = Angle(-2, 2, -2)
SWEP.ViewModelFOV = 60
SWEP.HoldType = "slam"
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Secondary.Ammo = ""

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:SetHoldType(self.HoldType)
end

function SWEP:CustomPrimaryAttack()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    ply:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    if CLIENT then return end
    local tr = util.TraceLine({start=ply:EyePos(), endpos=ply:EyePos()+ply:GetAimVector()*96, filter=ply})
    if not tr.Hit or not IsValid(tr.Entity) then return end
    local ent = tr.Entity
    self.AttachedEnt = ent
    self.Explosive = self.Explosive or false
    self:SetNW2Entity("mur_ctrl_ent", ent)
    self:SetNW2Bool("mur_ctrl_expl", self.Explosive)
    self:EmitSound("buttons/button6.wav", 60)
end

function SWEP:CustomSecondaryAttack()
    self.Explosive = not self.Explosive
    self:SetNW2Bool("mur_ctrl_expl", self.Explosive)
    if SERVER then self:EmitSound(self.Explosive and "buttons/button17.wav" or "buttons/button14.wav", 60) end
end

local function doorAction(ent, act)
    if not IsValid(ent) then return end
    if ent.Fire then
        if act == "open" then ent:Fire("Open") end
        if act == "close" then ent:Fire("Close") end
        if act == "lock" then ent:Fire("Lock") end
        if act == "unlock" then ent:Fire("Unlock") end
        if act == "toggle" then ent:Fire("Toggle") end
    end
end

function SWEP:Think()
    if CLIENT then return end
    if self.TriggerAction and self.AttachedEnt then
        local act = self.TriggerAction
        self.TriggerAction = nil
        if act == "explode" then
            if self.Explosive then
                local explosion = ents.Create("env_explosion")
                explosion:SetPos(self.AttachedEnt:WorldSpaceCenter())
                explosion:Spawn()
                explosion:SetKeyValue("iMagnitude", "140")
                explosion:Fire("Explode", 0, 0)
            end
            self.AttachedEnt = nil
            return
        end
        if act == "remove" then
            if IsValid(self.AttachedEnt) then self.AttachedEnt:Fire("Unlock") end
            self.AttachedEnt = nil
            return
        end
        doorAction(self.AttachedEnt, act)
    end
end

if CLIENT then
    hook.Add("HUDPaint", "mur_ctrl_hud", function()
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
        if not IsValid(wep) or wep:GetClass() ~= "weapon_mur_controller" then return end
        local ent = wep:GetNW2Entity("mur_ctrl_ent")
        local ex = wep:GetNW2Bool("mur_ctrl_expl") and "EXPLOSIVE" or "SAFE"
        draw.SimpleText("Controller ["..ex.."]", "DermaLarge", ScrW()-80, 80, color_white, TEXT_ALIGN_RIGHT)
        if IsValid(ent) then
            draw.SimpleText("Linked: "..tostring(ent:GetClass()), "DermaDefaultBold", ScrW()-80, 110, Color(200,200,200), TEXT_ALIGN_RIGHT)
            draw.SimpleText("Use: reload to cycle actions", "DermaDefault", ScrW()-80, 130, Color(200,200,200), TEXT_ALIGN_RIGHT)
        else
            draw.SimpleText("Primary: attach to door/button", "DermaDefault", ScrW()-80, 110, Color(200,200,200), TEXT_ALIGN_RIGHT)
        end
    end)
end

function SWEP:Reload()
    if CLIENT then return end
    if not IsValid(self.AttachedEnt) then return end
    local opts = {"open","close","lock","unlock","toggle","explode","remove"}
    self.ActionIndex = ((self.ActionIndex or 0) % #opts) + 1
    self.CurrentAction = opts[self.ActionIndex]
    self.TriggerAction = self.CurrentAction
    self:EmitSound("buttons/button9.wav", 55)
end

function SWEP:CustomInit() end

SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
