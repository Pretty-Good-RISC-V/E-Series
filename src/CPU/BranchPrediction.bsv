import PGRV::*;

import PipelineRegisters::*;

interface BranchPredictor;
    method ProgramCounter nextProgramCounter(PipelineRegisterCommon prc);
endinterface

module mkSimpleBranchPredictor(BranchPredictor);
    method ProgramCounter nextProgramCounter(PipelineRegisterCommon prc);
        let opcode = prc.ir[6:0];
        return case(opcode)
            'b1100011: begin    // BRANCH
                // Predict taken
                Int#(XLEN) offset = unpack(extend({
                    prc.ir[31],
                    prc.ir[7],
                    prc.ir[30:25],
                    prc.ir[11:8],
                    1'b0
                }));

                if (offset <= 0) begin
                    return pack(unpack(prc.pc) + offset);
                end else begin
                    return prc.pc + 4;
                end
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
