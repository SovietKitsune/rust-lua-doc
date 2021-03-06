local record etlua
   compile: function(string): function(any): string
   render: function(string, any): string
   compile_to_lua: function(string): string
   load: function(string): function(any): string
   result: function(function): string
   result: function(function, any): string
   result: function(function, any, {any}): string
end

return etlua
