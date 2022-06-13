import PGRV::*;
import FetchStage::*;
import MemoryIO::*;
import PipelineRegisters::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;


(* synthesize *)
module mkFetchStage_tb(Empty);
    // Device under test (DUT)
    FetchStage dut <- mkFetchStage;

    // Cycle counter
    Reg#(Bit#(XLEN)) cycle    <- mkReg(0);    
    rule cycleCounter;
        cycle <= cycle + 1;
    endrule

    //
    // Simulated instruction memory server
    //
    FIFO#(ReadOnlyMemoryRequest#(XLEN, 32)) memoryRequests <- mkFIFO;
    RWire#(FallibleMemoryResponse#(32))     memoryResponse <- mkRWire;
    Reg#(Bit#(2)) memoryLatencyCounter <- mkReg(~0);

    mkConnection(dut.instructionMemoryClient, toGPServer(memoryRequests, memoryResponse));

    rule handleMemoryRequest;
        if (memoryLatencyCounter > 0) begin
            let memoryRequest = memoryRequests.first();
            $display("---------------");
            $display("Cycle : %0d", cycle);
            $display("Memory request received: ", fshow(memoryRequest));
            $display("Memory delay cycles remaining: ", memoryLatencyCounter);
        end else begin
            let memoryRequest <- pop(memoryRequests);

            $display("---------------");
            $display("Cycle : %0d", cycle);
            $display("Memory latency expired - responding to memory request: ", fshow(memoryRequest));

            memoryResponse.wset(FallibleMemoryResponse {
                data: memoryRequest.address,
                denied: False
            });
        end

        memoryLatencyCounter <= memoryLatencyCounter - 1;
    endrule

    Reg#(ProgramCounter) programCounter <- mkReg('h8000_0000);
    Reg#(EX_MEM) ex_mem <- mkReg(defaultValue);

    rule test;
        $display("--------------");
        $display("Cycle : %0d", cycle);
        let if_id <- dut.fetch(programCounter, ex_mem);
        $display("IF_ID : ", fshow(if_id));

        if (cycle > 20) begin
            $display("    PASS");
            $finish();
        end
    endrule
endmodule
