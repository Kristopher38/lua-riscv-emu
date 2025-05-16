local cpulib = require("cpu")

cpu = cpulib.new()

function set_reg(idx, val)
    cpu.reg[idx] = val
end