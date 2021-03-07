package.path = './out/?/init.lua;./out/?.lua;' .. package.path

xpcall(
   function()
      require('tealdoc.cli').main()
   end,
   function(err)
      err = (err .. '\n' .. debug.traceback())
         :gsub('%./out/', './src/')
         :gsub('%./src/tealdoc/(.-)%.lua', function(name)
            return './src/tealdoc/' .. name .. '.tl'
         end)

      print(err)
   end
)
