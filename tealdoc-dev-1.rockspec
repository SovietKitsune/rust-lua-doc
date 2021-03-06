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
   "lua-toml",

   "tl" -- *casually depend on an entire compiler*
}
build = {
   type = "builtin",
   modules = {
      ["parser"] = "out/parser.lua"
   }
}
