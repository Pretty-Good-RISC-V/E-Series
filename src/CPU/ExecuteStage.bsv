import PGRV::*;
import ALU::*;
import BranchUnit::*;
import PipelineRegisters::*;

interface ExecuteStage;
    method ActionValue#(EX_MEM) execute(ID_EX id_ex);
endinterface

module mkExecuteStage(ExecuteStage);
    ALU        alu <- mkALU;
    BranchUnit bru <- mkBranchUnit;

    function Bool isLoadStoreValid(Bit#(3) func3, Bool isStore);
        if (isStore) begin
            return func3 < 'b11;
        end else begin
            return (func3 != 'b11 && func3 != 'b110 && func3 != 'b111);
        end
    endfunction

    method ActionValue#(EX_MEM) execute(ID_EX id_ex);
        let func7  = id_ex.common.instruction[31:25];
        let func3  = id_ex.common.instruction[14:12];
        let opcode = id_ex.common.instruction[6:0];

        Int#(XLEN) signedImmediate = unpack(id_ex.immediate);

        // ALU
        let isALU           = (opcode matches 'b0?10011 ? True : False);
        let aluIsImmediate  = opcode[5];
        let aluOperation    = {1'b0, func7, func3};
        let aluResult      <- alu.calculate(aluOperation, id_ex.a, (unpack(aluIsImmediate) ? id_ex.immediate : id_ex.b));

        // Branching
        let isBranch        = (opcode == 'b1100011);
        let branchResult   <- bru.calculate(func3, id_ex.a, id_ex.b);
        let branchTarget    = unpack(id_ex.nextProgramCounter) + signedImmediate;

        // Load/Store
        let isLoadStore     = (opcode matches 'b0?00011 ? True : False);
        let isStore         = unpack(opcode[5]);
        let loadStoreValid  = isLoadStoreValid(func3, isStore);
        let loadStoreTarget = unpack(id_ex.a) + signedImmediate;

        let isUnknownOpcode = !(isALU || isBranch || isLoadStore);
        let isIllegal       = (isALU && aluResult.illegalOperation) ||
                              (isBranch && branchResult.illegalOperation) ||
                              (isLoadStore && !loadStoreValid) ||
                              isUnknownOpcode;

        // If an exception is passed in, forward it - otherwise indicate if
        // the current instruction is illegal.
        Maybe#(RVExceptionCause) exceptionCause = id_ex.common.exceptionCause;
        if (!isValid(exceptionCause)) begin
            exceptionCause = (isIllegal ? tagged Invalid : tagged Valid exception_ILLEGAL_INSTRUCTION);
        end

        return EX_MEM {
            common: PipelineRegisterCommon {
                instruction: id_ex.common.instruction,
                programCounter: id_ex.common.programCounter,
                isBubble: id_ex.common.isBubble,
                exceptionCause: exceptionCause
            },
            aluOutput: (isALU ? aluResult.result : (isBranch ? pack(branchTarget) : pack(loadStoreTarget))),
            b: id_ex.b,
            branchTaken: (isBranch ? branchResult.taken : False)
        };
    endmethod
endmodule
