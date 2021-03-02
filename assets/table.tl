local record ext_table
   count: function(tbl: table): number
   deepcount: function(tbl: table): number
   copy: function<T>(tbl: {T}): {T}
   deepcopy: function<T>(tbl: {T}): {T}
   reverse: function(tbl: table): table
   reversed: function(tbl: table): table
   keys: function<K, V>(tbl: {K: V}): {K}
   values: function<K, V>(tbl: {K: V}): {V}
   randomipairs: function<V>(tbl: {V}): number, V
   randompairs: function<K, V>(tbl: {K: V}): K, V
   sorted: function<V>(tbl: {V}, fn: function): {V}
   search: function<K, V>(tbl: {K, V}, value: V): V
   slice: function<V>(tbl: {V}, start: number, stop: number, step: number): {V}
end

return ext_table
