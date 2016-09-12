module GROWTH
	# Super class of controller implementation classes.
	class ControllerModule
		def initialize(name)
			@controller = nil
			@name = name
			@commands = []
		end
		attr_accessor :controller, :name

		def define_command(name)
			@commands << name
		end

		def has_command(name)
			n = @commands.count(){|e| e==name }
			if(n!=0)then
				return true
			else
				return false
			end
		end
	end
end