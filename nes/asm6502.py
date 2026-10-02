#!/usr/bin/env python3
"""Minimal 6502 assembler for NES ROMs. Supports the subset needed for PYREKEEPER."""
import sys
import re

# Opcode table: (mnemonic, mode) -> opcode
# Modes: imp, imm, zp, zpx, zpy, abs, abx, aby, ind, indx, indy, rel
OPCODES = {
    ('lda','imm'): 0xA9, ('lda','zp'): 0xA5, ('lda','zpx'): 0xB5,
    ('lda','abs'): 0xAD, ('lda','abx'): 0xBD, ('lda','aby'): 0xB9,
    ('lda','indx'): 0xA1, ('lda','indy'): 0xB1,
    ('sta','zp'): 0x85, ('sta','zpx'): 0x95, ('sta','abs'): 0x8D,
    ('sta','abx'): 0x9D, ('sta','aby'): 0x99, ('sta','indx'): 0x81,
    ('sta','indy'): 0x91,
    ('ldx','imm'): 0xA2, ('ldx','zp'): 0xA6, ('ldx','zpy'): 0xB6,
    ('ldx','abs'): 0xAE, ('ldx','aby'): 0xBE,
    ('ldy','imm'): 0xA0, ('ldy','zp'): 0xA4, ('ldy','zpx'): 0xB4,
    ('ldy','abs'): 0xAC, ('ldy','abx'): 0xBC,
    ('stx','zp'): 0x86, ('stx','zpy'): 0x96, ('stx','abs'): 0x8E,
    ('sty','zp'): 0x84, ('sty','zpx'): 0x94, ('sty','abs'): 0x8C,
    ('tax','imp'): 0xAA, ('tay','imp'): 0xA8, ('txa','imp'): 0x8A,
    ('tya','imp'): 0x98, ('tsx','imp'): 0xBA, ('txs','imp'): 0x9A,
    ('pha','imp'): 0x48, ('pla','imp'): 0x68, ('php','imp'): 0x08,
    ('plp','imp'): 0x28,
    ('and','imm'): 0x29, ('and','zp'): 0x25, ('and','zpx'): 0x35,
    ('and','abs'): 0x2D, ('and','abx'): 0x3D, ('and','aby'): 0x39,
    ('and','indx'): 0x21, ('and','indy'): 0x31,
    ('ora','imm'): 0x09, ('ora','zp'): 0x05, ('ora','zpx'): 0x15,
    ('ora','abs'): 0x0D, ('ora','abx'): 0x1D, ('ora','aby'): 0x19,
    ('ora','indx'): 0x01, ('ora','indy'): 0x11,
    ('eor','imm'): 0x49, ('eor','zp'): 0x45, ('eor','zpx'): 0x55,
    ('eor','abs'): 0x4D, ('eor','abx'): 0x5D, ('eor','aby'): 0x59,
    ('eor','indx'): 0x41, ('eor','indy'): 0x51,
    ('adc','imm'): 0x69, ('adc','zp'): 0x65, ('adc','zpx'): 0x75,
    ('adc','abs'): 0x6D, ('adc','abx'): 0x7D, ('adc','aby'): 0x79,
    ('adc','indx'): 0x61, ('adc','indy'): 0x71,
    ('sbc','imm'): 0xE9, ('sbc','zp'): 0xE5, ('sbc','zpx'): 0xF5,
    ('sbc','abs'): 0xED, ('sbc','abx'): 0xFD, ('sbc','aby'): 0xF9,
    ('sbc','indx'): 0xE1, ('sbc','indy'): 0xF1,
    ('cmp','imm'): 0xC9, ('cmp','zp'): 0xC5, ('cmp','zpx'): 0xD5,
    ('cmp','abs'): 0xCD, ('cmp','abx'): 0xDD, ('cmp','aby'): 0xD9,
    ('cmp','indx'): 0xC1, ('cmp','indy'): 0xD1,
    ('cpx','imm'): 0xE0, ('cpx','zp'): 0xE4, ('cpx','abs'): 0xEC,
    ('cpy','imm'): 0xC0, ('cpy','zp'): 0xC4, ('cpy','abs'): 0xCC,
    ('inc','zp'): 0xE6, ('inc','zpx'): 0xF6, ('inc','abs'): 0xEE,
    ('inc','abx'): 0xFE,
    ('dec','zp'): 0xC6, ('dec','zpx'): 0xD6, ('dec','abs'): 0xCE,
    ('dec','abx'): 0xDE,
    ('inx','imp'): 0xE8, ('iny','imp'): 0xC8, ('dex','imp'): 0xCA,
    ('dey','imp'): 0x88,
    ('asl','imp'): 0x0A, ('asl','zp'): 0x06, ('asl','zpx'): 0x16,
    ('asl','abs'): 0x0E, ('asl','abx'): 0x1E,
    ('lsr','imp'): 0x4A, ('lsr','zp'): 0x46, ('lsr','zpx'): 0x56,
    ('lsr','abs'): 0x4E, ('lsr','abx'): 0x5E,
    ('rol','imp'): 0x2A, ('rol','zp'): 0x26, ('rol','zpx'): 0x36,
    ('rol','abs'): 0x2E, ('rol','abx'): 0x3E,
    ('ror','imp'): 0x6A, ('ror','zp'): 0x66, ('ror','zpx'): 0x76,
    ('ror','abs'): 0x6E, ('ror','abx'): 0x7E,
    ('jmp','abs'): 0x4C, ('jmp','ind'): 0x6C,
    ('jsr','abs'): 0x20,
    ('rts','imp'): 0x60, ('rti','imp'): 0x40, ('brk','imp'): 0x00,
    ('bcc','rel'): 0x90, ('bcs','rel'): 0xB0, ('beq','rel'): 0xF0,
    ('bmi','rel'): 0x30, ('bne','rel'): 0xD0, ('bpl','rel'): 0x10,
    ('bvc','rel'): 0x50, ('bvs','rel'): 0x70,
    ('clc','imp'): 0x18, ('sec','imp'): 0x38, ('cli','imp'): 0x58,
    ('sei','imp'): 0x78, ('clv','imp'): 0xB8, ('cld','imp'): 0xD8,
    ('sed','imp'): 0xF8,
    ('nop','imp'): 0xEA,
    ('bit','zp'): 0x24, ('bit','abs'): 0x2C,
}

class Assembler:
    def __init__(self):
        self.labels = {}
        self.code = bytearray()
        self.pc = 0
        self.pass_num = 0

    def parse_operand(self, op_str):
        op_str = op_str.strip()
        if not op_str:
            return ('imp', None)
        if op_str.startswith('#'):
            val = op_str[1:]
            return ('imm', self.parse_value(val))
        if op_str.startswith('('):
            # (zp),y or (zp,x) or (abs)
            m = re.match(r'\(([^,)]+)\)(,y)?', op_str, re.I)
            if m:
                if m.group(2):
                    return ('indy', self.parse_value(m.group(1)))
                else:
                    # check for ,x inside
                    inner = m.group(1)
                    if ',x' in inner.lower():
                        v = inner.split(',')[0]
                        return ('indx', self.parse_value(v))
                    return ('ind', self.parse_value(inner))
        if ',' in op_str:
            parts = op_str.split(',')
            base = parts[0].strip()
            idx = parts[1].strip().lower()
            val = self.parse_value(base)
            if idx == 'x':
                # zp,x or abs,x
                if isinstance(val, int) and val < 256:
                    return ('zpx', val)
                return ('abx', val)
            elif idx == 'y':
                if isinstance(val, int) and val < 256:
                    return ('zpy', val)
                return ('aby', val)
        val = self.parse_value(op_str)
        if isinstance(val, int) and val < 256:
            return ('zp', val)
        return ('abs', val)

    def parse_value(self, s):
        s = s.strip()
        if s.startswith('$'):
            return int(s[1:], 16)
        if s.startswith('%'):
            return int(s[1:], 2)
        if s.isdigit() or (s[0] == '-' and s[1:].isdigit()):
            return int(s)
        # label or expression
        return s

    def assemble_line(self, line):
        line = line.split(';')[0].strip()
        if not line:
            return
        # label
        if ':' in line:
            parts = line.split(':', 1)
            label = parts[0].strip()
            if self.pass_num == 1:
                self.labels[label] = self.pc
            line = parts[1].strip()
            if not line:
                return
        # directive
        if line.startswith('.'):
            self.directive(line)
            return
        # instruction
        parts = line.split(None, 1)
        mnem = parts[0].lower()
        operand = parts[1] if len(parts) > 1 else ''
        mode, val = self.parse_operand(operand)

        # branch instructions use rel mode
        if mnem in ('bcc','bcs','beq','bmi','bne','bpl','bvc','bvs'):
            mode = 'rel'

        key = (mnem, mode)
        if key not in OPCODES:
            # try zp->abs or abs->zp
            if mode == 'zp':
                key = (mnem, 'abs')
            elif mode == 'abs' and isinstance(val, int) and val < 256:
                key = (mnem, 'zp')
            if key not in OPCODES:
                raise ValueError(f"Unknown: {mnem} {mode} ({line})")

        opcode = OPCODES[key]
        if self.pass_num == 2:
            self.code.append(opcode)

        # operand bytes
        if mode == 'imp':
            self.pc += 1
        elif mode in ('imm','zp','zpx','zpy','indx','indy','rel'):
            if self.pass_num == 2:
                if mode == 'rel':
                    # calculate relative offset
                    if isinstance(val, str):
                        target = self.labels[val]
                    else:
                        target = val
                    offset = target - (self.pc + 2)
                    if offset < -128 or offset > 127:
                        raise ValueError(f"Branch out of range: {line}")
                    self.code.append(offset & 0xFF)
                elif isinstance(val, str):
                    self.code.append(self.labels[val] & 0xFF)
                else:
                    self.code.append(val & 0xFF)
            self.pc += 2
        elif mode in ('abs','abx','aby','ind'):
            if self.pass_num == 2:
                if isinstance(val, str):
                    addr = self.labels[val]
                else:
                    addr = val
                self.code.append(addr & 0xFF)
                self.code.append((addr >> 8) & 0xFF)
            self.pc += 3

    def directive(self, line):
        parts = line.split(None, 1)
        d = parts[0].lower()
        arg = parts[1] if len(parts) > 1 else ''
        if d == '.org':
            self.pc = self.parse_value(arg) if isinstance(self.parse_value(arg), int) else self.labels[self.parse_value(arg)]
            # pad code to pc? For simplicity, assume .org only increases
        elif d == '.byte':
            for v in arg.split(','):
                v = v.strip()
                if self.pass_num == 2:
                    if v.startswith('"'):
                        # string
                        for c in v[1:-1]:
                            self.code.append(ord(c))
                            self.pc += 1
                    else:
                        val = self.parse_value(v)
                        if isinstance(val, str):
                            val = self.labels[val]
                        self.code.append(val & 0xFF)
                        self.pc += 1
                else:
                    if v.startswith('"'):
                        self.pc += len(v) - 2
                    else:
                        self.pc += 1
        elif d == '.word':
            for v in arg.split(','):
                v = v.strip()
                if self.pass_num == 2:
                    val = self.parse_value(v)
                    if isinstance(val, str):
                        val = self.labels[val]
                    self.code.append(val & 0xFF)
                    self.code.append((val >> 8) & 0xFF)
                self.pc += 2
        elif d == '.res':
            n = int(arg)
            if self.pass_num == 2:
                self.code.extend([0] * n)
            self.pc += n

def assemble(source):
    asm = Assembler()
    lines = source.split('\n')
    # pass 1: collect labels
    asm.pass_num = 1
    asm.pc = 0
    for line in lines:
        # handle .org for pc
        s = line.split(';')[0].strip()
        if s.lower().startswith('.org'):
            asm.directive(s)
        else:
            asm.assemble_line(line)
    # pass 2: generate code
    asm.pass_num = 2
    asm.pc = 0
    asm.code = bytearray()
    for line in lines:
        s = line.split(';')[0].strip()
        if s.lower().startswith('.org'):
            asm.directive(s)
        else:
            asm.assemble_line(line)
    return bytes(asm.code), asm.labels

if __name__ == '__main__':
    with open(sys.argv[1]) as f:
        src = f.read()
    code, labels = assemble(src)
    with open(sys.argv[2], 'wb') as f:
        f.write(code)
    print(f"Assembled {len(code)} bytes")
