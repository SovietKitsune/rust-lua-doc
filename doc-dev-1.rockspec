package = "doc"
version = "dev-1"
source = {
   url = "git+https://github.com/SovietKitsune/lua-docs.git"
}
description = {
   homepage = "https://github.com/SovietKitsune/lua-docs",
   license = "MIT"
}
dependencies = {
   "sundown",
   "etlua"
}
build = {
   type = "builtin",
   modules = {
      ["parser"] = "out/parser.lua"
   }
}
