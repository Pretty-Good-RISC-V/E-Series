import PGRV::*;
import CPU::*;
import MemoryIO::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;

(* synthesize *)
module mkCPU_tb(Empty);
    // Device under test (DUT)
    CPU dut <- mkCPU(0);

    // Cycle counter
    Reg#(Bit#(XLEN)) cycle <- mkReg(0);    
    rule cycleCounter;
        cycle <= cycle + 1;
    endrule

    //
    // Program Memory
    // https://riscvasm.lucasteske.dev/#
    //
    // 0000000000000000 <_boot>:
    //    0:	00a00093          	li	ra,10
    //    4:	01400113          	li	sp,20
    //    8:	01e00493          	li	s1,30
    //    c:	002081b3          	add	gp,ra,sp
    //   10:	00919463          	bne	gp,s1,18 <_fail>
    //
    // 0000000000000014 <_pass>:
    //   14:	0000006f          	j	14 <_pass>
    //
    // 0000000000000018 <_fail>:
    //   18:	fe9ff06f          	j	0 <_boot>
    //
    let instructionCount = 7;
    Word32 programMemory[instructionCount] = {
        'h00a00093,
        'h01400113,
        'h01e00493,
        'h002081b3,
        'h00919463,
        'h0000006f,
        'hfe9ff06f
    };
    //
    // Simulated instruction memory server
    //
    FIFO#(ReadOnlyMemoryRequest#(XLEN, 32)) instructionMemoryRequests <- mkFIFO;
    RWire#(FallibleMemoryResponse#(32))     instructionMemoryResponse <- mkRWire;
    Reg#(Bit#(0)) instructionMemoryLatencyCounter <- mkReg(~0);
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

            let wordIndex = memoryRequest.address >> 2;
            if (wordIndex < instructionCount) begin
                instructionMemoryResponse.wset(FallibleMemoryResponse {
                    data: programMemory[wordIndex],
                    denied: False
                });
            end else begin
                instructionMemoryResponse.wset(FallibleMemoryResponse {
                    data: 'hCCCC_CCCC,
                    denied: True
                });
                $display("Exitting on invalid instruction memory access: $%0x", memoryRequest.address);
                $fatal();
            end
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

            let wordIndex = memoryRequest.address >> 2;
            if (wordIndex < instructionCount) begin
                dataMemoryResponse.wset(FallibleMemoryResponse {
                    data: programMemory[wordIndex],
                    denied: False
                });
            end else begin
                dataMemoryResponse.wset(FallibleMemoryResponse {
                    data: 'hCCCC_CCCC,
                    denied: True
                });
                $display("Exitting on invalid data memory access: $%0x", memoryRequest.address);
                $fatal();
            end
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
