AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Perk Machine"
ENT.Spawnable = false

MuR = MuR or {}
MuR.Mode18PerkDefs = {
    {id = "juggernog", name = "Juggernog", desc = "Increases max HP to 200", icon = "murdered/nz/jugg.png", sting = "murdered/nz/jugg_sting.mp3"},
    {id = "speedcola", name = "Speed Cola", desc = "2x faster reload", icon = "murdered/nz/speed.png", sting = "murdered/nz/speed_sting.mp3"},
    {id = "doubletap", name = "Double Tap", desc = "2x bullet damage", icon = "murdered/nz/dtap.png", sting = "murdered/nz/dtap2_sting.mp3"},
    {id = "quickrevive", name = "Quick Revive", desc = "HP regeneration when not taking damage", icon = "murdered/nz/revive.png", sting = "murdered/nz/revive_sting.mp3"},
    {id = "phd", name = "PHD Flopper", desc = "Immune to fall and explosion damage", icon = "murdered/nz/phd.png", sting = "murdered/nz/phd_sting.mp3"},
    {id = "melee", name = "Melee Macchiato", desc = "3x melee damage + heal 10 HP per hit", icon = "murdered/nz/melee.png", sting = "murdered/nz/melee_sting.mp3"},
    {id = "staminup", name = "Stamin-Up", desc = "Faster sprint + unlimited stamina", icon = "murdered/nz/staminup.png", sting = "murdered/nz/staminup_sting.mp3"},
    {id = "deadshot", name = "Deadshot Daiquiri", desc = "Increased headshot damage + 10% explosion chance", icon = "murdered/nz/deadshot.png", sting = "murdered/nz/deadshot_sting.mp3"},
    {id = "deathperception", name = "Death Perception", desc = "Warns of zombies behind, -50% back damage, speed boost on hit", icon = "murdered/nz/death.png", sting = "murdered/nz/death_sting.mp3"},
    {id = "slashersake", name = "Slasher Sake", desc = "Explosion on damage, deals 50% HP to nearby zombies (15s CD)", icon = "murdered/nz/sake.png", sting = "murdered/nz/sake_sting.mp3"},
    {id = "mulekick", name = "Mule Kick", desc = "Removes weapon carry limits", icon = "murdered/nz/mulekick.png", sting = "murdered/nz/mulekick_sting.mp3"},
    {id = "bandolier", name = "Bandolier Bandit", desc = "+4 magazines max ammo, +2 magazines on wave end", icon = "murdered/nz/candolier.png", sting = "murdered/nz/ammo_sting.wav"},
}

if SERVER then
    util.AddNetworkString("MuR.Mode18PerkMenu")
    util.AddNetworkString("MuR.Mode18BuyPerk")
    util.AddNetworkString("MuR.Mode18PerkSync")
    util.AddNetworkString("MuR.Mode18CloseUI")

    function ENT:Initialize()
        self:SetModel("models/props/cs_office/Vending_machine.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetNWBool("Mode18ShowOutline", true)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        effectdata:SetScale(2)
        util.Effect("cball_explode", effectdata)
        self:EmitSound("ambient/machines/teleport1.wav", 70, 120)
    end

    function ENT:OnRemove()
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        effectdata:SetScale(1.5)
        util.Effect("cball_explode", effectdata)
        self:EmitSound("ambient/machines/teleport3.wav", 60, 150)
    end

    function ENT:Use(activator, caller)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        if MuR.Mode18 and MuR.Mode18.State == "wave" then return end

        net.Start("MuR.Mode18PerkMenu")
        net.WriteEntity(self)
        net.Send(activator)
    end

    function ENT:GetPerkCost(ply)
        local perks = ply.Mode18Perks or {}
        local count = table.Count(perks)
        return 2000 + (count * 250)
    end

    net.Receive("MuR.Mode18BuyPerk", function(len, ply)
        local ent = net.ReadEntity()
        local perkId = net.ReadString()

        if not IsValid(ent) or ent:GetClass() ~= "mode18_perkmachine" then return end
        if ent:GetPos():Distance(ply:GetPos()) > 200 then return end
        if MuR.Mode18 and MuR.Mode18.State == "wave" then return end

        ply.Mode18Perks = ply.Mode18Perks or {}

        if ply.Mode18Perks[perkId] then
            ply:EmitSound("buttons/button10.wav")
            return
        end

        local cost = ent:GetPerkCost(ply)
        local points = ply:GetNWInt("MuR_ZombiesPoints", 0)

        if points < cost then
            ply:EmitSound("buttons/button10.wav")
            return
        end

        ply:SetNWInt("MuR_ZombiesPoints", points - cost)
        ply.Mode18Perks[perkId] = true

        if perkId == "juggernog" then
            ply:SetMaxHealth(200)
            ply:SetHealth(math.min(ply:Health() + 100, 200))
        elseif perkId == "staminup" then
            ply:SetNW2Bool("Mode18Staminup", true)
        end

        ply:EmitSound("murdered/nz/perk_drink.mp3", 60)

        MuR.Mode18LastStingTime = MuR.Mode18LastStingTime or 0
        if CurTime() > MuR.Mode18LastStingTime + 5 then
            for _, perk in ipairs(MuR.Mode18PerkDefs) do
                if perk.id == perkId and perk.sting then
                    MuR:PlaySoundOnClient(perk.sting)
                    MuR.Mode18LastStingTime = CurTime()
                    break
                end
            end
        end

        net.Start("MuR.Mode18PerkSync")
        net.WriteTable(ply.Mode18Perks)
        net.Send(ply)
    end)

    hook.Add("PlayerDeath", "MuR_Mode18_ClearPerks", function(victim)
        if MuR.Gamemode ~= 18 then return end

        victim:SetMaxHealth(100)
        victim:SetNW2Bool("Mode18Staminup", false)

    end)

    hook.Add("PlayerSpawn", "MuR_Mode18_ReapplyPerks", function(ply)
        if MuR.Gamemode ~= 18 then return end

        timer.Simple(0.1, function()
            if not IsValid(ply) or not ply.Mode18Perks then return end

            if ply.Mode18Perks["juggernog"] then
                ply:SetMaxHealth(200)
                ply:SetHealth(200)
            end

            if ply.Mode18Perks["staminup"] then
                ply:SetNW2Bool("Mode18Staminup", true)
            end

            net.Start("MuR.Mode18PerkSync")
            net.WriteTable(ply.Mode18Perks)
            net.Send(ply)
        end)
    end)

    hook.Add("EntityTakeDamage", "MuR_Mode18_PerkEffects", function(target, dmginfo)
        if MuR.Gamemode ~= 18 then return end

        local attacker = dmginfo:GetAttacker()

        if target:IsPlayer() and target.Mode18Perks and target.Mode18Perks["phd"] then
            if dmginfo:IsFallDamage() or dmginfo:IsExplosionDamage() then
                return true
            end
        end

        if IsValid(attacker) and attacker:IsPlayer() and attacker.Mode18Perks then
            local wep = attacker:GetActiveWeapon()
            local isMelee = IsValid(wep) and (wep.Melee or wep.Base == "tfa_melee_base" or wep:GetClass() == "mur_hands")
            local isBullet = dmginfo:IsBulletDamage()

            if attacker.Mode18Perks["doubletap"] and isBullet then
                dmginfo:ScaleDamage(2)
            end

            if attacker.Mode18Perks["melee"] and isMelee then
                dmginfo:ScaleDamage(3)
                attacker:SetHealth(math.min(attacker:Health() + 10, attacker:GetMaxHealth()))
            end

            if attacker.Mode18Perks["deadshot"] and isBullet then
                local hitgroup = dmginfo:GetReportedPosition()
                if MuR.IsAI(target) and target.IsMode18Zombie then
                    local headPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Head") or 0)
                    if headPos and dmginfo:GetDamagePosition():Distance(headPos) < 20 then
                        dmginfo:ScaleDamage(1.5)
                        if math.random() < 0.1 then
                            local effectdata = EffectData()
                            effectdata:SetOrigin(target:GetPos())
                            effectdata:SetScale(1)
                            util.Effect("Explosion", effectdata)
                            target:TakeDamage(100, attacker, attacker)
                        end
                    end
                end
            end
        end
    end)

    hook.Add("Think", "MuR_Mode18_QuickRevive", function()
        if MuR.Gamemode ~= 18 then return end

        for _, ply in player.Iterator() do
            if ply:Alive() and ply.Mode18Perks and ply.Mode18Perks["quickrevive"] then
                local lastDamage = ply.Mode18LastDamageTime or 0
                if CurTime() - lastDamage > 5 then
                    if ply:Health() < ply:GetMaxHealth() then
                        ply.Mode18RegenTime = ply.Mode18RegenTime or 0
                        if CurTime() > ply.Mode18RegenTime then
                            ply.Mode18RegenTime = CurTime() + 0.5
                            ply:SetHealth(math.min(ply:Health() + 5, ply:GetMaxHealth()))
                        end
                    end
                end
            end
        end
    end)

    hook.Add("PostEntityTakeDamage", "MuR_Mode18_TrackDamage", function(ent, dmginfo, took)
        if MuR.Gamemode ~= 18 then return end
        if ent:IsPlayer() and took then
            ent.Mode18LastDamageTime = CurTime()

            if ent.Mode18Perks and ent.Mode18Perks["deathperception"] then
                ent.Mode18SpeedBoostEnd = CurTime() + 3
            end

            local attacker = dmginfo:GetAttacker()
            if ent.Mode18Perks and ent.Mode18Perks["slashersake"] then
                if IsValid(attacker) and MuR.IsAI(attacker) then
                    ent.Mode18SakeNextUse = ent.Mode18SakeNextUse or 0
                    if CurTime() > ent.Mode18SakeNextUse then
                        ent.Mode18SakeNextUse = CurTime() + 15

                        local effectdata = EffectData()
                        effectdata:SetOrigin(ent:GetPos())
                        effectdata:SetScale(1.5)
                        util.Effect("Explosion", effectdata)
                        ent:EmitSound("weapons/explode3.wav", 80, 120)

                        for _, npc in ents.Iterator() do
                            if IsValid(npc) and MuR.IsAI(npc) and npc.IsMode18Zombie then
                                if npc:GetPos():Distance(ent:GetPos()) < 300 then
                                    local dmg = npc:Health() * 0.5
                                    npc:TakeDamage(dmg, ent, ent)

                                    local dir = (npc:GetPos() - ent:GetPos()):GetNormalized()
                                    local phys = npc:GetPhysicsObject()
                                    if IsValid(phys) then
                                        phys:ApplyForceCenter(dir * 5000)
                                    end
                                    npc:SetVelocity(dir * 500 + Vector(0, 0, 200))
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    hook.Add("EntityTakeDamage", "MuR_Mode18_DeathPerception", function(target, dmginfo)
        if MuR.Gamemode ~= 18 then return end
        if not target:IsPlayer() then return end
        if not target.Mode18Perks or not target.Mode18Perks["deathperception"] then return end

        local attacker = dmginfo:GetAttacker()
        if not IsValid(attacker) then return end

        local toAttacker = (attacker:GetPos() - target:GetPos()):GetNormalized()
        local facing = target:GetAimVector()
        local dot = facing:Dot(toAttacker)

        if dot < -0.3 then
            dmginfo:ScaleDamage(0.5)
        end
    end)

    hook.Add("SetupMove", "MuR_Mode18_DeathPerceptionSpeed", function(ply, mv, cmd)
        if MuR.Gamemode ~= 18 then return end
        if not ply.Mode18Perks or not ply.Mode18Perks["deathperception"] then return end

        if ply.Mode18SpeedBoostEnd and CurTime() < ply.Mode18SpeedBoostEnd then
            mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * 2)
        end
    end)

    hook.Add("PlayerCanPickupWeapon", "MuR_Mode18_MuleKick", function(ply, wep)
        if MuR.Gamemode ~= 18 then return end
        if ply.Mode18Perks and ply.Mode18Perks["mulekick"] then
            return true
        end
    end)

    local TFA_STATUS_RELOAD = 3

    hook.Add("Think", "MuR_Mode18_SpeedCola", function()
        if MuR.Gamemode ~= 18 then return end

        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end

            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) then continue end

            local hasSpeedCola = ply.Mode18Perks and ply.Mode18Perks["speedcola"]
            if not hasSpeedCola then
                if wep.Mode18SCActive then
                    wep.Mode18SCActive = false
                    wep:SetPlaybackRate(1)
                    local vm = ply:GetViewModel()
                    if IsValid(vm) then vm:SetPlaybackRate(1) end
                end
                continue
            end

            if wep.GetStatus and wep.SetStatusEnd and wep.GetStatusEnd then
                local status = wep:GetStatus()

                if status == TFA_STATUS_RELOAD then
                    local statusEnd = wep:GetStatusEnd()
                    local now = CurTime()

                    if statusEnd and statusEnd > now then
                        if not wep.Mode18SCReloadID or wep.Mode18SCReloadID ~= statusEnd then
                            wep.Mode18SCReloadID = statusEnd
                            wep.Mode18SCActive = true

                            local remaining = statusEnd - now
                            local newEnd = now + (remaining / 2)

                            wep:SetStatusEnd(newEnd)
                            wep:SetNextPrimaryFire(newEnd)
                            wep:SetNextSecondaryFire(newEnd)

                            if wep.SetNextIdleAnim then
                                wep:SetNextIdleAnim(newEnd)
                            end

                            wep:SetPlaybackRate(2)
                            local vm = ply:GetViewModel()
                            if IsValid(vm) then
                                vm:SetPlaybackRate(2)
                            end
                        end
                    end
                else
                    if wep.Mode18SCActive then
                        wep.Mode18SCActive = false
                        wep:SetPlaybackRate(1)
                        local vm = ply:GetViewModel()
                        if IsValid(vm) then vm:SetPlaybackRate(1) end
                    end
                end
            end
        end
    end)
end

if CLIENT then
    local perkIcons = {}
    local LocalPerks = {}

    for _, perk in ipairs(MuR.Mode18PerkDefs) do
        perkIcons[perk.id] = Material(perk.icon, "noclamp smooth")
    end

    local placeholderMat = Material("icon16/star.png")

    net.Receive("MuR.Mode18PerkSync", function()
        LocalPerks = net.ReadTable()
    end)

    net.Receive("MuR.Mode18PerkMenu", function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        local ply = LocalPlayer()
        local perks = LocalPerks or {}
        local perkCount = table.Count(perks)
        local nextCost = 2000 + (perkCount * 250)
        local myPoints = ply:GetNWInt("MuR_ZombiesPoints", 0)

        local frame = vgui.Create("DFrame")
        local frameW = math.min(We(970), ScrW() - 100)
        local frameH = math.min(He(500), ScrH() - 100)
        frame:SetSize(frameW, frameH)
        frame:Center()
        frame:SetTitle("")
        frame:MakePopup()
        frame:SetDraggable(false)
        frame:ShowCloseButton(false)
        frame.Paint = function(self, w, h)
            Derma_DrawBackgroundBlur(self, self.StartTime)

            draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 25, 250))

            local headerH = He(60)
            draw.RoundedBoxEx(8, 0, 0, w, headerH, Color(40, 40, 45, 255), true, true, false, false)
            draw.SimpleText(MuR.Language["mode18_wonderfizz"] or "WONDERFIZZ", "MuR_Font3", We(20), headerH/2, Color(255, 200, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local pointsText = (MuR.Language["mode18_points"] or "POINTS") .. ": " .. string.Comma(myPoints)
            draw.SimpleText(pointsText, "MuR_Font3", w - We(60), headerH/2, Color(100, 255, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            draw.SimpleText(MuR.Language["mode18_select_perk"] or "Select a perk to purchase", "MuR_Font2", w/2, headerH + He(25), Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        frame.StartTime = SysTime()
        frame.OpenedForEnt = ent

        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetSize(We(30), He(30))
        closeBtn:SetPos(frame:GetWide() - We(40), He(15))
        closeBtn:SetText("X")
        closeBtn:SetFont("MuR_Font2")
        closeBtn:SetTextColor(Color(255, 100, 100))
        closeBtn.Paint = function() end
        closeBtn.DoClick = function() frame:Close() end

        local grid = vgui.Create("DIconLayout", frame)
        grid:Dock(FILL)
        grid:DockMargin(We(20), He(90), We(20), He(60))
        grid:SetSpaceX(We(10))
        grid:SetSpaceY(He(10))

        for _, perk in ipairs(MuR.Mode18PerkDefs) do
            local owned = perks[perk.id]

            local btn = grid:Add("DButton")
            local btnW = math.floor((frameW - We(60)) / 6) - We(10)
            local btnH = math.floor((frameH - He(170)) / 2) - He(10)
            btn:SetSize(btnW, btnH)
            btn:SetText("")
            btn.PerkData = perk

            btn.Paint = function(self, w, h)
                local hovered = self:IsHovered()
                local canAfford = myPoints >= nextCost

                local bgCol = Color(30, 30, 35, 255)
                if owned then bgCol = Color(20, 50, 20, 255)
                elseif hovered and not owned then bgCol = Color(40, 40, 50, 255) end

                draw.RoundedBox(6, 0, 0, w, h, bgCol)

                if hovered and not owned and canAfford then
                    surface.SetDrawColor(255, 200, 50, 255)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                elseif owned then
                    surface.SetDrawColor(50, 200, 50, 100)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end

                local iconMat = perkIcons[perk.id] or placeholderMat
                surface.SetMaterial(iconMat)
                surface.SetDrawColor(255, 255, 255, owned and 100 or 255)
                local iconSize = He(60)
                surface.DrawTexturedRect(w/2 - iconSize/2, He(10), iconSize, iconSize)

                local perkName = MuR.Language["mode18_perk_" .. perk.id] or perk.name
                draw.SimpleText(perkName, "MuR_Font1", w/2, He(90), Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                if owned then
                    local ownedText = MuR.Language["mode18_owned"] or "OWNED"
                    draw.SimpleText(ownedText, "MuR_Font1", w/2, h - He(10), Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                else
                    local col = canAfford and Color(255, 220, 50) or Color(255, 100, 100)
                    draw.SimpleText("$" .. nextCost, "MuR_Font1", w/2, h - He(10), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end
            end

            btn.DoClick = function()
                if owned then return end
                if myPoints < nextCost then
                    surface.PlaySound("buttons/button10.wav")
                    return
                end

                net.Start("MuR.Mode18BuyPerk")
                net.WriteEntity(ent)
                net.WriteString(perk.id)
                net.SendToServer()

                frame:Close()
            end
        end

        local descPanel = vgui.Create("DPanel", frame)
        descPanel:SetSize(frame:GetWide() - We(40), He(40))
        descPanel:SetPos(We(20), frame:GetTall() - He(55))
        descPanel.CurrentDesc = ""
        descPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(25, 25, 30, 255))
            draw.SimpleText(self.CurrentDesc, "MuR_Font1", w/2, h/2, Color(180, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        hook.Add("Think", "Mode18PerkDescHover", function()
            if not IsValid(frame) then
                hook.Remove("Think", "Mode18PerkDescHover")
                return
            end

            local hoveredBtn = nil
            for _, child in pairs(grid:GetChildren()) do
                if child:IsHovered() and child.PerkData then
                    hoveredBtn = child
                    break
                end
            end

            if hoveredBtn and hoveredBtn.PerkData then
                descPanel.CurrentDesc = MuR.Language["mode18_perk_" .. hoveredBtn.PerkData.id .. "_desc"] or hoveredBtn.PerkData.desc
            else
                descPanel.CurrentDesc = MuR.Language["mode18_hover_hint"] or "Hover over a perk to see its effect"
            end
        end)

        hook.Add("Think", "Mode18PerkMenuAutoClose", function()
            if not IsValid(frame) then
                hook.Remove("Think", "Mode18PerkMenuAutoClose")
                return
            end
            if MuR.Mode18Client and MuR.Mode18Client.State == "wave" then
                frame:Close()
                hook.Remove("Think", "Mode18PerkMenuAutoClose")
            end
        end)
    end)

    net.Receive("MuR.Mode18CloseUI", function()
        for _, panel in ipairs(vgui.GetWorldPanel():GetChildren()) do
            if panel.OpenedForEnt then
                panel:Close()
            end
        end
    end)

    hook.Add("HUDPaint", "MuR.Mode18PerkHUD", function()
        if MuR.GamemodeCount ~= 18 then return end
        if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") or MuR.CutsceneActive then return end

        local ply = LocalPlayer()
        if not ply:Alive() then return end

        local perks = LocalPerks or {}
        local perkList = {}
        for id, _ in pairs(perks) do
            table.insert(perkList, id)
        end
        table.sort(perkList)

        if #perkList == 0 then return end

        local iconSize = 64
        local spacing = 4
        local totalWidth = #perkList * iconSize + (#perkList - 1) * spacing
        local startX = (ScrW() - totalWidth) / 2
        local y = ScrH() - 100

        for i, perkId in ipairs(perkList) do
            local x = startX + (i - 1) * (iconSize + spacing)
            local mat = perkIcons[perkId] or placeholderMat

            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(x, y, iconSize, iconSize)
        end
    end)

    hook.Add("Think", "MuR.Mode18SpeedCola", function()
        if MuR.GamemodeCount ~= 18 then return end

        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local perks = LocalPerks or {}
        local hasSpeedCola = perks["speedcola"]

        local vm = ply:GetViewModel()
        if IsValid(vm) then
            local rate = hasSpeedCola and 2 or 1
            if vm:GetPlaybackRate() ~= rate then
                vm:SetPlaybackRate(rate)
            end
        end
    end)

    local outlineMat = Material("models/debug/debugwhite")

    function ENT:Draw()
        self:DrawModel()
    end

    hook.Add("PreDrawHalos", "MuR.Mode18EntityOutlines", function()
        if MuR.GamemodeCount ~= 18 then return end

        local perks = {}
        local plyPos = LocalPlayer():GetPos()

        for _, ent in ents.Iterator() do
            if IsValid(ent) and ent:GetNWBool("Mode18ShowOutline", false) then
                if ent:GetPos():DistToSqr(plyPos) < 4000000 then
                    if ent:GetClass() == "mode18_perkmachine" then
                        table.insert(perks, ent)
                    end
                end
            end
        end

        if #perks > 0 then
            halo.Add(perks, Color(100, 255, 100), 2, 2, 1, true, true)
        end
    end)

    hook.Add("HUDPaint", "MuR.Mode18DeathPerception", function()
        if MuR.GamemodeCount ~= 18 then return end

        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local perks = LocalPerks or {}
        if not perks["deathperception"] then return end

        local plyPos = ply:GetPos()
        local plyAng = ply:EyeAngles()
        local forward = plyAng:Forward()

        local zombieBehind = false
        local closestDist = 500

        for _, ent in ents.Iterator() do
            if IsValid(ent) and MuR.IsAI(ent) and ent:GetNWBool("IsMode18Zombie", false) then
                local dist = ent:GetPos():Distance(plyPos)
                if dist < 400 then
                    local toZombie = (ent:GetPos() - plyPos):GetNormalized()
                    local dot = forward:Dot(toZombie)

                    if dot < -0.3 then
                        zombieBehind = true
                        closestDist = math.min(closestDist, dist)
                    end
                end
            end
        end

        if zombieBehind then
            local w, h = ScrW(), ScrH()
            local pulse = math.abs(math.sin(CurTime() * 5))
            local alpha = 80 + pulse * 100
            local intensity = 1 - (closestDist / 400)
            alpha = alpha * intensity

            surface.SetDrawColor(255, 0, 0, alpha)

            local edgeSize = He(80)
            surface.DrawRect(0, 0, w, edgeSize * intensity)
            surface.DrawRect(0, h - edgeSize * intensity, w, edgeSize * intensity)
            surface.DrawRect(0, 0, edgeSize * intensity, h)
            surface.DrawRect(w - edgeSize * intensity, 0, edgeSize * intensity, h)

            if pulse > 0.7 then
                local warnText = MuR.Language["mode18_zombie_behind"] or "ZOMBIE BEHIND!"
                draw.SimpleText(warnText, "MuR_Font3", w/2, He(100), Color(255, 50, 50, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)
end
