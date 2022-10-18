import PGRV::*;
import CSRFile::*;
import GPRFile::*;
import PipelineRegisters::*;

`define ENABLE_SPEW

interface WritebackStage;
    method ActionValue#(WB_OUT) writeback(MEM_WB mem_wb, GPRWritePort gprWritePort, CSRWritePort csrWritePort);
endinterface

module mkWritebackStage(WritebackStage);
    method ActionValue#(WB_OUT) writeback(MEM_WB mem_wb, GPRWritePort gprWritePort, CSRWritePort csrWritePort);
        let opcode = mem_wb.common.ir[6:0];
        let rd_    = mem_wb.common.ir[11:7];
        let csr_   = mem_wb.common.ir[31:20];

        match { .rd, .gprValue, .csr, .csrValue } = case (opcode) matches
            'b0010111: begin    // AUIPC
                return tuple4(rd_, mem_wb.aluOutput, 0, 0);
            end
            'b1110011: begin    // CSR
                return tuple4(rd_, mem_wb.aluOutput, csr_, mem_wb.lmd);
            end
            'b0000011: begin    // LOAD
                return tuple4(rd_, mem_wb.lmd, 0, 0);
            end
            'b0?10011: begin    // ALU
                return tuple4(rd_, mem_wb.aluOutput, 0, 0);
            end
            'b1100111: begin    // JALR
                return tuple4(rd_, mem_wb.aluOutput, 0, 0);
            end
            default: begin
                return tuple4(0, 0, 0, 0);
            end
        endcase;

`ifdef ENABLE_SPEW
        $display("WB: GPR Writing $%0x -> x%0d", gprValue, rd);
        $display("WB: CSR Writing $%0x -> x%0d", csrValue, csr);
`endif
        gprWritePort.write(rd, gprValue);
        csrWritePort.write(csr, csrValue);

        return WB_OUT {
            common: mem_wb.common,
            csrWritebackValue: csrValue,
            gprWritebackValue: gprValue
        };
    endmethod
endmodule
