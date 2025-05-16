local function new()
    local reg = setmetatable({
        0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    }, {
        __index = function(self, k)
            if k == 0 then
                return 0
            else
                return rawget(self, k)
            end
        end,
        __newindex = function(self, k, v)
            if k ~= 0 then
                error("attempt to access invalid register")
            end
        end
    })
    local pc = 0x0
    local mem = setmetatable({}, {
        __index = function(self, k)
            return 0
        end
    })
    local prog = {}
    local handlers = {
        ecall = function(...) end,
        ebreak = function(...) end,
    }

    local function print_state()
        print(string.format("PC: 0x%08x", pc))
        print("Register file:")
        print("[x0] = 0x00000000")
        for i, val in ipairs(reg) do
            print(string.format("[x%d] = 0x%08x", i, val))
        end
    end
    
    local function decode(instr)
        local funct7 = (instr & 0xFE000000) >> 25
        local rs2 = (instr & 0x1F00000) >> 20
        local rs1 = (instr & 0xF8000) >> 15
        local funct3 = (instr & 0x7000) >> 12
        local rd = (instr & 0xF80) >> 7
        local opcode = instr & 0x7F
        local immI = (instr & 0xFFF00000) >> 20
        if (instr & 0x80000000) > 0 then
            immI = immI | 0xFFFFF000
        end
        local immS = ((instr & 0xFE000000) >> 20) | ((instr & 0xF80) >> 7)
        if (instr & 0x80000000) > 0 then
            immS = immS | 0xFFFFF000
        end
        local immU = instr & 0xFFFFF000
        local immB = ((instr & 0x7E000000) >> 20) | -- instr[30:25]
                    ((instr & 0xF00) >> 7) | -- instr[11:8]
                    ((instr & 0x80) << 4) -- instr[7]
        if (instr & 0x80000000) > 0 then
            immB = immB | 0xFFFFF000
        end
        local immJ = ((instr & 0x7FE00000) >> 20) | -- instr[30:25]
                    ((instr & 0x100000) >> 9) | -- instr[20]
                    ((instr & 0xFF000)) -- instr[19:12]
        if (instr & 0x80000000) > 0 then
            immJ = immJ | 0xFFF00000
        end

        if opcode == 0x37 then
            return "lui", rd, nil, nil, immU
        elseif opcode == 0x17 then
            return "auipc", rd, nil, nil, immU
        elseif opcode == 0x6F then
            return "jal", rd, nil, nil, immJ
        elseif opcode == 0x67 then
            return "jalr", rd, rs1, nil, immI
        elseif opcode == 0x63 then
            if funct3 == 0x0 then
                return "beq", nil, rs1, rs2, immB
            elseif funct3 == 0x1 then
                return "bne", nil, rs1, rs2, immB
            elseif funct3 == 0x4 then
                return "blt", nil, rs1, rs2, immB
            elseif funct3 == 0x5 then
                return "bge", nil, rs1, rs2, immB
            elseif funct3 == 0x6 then
                return "bltu", nil, rs1, rs2, immB
            elseif funct3 == 0x7 then
                return "bgeu", nil, rs1, rs2, immB
            end
        elseif opcode == 0x3 then
            if funct3 == 0x0 then
                return "lb", rd, rs1, nil, immI
            elseif funct3 == 0x1 then
                return "lh", rd, rs1, nil, immI
            elseif funct3 == 0x2 then
                return "lw", rd, rs1, nil, immI
            elseif funct3 == 0x4 then
                return "lbu", rd, rs1, nil, immI
            elseif funct3 == 0x5 then
                return "lhu", rd, rs1, nil, immI
            end
        elseif opcode == 0x23 then
            if funct3 == 0x0 then
                return "sb", nil, rs1, rs2, immS
            elseif funct3 == 0x1 then
                return "sh", nil, rs1, rs2, immS
            elseif funct3 == 0x2 then
                return "sw", nil, rs1, rs2, immS
            end
        elseif opcode == 0x13 then
            if funct3 == 0x0 then
                return "addi", rd, rs1, nil, immI
            elseif funct3 == 0x2 then
                return "slti", rd, rs1, nil, immI
            elseif funct3 == 0x3 then
                return "sltiu", rd, rs1, nil, immI
            elseif funct3 == 0x4 then
                return "xori", rd, rs1, nil, immI
            elseif funct3 == 0x6 then
                return "ori", rd, rs1, nil, immI
            elseif funct3 == 0x7 then
                return "andi", rd, rs1, nil, immI
            elseif funct3 == 0x1 and funct7 == 0x0 then
                return "slli", rd, rs1, nil, immI
            elseif funct3 == 0x5 then
                if funct7 == 0x0 then
                    return "srli", rd, rs1, nil, immI
                elseif funct7 == 0x20 then
                    return "srai", rd, rs1, nil, immI
                end
            end
        elseif opcode == 0x33 then
            if funct3 == 0x0 then
                if funct7 == 0x0 then
                    return "add", rd, rs1, rs2, nil
                elseif funct7 == 0x20 then
                    return "sub", rd, rs1, rs2, nil
                end
            elseif funct3 == 0x1 and funct7 == 0x0 then
                return "sll", rd, rs1, rs2, nil
            elseif funct3 == 0x2 and funct7 == 0x0 then
                return "slt", rd, rs1, rs2, nil
            elseif funct3 == 0x3 and funct7 == 0x0 then
                return "sltu", rd, rs1, rs2, nil
            elseif funct3 == 0x4 and funct7 == 0x0 then
                return "xor", rd, rs1, rs2, nil
            elseif funct3 == 0x5 then
                if funct7 == 0x0 then
                    return "srl", rd, rs1, rs2, nil
                elseif funct7 == 0x20 then
                    return "sra", rd, rs1, rs2, nil
                end
            elseif funct3 == 0x6 and funct7 == 0x0 then
                return "or", rd, rs1, rs2, nil
            elseif funct3 == 0x7 and funct7 == 0x0 then
                return "and", rd, rs1, rs2, nil
            end
        elseif opcode == 0x73 then
            if rs2 == 0x0 then
                return "ecall", nil, nil, nil, nil
            elseif rs2 == 0x1 then
                return "ebreak", nil, nil, nil, nil
            end
        else
            error(string.format("Invalid opcode 0x%08x", instr))
        end
    end

    local function execute(instr, rd, rs1, rs2, imm)
        local advpc = true
        if instr == "add" then
            reg[rd] = (reg[rs1] + reg[rs2]) & 0xFFFFFFFF
        elseif instr == "slt" then
            local op1 = reg[rs1]
            local op2 = reg[rs2]
            if op1 & 0x80000000 > 0 then
                op1 = op1 | 0xFFFFFFFF00000000
            end
            if op2 & 0x80000000 > 0 then
                op2 = op2 | 0xFFFFFFFF00000000
            end
            if op1 < op2 then
                reg[rd] = 1
            else
                reg[rd] = 0
            end
        elseif instr == "sltu" then
            reg[rd] = (reg[rs1] < reg[rs2]) and 1 or 0
        elseif instr == "and" then
            reg[rd] = reg[rs1] & reg[rs2]
        elseif instr == "or" then
            reg[rd] = reg[rs1] | reg[rs2]
        elseif instr == "xor" then
            reg[rd] = reg[rs1] ~ reg[rs2]
        elseif instr == "sll" then
            reg[rd] = (reg[rs1] << (reg[rs2] & 0x1F)) & 0xFFFFFFFF
        elseif instr == "srl" then
            reg[rd] = reg[rs1] >> (reg[rs2] & 0x1F)
        elseif instr == "sub" then
            reg[rd] = (reg[rs1] - reg[rs2]) & 0xFFFFFFFF
        elseif instr == "sra" then
            local op1 = reg[rs1]
            local op2 = reg[rs2] & 0x1F
            local res = op1 >> op2
            if op1 & 0x80000000 > 0 then
                res = res | (((1 << op2) - 1) << (32 - op2))
            end
            reg[rd] = res
        elseif instr == "addi" then
            reg[rd] = (reg[rs1] + imm) & 0xFFFFFFFF
        elseif instr == "slti" then
            local op1 = reg[rs1]
            if op1 & 0x80000000 > 0 then
                op1 = op1 | 0xFFFFFFFF00000000
            end
            if imm & 0x80000000 > 0 then
                imm = imm - 0x100000000
            end
            if op1 < imm then
                reg[rd] = 1
            else
                reg[rd] = 0
            end
        elseif instr == "sltiu" then
            reg[rd] = (reg[rs1] < imm) and 1 or 0
        elseif instr == "andi" then
            reg[rd] = reg[rs1] & imm
        elseif instr == "ori" then
            reg[rd] = reg[rs1] | imm
        elseif instr == "xori" then
            reg[rd] = reg[rs1] ~ imm
        elseif instr == "slli" then
            reg[rd] = (reg[rs1] << imm) & 0xFFFFFFFF
        elseif instr == "srli" then
            reg[rd] = reg[rs1] >> imm
        elseif instr == "srai" then
            local op1 = reg[rs1]
            local sh = imm & 0x1F
            local res = op1 >> sh
            if op1 & 0x80000000 > 0 then
                res = res | (((1 << sh) - 1) << (32 - sh))
            end
            reg[rd] = res
        elseif instr == "lui" then
            reg[rd] = imm
        elseif instr == "auipc" then
            reg[rd] = (pc + imm) & 0xFFFFFFFF
        elseif instr == "jal" then
            reg[rd] = (pc + 4) & 0xFFFFFFFF
            pc = (pc + imm) & 0xFFFFFFFF
            advpc = false
        elseif instr == "jalr" then
            local target = (reg[rs1] + imm) & 0xFFFFFFFE
            reg[rd] = (pc + 4) & 0xFFFFFFFF
            pc = target
            advpc = false
        elseif instr == "beq" then
            if reg[rs1] == reg[rs2] then
                pc = (pc + imm) & 0xFFFFFFFF
                advpc = false
            end
        elseif instr == "bne" then
            if reg[rs1] ~= reg[rs2] then
                pc = (pc + imm) & 0xFFFFFFFF
                advpc = false
            end
        elseif instr == "blt" then
            local op1 = reg[rs1]
            local op2 = reg[rs2]
            if op2 & 0x80000000 > 0 then
                if op1 & 0x80000000 > 0 and op1 < op2 then
                    -- op2 < 0 and op1 < 0 and op1 < op2
                    pc = (pc + imm) & 0xFFFFFFFF
                    advpc = false
                end
            else
                if op1 & 0x80000000 > 0 or op1 < op2 then
                    -- (op2 >= 0 and op1 < 0) or
                    -- (op2 >= 0 and op1 >= 0 and op1 < op2)
                    pc = (pc + imm) & 0xFFFFFFFF
                    advpc = false
                end
            end
        elseif instr == "bltu" then
            if reg[rs1] < reg[rs2] then
                pc = (pc + imm) & 0xFFFFFFFF
                advpc = false
            end
        elseif instr == "bge" then
            local op1 = reg[rs1]
            local op2 = reg[rs2]
            if op2 & 0x80000000 > 0 then
                if op1 & 0x80000000 == 0 or op1 >= op2 then
                    -- (op2 < 0 and op1 >= 0) or
                    -- (op2 < 0 and op1 < 0) and op1 >= op2
                    pc = (pc + imm) & 0xFFFFFFFF
                    advpc = false
                end
            else
                if op1 & 0x80000000 == 0 and op1 >= op2 then
                    -- op2 >= 0 and op1 >= 0 and op1 >= op2
                    pc = (pc + imm) & 0xFFFFFFFF
                    advpc = false
                end
            end
        elseif instr == "bgeu" then
            if reg[rs1] >= reg[rs2] then
                pc = (pc + imm) & 0xFFFFFFFF
                advpc = false
            end
        elseif instr == "lw" then
            local eaddr = (reg[rs1] + imm) & 0xFFFFFFFF
            reg[rd] = mem[eaddr // 4]
        elseif instr == "lh" then
            local eaddr = (reg[rs1] + imm) & 0xFFFFFFFF
            local val = mem[eaddr // 4]
            if (eaddr & 0x3) > 1 then
                val = (val >> 16) & 0xFFFF
            else
                val = val & 0xFFFF
            end
            if (val & 0x8000) > 0 then
                val = val | 0xFFFF0000
            end
            reg[rd] = val
        elseif instr == "lhu" then
            local eaddr = (reg[rs1] + imm) & 0xFFFFFFFF
            local val = mem[eaddr // 4]
            if eaddr & 0x3 > 1 then
                reg[rd] = (val >> 16) & 0xFFFF
            else
                reg[rd] = val & 0xFFFF
            end
        elseif instr == "lb" then
            local eaddr = (reg[rs1] + imm) & 0xFFFFFFFF
            local val = mem[eaddr // 4]
            val = (val >> (8 * (eaddr & 0x3))) & 0xFF
            if val & 0x80 > 0 then
                val = val | 0xFFFFFF00
            end
            reg[rd] = val
        elseif instr == "lbu" then
            local eaddr = (reg[rs1] + imm) & 0xFFFFFFFF
            local val = mem[eaddr // 4]
            reg[rd] = (val >> (8 * (eaddr & 0x3))) & 0xFF
        elseif instr == "sw" then
            local addr = (reg[rs1] + imm) & 0xFFFFFFFF
            local baseaddr = addr >> 2
            local val = reg[rs2]
            mem[baseaddr] = val
        elseif instr == "sh" then
            local addr = (reg[rs1] + imm) & 0xFFFFFFFF
            local baseaddr = addr >> 2
            local shamt = (addr & 0x2) * 8
            local val = (reg[rs2] & 0xFFFF) << shamt
            local mask = 0xFFFF << (16 - shamt)
            mem[baseaddr] = (mem[baseaddr] & mask) | val
        elseif instr == "sb" then
            local addr = (reg[rs1] + imm) & 0xFFFFFFFF
            local baseaddr = addr >> 2
            local shamt = (addr & 0x3) * 8
            local val = (reg[rs2] & 0xFF) << shamt
            local mask = ~(0xFF << shamt)
            mem[baseaddr] = (mem[baseaddr] & mask) | val
        elseif instr == "ecall" then
            handlers.ecall(reg, pc, mem, prog)
        elseif instr == "ebreak" then
            handlers.ebreak(reg, pc, mem, prog)
        end
        if advpc then
            pc = (pc + 4) & 0xFFFFFFFF
        end
    end

    local function load_binary(path)
        local f, err = io.open(path, "rb")
        if f then
            repeat
                local bin = f:read(4)
                local instr
                if bin then
                    instr = string.unpack("<I" .. tostring(#bin), bin)
                    prog[#prog+1] = instr
                end
            until instr == nil
        else
            error(err)
        end

    end

    local function run_single()
        local instr = prog[(pc // 4)+1]
        execute(decode(instr))
    end

    return {
        reg = reg,
        pc = function(newpc)
            if newpc then
                pc = newpc
            else
                return pc
            end
        end,
        mem = mem,
        prog = prog,
        handlers = handlers,
        print_state = print_state,
        load_binary = load_binary,
        set_reg = set_reg,
        execute = execute,
        decode = decode,
        run_single = run_single,
    }
end

return {
    new = new
}