import PGRV::*;
import MemoryIO::*;
import PipelineRegisters::*;

import Assert::*;
import ClientServer::*;
import GetPut::*;
import Memory::*;

interface MemoryStage;
    method ActionValue#(MEM_WB) memory(EX_MEM ex_mem);
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
    Reg#(Maybe#(FallibleMemoryResponse#(XLEN))) memoryResponse     <- mkReg(tagged Invalid);

    method ActionValue#(MEM_WB) memory(EX_MEM ex_mem);
        let mem_wb = MEM_WB {
            common:     ex_mem.common,
            aluOutput:  ex_mem.aluOutput,
            lmd:        0
        };

        let opcode          = ex_mem.common.ir[6:0];
        let isLoadStore     = (opcode matches 'b0?00011 ? True : False);
        let isStore         = unpack(opcode[5]);

        if (state == WAITING_FOR_MEMORY_RESPONSE) begin
            // Request is in flight
            dynamicAssert(isLoadStore, "");
        end else if (!isValid(ex_mem.common.trap) && isLoadStore) begin
        end

        return mem_wb;
    endmethod

    method Bool isStalled;
        return (state == WAITING_FOR_MEMORY_RESPONSE);
    endmethod

    interface ReadWriteMemoryClient dataMemoryClient = toGPClient(dataMemoryRequest, dataMemoryResponse);
endmodule
