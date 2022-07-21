import PGRV::*;

import PipelineRegisters::*;

interface BranchPredictor;
    method ProgramCounter nextProgramCounter(PipelineRegisterCommon prc);
endinterface

module mkSimpleBranchPredictor(BranchPredictor);
    method ProgramCounter nextProgramCounter(PipelineRegisterCommon prc);
        let opcode = prc.ir[6:0];
        Word immediate = signExtend({
            prc.ir[31],        // 1 bit
            prc.ir[7],         // 1 bit
            prc.ir[30:25],     // 6 bits
            prc.ir[11:8],      // 4 bits
            1'b0                    // 1 bit
        });

        return case(opcode)
            'b1100011: begin    // BRANCH
                let branchPrediction = ?;
                if (prc.ir[31] == 1) begin
                    Int#(XLEN) offset = unpack(immediate);
                    branchPrediction = pack(unpack(prc.pc) + offset);
                end else begin
`ifdef EXT_C
                    branchPrediction = (prc.ir[1:0] == 'b11 ? prc.pc + 4 : prc.pc + 2);
`else
                    branchPrediction = prc.pc + 4;
`endif
                end

                return branchPrediction;
            end
            default: begin
`ifdef EXT_C
                return (prc.ir[1:0] == 'b11 ? prc.pc + 4 : prc.pc + 2);
`else
                return prc.pc + 4;
`endif
            end
        endcase;
    endmethod
endmodule
