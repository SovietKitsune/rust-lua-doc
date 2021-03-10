package = "tealdoc"
version = "dev-1"
source = {
   url = "git+https://github.com/SovietKitsune/tealdoc.git"
}
description = {
   homepage = "https://github.com/SovietKitsune/tealdoc",
   license = "MIT"
}
dependencies = {
   "argparse",
   "etlua",
   "luafilesystem",

   "tl" -- *casually depend on an entire compiler*
}
build = {
   type = "builtin",
   modules = {
      ["tealdoc.parser"] = "out/tealdoc/parser.lua",
      ["tealdoc.humanize"] = "out/tealdoc/humanize.lua",
      ["tealdoc.logger"] = "out/tealdoc/logger.lua",
      ["tealdoc.cli"] = "out/tealdoc/cli.lua"
   },
   install = {
      lua = {
         ["tealdoc.parser"] = "src/tealdoc/parser.tl",
         ["tealdoc.humanize"] = "src/tealdoc/humanize.tl",
         ["tealdoc.logger"] = "src/tealdoc/logger.tl",
         ["tealdoc.cli"] = "src/tealdoc/cli.tl"
      }
   }
}
