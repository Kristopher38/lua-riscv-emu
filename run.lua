local cpulib = require("cpu")

local argv = {...}
local cpu = cpulib.new()
if #argv < 1 then
    error("Usage: run.lua <executable>")
end
cpu.load_binary(argv[1])

local computer
if pcall(require, "computer") then
    computer = require("computer")
else
    computer = {
        uptime = function() return 0 end,
        pullSignal = function(...) end,
    }
end

local ic = 0
local t, tt = os.clock(), computer.uptime()
local tend, ttend
while true do
    cpu.run_single()
    ic = ic + 1
    if ic % 1000000 == 0 then
        tend = os.clock()
        ttend = computer.uptime()
        print(string.format("real: %f, ticks: %f", tend-t, ttend-tt))
        print(ic)
        computer.pullSignal(0)
        t = os.clock()
        tt = computer.uptime()
    end
end