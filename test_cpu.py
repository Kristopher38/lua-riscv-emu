import random
import lupa.lua53 as lupa
import logging

from tqdm import tqdm
from timeit_decorator import timeit
from riscvmodel.insn import (
    InstructionADDI,
    InstructionSLTI,
    InstructionSLTIU,
    InstructionXORI,
    InstructionORI,
    InstructionANDI,
    InstructionJALR,
)
from riscvmodel.model import Model
from riscvmodel.isa import *
from riscvmodel.variant import RV32I

instructions = []
instructions += get_insns(cls=InstructionRType)
instructions += [
    InstructionADDI,
    InstructionSLTI,
    InstructionSLTIU,
    InstructionXORI,
    InstructionORI,
    InstructionANDI,
    InstructionJALR,
]
instructions += get_insns(cls=InstructionILType)
instructions += get_insns(cls=InstructionISType)
instructions += get_insns(cls=InstructionSType)
instructions += get_insns(cls=InstructionBType)
instructions += get_insns(cls=InstructionUType)
instructions += get_insns(cls=InstructionJType)

INSTR_COUNT = 10000
MEM_SIZE_LOG = 9
SEED = 42

def toS32(bits):
    candidate = bits
    if (candidate >> 31):
        return (-0x80000000 + (candidate & 0x7fffffff))
    return candidate

def compare_core_states(ref_instr, ref_core):
    ref_regs = ref_model.state.intreg
    for i in range(32):
        ref_val = ref_regs[i].unsigned()
        val = lua.eval(f"cpu.reg[{i}]")
        if ref_val != val:
            print(ref_instr)
            print(ref_val, val)
            breakpoint()
    ref_pc = ref_model.state.pc.unsigned()
    pc = lua.eval(f"cpu.pc()")
    if ref_pc != pc:
        print(ref_instr)
        print(ref_pc, pc)
        breakpoint()

    ref_mem = ref_model.state.memory.memory
    mem = dict(lua.eval("cpu.mem"))
    if ref_mem != mem:
        print(ref_instr)
        print(ref_mem, mem)
        breakpoint()

def init_regs(ref_core):
    # allocate some random values for registers
    for i in range(32):
        reg_val = random.randint(0, 2**32 - 1)
        ref_core.state.intreg[i].set(toS32(reg_val))
        lua.eval(f"set_reg({i}, {reg_val})")

def random_test(count):
    # generate random instruction stream
    instr_stream = []
    for i in tqdm(range(count)):
        instr = random.choice(instructions)()
        instr.randomize(RV32I)
        if isinstance(instr, InstructionILType) or isinstance(instr, InstructionSType):
            instr2 = InstructionANDI(instr.rs1, instr.rs1, 2**(MEM_SIZE_LOG+1) - 1)
            instr.imm.set(random.randint(0, 2**(MEM_SIZE_LOG+1) - 1))
            instr_stream.append(instr2)
        instr_stream.append(instr)
    return instr_stream[:count]

def execute_instrs(instr_stream):
    # execute all instructions and compare core states after each instruction
    for ref_instr in tqdm(instr_stream):
        instr, rd, rs1, rs2, imm = lua.eval(f"cpu.decode({ref_instr.encode()})")
        assert ref_instr.mnemonic == instr
        if hasattr(ref_instr, "rd"):
            assert ref_instr.rd == rd
        if hasattr(ref_instr, "rs1"):
            assert ref_instr.rs1 == rs1
        if hasattr(ref_instr, "rs2"):
            assert ref_instr.rs2 == rs2
        if hasattr(ref_instr, "imm"):
            if instr in ["lui", "auipc"]:
                # cpu.lua returns not-shifted version
                # riscv-python-model returns shifted version
                immCorr = imm >> 12
            else:
                immCorr = imm
            assert int(ref_instr.imm) == toS32(immCorr)

        ref_model.execute(ref_instr)
        lua.eval(f"cpu.execute(\"{instr}\", {rd}, {rs1}, {rs2}, {imm})")
        compare_core_states(ref_instr, ref_model)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(name)s) %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

random.seed(SEED)

ref_model = Model(RV32I)
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.require("test_cpu")

init_regs(ref_model)
compare_core_states("", ref_model)

logging.info(f"Generating {INSTR_COUNT} instructions...")
instrs = random_test(INSTR_COUNT)

logging.info(f"Running test on {INSTR_COUNT} instructions...")
execute_instrs(instrs)

benchmark_f = lua.eval('''
    function(instrs)
        local decode = cpu.decode
        local execute = cpu.execute
        for instr in python.iter(instrs) do
            execute(decode(instr))
        end
    end
''')

logging.info(f"Encoding {INSTR_COUNT} instructions")
instrs_encoded = []
for instr in tqdm(instrs):
    instrs_encoded.append(instr.encode())

logging.info(f"Executing benchmark")

@timeit(runs=10, workers=1, log_level=logging.INFO, detailed=True)
def benchmark(toexec):
    benchmark_f(toexec)

benchmark(instrs_encoded)
