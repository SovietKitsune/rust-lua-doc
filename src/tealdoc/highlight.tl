-- Highlighter and type information
local lexer = require('pl.lexer')
local tl = require('tl')

local theme: {string: string} = {
   comment = '#a0a1a7',
   constant = '#e6c07b',
   error = '#e06c75',
   identifier = '#383a42',
   keyword = '#a626a4',
   number = '#d19a66',
   string = '#50a14f',

   text = '#383a42'
}

local css = {}

for name, color in pairs(theme) do
   table.insert(css, '.code-' .. name .. ' { color: ' .. color .. '; }')
end

local genCss = table.concat(css, '\n')

local record Token
   --- A basic type, it will attempt to query `parser.createType` to generate the basic type
   typ: tl.TypeInfo -- parser.Type
   --- The kind of token it is
   kind: string
   --- The contents of what the token is
   str: string
   line: number
end

--; TODO - merge parse and fullDocument into a single function?
-- It would be faster theoretically
local function parse(file: string, search: function(module: string): string, FILE, {string}): {Token}, tl.TypeReport
   local f = io.open(file)

   local contents = f:read('*a')

   f:close()

   local oldSearch = tl.search_module

   -- The new search isolates context which is needed to prevent external modules
   tl.search_module = search

   local result = tl.process_string(contents, false, nil, file)
   local report = tl.get_types(result)

   tl.search_module = oldSearch

   local tokens = {} as {Token}

   --; TODO - lexer.teal
   local stream = lexer.lua(contents, {
      space = false,
      comments = false
   }, {
      number = false,
      string = false
   })

   local x = 1
   local y = 1

   for kind, text in stream do
      local line = stream(0) as number

      if y ~= line then
         y = line
         x = 1
      end

      x = x + #text

      local types = tl.symbols_in_scope(report, line, x)

      local index: number

      for i, v in pairs(types) do
         if i == text then
            index = v
            break
         end
      end

      local token = {
         kind = kind,
         str = text,
         line = line,
         typ = report.types[index]
      } as Token

      table.insert(tokens, token)
   end

   return tokens
end

local entities = {
   ['<'] = '&lt;',
   ['>'] = '&gt;',
   ['&'] = '&amp;'
}

local function escape(text: string): string
   return text:gsub('[<>&]', entities) as string
end

local function fullDocument(tokens: {Token}, current: string, noOutline: boolean, toRoot: string): string
   toRoot = toRoot or './'

   local body = {}

   local y = 1

   for i = 1, #tokens do
      local token = tokens[i]
      local within = {}
      local tag = 'span'

      if token.kind == 'whitespace' then
         table.insert(body, token.str)
      else
         if token.line ~= y then
            y = token.line

            table.insert(body, '<span id="line-' .. y .. '"></span>')
         end

         if token.typ then
            table.insert(within, 'data-tippy-content="' .. token.typ.str .. '"')

            if token.typ.y then
               tag = 'a'

               local src = token.typ.file

               local href: string

               if src ~= current and src then
                  href = toRoot .. 'sources/' .. src:gsub('/', '-') .. '.html'
               else
                  href = '#line-' .. token.typ.y
               end

               table.insert(within, 'href="' .. href .. '"')
            end
         end

         local color = theme[token.kind] and token.kind or 'text'

         if token.str == 'true' or token.str == 'false' or token.str == 'nil' then
            color = 'number'
         end

         table.insert(within, 'class="code-' .. color .. '"')

         table.insert(body, '<' .. tag .. ' ' .. table.concat(within, ' ') .. '>' .. escape(token.str) .. '</' .. tag .. '>')
      end
   end

   if noOutline then
      return table.concat(body)
   end

   return ([[
   <!DOCTYPE html>
   <html lang="en">

   <head>
      <meta charset="UTF-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">

      <style>
         body { background-color: #fafafa; }
         a { text-decoration: none; }
         %s
      </style>
   </head>
   <body>
      <pre><code>
%s
      </code></pre>
      <script src="https://unpkg.com/@popperjs/core@2"></script>
      <script src="https://unpkg.com/tippy.js@6"></script>
      <script>
         tippy('[data-tippy-content]');
      </script>
   </body>
   ]]):format(genCss, table.concat(body))
end

return {
   parse = parse,
   fullDocument = fullDocument,
   css = genCss,
}
