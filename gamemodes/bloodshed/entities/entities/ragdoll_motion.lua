AddCSLuaFile()

ENT.Type = "anim"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.Editable = true

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "Scale", { KeyName = "scale", Edit = { type = "Float", min=1, max=512, order = 1 } } )

	self:NetworkVar( "Bool", 0, "Normalize", { KeyName = "normalize", Edit = { type = "Boolean", order = 2 } } )

	self:NetworkVar( "Bool", 1, "Debug", { KeyName = "debug", Edit = { type = "Boolean", order = 100 } } )

	self:NetworkVar( "Entity", 0, "Controller" )
	self:NetworkVar( "Entity", 1, "Target" )

	if ( SERVER ) then

		self:SetScale( 36 )
		self:SetDebug( false )
		self:SetNormalize( true )

	end

end

function ENT:Initialize()

	if ( SERVER ) then

		self:SetModel( "models/maxofs2d/motion_sensor.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )

		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

		self:DrawShadow( false )

		local phys = self:GetPhysicsObject()
		if ( IsValid( phys ) ) then

			phys:Wake()
			phys:EnableGravity( false )
			phys:EnableDrag( false )

		end

		local colors = {
			Color( 180, 255, 50 ),
			Color( 0, 150, 255 ),
			Color( 255, 255, 0 ),
			Color( 255, 50, 255 )
		}

		self:SetColor( table.Random( colors ) )

	end

end

function ENT:PhysicsUpdate( physobj )

	if ( self:IsPlayerHolding() ) then return end
	if ( self:IsConstrained() ) then return end

	physobj:SetVelocity( vector_origin )
	physobj:Sleep()

end

function ENT:OnRemove()

	if ( SERVER ) then

		local ragdoll = self:GetTarget()
		if ( IsValid( ragdoll ) ) then
			ragdoll:SetRagdollBuildFunction( nil )
		end

	end

end

function ENT:Draw()

	local ply = LocalPlayer()
	local wep = ply:GetActiveWeapon()
	if ( wep:IsValid() ) then
		if ( wep:GetClass() == "gmod_camera" ) then return end
	end

	self:DrawModel()

end

function ENT:DrawDebug( ragdoll, controller, pos, ang, rotation, scale, center, changed_sensor )

	local UpdateTime = 0.1
	local StayTime = 0.15

	if ( self.LastDebugUpdate && CurTime() - self.LastDebugUpdate < UpdateTime ) then return end

	self.LastDebugUpdate = CurTime()

	center = center

	local col_bone = color_white
	local col_point = Color( 255, 0, 0, 255 )
	local col_tran_bn = Color( 0, 255, 0, 255 )

	local realbonepos = {}
	local fixedbonepos = {}
	local min = Vector( 1, 1, 1 ) * -0.5
	local max = Vector( 1, 1, 1 ) * 0.5

	for i = 0, 19 do

		realbonepos[i] = controller:MotionSensorPos( i ) * scale
		realbonepos[i]:Rotate( rotation )
		realbonepos[i] = realbonepos[i] + center

		fixedbonepos[i] = changed_sensor[ i ] * scale
		fixedbonepos[i] = fixedbonepos[i] + center

		debugoverlay.Box( realbonepos[i], min, max, StayTime, col_point, true )
		debugoverlay.Box( fixedbonepos[i], min, max, StayTime, col_tran_bn, true )

	end

	for k, v in pairs( motionsensor.DebugBones ) do

		debugoverlay.Line( realbonepos[ v[1] ], realbonepos[ v[2] ], StayTime, col_bone, true )

	end

	for k, v in pairs( motionsensor.DebugBones ) do

		debugoverlay.Line( fixedbonepos[ v[1] ], fixedbonepos[ v[2] ], StayTime, col_tran_bn, true )

	end

	for i=0, ragdoll:GetPhysicsObjectCount() - 1 do

		local phys = ragdoll:GetPhysicsObjectNum( i )

		local pos = phys:GetPos()
		local angle = phys:GetAngles()
		local txt = i

		if ( ang[i] == nil ) then
			txt = i .. " (UNSET)"
		end

		debugoverlay.Text( pos, txt, StayTime )
		debugoverlay.Axis( pos, angle, 5, StayTime, true )

	end

end

function ENT:SetRagdoll( ragdoll )

	self:SetTarget( ragdoll )
	ragdoll:PhysWake()

	local buildername = motionsensor.ChooseBuilderFromEntity( ragdoll )

	ragdoll:SetRagdollBuildFunction( function( ragdoll )

		local controller = self:GetController()
		if ( !IsValid( controller ) ) then return end

		local builder = list.Get( "SkeletonConvertor" )[ buildername ]
		local scale = self:GetScale()
		local rotation = self:GetAngles()
		local center = self:GetPos()
		local normalize = self:GetNormalize()
		local debug = self:GetDebug()

		local pos, ang, changed_sensor	= motionsensor.BuildSkeleton( builder, controller, rotation )

		if ( debug ) then
			self:DrawDebug( ragdoll, controller, pos, ang, rotation, scale, center, changed_sensor )
		end

		local iSkipped = 0
		local iMaxSkip = table.Count( pos ) * 0.25
		for k, v in pairs( pos ) do

			if ( math.abs( v.x ) > 0.05 ) then continue end
			if ( math.abs( v.y ) > 0.05 ) then continue end

			pos[k] = nil
			ang[k] = nil

			iSkipped = iSkipped + 1

			if ( iSkipped > iMaxSkip ) then

				ragdoll:RagdollStopControlling()
				return

			end

		end

		for k, v in pairs( pos ) do

			if ( ang[ k ] != nil ) then
				ragdoll:SetRagdollAng( k, ang[ k ] )
			end

			if ( k == 0 || !normalize ) then

				local new_position = center + v * scale
				ragdoll:SetRagdollPos( k, new_position )

			end

		end

		if ( normalize ) then

			ragdoll:RagdollSolve()

		end

		ragdoll:RagdollUpdatePhysics()

	end )

end
