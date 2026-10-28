SWEP.PrintName = "Mind Controller"
SWEP.Author = "Hari"
SWEP.Category = "Bloodshed - Illegal"
SWEP.Base = "mur_other_base"

SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.WorldModel = "models/murdered/heroin/syringe_out/syringe_out.mdl"
SWEP.ViewModel = "models/murdered/heroin/darky_m/c_syringe_v2.mdl"
SWEP.UseHands = true
SWEP.Spawnable = true

SWEP.Primary.ClipSize = 3
SWEP.Primary.DefaultClip = 3
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.VElements = {
	["heroin"] = { type = "Model", model = "models/murdered/heroin/syringe_out/syringe_out.mdl", bone = "main", rel = "", pos = Vector(0, -5.41, -0.205), angle = Angle(0, -90, -30), size = Vector(1.2, 1.2, 1.2), color = Color(50, 50, 50), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.ViewModelBoneMods = {
	["main"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["button"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["cap"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["capup"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}

if SERVER then
    if not INFECTED_PLAYERS then
        INFECTED_PLAYERS = {}
    end

    local function BlockPlayerInput(ply, bind, pressed)
        if ply:GetNW2Bool("MindControlled") then
            if bind == "cancelselect" then
                return false
            end
            return true
        end
    end
    hook.Add("PlayerBindPress", "MindControl_BlockInput", BlockPlayerInput)

    hook.Add("PlayerCanHearPlayersVoice", "MindControl_BlockVoice", function(listener, talker)
        if talker:GetNW2Bool("MindControlled") then
            return false
        end
    end)

    hook.Add("PlayerSay", "MindControl_BlockChat", function(ply, text, team)
        if ply:GetNW2Bool("MindControlled") then
            return ""
        end
    end)
end

function SWEP:DrawWorldModel() end

function SWEP:Deploy( wep )
    self:SendWeaponAnim(ACT_VM_DRAW)
end

function SWEP:CustomInit()
    self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    self:SetNextPrimaryFire(CurTime() + 2)

    local owner = self:GetOwner()
    if !IsValid(owner) then return end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 128,
        filter = owner
    })

    local target = tr.Entity
    if IsValid(target) and target.isRDRag and IsValid(target.Owner) then
		target = target.Owner
	end
    if IsValid(target) and target:IsPlayer() and target:Alive() then
        self:InfectPlayer(target, owner)

        MuR:GiveMessage("mindcontroller_use", owner)

        self:Remove()
    end
end

function SWEP:InfectPlayer(target, infector)
    if SERVER then
        INFECTED_PLAYERS[target:SteamID()] = {
            player = target,
            infector = infector,
            infected_time = CurTime()
        }
    end
end

function SWEP:SecondaryAttack()
    return false
end

if SERVER then
    concommand.Add("mur_mindactivate", function(ply, cmd, args)
        local isTraitor = ply:Team() == 1

        if isTraitor then
            local activatedCount = 0

            for steamID, data in pairs(INFECTED_PLAYERS) do
                local target = data.player
                if IsValid(target) and target:Alive() then
                    ActivateMindControl(target, ply)
                    activatedCount = activatedCount + 1
                    INFECTED_PLAYERS[target:SteamID()] = nil
                end
            end

            ply:ChatPrint("Activated mind control on " .. activatedCount .. " infected players.")
        end
    end)

    function ActivateMindControl(target, att)
        local weapons = target:GetWeapons()
        local attackWeapon = target:GetWeapon("mur_hands")

        if #weapons > 0 then
            for _, weapon in pairs(weapons) do
                if weapon:Clip1() > 1 and string.find(weapon:GetClass(), "tfa") then
                    attackWeapon = weapon
                    break
                elseif weapon.Melee and string.find(weapon:GetClass(), "mur") then
                    attackWeapon = weapon
                    break
                end
            end
        end

        if attackWeapon then
            local duration = 20
            local attackThink = 0
            local tick = 0
            local lastDirection = Vector(0, 0, 0)
            local moveTimer = 0
            local strafeDirection = 1
            local behaviorState = "hunting"
            local searchTimer = 0
            local stuckTimer = 0
            local lastPos = target:GetPos()
            local jumpCooldown = 0
            local wanderDirection = math.random(0, 360)
            local wanderTimer = 0

            local originalTeam = target:Team()
            local originalRunSpeed = target:GetRunSpeed()
            local originalWalkSpeed = target:GetWalkSpeed()

            target:SetNW2Bool("MindControlled", true)
            target:SetNW2Entity("MindController", att)

            local function findFreeDirection(pos, currentAngle)
                local bestDir = nil
                local bestDist = 0

                for i = 0, 7 do
                    local angle = currentAngle + Angle(0, i * 45, 0)
                    local dir = angle:Forward()

                    local tr = util.TraceLine({
                        start = pos + Vector(0, 0, 40),
                        endpos = pos + Vector(0, 0, 40) + dir * 200,
                        filter = target
                    })

                    if tr.Fraction > bestDist then
                        bestDist = tr.Fraction
                        bestDir = angle
                    end
                end

                return bestDir
            end

            local function scanRoom()
                local roomSize = 0
                local openDirs = {}

                for i = 0, 7 do
                    local angle = Angle(0, i * 45, 0)
                    local dir = angle:Forward()

                    local tr = util.TraceLine({
                        start = target:GetPos() + Vector(0, 0, 40),
                        endpos = target:GetPos() + Vector(0, 0, 40) + dir * 500,
                        filter = target
                    })

                    if tr.Fraction > 0.5 then
                        table.insert(openDirs, angle.y)
                    end

                    roomSize = roomSize + tr.Fraction
                end

                return openDirs, roomSize / 8
            end

            timer.Create("MindControl_" .. target:EntIndex(), 0.01, duration * 100, function()
                if not IsValid(target) or not target:Alive() then
                    timer.Remove("MindControl_" .. target:EntIndex())
                    if IsValid(target) then
                        target:SetNW2Bool("MindControlled", false)
                        target:SetNW2Entity("MindController", NULL)
                        target:SetTeam(originalTeam)
                    end
                    return
                end

                tick = tick + 1
                moveTimer = moveTimer + 0.01
                jumpCooldown = math.max(0, jumpCooldown - 0.01)
                wanderTimer = wanderTimer + 0.01

                if tick >= 2000 then
                    target:SetHealth(1)
                    target.DeathBlowHead = true
                    target:TakeDamage(10, att)
                    target:SetNW2Bool("MindControlled", false)
                    target:SetNW2Entity("MindController", NULL)
                    return
                end

                target:SetTeam(1)
                target.MindController = att

                if attackWeapon and attackWeapon:IsValid() then
                    if attackWeapon:Clip1() == 0 and attackWeapon:GetMaxClip1() > 0 then
                        local hasAmmo = false
                        local ammoType = attackWeapon:GetPrimaryAmmoType()
                        if ammoType > 0 then
                            hasAmmo = target:GetAmmoCount(ammoType) > 0
                        end

                        if not hasAmmo then
                            local newWeapon = nil
                            local weapons = target:GetWeapons()

                            for _, weapon in pairs(weapons) do
                                if weapon != attackWeapon then
                                    if weapon:Clip1() > 0 and string.find(weapon:GetClass(), "tfa") then
                                        newWeapon = weapon
                                        break
                                    elseif weapon.Melee and string.find(weapon:GetClass(), "mur") then
                                        newWeapon = weapon
                                    end
                                end
                            end

                            if newWeapon then
                                attackWeapon = newWeapon
                            elseif not newWeapon then
                                attackWeapon = target:GetWeapon("mur_hands")
                            end
                        end
                    end
                end

                target:SelectWeapon(attackWeapon:GetClass())

                if math.random(1, 15) == 1 then
                    local effectdata = EffectData()
                    effectdata:SetOrigin(target:GetPos() + Vector(0, 0, 64))
                    util.Effect("StunstickImpact", effectdata)
                end

                local checkDoors = function()
                    local doorTr = util.TraceLine({
                        start = target:GetShootPos(),
                        endpos = target:GetShootPos() + target:GetAimVector() * 100,
                        filter = target
                    })

                    if IsValid(doorTr.Entity) then
                        local ent = doorTr.Entity
                        if ent:GetClass() == "func_door" or ent:GetClass() == "func_door_rotating" or ent:GetClass() == "prop_door_rotating" then
                            ent:Fire("Open")
                            return true
                        end
                    end
                    return false
                end

                if target:GetPos():Distance(lastPos) < 10 then
                    stuckTimer = stuckTimer + 0.01
                else
                    stuckTimer = 0
                    lastPos = target:GetPos()
                end

                local closestPlayer = nil
                local closestDist = 2000

                for _, ply in player.Iterator() do
                    if ply != target and ply:Alive() and ply:Health() > 1 and ply:Team() != 1 then
                        local dist = ply:GetPos():Distance(target:GetPos())
                        if dist < closestDist then
                            local tr = util.TraceLine({
                                start = target:GetShootPos(),
                                endpos = ply:GetShootPos(),
                                filter = {target}
                            })

                            if tr.Entity == ply or tr.Fraction > 0.9 then
                                closestDist = dist
                                closestPlayer = ply
                            end
                        end
                    end
                end

                if IsValid(closestPlayer) then
                    behaviorState = closestDist < 150 and "attacking" or "hunting"
                    wanderTimer = 0

                    local aimPos = closestPlayer:GetPos() + Vector(0, 0, 40)
                    local aimOffset = VectorRand() * math.random(0, 3)
                    local aimVector = (aimPos + aimOffset - target:GetShootPos()):GetNormalized()

                    local currentAngles = target:EyeAngles()
                    local targetAngles = aimVector:Angle()
                    local angleDiff = math.abs(math.AngleDifference(currentAngles.y, targetAngles.y))
                    local lerpAmount = math.Clamp(0.05 + (angleDiff / 180) * 0.1, 0.05, 0.25)
                    local newAngles = LerpAngle(lerpAmount, currentAngles, targetAngles)
                    target:SetEyeAngles(newAngles)

                    if behaviorState == "attacking" then
                        attackThink = attackThink + 0.01
                        if attackThink >= 0.3 then
                            attackThink = 0
                            target:ConCommand("+attack")
                            timer.Simple(0.1, function()
                                if IsValid(target) then
                                    target:ConCommand("-attack")
                                end
                            end)
                        end

                        if attackWeapon.SetCustomize then
                            attackWeapon:SetCustomize(false)
                        end

                        if moveTimer > 0.5 then
                            strafeDirection = -strafeDirection
                            moveTimer = 0
                        end

                        target:ConCommand(strafeDirection > 0 and "+moveright" or "+moveleft")
                        timer.Simple(0.1, function()
                            if IsValid(target) then
                                target:ConCommand(strafeDirection > 0 and "-moveright" or "-moveleft")
                            end
                        end)

                        if attackWeapon:IsValid() and string.find(attackWeapon:GetClass(), "mur") then
                            target:ConCommand("+forward")
                            timer.Simple(0.1, function()
                                if IsValid(target) then
                                    target:ConCommand("-forward")
                                end
                            end)
                        end

                    elseif behaviorState == "hunting" then
                        local moveDir = (closestPlayer:GetPos() - target:GetPos()):GetNormalized()

                        local frontTrace = util.TraceLine({
                            start = target:GetPos() + Vector(0, 0, 40),
                            endpos = target:GetPos() + Vector(0, 0, 40) + moveDir * 100,
                            filter = target
                        })

                        checkDoors()

                        if frontTrace.Hit and frontTrace.Fraction < 0.7 then
                            local freeDir = findFreeDirection(target:GetPos(), target:EyeAngles())
                            if freeDir then
                                local newAngles = LerpAngle(0.1, target:EyeAngles(), freeDir)
                                target:SetEyeAngles(newAngles)
                            end

                            if jumpCooldown <= 0 and frontTrace.HitNormal.a < 0.7 then
                                target:ConCommand("+jump")
                                jumpCooldown = 1
                                timer.Simple(0.1, function()
                                    if IsValid(target) then
                                        target:ConCommand("-jump")
                                    end
                                end)
                            end
                        end

                        target:ConCommand("+forward")
                        timer.Simple(0.1, function()
                            if IsValid(target) then
                                target:ConCommand("-forward")
                            end
                        end)

                        if closestDist > 500 then
                            target:ConCommand("+speed")
                        else
                            target:ConCommand("-speed")
                        end

                        if closestDist < 800 and attackWeapon:Clip1() > 0 then
                            attackThink = attackThink + 0.01
                            if attackThink >= 0.5 then
                                attackThink = 0
                                target:ConCommand("+attack")
                                timer.Simple(0.05, function()
                                    if IsValid(target) then
                                        target:ConCommand("-attack")
                                    end
                                end)
                            end
                        end
                    end

                else
                    behaviorState = "searching"

                    if wanderTimer > 2 or stuckTimer > 0.5 then
                        local openDirs, roomSize = scanRoom()

                        if #openDirs > 0 then
                            wanderDirection = openDirs[math.random(1, #openDirs)]
                        else
                            wanderDirection = math.random(0, 360)
                        end

                        wanderTimer = 0
                    end

                    local wanderAngle = Angle(0, wanderDirection, 0)
                    local currentAngles = target:EyeAngles()
                    local newAngles = LerpAngle(0.06, currentAngles, wanderAngle)
                    target:SetEyeAngles(newAngles)

                    local frontCheck = util.TraceLine({
                        start = target:GetPos() + Vector(0, 0, 40),
                        endpos = target:GetPos() + Vector(0, 0, 40) + target:GetAimVector() * 100,
                        filter = target
                    })

                    checkDoors()

                    if frontCheck.Hit and frontCheck.Fraction < 0.5 then
                        wanderDirection = wanderDirection + math.random(90, 270)
                        if wanderDirection > 360 then wanderDirection = wanderDirection - 360 end
                    else
                        target:ConCommand("+forward")
                        timer.Simple(0.2, function()
                            if IsValid(target) then
                                target:ConCommand("-forward")
                            end
                        end)
                    end
                end

                if stuckTimer > 1 and jumpCooldown <= 0 then
                    target:ConCommand("+jump")
                    jumpCooldown = 1
                    timer.Simple(0.1, function()
                        if IsValid(target) then
                            target:ConCommand("-jump")
                        end
                    end)

                    target:ConCommand("+back")
                    timer.Simple(0.3, function()
                        if IsValid(target) then
                            target:ConCommand("-back")
                        end
                    end)

                    wanderDirection = wanderDirection + 180
                    if wanderDirection > 360 then wanderDirection = wanderDirection - 360 end

                    stuckTimer = 0
                end

                if attackWeapon:Clip1() == 0 and attackWeapon:GetMaxClip1() > 0 then
                    target:ConCommand("+reload")
                    timer.Simple(0.1, function()
                        if IsValid(target) then
                            target:ConCommand("-reload")
                        end
                    end)
                end

                if tick % 50 == 0 and attackWeapon:Clip1() == 0 then
                    local weapons = target:GetWeapons()
                    for _, weapon in pairs(weapons) do
                        if weapon != attackWeapon then
                            if (weapon:Clip1() > 0 and string.find(weapon:GetClass(), "tfa")) or
                            (weapon.Melee and string.find(weapon:GetClass(), "mur")) then
                                attackWeapon = weapon
                                break
                            end
                        end
                    end
                end
            end)
        end
    end
end

function SWEP:DrawHUD()
	local ply = self:GetOwner()
	draw.SimpleText(MuR.Language["mindcontroller_hint"], "MuR_Font1", ScrW()/2, ScrH()-He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

if CLIENT then
    local MindControlPanel = nil

    hook.Add("HUDPaint", "MindControl_Effect", function()
        local ply = LocalPlayer()
        if ply:GetNW2Bool("MindControlled") then
            local alpha = math.abs(math.sin(CurTime() * 3)) * 255
            draw.SimpleText(MuR.Language["message_mindcontroller_used"], "MuR_Font3", ScrW()/2, He(100), Color(255, 0, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    hook.Add("Think", "MindControl_Panel", function()
        local ply = LocalPlayer()

        if ply:GetNW2Bool("MindControlled") then
            if not IsValid(MindControlPanel) then
                MindControlPanel = vgui.Create("DPanel")
                MindControlPanel:SetSize(ScrW(), ScrH())
                MindControlPanel:SetPos(0, 0)
                MindControlPanel:SetVisible(true)
                MindControlPanel:SetAlpha(0)
                MindControlPanel:MakePopup()
                MindControlPanel:SetKeyboardInputEnabled(false)
                MindControlPanel:SetMouseInputEnabled(true)

                MindControlPanel.Think = function(self)
                    if not LocalPlayer():GetNW2Bool("MindControlled") then
                        self:Remove()
                        MindControlPanel = nil
                    end
                end

                MindControlPanel.Paint = function(self, w, h) end
            end
        else
            if IsValid(MindControlPanel) then
                MindControlPanel:Remove()
                MindControlPanel = nil
            end
        end
    end)

    hook.Add("PreventScreenClicks", "MindControl_BlockMenus", function()
        if LocalPlayer():GetNW2Bool("MindControlled") then
            return true
        end
    end)
end

hook.Add("PlayerDisconnected", "MindControl_Cleanup", function(ply)
    if timer.Exists("MindControl_" .. ply:EntIndex()) then
        timer.Remove("MindControl_" .. ply:EntIndex())
    end
    ply:SetNW2Bool("MindControlled", false)
    ply:SetNW2Entity("MindController", NULL)
end)
