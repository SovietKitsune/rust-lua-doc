package.path = './out/packages/?/init.lua;./out/packages/?.lua;' .. package.path

xpcall(
   function()
      require('tealdoc-cli.main')()
   end,
   function(err)
      err = (err .. '\n' .. debug.traceback())

      print(err)
   end
)
