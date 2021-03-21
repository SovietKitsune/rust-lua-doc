local command = require('tealdoc-cli.command')
local util = require('tealdoc-cli.util')
local fs = require('tealdoc-cli.fs')

local logger = require('tealdoc.logger')

local argparse = require('argparse')

local parser = argparse('tealdoc', 'Teal documentation generator')

parser:flag('-v --version', 'Print version information')
parser:flag('-q --quiet', 'Silence all output besides errors')
parser:flag('-d --debug', 'Enables debug output')
parser:flag('-n --no-color', 'Disables color output')

parser:command_target('command')
parser:require_command(false)

local scriptDir = fs.scriptLocation()

local commands = fs.searchAll(scriptDir .. 'commands', '%.lua$')

for i = 1, #commands do
   command.register(util.require(commands[i]) as command.Command)
end

command.load(parser)

--- @{hidden}
local function main()
   local res = parser:parse()

   if res.version then
      print(
         'tealdoc-cli ' .. require('tealdoc-cli.version') .. '\n' ..
         'tealdoc ' .. require('tealdoc.version')
      )

      os.exit()
   end

   logger.level =
      (res.quiet and 1) or
      (res.debug and 5) or 3

   logger.color = not res.no_color

   if res.command then
      command.run(res.command as string, res)
   else
      parser:error('a command is required')
   end
end

return main
