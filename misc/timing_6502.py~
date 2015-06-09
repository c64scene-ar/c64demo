#!/usr/bin/env python
# 
# Copyright (c) 2015 C64 Demo Project
# 
from sys import argv, exit
from collections import namedtuple
from re import compile, DOTALL

try:
    from idaapi import *
    from idautils import *
    from idc import *
except ImportError, err:
    print "This script runs under IDA Python!"
    exit(1)

__description__ = "Instruction timing for MOS 6502"
__version__ = "0.1"

# Representation of the different timings for a specific instruction.
TimedInstruction = namedtuple(
    "TimedInstruction", [
        "accumulator",              # 1
        "implied",                  # 2
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
    M65_adc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) + M + C
    M65_anc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- A /\ M, C <- ~A7
    M65_and : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) /\ M
    M65_ane : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <-[(A)\/$EE] /\ (X)/\(M)
    M65_arr : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- [(A /\ M) >> 1]
    M65_asl : TimedInstruction(2, None, None, 6, 5, None, 7, None, 6, None, None, None),   #  C <- A7, A <- (A) << 1
    M65_asr : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- [(A /\ M) >> 1]
    M65_bcc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if C=0, PC = PC + offset
    M65_bcs : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if C=1, PC = PC + offset
    M65_beq : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if Z=1, PC = PC + offset
    M65_bit : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Z <- ~(A /\ M) N<-M7 V<-M6
    M65_bmi : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if N=1, PC = PC + offset
    M65_bne : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if Z=0, PC = PC + offset
    M65_bpl : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if N=0, PC = PC + offset
    M65_brk : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Stack <- PC, PC <- ($fffe)
    M65_bvc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if V=0, PC = PC + offset
    M65_bvs : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  if V=1, PC = PC + offset
    M65_clc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C <- 0
    M65_cld : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  D <- 0
    M65_cli : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  I <- 0
    M65_clv : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  V <- 0
    M65_cmp : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  (A - M) -> NZC
    M65_cpx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  (X - M) -> NZC
    M65_cpy : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  (Y - M) -> NZC
    M65_dcp : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M)-1, (A-M) -> NZC
    M65_dec : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M) - 1
    M65_dex : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (X) - 1
    M65_dey : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Y <- (Y) - 1
    M65_eor : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) \-/ M
    M65_inc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M) + 1
    M65_inx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (X) +1
    M65_iny : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Y <- (Y) + 1
    M65_isb : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M) - 1,A <- (A)-M-~C
    M65_jmp : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  PC <- Address
    M65_jmpi : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  (PC <- Address)
    M65_jsr : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Stack <- PC, PC <- Address
    M65_lae : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X,S,A <- (S /\ M)
    M65_lax : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- M, X <- M
    M65_lda : TimedInstruction(None, None, 2, 4, 3, None, 4, 4, 4, None, 6, 5),   #  A <- M
    M65_ldx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- M
    M65_ldy : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Y <- M
    M65_lsr : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C <- A0, A <- (A) >> 1
    M65_lxa : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X04 <- (X04) /\ M04, A04 <- (A04) /\ M04
    M65_nop : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  [no operation]
    M65_ora : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) V M
    M65_pha : TimedInstruction(None, 3, None, None, None, None, None, None, None, None, None, None),   #  Stack <- (A)
    M65_php : TimedInstruction(None, 3, None, None, None, None, None, None, None, None, None, None),   #  Stack <- (P)
    M65_pla : TimedInstruction(None, 4, None, None, None, None, None, None, None, None, None, None),   #  A <- (Stack)
    M65_plp : TimedInstruction(None, 4, None, None, None, None, None, None, None, None, None, None),   #  A <- (Stack)
    M65_rla : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M << 1) /\ (A)
    M65_rol : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C <- A7 & A <- A << 1 + C
    M65_ror : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C<-A0 & A<- (A7=C + A>>1)
    M65_rra : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M >> 1) + (A) + C
    M65_rti : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  P <- (Stack), PC <-(Stack)
    M65_rts : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  PC <- (Stack)
    M65_sax : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (A) /\ (X)
    M65_sbc : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (A) - M - ~C
    M65_sbx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (X)/\(A) - M
    M65_sec : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  C <- 1
    M65_sed : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  D <- 1
    M65_sei : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  I <- 1
    M65_sha : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (A) /\ (X) /\ (PCH+1)
    M65_shs : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (A) /\ (X), S <- (X), M <- (X) /\ (PCH+1)
    M65_shx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (X) /\ (PCH+1)
    M65_shy : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (Y) /\ (PCH+1)
    M65_slo : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M >> 1) + A + C
    M65_sre : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (M >> 1) \-/ A
    M65_sta : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (A)
    M65_stx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (X)
    M65_sty : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  M <- (Y)
    M65_tax : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  X <- (A)
    M65_tay : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Y <- (A)
    M65_tsx : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  X <- (S)
    M65_txa : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (X)
    M65_txs : TimedInstruction(None, 2, None, None, None, None, None, None, None, None, None, None),   #  S <- (X)
    M65_tya : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  A <- (Y)
    M65_bbr0 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 0 reset
    M65_bbr1 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 1 reset
    M65_bbr2 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 2 reset
    M65_bbr3 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 3 reset
    M65_bbr4 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 4 reset
    M65_bbr5 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 5 reset
    M65_bbr6 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 6 reset
    M65_bbr7 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 7 reset
    M65_bbs0 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 0 set
    M65_bbs1 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 1 set
    M65_bbs2 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 2 set
    M65_bbs3 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 3 set
    M65_bbs4 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 4 set
    M65_bbs5 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 5 set
    M65_bbs6 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 6 set
    M65_bbs7 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Branch if bit 7 set
    M65_rmb0 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 0
    M65_rmb1 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 1
    M65_rmb2 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 2
    M65_rmb3 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 3
    M65_rmb4 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 4
    M65_rmb5 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 5
    M65_rmb6 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 6
    M65_rmb7 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Reset memory bit 7
    M65_smb0 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 0
    M65_smb1 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 1
    M65_smb2 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 2
    M65_smb3 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 3
    M65_smb4 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 4
    M65_smb5 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 5
    M65_smb6 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 6
    M65_smb7 : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),  #  Set memory bit 7
    M65_stz : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Store zero
    M65_tsb : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Test and set bits
    M65_trb : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Test and reset bits
    M65_phy : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Push Y register
    M65_ply : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Pull Y register
    M65_phx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Push X register
    M65_plx : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Pull X register
    M65_bra : TimedInstruction(None, None, None, None, None, None, None, None, None, None, None, None),   #  Branch always
    }


class MOS6502TimmingException(Exception):
    """Default exception for MOS 6502 timing class."""
    pass


class MOS6502Timming(object):
    """Instructions timing for processor MOS 6502."""

    def __init__(self):
        if not self.__validate_environment():
            raise MOS6502TimmingException("Current architecture is not supported.")

        self.absolute_idx_x_re = compile("\$\w+,[X]", DOTALL) # Absolute Indexed X
        self.absolute_idx_y_re = compile("\$\w+,[Y]", DOTALL) # Absolute Indexed Y
        self.zero_page_idx_ind_x_re = compile("\(\$\w+,[X]\)", DOTALL) # Zero Page Indexed Indirect X
        self.zero_page_idx_ind_y_re = compile("\(\$\w+\),[Y]", DOTALL) # Zero Page Indexed Indirect Y
        self.zero_page_idx_x_re = compile("\$\w+,[X]", DOTALL) # Zero Page Indexed X
        self.zero_page_idx_y_re = compile("\$\w+,[Y]", DOTALL) # Zero Page Indexed Y

    def __validate_environment(self):
        """Validate that we're executing the script on the right architecture."""
        # Return the current architecture in use.
        # Add extra validation here.
        return get_idp_name() == "m65"

    def time_function(self, address):
        """Retuen the timing for the instruction in the function containing the specified address."""
        return 0

    def time_instruction(self, address):
        """Return the timing for the instruction at the specified address."""
        return self.__get_inst_time(address)

    def __get_inst_time(self, address):
        """Return the time for the instruction at the specified address."""
        # Fetch the instruction and then lookup the timing table for the timing.
        decoded_inst = DecodeInstruction(address)

        if not decoded_inst:
            raise MOS6502TimmingException("Unable to get decoded instruction at 0x%X" % address)

        # Make sure that we know the instruction being timed.
        if decoded_inst.itype not in INSTRUCTIONS:
            raise MOS6502TimmingException("Unknown instruction at 0x%X" % address)

        # Obtain the instruction timing information, determine the addressing mode and return its timing value.
        inst = INSTRUCTIONS[decoded_inst.itype]

        # Determine operand information from the operands at the current instruction.
        op = decoded_inst.Operands[0]
        str_op = GetOpnd(address, 0)

        if op is None:
            raise MOS6502TimmingException("No operand available.")

        #
        # Type 1. Accumulator
        #
        if op.type == o_reg:
            _type = "o_reg"
            value = hex(op.reg)

            if op.reg == 0: # A
                return inst.accumulator

        #
        # Type 2. Implicit
        #
        elif op.type == o_imm:
            _type = "o_imm"
            value = hex(op.value)

            return inst.immediate

        #
        # Type 3. Immediate
        #
        elif op.type == o_void:
            _type = "o_void"
            value = "-"

            return inst.implied

        #
        # Type 4. Absolute
        # Type 5. Relative
        #
        elif op.type in [o_mem, o_far, o_near]:
            _type = "o_mem"
            value = hex(op.addr)

            # TODO : Differentiate between absolute and zero page (size?)
            return inst.absolute

        #
        # Type 6. Absolute Indexed X
        # Type 7. Absolute Indexed Y
        # Type 8. Zero Page Indexed X
        # Type 9. Zero Page Indexed Y
        #
        # Type 11. Zero Page Indexed Indirect X
        # Type 12. Zero Page Indexed Indirect Y
        #
        elif op.type == o_displ:
            _type = "o_displ"
            value = "(0x%x)%x" % (op.addr, op.phrase)

            if self.absolute_idx_x_re.match(str_op):
                return inst.absolute_x

            elif self.absolute_idx_y_re.match(str_op):
                return inst.absolute_y

            elif self.zero_page_idx_ind_x_re.match(str_op):
                return inst.zero_page_idx_indirect_x

            elif self.zero_page_idx_ind_y_re.match(str_op):
                return inst.zero_page_idx_indirect_y

            elif self.zero_page_idx_x_re.match(str_op):
                return inst.zero_page_idx_x

            elif self.zero_page_idx_y_re.match(str_op):
                return inst.zero_page_idx_y

        elif op.type == o_phrase:
            _type = "o_phrase"
            value = hex(op.phrase)

        else:
            _type = "Unknown (%d)" % op.type
            value = op.value

        # Debug information.
        print "[+] Operand type:%s value:%s" % (_type, value)

        raise MOS6502TimmingException("Unknown operand type (%d) and value (%s) at 0x%X" % (
            op.type, op.value, address))

    def get_function_name(self, address):
        """Get the name of the function at the specified memory address."""
        name = get_func_name(address)

        if name is not None:
            return name

        raise MOS6502TimmingException(
            "Unable to obtain function name for address 0x%X" % address)

    def get_mnemonic(self, address):
        """Return the mnemonic for the specified instruction address."""
        try:
            return GetDisasm(address).split()[0]
        except IndexError, err:
            return None
        #return ua_mnem(inst_address)

def print_instructions():
    """Display instruction features for debugging purposes."""
    FEATURES_STR = {
        CF_STOP : "CF_STOP",
        CF_CALL : "CF_CALL",
        CF_CHG1 : "CF_CHG1",
        CF_CHG2 : "CF_CHG2",
        CF_CHG3 : "CF_CHG3",
        CF_CHG4 : "CF_CHG4",
        CF_CHG5 : "CF_CHG5",
        CF_CHG6 : "CF_CHG6",
        CF_USE1 : "CF_USE1",
        CF_USE2 : "CF_USE2",
        CF_USE3 : "CF_USE3",
        CF_USE4 : "CF_USE4",
        CF_USE5 : "CF_USE5",
        CF_USE6 : "CF_USE6",
        CF_JUMP : "CF_JUMP",
        CF_SHFT : "CF_SHFT",
        CF_HLL  : "CF_HLL"
        }

    for itype, inst in enumerate(ph_get_instruc()):
        # Display instruction information obtained form IDA internals.
        feature_str = ", ".join(
            [f_v for f_k, f_v in FEATURES_STR.iteritems() \
                if f_k & inst[1] == f_k])

        inst_str = "%-3d %+5s - fea: %5d %s" % (
            itype,
            inst[0],
            inst[1],
            feature_str)

        print inst_str

def usage(err=None):
    """Print usage information and error messages if appropriate."""
    if err:
        print "Error : %s" % err

    print "    -f <address>         Specify an address inside the function being timed."
    print "    -i <address>         Address of the instruction being timed."
    print "    -s <addr_start:end>  An specific address range being timed."
    print ""

def main(argv):
    print "%s v%s\n" % (__description__, __version__)

    try:
        # Initialize the timing instance.
        tim = MOS6502Timming()

        function_address = None
        instruction_address = None
        selection_addresses = None

        if len(argv) <= 1:
            usage()
            return
        elif len(argv) == 3:
            if argv[1] == "-f":
                pass
               
            elif argv[1] == "-i":
                #address = int(argv
                pass
        else:
            usage()
            return

        if function_address:
            print "[+] Timing function %s at 0x%X..." % (
                tim.get_function_name(function_address), function_address)

            cycles = tim.time_function(function_address)

        elif instruction_address:
            print "[+] Timing instruction %s at 0x%X..." % (
                    tim.get_mnemonic(instruction_address), instruction_address)

            cycles = tim.time_instruction(instruction_address)

        elif selection_addresses:
            print "[+] Timing selection between 0x%X - 0x%X..." % (
                    selection_addresses[0], selection_addresses[1])

            cycles = tim.time_range(selection_addresses)

        if cycles is not None:
            print "[+] Cycles : %d" % cycles
        else:
            print "[+] No cycles information available."

    except MOS6502TimmingException, err:
        print "[-] Exception : %s" % err

if __name__ == "__main__":
    #print_instructions()
    main(ARGV)
