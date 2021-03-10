--- Logger for debugging and logging
local logger = {
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
   if not logger.color then return '' end
   return '\27[38;5;' .. color .. 'm'
end

local function reset(): string
   if not logger.color then return '' end

   return '\27[39m'
end

--- Create a log message, the level must be a number between 1 and 5
function logger.log(level: number, message: string)
   if level > logger.level then return end

   message = message:gsub('\n', '\n' .. fg(colors[level]) .. human[level] .. reset())

   local file = level >= 3 and io.stdout or io.stderr

   file:write(fg(colors[level]) .. human[level] .. reset() .. message .. '\n')
end

--- Send an error level message
function logger.error(message: string) logger.log(1, message) end
--- Send a warning level message
function logger.warn(message: string) logger.log(2, message) end
--- Send an informational message
function logger.info(message: string) logger.log(3, message) end

--- Send a debug message
---
--- The debug message will be inspected and colorized to aid in debugging (both `inspect.lua` and `pl.lexer` must be installed)
function logger.debug(...: any)
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
               elseif token == 'string' then
                  table.insert(buffer, fg(2))
               elseif token == 'number' or token == 'keyword' and (val == 'false' or val == 'true') then
                  table.insert(buffer, fg(3))
               elseif token == 'iden' and val == 'self' then
                  table.insert(buffer, fg(11))
               end

               table.insert(buffer, val .. reset())
            end

            message = table.concat(buffer)
         end

         messages[i] = (message as string)
      end
   end

   logger.log(4, table.concat(messages as {string}, '\t'))
end

--- Get the traceback where all build-file paths are replaced with source-file paths
function logger.trace()
   -- Not the cleanest but doesn't need to be
   local msg = debug.traceback()
      :gsub('\t', fg(colors[5]) .. human[5] .. reset())
      :gsub('%./out/', './src/')
      :gsub('%.lua:', '.tl:')

   logger.log(5, msg)
end

return logger
