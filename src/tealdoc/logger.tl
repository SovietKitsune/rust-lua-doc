--- Logger for debugging and logging
local Logger = {
   --- The current level of the logger
   level = 3,
   --- If there should be color in the output
   color = true
}

local human = {
   'Error ',
   'Warn  ',
   'Info  ',
   'Debug ',
   'Trace '
}

local colors = {
   1,
   3,
   2,
   6,
   5
}

local function fg(color: number): string
   if not Logger.color then return '' end
   return '\27[38;5;' .. color .. 'm'
end

local function reset(): string
   if not Logger.color then return '' end

   return '\27[39m'
end

--- Create a log message, the level must be a number between 1 and 5
function Logger.log(level: number, message: string)
   if level > Logger.level then return end

   io.write(fg(colors[level]) .. human[level] .. reset() .. message .. '\n')
end

--- Send an error level message
function Logger.error(message: string) Logger.log(1, message) end
--- Send a warning level message
function Logger.warn(message: string) Logger.log(2, message) end
--- Send an informational message
function Logger.info(message: string) Logger.log(3, message) end

--- Send a debug message
---
--- The debug message will be inspected and colorized to aid in debugging (both `inspect.lua` and `pl.lexer` must be installed)
function Logger.debug(...: any)
   local messages = {...}

   local success, inspect = pcall(require, 'inspect')

   if success then
      for i = 1, select('#', ...) do
         local message = select(i, ...)
      
         message = (inspect as function(any, table): string)(message, {
            indent = '   '
         })
   
         local hasLexer, lexer = pcall(require, 'pl.lexer')
   
         if hasLexer then
            local buffer: {string} = {}
   
            for token, val in lexer.lua((message as string), {}, {}) do
               if token == 'comment' then
                  table.insert(buffer, fg(0))
               elseif token == 'keyword' and val ~= 'true' and val ~= 'false' then
                  table.insert(buffer, fg(5))
               elseif token == 'keyword' and (val == 'false' or val == 'true') then
                  table.insert(buffer, fg(3))
               elseif token == 'string' then
                  table.insert(buffer, fg(2))
               elseif token == 'number' then
                  table.insert(buffer, fg(3))
               elseif token == 'iden' and val == 'self' then
                  table.insert(buffer, fg(11))
               end
   
               table.insert(buffer, val .. reset())
            end
   
            message = table.concat(buffer)
         end
   
         messages[i] = (message as string):gsub('\n', '\n' .. fg(colors[4]) .. human[4] .. reset())
      end
   end

   Logger.log(4, table.concat(messages as {string}, '\t'))
end

--- Get the traceback where all build-file paths are replaced with source-file paths
function Logger.trace()
   -- Not the cleanest but doesn't need to be
   local msg = debug.traceback()
      :gsub('\t', fg(colors[5]) .. human[5] .. reset())
      :gsub('%./out/', './src/')
      :gsub('%.lua:', '.tl:')

   Logger.log(5, msg)
end

return Logger
