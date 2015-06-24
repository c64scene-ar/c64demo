#!/usr/bin/env python
# 
# Copyright (c) 2015 C64 Demo Project
# 
from sys import argv, exit
from collections import namedtuple
from re import compile, DOTALL, MULTILINE
from fileinput import input

__description__ = "Instruction timing for MOS 6502"
__version__ = "0.1"

# Representation of the different timings for a specific instruction.
TimedInstruction = namedtuple(
    "TimedInstruction", [
        "accumulator",              # 1
        "implicit",                 # 2
        "immediate",                # 3
        "absolute",                 # 4
        "zero_page",                # 5
        "relative",                 # 6
        "absolute_x",               # 7
        "absolute_y",               # 8
        "zero_page_idx_x",          # 9
        "zero_page_idx_y",          # 10
        "zero_page_idx_indirect_x", # 11
        "zero_page_idx_indirect_y"  # 12
        ])
        

INSTRUCTIONS = {
    "adc" : TimedInstruction(None, None, 2, 4, 3, None, 4, 4, 4, None, 6, 5),   #  A <- (A) + M + C
    "anc" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- A /\ M, C <- ~A7
    "and" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) /\ M
    "ane" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <-[(A)\/$EE] /\ (X)/\(M)
    "arr" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- [(A /\ M) >> 1]
    "asl" : TimedInstruction(2, None, None, 6, 5, None, 7, None, 6, None, None, None),   #  C <- A7, A <- (A) << 1
    "asr" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- [(A /\ M) >> 1]
    "bcc" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if C=0, PC = PC + offset
    "bcs" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if C=1, PC = PC + offset
    "beq" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if Z=1, PC = PC + offset
    "bit" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Z <- ~(A /\ M) N<-M7 V<-M6
    "bmi" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if N=1, PC = PC + offset
    "bne" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if Z=0, PC = PC + offset
    "bpl" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if N=0, PC = PC + offset
    "brk" : TimedInstruction(None, 7, None, None, None, None, None, None, None, None, None, None),   #  Stack <- PC, PC <- ($fffe)
    "bvc" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if V=0, PC = PC + offset
    "bvs" : TimedInstruction(None, None, None, None, None, 2, None, None, None, None, None, None),   #  if V=1, PC = PC + offset
    "clc" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  C <- 0
    "cld" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  D <- 0
    "cli" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  I <- 0
    "clv" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  V <- 0
    "cmp" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  (A - M) -> NZC
    "cpx" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  (X - M) -> NZC
    "cpy" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  (Y - M) -> NZC
    "dcp" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M)-1, (A-M) -> NZC
    "dec" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M) - 1
    "dex" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  X <- (X) - 1
    "dey" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  Y <- (Y) - 1
    "eor" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) \-/ M
    "inc" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M) + 1
    "inx" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  X <- (X) +1
    "iny" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  Y <- (Y) + 1
    "isb" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M) - 1,A <- (A)-M-~C
    "jmp" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  PC <- Address
    "jmpi" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  (PC <- Address)
    "jsr" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Stack <- PC, PC <- Address
    "lae" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X,S,A <- (S /\ M)
    "lax" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- M, X <- M
    "lda" : TimedInstruction(None, None, 2, 4, 3, None, 4, 4, 4, None, 6, 5),   #  A <- M
    "ldx" : TimedInstruction(None, None, 2, 4, 3, None, None, 4, None, None, None, None),   #  X <- M
    "ldy" : TimedInstruction(None, None, 2, 4, 3, None, 4, None, 4, None, None, None),   #  Y <- M
    "lsr" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C <- A0, A <- (A) >> 1
    "lxa" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X04 <- (X04) /\ M04, A04 <- (A04) /\ M04
    "nop" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  [no operation]
    "ora" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) V M
    "pha" : TimedInstruction(None, 3, None, None, None, None, None, None, None, None, None, None),   #  Stack <- (A)
    "php" : TimedInstruction(None, 3, None, None, None, None, None, None, None, None, None, None),   #  Stack <- (P)
    "pla" : TimedInstruction(None, 4, None, None, None, None, None, None, None, None, None, None),   #  A <- (Stack)
    "plp" : TimedInstruction(None, 4, None, None, None, None, None, None, None, None, None, None),   #  A <- (Stack)
    "rla" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M << 1) /\ (A)
    "rol" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C <- A7 & A <- A << 1 + C
    "ror" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C<-A0 & A<- (A7=C + A>>1)
    "rra" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M >> 1) + (A) + C
    "rti" : TimedInstruction(None, 6, None, None, None, None, None, None, None, None, None, None),   #  P <- (Stack), PC <-(Stack)
    "rts" : TimedInstruction(None, 6, None, None, None, None, None, None, None, None, None, None),   #  PC <- (Stack)
    "sax" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (A) /\ (X)
    "sbc" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) - M - ~C
    "sbx" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (X)/\(A) - M
    "sec" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  C <- 1
    "sed" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  D <- 1
    "sei" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  I <- 1
    "sha" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (A) /\ (X) /\ (PCH+1)
    "shs" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (A) /\ (X), S <- (X), M <- (X) /\ (PCH+1)
    "shx" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (X) /\ (PCH+1)
    "shy" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (Y) /\ (PCH+1)
    "slo" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M >> 1) + A + C
    "sre" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M >> 1) \-/ A
    "sta" : TimedInstruction(None, None, None, 4, 3, None, 5, 5, 4, None, 6, 6),   #  M <- (A)
    "stx" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (X)
    "sty" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (Y)
    "tax" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  X <- (A)
    "tay" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  Y <- (A)
    "tsx" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  X <- (S)
    "txa" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  A <- (X)
    "txs" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  S <- (X)
    "tya" : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  A <- (Y)
    "bbr0" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 0 reset
    "bbr1" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 1 reset
    "bbr2" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 2 reset
    "bbr3" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 3 reset
    "bbr4" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 4 reset
    "bbr5" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 5 reset
    "bbr6" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 6 reset
    "bbr7" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 7 reset
    "bbs0" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 0 set
    "bbs1" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 1 set
    "bbs2" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 2 set
    "bbs3" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 3 set
    "bbs4" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 4 set
    "bbs5" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 5 set
    "bbs6" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 6 set
    "bbs7" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 7 set
    "rmb0" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 0
    "rmb1" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 1
    "rmb2" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 2
    "rmb3" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 3
    "rmb4" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 4
    "rmb5" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 5
    "rmb6" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 6
    "rmb7" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 7
    "smb0" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 0
    "smb1" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 1
    "smb2" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 2
    "smb3" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 3
    "smb4" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 4
    "smb5" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 5
    "smb6" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 6
    "smb7" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 7
    "stz" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Store zero
    "tsb" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Test and set bits
    "trb" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Test and reset bits
    "phy" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Push Y register
    "ply" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Pull Y register
    "phx" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Push X register
    "plx" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Pull X register
    "bra" : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Branch always
    }

MODE_ACCUMULATOR = 0
MODE_IMPLICIT = 1
MODE_IMMEDIATE = 2
MODE_ABSOLUTE = 3
MODE_ZERO_PAGE = 4
MODE_RELATIVE = 5
MODE_ABOLUTE_INDEXED_X = 6
MODE_ABOLUTE_INDEXED_Y = 7
MODE_ZERO_PAGE_INDEXED_X = 8
MODE_ZERO_PAGE_INDEXED_Y = 9
MODE_ZERO_PAGE_INDEXED_INDIRECT_X = 10
MODE_ZERO_PAGE_INDEXED_INDIRECT_Y = 11

ACCUMULATOR_INSTRUCSTIONS = ["asl", "lsr", "rol", "ror"]
IMPLICIT_INSTRUCTIONS = [
    "brk", "nop", "rti", "rts txs", "tsx",
    "pha", "pla", "php", "plp", "clc", "sec", "cli", "sei", "clv", "cld", "sed",
    "tax", "txa", "dex", "inx", "tay", "tya", "dey", "iny"]
RELATIVE_INSTRUCTIONS = [
    "bpl", "bmi", "bvc", "bvs", "bcc", "bcs", "bne", "beq"]

immediate_re = compile("\#\$\w+", DOTALL) # Immediate

absolute_re = compile("\$\w+", DOTALL) # Absolute

zero_page_re = compile("\$\w+,[X]", DOTALL) # Zero page

relative_re = compile("\*\w+,[X]", DOTALL) # Relative

absolute_idx_x_re = compile("\$\w+,[X]", DOTALL) # Absolute Indexed X
absolute_idx_y_re = compile("\$\w+,[Y]", DOTALL) # Absolute Indexed Y
zero_page_idx_x_re = compile("\w+,[X]", DOTALL) # Zero Page Indexed X
zero_page_idx_y_re = compile("\w+,[Y]", DOTALL) # Zero Page Indexed Y
zero_page_idx_ind_x_re = compile("\(\$\w+,[X]\)", DOTALL) # Zero Page Indexed Indirect X
zero_page_idx_ind_y_re = compile("\(\$\w+\),[Y]", DOTALL) # Zero Page Indexed Indirect Y


class DecodedInstructionException(Exception):
    pass


class DecodedInstruction(object):
    """Simple assembly decoded instruction for further manipulation."""

    def __init__(self, asm):
        asm_splitted = asm.split()
        self.mnem = asm_splitted[0].lower()
        if len(asm_splitted) > 1:
            self.operand_str = asm_splitted[1]
        else:
            self.operand_str = ""

        self._set_operand_info()

    def _set_operand_info(self):
        """Set operand type and other related information."""
        #
        # Type 1. Accumulator
        #
        if len(self.operand_str) == 0 and self.mnem in ACCUMULATOR_INSTRUCSTIONS:
            self.mode = MODE_ACCUMULATOR

        #
        # Type 2. Implicit
        #
        elif len(self.operand_str) == 0 and self.mnem in IMPLICIT_INSTRUCTIONS:
            self.mode = MODE_IMPLICIT

        #
        # Type 3. Immediate
        #
        elif immediate_re.match(self.operand_str):
            self.mode = MODE_IMMEDIATE

        #
        # Type 5. Relative
        #
        elif len(self.operand_str) > 0 and self.mnem in RELATIVE_INSTRUCTIONS:
            self.mode = MODE_RELATIVE

        #
        # Type 6. Zero Page
        #
        elif len(self.operand_str) > 0 and self.operand_str.startswith("zp_"):
            self.mode = MODE_ZERO_PAGE

        elif len(self.operand_str.split(",")) == 2:
            #
            # Type 6. Absolute Indexed X
            #
            if absolute_idx_x_re.match(self.operand_str):
                self.mode = MODE_ABOLUTE_INDEXED_X

            #
            # Type 7. Absolute Indexed Y
            #
            elif absolute_idx_y_re.match(self.operand_str):
                self.mode = MODE_ABOLUTE_INDEXED_Y

            #
            # Type 8. Zero Page Indexed X
            #
            elif zero_page_idx_x_re.match(self.operand_str):
                self.mode = MODE_ZERO_PAGE_INDEXED_X

            #
            # Type 9. Zero Page Indexed Y
            #
            elif zero_page_idx_y_re.match(self.operand_str):
                self.mode = MODE_ZERO_PAGE_INDEXED_Y

            #
            # Type 11. Zero Page Indexed Indirect X
            #
            elif zero_page_idx_ind_x_re.match(self.operand_str):
                self.mode = MODE_ZERO_PAGE_INDEXED_INDIRECT_X

            #
            # Type 12. Zero Page Indexed Indirect Y
            #
            elif zero_page_idx_ind_y_re.match(self.operand_str):
                self.mode = MODE_ZERO_PAGE_INDEXED_INDIRECT_Y

            else:
                raise DecodedInstructionException("Invalid indexed instruction operand %s" % self.operand_str)

        #
        # Type 4. Absolute
        #
        elif len(self.operand_str) > 0:
            self.mode = MODE_ABSOLUTE

        else:
            raise DecodedInstructionException("Invalid operand %s" % self.operand_str)

    @property
    def mode(self):
        """String representing the instruciton mode."""
        return self._mode

    @mode.setter
    def mode(self, mode):
        """Store string represention of the instruciton mode."""
        self._mode = mode

    @property
    def mnem(self):
        """String representing the instruciton mnemonic."""
        return self._mnem

    @mnem.setter
    def mnem(self, mnem):
        """Store string represention of the instruciton mnemonic."""
        self._mnem = mnem

    @property
    def operand_str(self):
        """String representing the instruciton operand_str."""
        return self._operand_str

    @operand_str.setter
    def operand_str(self, operand_str):
        """Store string represention of the instruciton operand_str."""
        self._operand_str = operand_str

    @property
    def operand_type(self):
        """String representing the instruciton operand."""
        return self._operand_type

    @operand_type.setter
    def operand_type(self, operand_type):
        """Store string represention of the instruciton operand."""
        self._operand_type = operand_type


class MOS6502TimmingException(Exception):
    """Default exception for MOS 6502 timing class."""
    pass


class MOS6502Timming(object):
    """Instructions timing for processor MOS 6502."""

    def __init__(self):
        pass

    def time_assembly(self, asm):
        """Split the assembly lines specified and time each one."""
        # Remove comments.
        re_comments_1 = compile("/\*.*?\*/", DOTALL | MULTILINE)
        re_comments_2 = compile("//.*")
        re_comments_3 = compile(";.*")
        replaced = re_comments_1.sub("", asm)
        replaced = re_comments_2.sub("", replaced)
        replaced = re_comments_3.sub("", replaced)

        # Whith the code clean of comments we proceed to parse instructions and determine their cycles count.
        time_list = list()
        for line in replaced.splitlines():
            if len(line.strip()) > 0:
                time_list.append(self.time_instruction(line.strip()))

        return time_list

    def time_instruction(self, asm):
        """Return the timing for the instruction at the specified address."""
        # Parse the assembly line containing the instruciton being timed and split it for a meaningful usage.
        if len(asm.strip()) == 0:
            raise MOS6502TimmingException("No assembly specified.")

        try:
            decoded_inst = DecodedInstruction(asm)
        except DecodedInstructionException, err:
            raise MOS6502TimmingException("Unable to decode instruction '%s'" % asm)

        # Make sure that we know the instruction being timed.
        if decoded_inst.mnem not in INSTRUCTIONS:
            raise MOS6502TimmingException("Unknown instruction %s" % decoded_inst.mnem)

        # Obtain the instruction timing information, determine the addressing mode and return its timing value.
        inst = INSTRUCTIONS[decoded_inst.mnem]
        cycles = None

        if decoded_inst.mode == MODE_ACCUMULATOR:
            if inst.accumulator is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Accumulator' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.accumulator

        elif decoded_inst.mode == MODE_IMPLICIT:
            if inst.implicit is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Implicit' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.implicit

        elif decoded_inst.mode == MODE_IMMEDIATE:
            if inst.immediate is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Immediate' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.immediate

        elif decoded_inst.mode == MODE_ABSOLUTE:
            if inst.absolute is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Absolute' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.absolute

        elif decoded_inst.mode == MODE_ZERO_PAGE:
            if inst.zero_page is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Zero Page' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.zero_page

        elif decoded_inst.mode == MODE_RELATIVE:
            if inst.relative is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Relative' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.relative

        elif decoded_inst.mode == MODE_ABOLUTE_INDEXED_X:
            if inst.absolute_x is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Absolute Indexed X' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.absolute_x

        elif decoded_inst.mode == MODE_ABOLUTE_INDEXED_Y:
            if inst.absolute_y is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Absolute Indexed Y' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.absolute_y

        elif decoded_inst.mode == MODE_ZERO_PAGE_INDEXED_X:
            if inst.zero_page_idx_x is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Zero Page Indexed X' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.zero_page_idx_x

        elif decoded_inst.mode == MODE_ZERO_PAGE_INDEXED_Y:
            if inst.zero_page_idx_y is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Zero Page Indexed Y' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.zero_page_idx_y

        elif decoded_inst.mode == MODE_ZERO_PAGE_INDEXED_INDIRECT_X:
            if inst.zero_page_idx_indirect_x is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Zero Page Indexed indirect X' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.zero_page_idx_indirect_x

        elif decoded_inst.mode == MODE_ZERO_PAGE_INDEXED_INDIRECT_Y:
            if inst.zero_page_idx_indirect_y is None:
                raise MOS6502TimmingException(
                    "Addressing mode 'Zero Page Indexed Indexed Y' not available for instruction '%s'" % decoded_inst.mnem)
            cycles = inst.zero_page_idx_indirect_y

        if not cycles:
            raise MOS6502TimmingException(
                "Unknown operand type (%d): %s" % (
                decoded_inst.operand_type, decoded_inst.operand_str))

        return (decoded_inst, cycles)

def usage():
    """Display help."""
    print "Usage : cat my_demo.asm | %s" % argv[0]
    print ""

def main():
    print "%s v%s\n" % (__description__, __version__)

    try:
        if len(argv) == 2 and argv[1] in ["-h", "--help"]:
            usage()
            return

        # Initialize the timing instance.
        tim = MOS6502Timming()

        asm = ""

        for line in input():
            asm += line

        #asm = """
        #        ASL                     ; accumulator
        #        TXA                     ; implicit
        #        LDA     #$1BF ; '"'     ; immediate hex
        #        LDA     #%101 ; '"'     ; immediate binary
        #        LDA     #567 ; '"'      ; immediate octal
        #        /*
        #        dsadssdf
        #        */
        #        // dsdsds
        #        LDX     $D010           ; absolute num
        #        LDX     my_label        ; absolute label
        #        LDY     loc_2           ; zero page (1 byte)
        #        BPL     loc_1A8         ; relative
        #        BPL     *+1             ; relative
        #        BPL     *-1             ; relative
        #        /* dasdasdas */
        #        ADC     $307A,X         ; Absolute Indexed with X
        #        ADC     $307A,Y         ; Absolute Indexed with Y
        #        LDA     1,X             ; Zero Page Indexed with X
        #        //LDA     1,Y             ; N/D
        #        STA     ($15,X)         ; Zero Page Indexed Indirect X
        #        LDA     ($15),Y         ; Zero Page Indexed Indirect Y
        #        """

        print "[+] Performing instruction timing count..."
        cycles = tim.time_assembly(asm)

        if cycles is not None:
            for idx, (inst, inst_cycles) in enumerate(cycles):
                print "    %02d. %4s : %d" % (idx, inst.mnem, inst_cycles)
            print "[+] Cycles : %d" % sum([i_cycles for i, i_cycles in cycles])
        else:
            print "[+] No cycles information available."

    except MOS6502TimmingException, err:
        print "[-] Exception : %s" % err

if __name__ == "__main__":
    main()
