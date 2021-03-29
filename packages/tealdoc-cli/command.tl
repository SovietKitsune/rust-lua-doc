local argparse = require('argparse')

--- The structure of all commands
local record Command
   name: string
   description: string
   main: function({string: any})
   init: function(argparse.Command)
end

--- All registered commands
local commands = {}

--- Register a new command using the `Command` object
local function register(cmd: Command)
   assert(not commands[cmd.name], 'Attempt to overwrite existing command `' .. cmd.name .. '`')

   commands[cmd.name] = cmd
end

--- Load all created commands into the `argparse.Parser` instance
local function load(parser: argparse.Parser)
   for i, v in pairs(commands) do
      local cmd = parser:command(i, v.description)

      if v.init then
         v.init(cmd)
      end
   end
end

--- Run a command
local function run(name: string, args: {string: any})
   commands[name].main(args)
end

return {
   register = register,
   load = load,
   run = run,
   commands = commands,
   Command = Command
}
