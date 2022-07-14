import PGRV::*;
import ALU::*;
import BranchUnit::*;
import CSRFile::*;
import PipelineRegisters::*;
import Trap::*;

import GetPut::*;

`undef ENABLE_SPEW

interface ExecuteStage;
    method ActionValue#(EX_MEM) execute(ID_EX id_ex, Maybe#(Word) a_forward, Maybe#(Word) b_forward, Bit#(1) epoch, CSRWritePermission csrWritePermission);
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

    method ActionValue#(EX_MEM) execute(ID_EX id_ex, Maybe#(Word) a_forward, Maybe#(Word) b_forward, Bit#(1) epoch, CSRWritePermission csrWritePermission);
        let func7  = id_ex.common.ir[31:25];
        let func3  = id_ex.common.ir[14:12];
        let opcode = id_ex.common.ir[6:0];

        let a = fromMaybe(id_ex.a, a_forward);
        let b = fromMaybe(id_ex.b, b_forward);

        Int#(XLEN) signedImmediate = unpack(id_ex.imm);

`ifdef ENABLE_SPEW
        $display("EXECUTE: PC=$%0x", id_ex.common.pc);
        $display("EXECUTE: Opcode: b%0b", opcode);
`endif

        Word aluOutput = ?;
        Bool cond      = False;

        let aluOperation     = {1'b0, func7, func3};
        let branchTaken      = False;
        let illegalOperation = True;
        let csr              = id_ex.common.ir[31:20];
        let isCSRImmediate   = unpack(id_ex.common.ir[14]);

        // Check if instruction epoch matches the pipline epoch.  If not,
        // the instruction stream for this instruction is stale.
        if (id_ex.epoch != epoch) begin
            // Instruction stream is stale, return bubble.
            return defaultValue;
        end else begin
            // Check for a trap in the incoming instruction.  If one does
            // *not* exist, execute the instruction.
            Maybe#(Trap) trap = id_ex.common.trap;
            if (isValid(trap) == False) begin

                // Execute the instruction
                case(id_ex.common.ir) matches
                    // ALU
                    'b????????????_?????_???_?????_0?10011: begin
                        let aluIsImmediate  = ~opcode[5];
                        let aluResult      <- alu.calculate(aluOperation, a, (unpack(aluIsImmediate) ? id_ex.imm : b));

`ifdef ENABLE_SPEW
                        $display("EXECUTE: ALU - A: $%0x, B: $%0x", a, (unpack(aluIsImmediate) ? id_ex.imm : b));
`endif

                        aluOutput           = aluResult.result;
                        illegalOperation    = aluResult.illegalOperation;
                    end

                    // Branch
                    'b????????????_?????_???_?????_1100011: begin
                        let branchTarget    = unpack(id_ex.common.pc) + signedImmediate;
                        let branchResult   <- bru.isTaken(func3, a, b);

`ifdef ENABLE_SPEW
                        $display("EXECUTE: BRANCH - OP: %0b, $%0x, B: $%0x", func3, a, b);
                        $display("EXECUTE: BRANCH RESULT: ", fshow(branchResult));
`endif

                        aluOutput           = pack(branchTarget);
                        branchTaken         = branchResult.taken;
                        illegalOperation    = branchResult.illegalOperation;
                    end

                    // Jumps
                    'b????????????_?????_???_?????_110?111: begin
                        let isJumpRelative  = (opcode == 'b1100111) && (func3 == 0); // JALR
                        let jumpTarget      = (isJumpRelative ? ((unpack(a) + signedImmediate) & ~1) : unpack(id_ex.common.pc) + signedImmediate);
                        let jumpLink        = unpack(id_ex.common.pc) + 4;

`ifdef ENABLE_SPEW
                        if (isJumpRelative) begin
                            $display("EXECUTE: JALR ($%0x)", jumpTarget);
                        end else begin
                            $display("EXECUTE: JAL ($%0x)", jumpTarget);
                        end
`endif

                        aluOutput           = pack(jumpTarget);
                        branchTaken         = True;
                        illegalOperation    = False;
                    end

                    // Load/Store
                    'b????????????_?????_???_?????_0?00011: begin
                        let isStore         = unpack(opcode[5]);
                        let loadStoreValid  = isLoadStoreValid(func3, isStore);
                        let loadStoreTarget = unpack(a) + signedImmediate;

`ifdef ENABLE_SPEW
                        if (isStore) begin
                            $display("EXECUTE: STORE");
                        end else begin
                            $display("EXECUTE: LOAD");
                        end
`endif

                        aluOutput           = pack(loadStoreTarget);
                        illegalOperation    = !loadStoreValid;
                    end

                    // System (ECALL)
                    'b000000000000_00000_000_00000_1110011: begin
                        trap = tagged Valid Trap {
                            // NOTE: for ECALL, the code specified below is for M mode -
                            //       the handling of the exception will translate it
                            //       to the call proper for the mode of the processor.
                            cause: (exception_ENVIRONMENT_CALL_FROM_M_MODE),
                            isInterrupt: False
                        };
                        illegalOperation    = False;
                    end

                    // System (EBREAK)
                    'b000000000001_00000_000_00000_1110011: begin
                        trap = tagged Valid Trap {
                            cause: exception_BREAKPOINT,
                            isInterrupt: False
                        };                
                    end

                    // System (CSRRW/CSRRWI)
                    'b????????????_?????_?01_?????_1110011: begin
                        aluOutput = (isCSRImmediate ? id_ex.imm : id_ex.b); // GPRWriteback
                        b = id_ex.a;                                        // CSRWriteback

                        if (!csrWritePermission.isWriteable(csr)) begin
                            illegalOperation = True;
                        end
                    end

                    // System (CSRRS/CSRRSI)
                    'b????????????_?????_?10_?????_1110011: begin
                        aluOutput = (isCSRImmediate ? id_ex.imm : id_ex.b); // GPRWriteback
                        b = id_ex.a | aluOutput;                            // CSRWriteback

                        if (!csrWritePermission.isWriteable(csr)) begin
                            illegalOperation = True;
                        end
                    end

                    // System (CSRRC/CSRRCI)
                    'b????????????_?????_?11_?????_1110011: begin
                        aluOutput = (isCSRImmediate ? id_ex.imm : id_ex.b); // GPRWriteback
                        b = ~id_ex.a & aluOutput;                           // CSRWriteback

                        if (!csrWritePermission.isWriteable(csr)) begin
                            illegalOperation = True;
                        end
                    end
                endcase

                if (illegalOperation) begin
                    trap = tagged Valid Trap {
                        cause: exception_ILLEGAL_INSTRUCTION,
                        isInterrupt: False
                    };               
                end
            end

            return EX_MEM {
                common: PipelineRegisterCommon {
                    ir:         id_ex.common.ir,
                    pc:         id_ex.common.pc,
                    isBubble:   id_ex.common.isBubble,
                    trap:       trap
                },
                aluOutput: aluOutput,
                b: b,
                cond: branchTaken
            };
        end
    endmethod
endmodule
