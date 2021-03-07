--- The core functions of math, addition, subtraction, multiplication, and division
local core = {
   --- This is a fun variable
   isFun = true,
   --- Add two numbers together
   ---
   --- ```lua
   --- core.add(1, 2) -- 3
   --- ```
   add = function(a: number, b: number): number
      return a + b
   end,
   --- Subtract two numbers apart
   ---
   --- ```lua
   --- core.subtract(1, 2) -- -1
   --- ```
   sub = function(a: number, b: number): number
      return a - b
   end,
   --- Multiply two numbers together
   ---
   --- ```lua
   --- core.multiply(1, 2) -- 2
   --- ```
   mul = function(a: number, b: number): number
      return a * b
   end,
   --- Divide two numbers apart
   ---
   --- ```lua
   --- core.divide(1, 2) -- 0.5
   --- ```
   div = function(a: number, b: number): number
      return a / b
   end
}

return core
