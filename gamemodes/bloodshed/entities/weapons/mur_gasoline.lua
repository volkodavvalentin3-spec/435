AddCSLuaFile()

SWEP.PrintName = "Gas Can"
SWEP.Author = "Hari"
SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
SWEP.Slot = 4
SWEP.SlotPos = 4
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.ViewModel = "models/props_junk/gascan001a.mdl"
SWEP.WorldModel = "models/props_junk/gascan001a.mdl"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Fires = { }
SWEP.Matches = { }
SWEP.HitPoint = { }
SWEP.MaxFires = 256
SWEP.MaxMatches = 8
SWEP.Pouring = false
SWEP.PumpModel = "models/props_wasteland/gaspump001a.mdl"

PrecacheParticleSystem("fire_verysmall_01")
PrecacheParticleSystem("water_splash_01_surface1")
util.PrecacheSound("ambient/water/leak_1.wav")
util.PrecacheSound("ambient/water/rain_drip1.wav")
util.PrecacheSound("ambient/water/rain_drip2.wav")
util.PrecacheSound("ambient/water/rain_drip3.wav")
util.PrecacheSound("ambient/water/rain_drip4.wav")
util.PrecacheSound("weapons/slam/throw.wav")

if not util.IsValidModel("models/props/de_inferno/Splinter_Damage_01.mdl") then
  SWEP.MatchModel = Model("models/props_debris/wood_splinters01a.mdl")
  SWEP.MatchOffset = Vector(-.012, -.163, 3.065)
else
  SWEP.MatchModel = Model("models/props/de_inferno/Splinter_Damage_01.mdl")
  SWEP.MatchOffset = Vector(.3, 4.5, .3)
end

if CLIENT then
  surface.CreateFont("GasCan_HUD", {
    font = "Lucida Sans Unicode",
    weight = 700,
    antialias = true,
    size = 20,
  })

  surface.CreateFont("GasCan_HUD_Back", {
    font = "Lucida Sans Unicode",
    weight = 700,
    antialias = true,
    size = 20,
    blursize = 2,
  })
end

SWEP.Irons = {
  Normal = {
    Pos = Vector(68.67, -30, -35),
    Ang = Vector(3.95, 86.76, -24.98),
  },
  Pour = {
    Pos = Vector(68.67, -30, -55),
    Ang = Vector(3.95, 86.76, -34.98),
  },
}

SWEP.Aspects = {
  [1.6] = vector_origin,
  [1.8] = Vector(0, 0, -1.1),
  [1.3] = Vector(0, 0, 2.2),
  [1.25] = Vector(0, 0, 3.1),
}

SWEP.Offset = {
  Pos = {
    Right = -3,
    Forward = 1,
    Up = 0,
  },
  Ang = {
    Right = 0,
    Forward = 0,
    Up = 160,
  },
  Scale = Vector(.5, .5, .5),
}

function SWEP:Initialize()
  self:SetWeaponHoldType("slam")
  self:SetClip1(100)
  self:SetClip2(1)

  if SERVER then
    hook.Add("PlayerUse", self, self.PlayerUse)
  else
    self.HudBit = ClientsideModel(self.ViewModel, RENDERGROUP_OPAQUE)
    self.HudBit:AddEffects(EF_NODRAW + EF_NOSHADOW)
    hook.Add("CalcViewModelView", self, self.CalcViewModelView)
  end
end

function SWEP:PrimaryAttack()
  local fire, tr

  if self:Clip1() < 1 then
    if SERVER then
      self.Wet:Stop()
      self.Owner:EmitSound("ambient/water/rain_drip" .. math.random(4) .. ".wav", 50, 75)
    end

    self:SetNextPrimaryFire(CurTime() + 1.333)

    return
  end

  self:SetNextPrimaryFire(CurTime() + .05)

  tr = util.TraceLine{
    start = self.Owner:GetShootPos(),
    endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 160,
    filter = self.Owner
  }

  if not tr.Hit then return end
  self:TakePrimaryAmmo(1)

  if SERVER then
    self.Wet = self.Wet or CreateSound(self, "ambient/water/leak_1.wav")
    self.Wet:ChangePitch(80 + 120 * self:Clip1() / 100, .05)

    if not self.Wet:IsPlaying() then
      self.Wet:Play()
    end
  end

  util.Decal("BeerSplash", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
  ParticleEffect("water_splash_01_surface1", tr.HitPos, tr.HitNormal:Angle())
  if CLIENT then return end

  local life = math.Rand(4, 8) * 2
	local owner = self:GetOwner()
	local forwardBoost = math.Rand(20, 40)
	local frac = owner:GetEyeTrace().Fraction
	if frac < 0.001245 then
		forwardBoost = 1
	end
	local forward = self:GetOwner():EyeAngles():Forward()
	local pos = tr.HitPos
	local vel = forward
	local feedCarry = math.Rand(5, 25) * 0.5
	table.insert(self.HitPoint, tr.HitPos)
	for k, v in pairs(self.Fires) do
		for j, l in pairs(self.HitPoint) do
			if l:Distance( v ) < 25 then
				CreateVFireBall(life, feedCarry, pos, vel, owner)
				table.remove(self.HitPoint, j)
				table.insert(self.Fires, l)
			end
		end
	end
end

function SWEP:SecondaryAttack( )
	local match, heat, att, phys, tr, particle

	self.Owner:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_GMOD_GESTURE_ITEM_PLACE )
	timer.Simple(1.4, function()
    if !IsValid(self) then return end
    self.Owner:AnimResetGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD )
  end)
	self:SetNextSecondaryFire( CurTime( ) + 1 )

	if CLIENT then
		return
	end

	self.Owner:EmitSound( "weapons/slam/throw.wav", 50 )

	self.Hand = self.Hand or self.Owner:LookupAttachment( "anim_attachment_lh" )

	match = ents.Create( "prop_physics" )
	match:SetModel( self.MatchModel )
	match:SetOwner( self.Owner )
	match:SetSolid( SOLID_NONE )

	if self.Hand == -1 then
		att = self.Owner:GetAttachment( self.Hand )
		match:SetPos( att.Pos )
	else
		match:SetPos( self.Owner:GetShootPos( ) )
	end

	match:Spawn( )

	heat = ents.Create( "env_firesource" )
	heat:SetPos( match:GetPos( ) )
	heat:SetParent( match )
	heat:SetLocalPos( self.MatchOffset )

	heat:SetKeyValue( "fireradius", 36 )
	heat:SetKeyValue( "firedamage", 50 )

	heat:Spawn( )
	heat:Input( "Enable" )

	phys = match:GetPhysicsObject( )

	tr = util.TraceLine{
		start = self.Owner:GetShootPos( ),
		endpos = self.Owner:GetShootPos( ) + self.Owner:GetAimVector( ) * 512,
		filter = { match, heat, self.Owner, particle },
	}

	SafeRemoveEntityDelayed( match, 30 )

	particle = ents.Create( "info_particle_system" )
	particle:SetKeyValue( "start_active", 1 )
	particle:SetKeyValue( "effect_name", "fire_verysmall_01" )
	particle:Spawn( )

	particle:SetPos( match:GetPos( ) )
	particle:SetParent( match )
	particle:SetLocalPos( self.MatchOffset )
	particle:Activate( )

	if IsValid( phys ) then
		phys:SetVelocity( ( tr.HitPos - match:GetPos( ) ):GetNormal( ) * 128 * phys:GetMass( ) )
	end
	timer.Simple(0.5, function()
	for k, v in pairs(self.HitPoint) do
		if self.HitPoint[k-1] == nil then continue end
		if self.HitPoint[k-1]:Distance( match:GetPos() ) < 50 then
		local life = math.Rand(4, 8) * 4
		local owner = self:GetOwner()
		local forwardBoost = math.Rand(20, 40)
		local frac = owner:GetEyeTrace().Fraction
		if frac < 0.001245 then
			forwardBoost = 1
		end
		local forward = self:GetOwner():EyeAngles():Forward()
		local pos = v
		local vel = forward
		local feedCarry = math.Rand(5, 25) * 0.5
		CreateVFireBall(life, feedCarry, pos, vel, owner)
		table.remove(self.HitPoint, k)
		table.insert(self.Fires, v)
		end
	end
	end)

	SafeRemoveEntity( table.remove( self.Matches, self.MaxMatches ) )
	table.insert( self.Matches, 1, match )
end

function SWEP:Think()
  if CLIENT then
    self.Pouring = self.Owner:KeyDown(IN_ATTACK)
  else
    for k, v in pairs(self.Fires) do
      for j, l in pairs(self.HitPoint) do
        if l:Distance( v ) < 25 then
          local life = math.Rand(4, 8) * 2
          local owner = self:GetOwner()
          local forwardBoost = math.Rand(20, 40)
          local frac = owner:GetEyeTrace().Fraction
          if frac < 0.001245 then
            forwardBoost = 1
          end
          local forward = self:GetOwner():EyeAngles():Forward()
          local pos = l
          local vel = forward
          local feedCarry = math.Rand(5, 25) * 0.5
          CreateVFireBall(life, feedCarry, pos, vel, owner)
          table.remove(self.HitPoint, j)
          table.insert(self.Fires, l)
        end
      end
    end

    if self.Leak and (CurTime() - self.NextCharge >= .05) then
      self.Leak:Stop()
    end

    if self.Wet and (CurTime() - self:GetNextPrimaryFire() >= .06) then
      self.Wet:Stop()
    end

    if self.Owner:KeyDown(IN_USE) then
      local tr = util.TraceLine{
        start = self.Owner:GetShootPos(),
        endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 80,
        filter = self.Owner
      }

      local ent = tr.Entity
      if not IsValid(ent) then return end
      if ent:GetClass() ~= "prop_physics" then return end

      if self:Clip1() < 100 then
        if ent:GetModel():lower() == self.PumpModel:lower() then
          self.Leak = self.Leak or CreateSound(self, "ambient/water/leak_1.wav")
          self.Leak:ChangePitch(80 + 120 * (self:Clip1() / 100), .05)
          self.NextCharge = self.NextCharge or CurTime()

          if self.NextCharge <= CurTime() then
            self:SetClip1(self:Clip1() + 1)
            self.NextCharge = CurTime() + .05

            if not self.Leak:IsPlaying() then
              self.Leak:Play()
            end
          end
        end
      end
    end
  end
end

function SWEP:PlayerUse(pl, ent)
  if pl == self.Owner and self:Clip2() < 5 and self == self.Owner:GetActiveWeapon() then
    if ent:GetClass() == "prop_physics" and ent:GetModel():lower() == self.ViewModel and not ent.GasCan_Spent then
      SafeRemoveEntity(ent)
      self:SetClip2(self:Clip2() + 1)
    end
  end
end

function SWEP:Reload()

end

function SWEP:DrawWorldModel()
  if not IsValid(self.Owner) then return self:DrawModel() end
  local offset, hand
  self.Hand2 = self.Hand2 or self.Owner:LookupAttachment("anim_attachment_rh")
  hand = self.Owner:GetAttachment(self.Hand2)
  if not hand then return end
  offset = hand.Ang:Right() * self.Offset.Pos.Right + hand.Ang:Forward() * self.Offset.Pos.Forward + hand.Ang:Up() * self.Offset.Pos.Up
  hand.Ang:RotateAroundAxis(hand.Ang:Right(), self.Offset.Ang.Right)
  hand.Ang:RotateAroundAxis(hand.Ang:Forward(), self.Offset.Ang.Forward)
  hand.Ang:RotateAroundAxis(hand.Ang:Up(), self.Offset.Ang.Up)
  self:SetRenderOrigin(hand.Pos + offset)
  self:SetRenderAngles(hand.Ang)
  self:SetModelScale(.5, 0)
  self:DrawModel()
end

function SWEP:OnRemove()
  if CLIENT then
    hook.Remove("CalcViewModelView", self)
  end
end

local function tostrings(...)
  local t = {}
  local k, v

  for k, v in pairs{...} do
    t[k] = tostring(v)
  end

  return unpack(t)
end

function SWEP:CalcViewModelView(this, vm, oldpos, oldang, pos, ang)
  local b, r, u, f, n, x, y, z, to, from
  b = self.Pouring
  if self ~= this then return end

  if b == nil then
    b = false
  end

  if b ~= self.LastIron then
    self.BlendProgress = 0
    self.LastIron = b
  end

  self.SwayScale = 1.0
  self.BobScale = 1.0

  if b then
    to = self.Irons.Pour
    from = self.Irons.Normal
  else
    to = self.Irons.Normal
    from = self.Irons.Pour
  end

  self.BlendProgress = math.Approach(self.BlendProgress, 1, FrameTime() * 2)
  n = 1 - self.BlendProgress
  r, u, f = ang:Right(), ang:Up(), ang:Forward()
  x = to.Ang.x * self.BlendProgress + from.Ang.x * n
  y = to.Ang.y * self.BlendProgress + from.Ang.y * n
  z = to.Ang.z * self.BlendProgress + from.Ang.z * n
  ang:RotateAroundAxis(r, x)
  ang:RotateAroundAxis(u, y)
  ang:RotateAroundAxis(f, z)
  r, u, f = ang:Right(), ang:Up(), ang:Forward()
  x = to.Pos.x * self.BlendProgress + from.Pos.x * n
  y = to.Pos.y * self.BlendProgress + from.Pos.y * n
  z = to.Pos.z * self.BlendProgress + from.Pos.z * n
  pos = pos + x * r
  pos = pos + y * f
  pos = pos + z * u

  return pos, ang
end

function SWEP:DrawHUD()
    local x, y, w, h, sw, sh, pos, ang, rot
    sw = ScrW()
    sh = ScrH()
    w = sw * .2
    h = sh * .015
    self.Current = math.Approach(self.Current or 0, self:Clip1() / 100, RealFrameTime() * 2)
    surface.SetDrawColor(color_black)
    surface.DrawRect(sw - w - 2, sh - h - 2, w, h)
    surface.SetDrawColor(color_white)
    surface.DrawOutlinedRect(sw - w - 2, sh - h - 2, w, h)
    surface.DrawRect(sw - w, sh - h, (w - 4) * self.Current, h - 4)
    pos = Vector(-11.6, -18.5, 10) + (self.Aspects[math.Round(sw / sh, 2)] or self.Aspects[math.Round(sw / sh, 1)])
    ang = (-self.HudBit:GetForward()):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), 90)
    self.HudBit:SetModelScale(.05, 0)
    rot = vector_origin:Angle()
    rot:RotateAroundAxis(rot:Right(), 90)
    cam.Start3D(pos, ang, 90)
    render.SuppressEngineLighting(true)
    render.ResetModelLighting(1, 1, 1)
    self.HudBit:SetRenderAngles(rot)

    for i = 1, 5 do
        self.HudBit:SetRenderOrigin(rot:Forward() * (i - 1) * .5)

        if i > self:Clip2() then
        render.SetColorModulation(0, 0, 0)
        else
        render.SetColorModulation(1, 1, 1)
        end

        self.HudBit:SetupBones()
        self.HudBit:DrawModel()
    end

    render.SuppressEngineLighting(false)
    cam.End3D()
end

if SERVER then
    local ragdollsNearFire = {}

    local function TransferBones(base, ragdoll)
        if not IsValid(base) or not IsValid(ragdoll) then return end

        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local bone = ragdoll:GetPhysicsObjectNum(i)

            if IsValid(bone) then
                local pos, ang = base:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))

                if pos then
                    bone:SetPos(pos)
                end

                if ang then
                    bone:SetAngles(ang)
                end
            end
        end
    end

    local function IsEntityClose(ent1, ent2, maxDistance)
        local dist = ent1:GetPos():Distance(ent2:GetPos())
        return dist <= maxDistance
    end

    local function ReplaceWithBurntRagdoll(ragdoll)
        if !IsValid(ragdoll) then return end

        local pos = ragdoll:GetPos()
        local ang = ragdoll:GetAngles()

        local burntRagdoll = ents.Create("prop_ragdoll")
        burntRagdoll:SetPos(pos)
        burntRagdoll:SetAngles(ang)
        burntRagdoll:SetModel("models/player/charple.mdl")
        burntRagdoll:Spawn()
        burntRagdoll:SetNWString("Name", MuR.UNIDENTIFIED_NAME)
        burntRagdoll.IsDead = true
        burntRagdoll.isRDRag = true
        burntRagdoll.Burned = true
        burntRagdoll.MaxBlood = 0
        burntRagdoll:ZippyGoreMod3_BecomeGibbableRagdoll(BLOOD_COLOR_RED)
        burntRagdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        TransferBones(ragdoll, burntRagdoll)

        ragdoll:Remove()
    end

    hook.Add("Think", "CheckRagdollsNearFire", function()
        if CurTime() % 0.5 > 0 then return end

        local ragdolls = ents.FindByClass("prop_ragdoll")
        if not ragdolls then return end

        local fires = ents.FindByClass("vfire")
        if not fires then return end

        for _, ragdoll in ipairs(ragdolls) do
            local ragdollID = ragdoll:EntIndex()
            if ragdollsNearFire[ragdollID] or not ragdoll.IsDead or ragdoll.Burned then continue end

            for _, fire in ipairs(fires) do
                if IsEntityClose(ragdoll, fire, 32) then
                    ragdollsNearFire[ragdollID] = true

                    timer.Create("BurnRagdoll_" .. ragdollID, 10, 1, function()
                        if IsValid(ragdoll) then
                            ReplaceWithBurntRagdoll(ragdoll)
                        end
                        ragdollsNearFire[ragdollID] = nil
                    end)

                    break
                end
            end
        end
    end)

end
