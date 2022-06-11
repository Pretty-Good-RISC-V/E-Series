import PGRV::*;
import CPU::*;
import MemoryIO::*;
import ProgramMemory::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;

(* synthesize *)
module mkCPU_tb(Empty);
    // Device under test (DUT)
    CPU dut <- mkCPU('h8000_0000);

    // Cycle counter
    Reg#(Bit#(XLEN)) cycle <- mkReg(0);    
    rule cycleCounter;
        cycle <= cycle + 1;
    endrule

    //
    // Simulated instruction memory server
    //
    FIFO#(ReadOnlyMemoryRequest#(XLEN, 32)) instructionMemoryRequests <- mkFIFO;
    RWire#(FallibleMemoryResponse#(32))     instructionMemoryResponse <- mkRWire;
    Reg#(Bit#(2)) instructionMemoryLatencyCounter <- mkReg(~0);
    mkConnection(dut.instructionMemoryClient, toGPServer(instructionMemoryRequests, instructionMemoryResponse));

    rule instructionMemoryRequest;
        if (instructionMemoryLatencyCounter > 0) begin
            let memoryRequest = instructionMemoryRequests.first();
            $display("---------------");
            $display("Cycle : %0d", cycle);
            $display("IMemory request received: ", fshow(memoryRequest));
            $display("IMemory delay cycles remaining: ", instructionMemoryLatencyCounter);
        end else begin
            let memoryRequest <- pop(instructionMemoryRequests);

            $display("---------------");
            $display("Cycle : %0d", cycle);
            $display("IMemory latency expired - responding to memory request: ", fshow(memoryRequest));

            instructionMemoryResponse.wset(FallibleMemoryResponse {
                data: memoryRequest.address,
                denied: False
            });
        end

        instructionMemoryLatencyCounter <= instructionMemoryLatencyCounter - 1;
    endrule

    //
    // Simulated data memory server
    //
    FIFO#(MemoryRequest#(XLEN, XLEN))     dataMemoryRequests <- mkFIFO;
    RWire#(FallibleMemoryResponse#(XLEN)) dataMemoryResponse <- mkRWire;
    Reg#(Bit#(3)) dataMemoryLatencyCounter <- mkReg(~0);
    mkConnection(dut.dataMemoryClient, toGPServer(dataMemoryRequests, dataMemoryResponse));

    rule handleDataMemoryRequest;
        if (dataMemoryLatencyCounter > 0) begin
            let memoryRequest = dataMemoryRequests.first();
            $display("---------------");
            $display("Cycle : %0d", cycle);
            $display("DMemory request received: ", fshow(memoryRequest));
            $display("DMemory delay cycles remaining: ", dataMemoryLatencyCounter);
        end else begin
            let memoryRequest <- pop(dataMemoryRequests);

            $display("---------------");
            $display("Cycle : %0d", cycle);
            $display("DMemory latency expired - responding to memory request: ", fshow(memoryRequest));

            dataMemoryResponse.wset(FallibleMemoryResponse {
                data: memoryRequest.address,
                denied: False
            });
        end

        dataMemoryLatencyCounter <= dataMemoryLatencyCounter - 1;
    endrule

    rule test;
        if (cycle > 20) begin
            $display("    PASS");
            $finish();
        end
    endrule
endmodule
