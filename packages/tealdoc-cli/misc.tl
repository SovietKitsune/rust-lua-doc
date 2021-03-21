local parser = require('tealdoc.parser')

local function toRoot(current: parser.Type): string
   if not current.tree then return './' end

   local count = 0

   for i = 1, #current.tree do
      if current.tree:sub(i, i) == '/' then
         count = count + 1
      end
   end

   return './' .. string.rep('../', count)
end

--- Things used in templates that are not large enough for their own file
return {
   --- The order in which module contents are sorted
   order = {
      'Modules',
      'Records',
      'Enums',
      'Functions',
      'Variables'
   },
   --- The tippy configuration used
   tippy = [[
      <script src="https://unpkg.com/@popperjs/core@2"></script>
      <script src="https://unpkg.com/tippy.js@6"></script>
      <script>
         tippy('[data-tippy-content]', {
            allowHTML: true,
            theme: 'auto',
            content(reference) {
               return reference.querySelector('span').innerHTML
            }
         });
      </script>
   ]],
   --- Get the root of the documentation output
   toRoot = toRoot,
}
