import PGRV::*;
import ALU::*;
import BranchUnit::*;
import PipelineRegisters::*;
import Trap::*;

import GetPut::*;

interface ExecuteStage;
    method ActionValue#(EX_MEM) execute(ID_EX id_ex, Bit#(1) epoch);
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

    method ActionValue#(EX_MEM) execute(ID_EX id_ex, Bit#(1) epoch);
        let func7  = id_ex.common.ir[31:25];
        let func3  = id_ex.common.ir[14:12];
        let opcode = id_ex.common.ir[6:0];

        Int#(XLEN) signedImmediate = unpack(id_ex.imm);

        $display("EXECUTE: PC=$%0x", id_ex.common.pc);
        $display("EXECUTE: Opcode: b%0b", opcode);

        // ALU
        let isALU           = (opcode matches 'b0?10011 ? True : False);
        let aluIsImmediate  = ~opcode[5];
        let aluOperation    = {1'b0, func7, func3};
        let aluResult      <- alu.calculate(aluOperation, id_ex.a, (unpack(aluIsImmediate) ? id_ex.imm : id_ex.b));
        if (isALU) begin
            $display("EXECUTE: ALU - A: $%0x, B: $%0x", id_ex.a, (unpack(aluIsImmediate) ? id_ex.imm : id_ex.b));
        end

        // Branching
        let isBranch        = (opcode == 'b1100011);
        let branchResult   <- bru.isTaken(func3, id_ex.a, id_ex.b);
        let branchTarget    = unpack(id_ex.common.pc) + signedImmediate;
        if (isBranch) begin
            $display("EXECUTE: BRANCH - A: $%0x, B: $%0x", id_ex.a, id_ex.b);
            $display("EXECUTE: BRANCH RESULT: ", fshow(branchResult));
        end

        // Jumping
        let isJump          = (opcode == 'b1101111);                 // JAL
        let isJumpRelative  = (opcode == 'b1100111) && (func3 == 0); // JALR
        let jumpTarget      = (isJumpRelative ? ((unpack(id_ex.a) + signedImmediate) & ~1) : unpack(id_ex.common.pc) + signedImmediate);
        let jumpLink        = unpack(id_ex.common.pc) + 4;
        if (isJump) begin
            $display("EXECUTE: JAL ($%0x)", jumpTarget);
        end

        if (isJumpRelative) begin
            $display("EXECUTE: JALR ($%0x)", jumpTarget);
        end

        // Load/Store
        let isLoadStore     = (opcode matches 'b0?00011 ? True : False);
        let isStore         = unpack(opcode[5]);
        let loadStoreValid  = isLoadStoreValid(func3, isStore);
        let loadStoreTarget = unpack(id_ex.a) + signedImmediate;
        if (isLoadStore) begin
            if (isStore) begin
                $display("EXECUTE: STORE");
            end else begin
                $display("EXECUTE: LOAD");
            end
        end

        let isUnknownOpcode = !(isALU || isBranch || isJump || isJumpRelative || isLoadStore);
        let isIllegal       = (isALU && aluResult.illegalOperation) ||
                              (isBranch && branchResult.illegalOperation) ||
                              (isLoadStore && !loadStoreValid) ||
                              isUnknownOpcode;

        $display("EXECUTE: Unknown Opcode: ", fshow(isUnknownOpcode));
        $display("EXECUTE: Illegal Opcode: ", fshow(isIllegal));

        if (id_ex.epoch != epoch) begin
            $display("Execute stage epoch mismatch - inserting bubble");
            return defaultValue;
        end else begin
            // If an exception is passed in, forward it - otherwise indicate if
            // the current instruction is illegal.
            Maybe#(Trap) trap = id_ex.common.trap;
            if (!isValid(trap)) begin
                trap = (isIllegal ? tagged Valid Trap {
                    cause: exception_ILLEGAL_INSTRUCTION,
                    isInterrupt: False
                } : tagged Invalid);
            end

            let aluOutput = (isALU    ? aluResult.result : 
                            (isBranch ? pack(branchTarget) : 
                            (isJump   ? pack(jumpTarget) : 
                            pack(loadStoreTarget))));

            let branchTaken = (isIllegal      ? False :
                              (isBranch       ? branchResult.taken : 
                              (isJump         ? True :
                              (isJumpRelative ? True :
                              False))));

            return EX_MEM {
                common: PipelineRegisterCommon {
                    ir:         id_ex.common.ir,
                    pc:         id_ex.common.pc,
                    isBubble:   id_ex.common.isBubble,
                    trap:       trap
                },
                aluOutput: aluOutput,
                b: id_ex.b,
                cond: branchTaken
            };
        end
    endmethod
endmodule
