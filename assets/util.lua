local project
local genFn

local primitive = {
    ['nil'] = true,
    ['boolean'] = true,
    ['number'] = true,
    ['string'] = true,
    ['userdata'] = true,
    ['thread'] = true,
    ['any'] = true,
    ['unknown'] = true
}

local links = {
    ['nil'] = 'https://www.lua.org/pil/2.1.html',
    ['boolean'] = 'https://www.lua.org/pil/2.2.html',
    ['number'] = 'https://www.lua.org/pil/2.3.html',
    ['string'] = 'https://www.lua.org/pil/2.4.html',
    ['table'] = 'https://www.lua.org/pil/2.5.html',
    ['function'] = 'https://www.lua.org/pil/2.6.html',
    ['userdata'] = 'https://www.lua.org/pil/2.7.html',
    ['thread'] = 'https://www.lua.org/pil/2.7.html',
    ['any'] = 'https://www.lua.org/pil/contents.html#2'
}

local function humanize(type, style)
    local kind = type.kind

    if primitive[kind] then
        return style and '<a href="' .. links[kind] .. '" class="text-blue-500">' .. kind .. '</a>' or kind
    elseif kind == 'function' then
        return genFn(type.func, style)
    elseif kind == 'table' then
        if type.key.kind == 'number' then
            return '{' .. humanize(type.value, style) .. '}'
        elseif type.key.kind == 'any' and type.value.kind == 'any' then
            return style and '<a href="' .. links[kind] .. '" class="text-blue-500">' .. kind .. '</a>' or kind
        else
            return '{' .. humanize(type.key, style) .. ': ' .. humanize(type.value, style) .. '}'
        end
    elseif kind == 'generic' then
        return style and '<span class="text-green-500">' .. type.name .. '</span>' or type.name
    elseif kind == 'custom' or kind == 'enum' then
        local struct = type.struct

        local name = (struct.name or type.name or '')
        --; TODO - Use a better solution
        return style and '<a href="./' .. name .. '.html" class="text-blue-500">' .. name .. '</a>' or name
    elseif kind == 'union' or kind == 'tuple' then
        local types = {}

        for i = 1, #type.types do
            local humanized = humanize(type.types[i], style)
            table.insert(types, humanized)
        end

        local res = table.concat(types, kind == 'union' and ' | ' or ', ')

        if kind == 'tuple' then
            return '(' .. res .. ')'
        else
            return res
        end
    elseif kind == 'nominal' then
        return humanize(type.ref, style)
    end
end

genFn = function(fn, style)
    local fnName = fn.parent or ''
    local src

    if project.functionStyle == 'moon' then
        src = (style and '<b>' .. fnName .. '</b>' or fnName) .. (fnName ~= '' and ' = ' or '')
    else
        src = (style and '<b>function</b>' or 'function') .. (fnName ~= '' and ' ' or '') .. fnName
    end

    local parens = {}
    local generics = {}
    local rets = {}

    for i = 1, #fn.params do
        local param = fn.params[i]

        if param.type.kind == 'generic' then
            table.insert(generics, param.name)
        end

        local paramName = (param.name and param.name .. ': ' or '') .. humanize(param.type, style)

        table.insert(parens, paramName)
    end

    for i = 1, #fn.returns do
        local humanized = humanize(fn.returns[i], style)
        table.insert(rets, humanized)
    end

    generics = #generics > 0 and '<' .. table.concat(generics, ', ') .. '>' or ''
    parens = '(' .. table.concat(parens, ', ') .. ')'

    if project.functionStyle == 'moon' then
        rets = #rets > 0 and ' -> ' .. table.concat(rets, ', ') or ''
    else
        rets = #rets > 0 and ': ' .. table.concat(rets, ', ') or ''
    end

    src = src .. generics .. parens .. rets

    return src
end

return function(proj)
    project = proj
    return {
        genFn = genFn,
        humanize = humanize
    }
end
