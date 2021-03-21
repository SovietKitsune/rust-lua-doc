local argparse = require('argparse')

local record Command
   name: string
   description: string
   main: function({string: any})
   init: function(argparse.Command)
end

local commands = {}

local function register(cmd: Command)
   assert(not commands[cmd.name], 'Attempt to overwrite existing command `' .. cmd.name .. '`')

   commands[cmd.name] = cmd
end

local function load(parser: argparse.Parser)
   for i, v in pairs(commands) do
      local cmd = parser:command(i, v.description)

      if v.init then
         v.init(cmd)
      end
   end
end

local function run(name: string, args: {string: any})
   commands[name].main(args)
end

return {
   --- Register a new command using the `Command` object
   register = register,
   --- Load all created commands into the `argparse.Parser` instance
   load = load,
   --- Run a command
   run = run,
   --- All registered commands
   commands = commands,
   --- The structure of all commands
   Command = Command
}
