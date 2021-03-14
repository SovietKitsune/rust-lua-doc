-- Highlighter and type information
local tippy = require('tealdoc.tippy')
local theme = require('tealdoc.theme')
local lexer = require('pl.lexer')
local tl = require('tl')

local record Token
   --- A basic type, it will attempt to query `parser.createType` to generate the basic type
   typ: tl.TypeInfo -- parser.Type
   --- The kind of token it is
   kind: string
   --- The contents of what the token is
   str: string
   line: integer
end

local function castKind(kind: string, text: string): string
   if kind == 'identifier' and text == '_G' or text == '_ENV' then
      return 'constant'
   elseif kind == 'identifier' and (_G as {string: any})[text] then
      return 'library'
   elseif kind == 'identifier' and text == 'self' then
      return 'keyword2'
   else
      return kind
   end
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
      kind = castKind(kind, text)

      local line = stream(0) as integer

      if y ~= line then
         y = line
         x = 1
      end

      x = x + #text

      local types = tl.symbols_in_scope(report, line, x)

      local index: integer

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

-- No teal involved here, just highlighting
local function fastHighlight(text: string, noWrap: boolean): string
   local body = {}

   local stream = lexer.lua(text, {
      space = false,
      comments = false
   }, {
      number = false,
      string = false
   })

   for kind, text in stream do
      kind = castKind(kind, text)

      if kind == 'whitespace' then
         table.insert(body, text)
      elseif theme.isNonText(kind) then
         table.insert(body, '<span class="code-' .. kind .. '">' .. escape(text) .. '</span>')
      else
         table.insert(body, '<span class="code-text">' .. escape(text) .. '</span>')
      end
   end

   if noWrap then
      return table.concat(body)
   else
      return '<pre class="code-block"><code>' .. table.concat(body) .. '</code></pre>'
   end
end

local function fullDocument(tokens: {Token}, current: string, selectedTheme: string, noOutline: boolean, toRoot: string): string
   toRoot = toRoot or '../'

   local body = {}

   local y = 1

   for i = 1, #tokens do
      local token = tokens[i]
      local within = {}
      local tag = 'span'
      local extra = ''

      if token.kind == 'whitespace' then
         table.insert(body, token.str)
      else
         if token.line ~= y then
            y = token.line

            table.insert(body, '<span id="line-' .. y .. '"></span>')
         end

         if token.typ then
            table.insert(within, 'data-tippy-content')

            extra = '<span style="display: none;"><code>' .. fastHighlight(token.typ.str, true) .. '</code></span>'

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

         local color = theme.isNonText(token.kind) and token.kind or 'text'

         if token.str == 'true' or token.str == 'false' or token.str == 'nil' then
            color = 'number'
         end

         table.insert(within, 'class="code-' .. color .. '"')

         table.insert(body, '<' .. tag .. ' ' .. table.concat(within, ' ') .. '>' .. escape(token.str) .. extra .. '</' .. tag .. '>')
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
         a { text-decoration: none; }
         %s
      </style>
   </head>
   <body class="%s">
      <pre class="code-block"><code>
%s
      </code></pre>
      %s
   </body>
   ]]):format(theme.css, selectedTheme, table.concat(body), tippy)
end

return {
   parse = parse,
   fullDocument = fullDocument,
   fastHighlight = fastHighlight
}
