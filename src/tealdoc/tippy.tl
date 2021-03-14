--- The tippy configuration used
return [[
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
]]
