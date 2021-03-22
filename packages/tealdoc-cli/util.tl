local fs = require('tealdoc-cli.fs')

local util = {
   _requireCache = {} as {string: any}
}

function util.require(path: string): any
   if util._requireCache[path] then
      return util._requireCache[path]
   end

   local data = fs.read(path)

   local fn: function

   if _VERSION == 'Lua 5.1' then
      global loadstring: function(string, string): function
      fn = assert(loadstring(data, path))
   else
      fn = assert(load(data, path))
   end

   local res = fn()

   util._requireCache[path] = res

   return res
end

-- Things like a rockspec or config.ld
function util.loadGlobalConfig(path: string): table -- Let the caller typecast it
   if util._requireCache[path] then
      return util._requireCache[path] as table
   end

   local data = fs.read(path)

   local env = {}

   local fn: function

   if _VERSION == 'Lua 5.1' then
      global setfenv: function(function, table)
      global loadstring: function(string, string): function

      fn = assert(loadstring(data, path))

      setfenv(fn, env)
   else
      fn = assert(load(data, path, 't', env))
   end

   fn()

   util._requireCache[path] = env

   return env
end

return util
