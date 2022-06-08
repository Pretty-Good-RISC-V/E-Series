import PGRV::*;

import DefaultValue::*;

//
// PipelineRegisterCommon
//
typedef struct {
    Word32 instruction;
    Word programCounter;
    Bool isBubble;

    Maybe#(RVExceptionCause) exceptionCause;
} PipelineRegisterCommon deriving(Bits, Eq, FShow);

instance DefaultValue #(PipelineRegisterCommon);
    defaultValue = PipelineRegisterCommon { 
        instruction: 32'b0000000_00000_00000_000_00000_0110011, // ADD x0, x0, x0
        programCounter: 'hc0dec0de,
        isBubble: True,
        exceptionCause: tagged Invalid
    };
endinstance

//
// IF_ID
//
typedef struct {
    PipelineRegisterCommon common;
    Word nextProgramCounter;
} IF_ID deriving(Bits, Eq, FShow);

instance DefaultValue #(IF_ID);
    defaultValue = IF_ID {
        common: defaultValue,
        nextProgramCounter: 'hbeefbeef
    };
endinstance

//
// ID_EX
//
typedef struct {
    PipelineRegisterCommon common;
    Word nextProgramCounter;
    Word a;
    Word b;
    Word immediate;
} ID_EX deriving(Bits, Eq, FShow);

instance DefaultValue #(ID_EX);
    defaultValue = ID_EX {
        common: defaultValue,
        nextProgramCounter: 'hbeefbeef,
        a: 0,
        b: 0,
        immediate: 0
    };
endinstance

//
// EX_MEM
//
typedef struct {
    PipelineRegisterCommon common;
    Word aluOutput;
    Word b;
    Bool branchTaken;
} EX_MEM deriving(Bits, Eq, FShow);

instance DefaultValue #(EX_MEM);
    defaultValue = EX_MEM {
        common: defaultValue,
        aluOutput: 0,
        b: 0,
        branchTaken: False
    };
endinstance

//
// MEM_WB
//
typedef struct {
    PipelineRegisterCommon common;
    Word aluOutput;
    Word loadResult;
} MEM_WB deriving(Bits, Eq, FShow);

instance DefaultValue #(MEM_WB);
    defaultValue = MEM_WB {
        common: defaultValue,
        aluOutput: 0,
        loadResult: 0
    };
endinstance
