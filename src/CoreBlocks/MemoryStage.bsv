import PGRV::*;
import MemoryIO::*;
import PipelineRegisters::*;
import Trap::*;

import Assert::*;
import ClientServer::*;
import GetPut::*;
import Memory::*;

`define ENABLE_SPEW

interface MemoryStage;
    method ActionValue#(MEM_WB) accessMemory(EX_MEM ex_mem);
    method Bool isStalled;

    interface ReadWriteMemoryClient#(XLEN, XLEN) dataMemoryClient;
endinterface

typedef enum {
    WAITING_FOR_MEMORY_REQUEST,
    WAITING_FOR_MEMORY_RESPONSE
} MemoryStageState deriving(Bits, Eq, FShow);

module mkMemoryStage(MemoryStage);
    RWire#(MemoryRequest#(XLEN, XLEN))          dataMemoryRequest  <- mkRWire;
    RWire#(FallibleMemoryResponse#(XLEN))       dataMemoryResponse <- mkRWire;
    Reg#(MemoryStageState)                      state              <- mkReg(WAITING_FOR_MEMORY_REQUEST);

    function Bit#(TDiv#(XLEN,8)) getByteEnable(Bit#(3) func3);
        return case(func3[1:0])
            'b00: return 'b0001;
            'b01: return 'b0011;
            'b10: return 'b1111;
`ifdef RV64
            'b11: return 'b1111_1111;
`endif
        endcase;
    endfunction

    method ActionValue#(MEM_WB) accessMemory(EX_MEM ex_mem);
        let mem_wb = MEM_WB {
            common:     ex_mem.common,
            aluOutput:  ex_mem.aluOutput,
            lmd:        0
        };

        let opcode          = ex_mem.common.ir[6:0];
        let isLoadStore     = (opcode matches 7'b0?00011 ? True : False);
        let isStore         = unpack(opcode[5]);
        let func3           = ex_mem.common.ir[14:12];

`ifdef ENABLE_SPEW
        $display("MEMORY: isLoadStore: ", fshow(isLoadStore));
`endif

        if (state == WAITING_FOR_MEMORY_RESPONSE) begin
            // Request is in flight
            dynamicAssert(isLoadStore, "");
            if (dataMemoryResponse.wget matches tagged Valid .response) begin
                if (response.denied) begin
                    mem_wb.common.trap = tagged Valid Trap {
                        cause: (isStore ? exception_STORE_ACCESS_FAULT : exception_LOAD_ACCESS_FAULT),
                        isInterrupt: False,
                        tval: ex_mem.aluOutput
                    };
                end else if (!isStore) begin
                    mem_wb.lmd = response.data;
                end
                state <= WAITING_FOR_MEMORY_REQUEST;
            end else begin
`ifdef ENABLE_SPEW
                $display("MEMORY: Waiting for memory response...");
`endif
                mem_wb = defaultValue;
            end
        end else if (!isValid(ex_mem.common.trap) && isLoadStore) begin
            let memoryRequest = MemoryRequest {
                address: ex_mem.aluOutput,
                data: ex_mem.b,
                byteen: getByteEnable(func3),
                write: isStore
            };

`ifdef ENABLE_SPEW
            $display("MEMORY: Sending request: ", fshow(memoryRequest));
`endif

            dataMemoryRequest.wset(memoryRequest);
            state <= WAITING_FOR_MEMORY_RESPONSE;
            mem_wb = defaultValue;
        end

        return mem_wb;
    endmethod

    method Bool isStalled;
        return (state == WAITING_FOR_MEMORY_RESPONSE);
    endmethod

    interface ReadWriteMemoryClient dataMemoryClient = toGPClient(dataMemoryRequest, dataMemoryResponse);
endmodule
