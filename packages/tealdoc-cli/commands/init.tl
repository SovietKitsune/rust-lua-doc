local logger = require('tealdoc.logger')
local fs = require('tealdoc-cli.fs')

local function main()
   fs.write('tealdoc.lua', [[
return {
   -- name = '<taken from rockspec>', -- The name of the project
   -- version = '<taken from rockspec>', -- The version of the project
   -- isLua = false, -- If the project is written in Lua or not
   -- functionStyle = 'lua', -- Specify the style of function signatures, can be `lua` or `moon`
   -- output = 'docs', -- The output of the documentation
   -- source = '.', -- The source files of the documentation
   -- tagStyle = 'tealdoc', -- The style of tags, can be `tealdoc`, `ldoc`, or `none`
   -- tags = {}, -- Directories where extra tags are stored
   -- theme = 'moonlight', -- The default theme, can be `light`, `moonlight`, or `nordic`
   -- forceRootModule = true, -- If the type should be flagged as a module forcefully
   -- pages = {'readme.md'}, -- All the pages that should be added
   -- noIncludeReadme = false -- If the readme should be included
}
]])
   logger.info('Wrote tealdoc.lua')
end

--- @{hidden}
return {
   name = 'init',
   description = 'Create the base `tealdoc.lua` config file',
   main = main,
}
