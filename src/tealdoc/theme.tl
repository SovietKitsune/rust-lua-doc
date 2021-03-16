local record Theme
   record Code
      text: string
      background: string
      border: string
      syntax: Syntax
   end

   record Syntax
      comment: string
      constant: string
      identifier: string
      keyword: string
      number: string
      string: string
      library: string
   end

   text: string
   background: string
   tooltip: string
   outline: string
   outlineMain: string
   outlineBackground: string

   link: string
   nav: string
   navLink: string
   code: Code
end

local supportedTokens: {string: boolean} = {
   comment = true,
   constant = true,
   identifier = true,
   keyword = true,
   number = true,
   string = true,
   library = true
}

local themes: {string: Theme} = {}

-- Basically one-light
themes.light = {
   -- Everything else is automatically selected by the template
   tooltip = '#eeeeee', -- The tooltip background color
   code = {
      text = '#383a42', -- The color of non-special tokens (usually the same as identifiers)
      background = '#fafafa', -- The background of code blocks
      border = '#aaaaaa', -- The border color around code blocks
      syntax = {
         comment = '#a0a1a7', -- -- abc, --[[abc]], etc
         constant = '#e6c07b', -- _G, _ENV
         identifier = '#383a42', -- hi, bye, etc
         keyword = '#a626a4', -- local, function, etc
         keyword2 = '#FF5370', -- self
         number = '#d19a66', -- 1, 0x3, etc
         string = '#50a14f', -- 'hi', "hi", [[hi]], etc
         library = '#82AAFF' -- table, print, etc
      }
   }
}

-- https://github.com/atomiks/moonlight-vscode-theme
themes.moonlight = {
   text = '#C8D3F5',
   background = '#1e2030',
   link = '#7A88CF',
   nav = '#3e4260',
   navLink = '#C8D3F5',
   tooltip = '#3e4260',
   outline = '#C8D3F5',
   outlineMain = '#00000000',
   outlineBackground = '#363a54',
   code = {
      text = '#e4f3fa',
      background = '#1e2030',
      border = '#191a2a',
      syntax = {
         comment = '#7e8eda',
         constant = '#ffdf9b',
         identifier = '#e4f3fa',
         keyword = '#baacff',
         keyword2 = '#FF5370',
         number = '#ff9668',
         string = '#7af8ca',
         library = '#82AAFF'
      }
   }
}

-- https://www.nordtheme.com/
themes.nordic = {
   text = '#eceff4',
   background = '#2e3440',
   link = '#81a1c1',
   nav = '#242933',
   navLink = '#eceff4',
   tooltip = '#2f3542',
   outline = '#eceff4',
   outlineMain = '#00000000',
   outlineBackground = '#20252d',
   code = {
      text = '#eceff4',
      background = '#2a2f3a',
      border = '#20252d',
      syntax = {
         comment = '#4c566a',
         constant = '#8fbcbb',
         identifier = '#eceff4',
         keyword = '#5e81ac',
         keyword2 = '#5e81ac',
         number = '#ebcb8b',
         string = '#a3be8c',
         library = '#81a1c1'
      }
   }
}

local function createCSS(): string
   local sheet = {
      [[
         .tooltip-parent .tooltip {
            visibility: hidden;
            text-align: center;

            padding-left: 0.25rem;
            padding-right: 0.25rem;

            border-radius: 1px;
            position: absolute;
            z-index: 1;
         }

         .tooltip-parent:hover .tooltip {
            visibility: visible;
         }
      ]]
   }

   for theme, styles in pairs(themes) do
      table.insert(sheet, string.format('/* %s theme */', theme))
      table.insert(
         sheet,
         string.format([[
            .%s {
               background-color: %s;
               color: %s;
            }

            .%s .border-black {
               border-color: %s;
            }

            .%s .top-border {
               background-color: %s;
               border-color: %s;
            }

            .%s a {
               color: %s;
            }

            .%s nav {
               background-color: %s;
            }

            .%s nav a {
               color: %s;
            }

            .%s .tippy-box[data-theme~='auto'] {
               background-color: %s;
            }

            .%s .tooltip-parent .tooltip {
               background-color: %s;
               color: %s;
            }

            .%s .code-block {
               background-color: %s;
               border-color: %s;
            }
         ]],
         theme,
         styles.background,
         styles.text,
         theme,
         styles.outline,
         theme,
         styles.outlineBackground,
         styles.outlineMain,
         theme,
         styles.link,
         theme,
         styles.nav,
         theme,
         styles.navLink,
         theme,
         styles.tooltip,
         theme,
         styles.code.border,
         styles.code.text,
         theme,
         styles.code.background,
         styles.code.border
      ))

      for kind, style in pairs(styles.code.syntax as {string: string}) do
         table.insert(sheet, string.format('.%s .code-%s { color: %s; }', theme, kind, style))
      end

      table.insert(sheet, string.format('.%s .code-text { color: %s; }', theme, styles.code.text))
   end

   return table.concat(sheet, '\n')
end

local function isNonText(kind: string): boolean
   return supportedTokens[kind]
end

return {
   themes = themes,
   createCSS = createCSS,
   css = createCSS(), -- Generate CSS at load, if a new theme is added, it can manually be regenerated
   isNonText = isNonText
}
