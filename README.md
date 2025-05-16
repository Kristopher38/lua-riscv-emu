# Pure Lua RV32I emulator

To run compiled binary (not ELF, just .text section):
```
lua run.lua <binary name>
```

To run test and benchmark:
```
pip install -r requirements.txt
python test_cpu.py
```

Performance of a random instruction stream is about 1.4M instructions on i7-8700k.

