local highlight = require('tealdoc-cli.highlight')

local lunamark = require('lunamark')

local writer = lunamark.writer.html.new()

-- Change some defaults since of tailwind messing with them

writer.template = '$body'

writer.link = function(label: string, uri: string, title: string): {string}
   local titleAtt = ''

   if type(title) == 'string' and #title > 0 then
      titleAtt = 'title="' .. title .. '"'
   end

   return {'<a href="', uri, '" class="text-blue-500" ', titleAtt, '>', label, '</a>'}
end

writer.header = function(str: string, level: integer): {string}
   local textMaps = {
      '3xl',
      '2xl',
      'xl',
      'lg',
      'base',
      'base'
   }

   return {'<h', tostring(level), ' class="text-', textMaps[level], ' pt-2">', str, '</h', tostring(level), '>'}
end

writer.fenced_code = function(code: string, language: string): {string} --;ignore
   if language == 'lua' or language == 'tl' then
      return {highlight(code)}
   else
      return {'<pre class="code-block"><code>', code, '</code></pre>'}
   end
end

local markdown = lunamark.reader.markdown.new(writer, {
   fenced_code_blocks = true --;ignore
})

return markdown
