import PGRV::*;
import Trap::*;

import DefaultValue::*;

//
// PipelineRegisterCommon
//
typedef struct {
    Word32       ir;
    Word         pc;
    Bool         isBubble;
    Maybe#(Trap) trap;
} PipelineRegisterCommon deriving(Bits, Eq, FShow);

instance DefaultValue #(PipelineRegisterCommon);
    defaultValue = PipelineRegisterCommon { 
        ir:         32'b0000000_00000_00000_000_00000_0110011, // ADD x0, x0, x0
        pc:         'hf000c0de,
        isBubble:   True,
        trap:       tagged Invalid
    };
endinstance

//
// IF_ID
//
typedef struct {
    PipelineRegisterCommon common;
    Bit#(1)                epoch;
    Word                   npc;     // Next program counter
} IF_ID deriving(Bits, Eq, FShow);

instance DefaultValue #(IF_ID);
    defaultValue = IF_ID {
        common: defaultValue,
        epoch:  0,
        npc:    'hbeefbeef
    };
endinstance

//
// ID_EX
//
typedef struct {
    PipelineRegisterCommon common;
    Bit#(1)                epoch;
    Word                   npc;     // Next program counter
    Word                   a;       // Operand 1
    Word                   b;       // Operand 2
    Bool                   isBValid;// In the case of a CSR, this will indicate if 'b' is valid 
    Word                   imm;     // Sign extended immediate
} ID_EX deriving(Bits, Eq, FShow);

instance DefaultValue #(ID_EX);
    defaultValue = ID_EX {
        common:   defaultValue,
        epoch:    0,
        npc:      'hbeefbeef,
        a:        0,
        b:        0,
        isBValid: False,
        imm:      0
    };
endinstance

//
// EX_MEM
//
typedef struct {
    PipelineRegisterCommon common;
    Word                   aluOutput;
    Word                   b;           // Store value
    Bool                   cond;        // Branch taken?
} EX_MEM deriving(Bits, Eq, FShow);

instance DefaultValue #(EX_MEM);
    defaultValue = EX_MEM {
        common:     defaultValue,
        aluOutput:  0,
        b:          0,
        cond:       False
    };
endinstance

//
// MEM_WB
//
typedef struct {
    PipelineRegisterCommon common;
    Word                   aluOutput;
    Word                   lmd;         // Load result
} MEM_WB deriving(Bits, Eq, FShow);

instance DefaultValue #(MEM_WB);
    defaultValue = MEM_WB {
        common:     defaultValue,
        aluOutput:  0,
        lmd:        0
    };
endinstance

//
// WB_OUT
//
typedef struct {
    PipelineRegisterCommon common;
    Word csrWritebackValue;
    Word gprWritebackValue;
} WB_OUT deriving(Bits, Eq, FShow);

instance DefaultValue#(WB_OUT);
    defaultValue = WB_OUT {
        common:            defaultValue,
        gprWritebackValue: 0,
        csrWritebackValue: 0
    };
endinstance