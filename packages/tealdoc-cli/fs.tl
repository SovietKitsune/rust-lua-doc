local lfs = require('lfs')

--- Combination of luafilesystem and io
local fs = {
   _location = nil as string
}

function fs.scriptLocation(): string
   if fs._location then
      return fs._location
   end

   fs._location = debug.getinfo(2, 'S').source:sub(2):match('(.*/)')

   return fs._location
end

function fs.read(path: string): string
   local f = assert(io.open(path, 'r'))

   local data = f:read('*a')

   f:close()

   return data
end

function fs.write(path: string, data: string)
   local f = assert(io.open(path, 'w'))

   f:write(data)

   f:close()
end

function fs.dirTree(dir: string, current: {string: string}, depth: string): {string: string}
   local tree = current or {}

   depth = (depth or '') .. (dir:match('.*/(.*)$') or dir)

   if depth ~= '' then
      depth = depth .. '.'
   end

   depth = depth:match('%.*(.*)')

   for path in lfs.dir(dir) do
      if path ~= '.' and path ~= '..' then
         local attributes = lfs.attributes(dir .. '/' .. path)

         if attributes.mode == 'file' and (path:match('%.lua$') or path:match('%.tl$')) then
            tree[depth .. path:match('(.-)%.(.*)')] = dir .. '/' .. path
         elseif attributes.mode == 'directory' then
            fs.dirTree(dir .. '/' .. path, tree, depth)
         end
      end
   end

   return tree
end

function fs.search(pat: string, dirs: {string}): string
   for i = 1, #dirs do
      if lfs.attributes(dirs[i]) and lfs.attributes(dirs[i]).mode == 'directory' then
         for path in lfs.dir(dirs[i]) do
            if path:match(pat) then
               return path
            end
         end
      end
   end
end

function fs.searchAll(path: string, pat: string, current: {string}): {string}
   current = current or {}

   for location in lfs.dir(path) do
      if location ~= '.' and location ~= '..' then

         if lfs.attributes(path .. '/' .. location).mode == 'directory' then
            fs.searchAll(path .. '/' .. location, pat, current)
         elseif lfs.attributes(path .. '/' .. location).mode == 'file' and location:match(pat) then
            table.insert(current, path .. '/' .. location)
         end
      end
   end

   return current
end

function fs.exists(path: string): boolean
   return not not lfs.attributes(path)
end

function fs.mkdir(path: string)
   lfs.mkdir(path)
end

function fs.copy(file: string, newLocation: string, map: function(string): string)
   if map then
      fs.write(newLocation, map(fs.read(file)))
   else
      fs.write(newLocation, fs.read(file))
   end
end

function fs.copyDir(path: string, newPath: string, map: function(string): string)
   fs.mkdir(newPath)

   for location in lfs.dir(path) do
      if location ~= '.' and location ~= '..' then
         if lfs.attributes(path .. '/' .. location).mode == 'directory' then
            fs.copyDir(path .. '/' .. location, newPath .. '/' .. location)
         elseif lfs.attributes(path .. '/' .. location).mode == 'file' then
            fs.copy(path .. '/' .. location, newPath .. '/' .. location, map)
         end
      end
   end
end

return fs
