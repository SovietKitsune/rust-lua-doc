local record toml
   strict: boolean

   parse: function(string): table
   encode: function(table): string
end

return toml
