include("shared.lua")

local mat = Material("sprites/light_ignorez")
local matr = Matrix()

function ENT:Initialize()
	self.Rotor = ClientsideModel(self.RotorModel)
	self.Rotor:SetNoDraw(true)
	self.Rotor2 = ClientsideModel(self.Rotor2Model)
	self.Rotor2:SetNoDraw(true)

	self.RotorSound = CreateSound(self,self.RotorSoundPatch)
	self.RotorSound:SetSoundLevel(85)
	self.RotorSound:Play()

	self.Spotlight = ProjectedTexture()
	self.Spotlight:SetTexture("effects/flashlight001")
	self.Spotlight:SetFarZ(1000)
	self.Spotlight:SetFOV(25)
	self.Spotlight:SetColor(color_white)
	local pos,ang = LocalToWorld(self.SpotlightPos,Angle(),self:GetPos(),self:GetAngles())
	self.Spotlight:SetPos(pos)
	self.Spotlight:SetAngles(ang)
	self.Spotlight:Update()

	self:DrawShadow(true)
	self.Scale = Vector(1,1,1)
end

function ENT:Draw()
	local vel = WorldToLocal(self:GetVelocity(),Angle(),Vector(),Angle(0,self:GetAngles().y,0))
	local speed = self:GetVelocity():Length2D()

	self.Scale = Vector(1,1,1)

	matr:SetScale(self.Scale)

	self:EnableMatrix("RenderMultiply",matr)
	self:DrawModel()

	local pos,ang = LocalToWorld(self.RotorPos*self.Scale,Angle(0,RealTime()*1000,0),self:GetPos(),self:GetAngles())
	self.Rotor:SetPos(pos)
	self.Rotor:SetAngles(ang)
	self.Rotor:SetupBones()
	self.Rotor:DrawModel()

	local pos,ang = LocalToWorld(self.Rotor2Pos*self.Scale,Angle(RealTime()*1000,0,0),self:GetPos(),self:GetAngles())
	self.Rotor2:SetPos(pos)
	self.Rotor2:SetAngles(ang)
	self.Rotor2:SetupBones()
	self.Rotor2:DrawModel()

	local spotpos = self.Spotlight:GetPos()
	local redpos = LocalToWorld(self.RedLightPos*self.Scale,Angle(),self:GetPos(),self:GetAngles())
	local dist = EyePos():Distance(spotpos)
	local dist2 = EyePos():Distance(redpos)

	if !IsValid(self.PoliceModel) then
		local m = ClientsideModel("models/murdered/npc/police/male_0"..math.random(3,9)..".mdl")
		self.PoliceModel = m
		m:SetBodygroup(3,1)
		m:ManipulateBoneAngles(m:LookupBone("ValveBiped.Bip01_R_Calf"), Angle(-10,-70,0))
		m:ManipulateBoneAngles(m:LookupBone("ValveBiped.Bip01_L_Calf"), Angle(10,-70,0))
	else
		self.PoliceModel:SetPos(self:GetPos())
		self.PoliceModel:SetParent(self)
		self.PoliceModel:SetLocalPos(Vector(80,12,-32))
		self.PoliceModel:SetAngles(self:GetAngles())
		self.PoliceModel:SetNoDraw(!self:IsDormant())
		self.PoliceModel:ResetSequence("silo_sit")
	end

	if dist<2000 and util.TraceLine({start = EyePos(),endpos = spotpos,filter = LocalPlayer(),collisiongroup = COLLISION_GROUP_PROJECTILE}).Fraction==1 then
		mat:SetInt("$ignorez",0)

			render.SetMaterial(mat)
			render.DrawSprite(spotpos,256,256,Color(255,255,255,255-dist/2000*255))

		mat:SetInt("$ignorez",1)
	end
	if dist2<2000 and math.floor(RealTime()*1.5)==math.Round(RealTime()*1.5) and util.TraceLine({start = EyePos(),endpos = redpos,filter = LocalPlayer(),collisiongroup = COLLISION_GROUP_PROJECTILE}).Fraction==1 then
		mat:SetInt("$ignorez",0)

			render.SetMaterial(mat)
			render.DrawSprite(redpos,128,128,Color(255,0,0,255-dist2/2000*255))

		mat:SetInt("$ignorez",1)
	end
end

function ENT:Think()
	local speed = self:GetVelocity():Length()

	self.RotorSound:ChangePitch(100+math.Round(math.Clamp(speed/80,0,5),1))

	self.Spotlight:SetPos(LocalToWorld(self.SpotlightPos*self.Scale,Angle(),self:GetPos(),self:GetAngles()))
	if self:GetTarMode() or IsValid(self:GetTarget()) then
		self.Spotlight:SetBrightness(10)
		self.Spotlight:SetAngles((self:GetTargetPos()-self.Spotlight:GetPos()):Angle())
	else
		self.Spotlight:SetBrightness(0)
	end
	self.Spotlight:Update()
end

function ENT:OnRemove()
	self.Rotor:Remove()
	self.Rotor2:Remove()
	self.RotorSound:Stop()
	self.Spotlight:Remove()
	if IsValid(self.PoliceModel) then
		self.PoliceModel:Remove()
	end
end
