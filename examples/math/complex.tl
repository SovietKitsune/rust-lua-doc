local core = require('math.core')

--- The configuration on how to to the worlds most complex equation
local record Config
   --- The amount to pass to the equation
   count: number
   --- Some other fun variable
   fun: boolean
end

--- Preform the most complex equation
local function doStuff(a: number, b: number, config: Config): number
   return core.add(a, core.sub(b, core.mul(a, core.div(b, config.count))))
end

return doStuff
