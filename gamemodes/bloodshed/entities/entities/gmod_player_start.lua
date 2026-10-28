ENT.Type = "point"

function ENT:Initialize()

	if ( self.RedTeam or self.GreenTeam or self.YellowTeam or self.BlueTeam ) then

		self.BlueTeam = self.BlueTeam or false
		self.GreenTeam = self.GreenTeam or false
		self.YellowTeam = self.YellowTeam or false
		self.RedTeam = self.RedTeam or false

	else

		self.BlueTeam = true
		self.GreenTeam = true
		self.YellowTeam = true
		self.RedTeam = true

	end

end

function ENT:KeyValue( key, value )

	if ( key == "spawnflags" ) then

		local sf = tonumber( value )

		for i = 15, 0, -1 do

			local bit = math.pow( 2, i )

			if ( ( sf - bit ) >= 0 ) then

				if ( bit == 8 ) then self.RedTeam = true
				elseif ( bit == 4 ) then self.GreenTeam = true
				elseif ( bit == 2 ) then self.YellowTeam = true
				elseif ( bit == 1 ) then self.BlueTeam = true
				end

				sf = sf - bit

			else

				if ( bit == 8 ) then self.RedTeam = false
				elseif ( bit == 4 ) then self.GreenTeam = false
				elseif ( bit == 2 ) then self.YellowTeam = false
				elseif ( bit == 1 ) then self.BlueTeam = false
				end

			end

		end

	end

end
