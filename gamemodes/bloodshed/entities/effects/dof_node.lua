EFFECT.Mat = Material( "pp/dof" )

function EFFECT:Init( data )

	table.insert( DOF_Ents, self.Entity )
	self.Scale = data:GetScale()

	local size = 32
	self:SetCollisionBounds( Vector( -size, -size, -size ), Vector( size, size, size ) )

end

function EFFECT:Think( )

	local ply = LocalPlayer()

	self.spacing = DOF_SPACING * self.Scale
	self.offset = DOF_OFFSET

	local pos = ply:EyePos()
	local fwd = ply:EyeAngles():Forward()

	if ( ply:GetViewEntity() != ply ) then
		pos = ply:GetViewEntity():GetPos()
		fwd = ply:GetViewEntity():GetForward()
	end

	pos = pos + ( fwd * self.spacing ) + ( fwd * self.offset )

	self:SetParent( nil )
	self:SetPos( pos )
	self:SetParent( ply )

	return true

end

function EFFECT:Render()

	render.UpdateRefractTexture()

	local SpriteSize = ( self.spacing + self.offset ) * 8

	render.SetMaterial( self.Mat )
	render.DrawSprite( self:GetPos(), SpriteSize, SpriteSize, color_white )

end
