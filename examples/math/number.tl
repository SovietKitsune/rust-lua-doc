--- The better number
local record Number
   metamethod __add: function(Number, Number): Number
end

return Number
