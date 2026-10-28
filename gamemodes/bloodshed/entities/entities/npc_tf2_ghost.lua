AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Spawnable = false

function ENT:Initialize()

	self:SetModel( "models/mossman.mdl" )

end

function ENT:RunBehaviour()

	while ( true ) do

		self:StartActivity( ACT_WALK )
		self.loco:SetDesiredSpeed( 100 )

		local targetPos = self:GetPos() + Vector( math.Rand( -1, 1 ), math.Rand( -1, 1 ), 0 ) * 400

		local area = navmesh.GetNearestNavArea( targetPos )

		if ( IsValid( area ) ) then targetPos = area:GetClosestPointOnArea( targetPos ) end

		self:MoveToPos( targetPos )

		self:StartActivity( ACT_IDLE )

		self:PlaySequenceAndWait( "idle_to_sit_ground" )
		self:SetSequence( "sit_ground" )
		coroutine.wait( self:PlayScene( "scenes/eli_lab/mo_gowithalyx01.vcd" ) )
		self:PlaySequenceAndWait( "sit_ground_to_idle" )

		local pos = self:FindSpot( "random", { type = 'hiding', radius = 5000 } )

		if ( pos ) then
			self:StartActivity( ACT_RUN )
			self.loco:SetDesiredSpeed( 200 )
			self:PlayScene( "scenes/npc/female01/watchout.vcd" )
			self:MoveToPos( pos )
			self:PlaySequenceAndWait( "fear_reaction" )
			self:StartActivity( ACT_IDLE )
		else

		end

		coroutine.yield()

	end

end

list.Set( "NPC", "npc_tf2_ghost", {
	Name = "Example NPC",
	Class = "npc_tf2_ghost",
	Category = "Nextbot"
} )
