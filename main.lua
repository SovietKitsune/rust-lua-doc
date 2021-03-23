package.path = './out/packages/?/init.lua;./out/packages/?.lua;' .. package.path

xpcall(
   function()
      require('tealdoc-cli.main')()
      -- local parser = require('tealdoc.parser')
      -- local logger = require('tealdoc.logger')
      -- logger.level = 5

      -- local tree = {
      --    ['tl'] = './test.tl'
      -- }

      -- local state = parser.getReport(tree, false, false)

      -- local mods = parser.extractModules(state, tree)

      -- logger.debug(parser.createType(mods.tl, state))
   end,
   function(err)
      err = (err .. '\n' .. debug.traceback())

      print(err)
   end
)
