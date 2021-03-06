local record lunamark
   record writer
      record html
         new: function(table): table
      end
   end
   record reader
      record markdown
         new: function(table, table): function(string): string
      end
   end
end

return lunamark
