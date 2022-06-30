import PGRV::*;
import GPRFile::*;
import PipelineRegisters::*;

`undef ENABLE_SPEW

interface WritebackStage;
    method ActionValue#(WB_OUT) writeback(MEM_WB mem_wb, GPRWritePort gprWritePort);
endinterface

module mkWritebackStage(WritebackStage);
    method ActionValue#(WB_OUT) writeback(MEM_WB mem_wb, GPRWritePort gprWritePort);
        let opcode = mem_wb.common.ir[6:0];
        let rd_    = mem_wb.common.ir[11:7];

        match { .rd, .value } = case (opcode) matches
            'b0000011: begin    // LOAD
                return tuple2(rd_, mem_wb.lmd);
            end
            'b0?10011: begin    // ALU
                return tuple2(rd_, mem_wb.aluOutput);
            end
            'b1100111: begin    // JALR
                return tuple2(rd_, mem_wb.aluOutput);
            end
            default: begin
                return tuple2(0, 0);
            end
        endcase;

`ifdef ENABLE_SPEW
        $display("WB: Writing $%0x -> x%0d", value, rd);
`endif
        gprWritePort.write(rd, value);

        return WB_OUT {
            common: mem_wb.common,
            writebackValue: value
        };
    endmethod
endmodule
