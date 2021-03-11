local parser = require('tealdoc.parser')

local project: table
local genFn: function(fn: parser.Type, style: boolean)

local primitive: {parser.Type.Kinds: boolean} = {
    ['nil'] = true,
    ['boolean'] = true,
    ['number'] = true,
    ['string'] = true,
    ['userdata'] = true,
    ['thread'] = true,
    ['any'] = true,
    ['unknown'] = true
}

local links: {parser.Type.Kinds: string} = {
    ['nil'] = 'https://www.lua.org/pil/2.1.html',
    ['boolean'] = 'https://www.lua.org/pil/2.2.html',
    ['number'] = 'https://www.lua.org/pil/2.3.html',
    ['string'] = 'https://www.lua.org/pil/2.4.html',
    ['table'] = 'https://www.lua.org/pil/2.5.html',
    ['function'] = 'https://www.lua.org/pil/2.6.html',
    ['userdata'] = 'https://www.lua.org/pil/2.7.html',
    ['thread'] = 'https://www.lua.org/pil/2.7.html',
    ['any'] = 'https://www.lua.org/pil/contents.html#2',
    ['unknown'] = 'https://www.lua.org/contents.html#2'
}

local function humanize(typ: parser.Type, style: boolean): string
    local kind = typ.kind

    if primitive[kind] then
        return style and '<a href="' .. links[kind] .. '" class="text-blue-500">' .. kind .. '</a>' or kind
    elseif kind == 'named' then
        return typ.customName
    elseif kind == 'function' then
        return genFn(typ, style)
    elseif kind == 'table' then
        if (typ.key as parser.Type).kind == 'number' then
            return '{' .. humanize(typ.value, style) .. '}'
        elseif (typ.key as parser.Type).kind == 'any' and (typ.value as parser.Type).kind == 'any' then
            return style and '<a href="' .. links[kind] .. '" class="text-blue-500">' .. kind .. '</a>' or kind
        else
            return '{' .. humanize(typ.key, style) .. ': ' .. humanize(typ.value, style) .. '}'
        end
    elseif kind == 'generic' then
        return style and '<span class="text-green-500">' .. typ.name .. '</span>' or typ.name
    elseif kind == 'custom' or kind == 'enum' then
        local name = typ.name
        return style and '<a href="./' .. name .. '.html" class="text-blue-500">' .. name .. '</a>' or name
    elseif kind == 'union' or kind == 'tuple' then
        local types = {}

        for i = 1, #typ.types do
            local humanized = humanize((typ.types as {parser.Type})[i], style)
            table.insert(types, humanized)
        end

        local res = table.concat(types, kind == 'union' and ' | ' or ', ')

        if kind == 'tuple' then
            return '(' .. res .. ')'
        else
            return res
        end
    end
end

genFn = function(tp: parser.Type, style: boolean): string
    local fn = tp.func as parser.Function
    local fnName = tp.name or ''
    local src: string

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

        if param.kind == 'generic' then
            table.insert(generics, param.name)
        end

        local paramName = (param.name and param.name .. ': ' or '') .. humanize(param, style)

        table.insert(parens, paramName)
    end

    for i = 1, #fn.returns do
        local humanized = humanize(fn.returns[i], style)
        table.insert(rets, humanized)
    end

    local retStr: string

    local genericsStr = #generics > 0 and '<' .. table.concat(generics, ', ') .. '>' or ''
    local parensStr = '(' .. table.concat(parens, ', ') .. ')'

    if project.functionStyle == 'moon' then
        retStr = #rets > 0 and ' -> ' .. table.concat(rets, ', ') or ''
    else
        retStr = #rets > 0 and ': ' .. table.concat(rets, ', ') or ''
    end

    src = src .. genericsStr .. parensStr .. retStr

    return src
end

--- A factory used to generate a function that converts types into strings
return function(pro: table): function(tp: parser.Type, style: boolean): string
    project = pro

    return humanize
end
