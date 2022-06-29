import PGRV::*;
import CPU::*;
import InstructionLogger::*;
import MemoryIO::*;
import PipelineRegisters::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;

interface SimpleMemorySystem;
    interface Put#(Word) putCycleNumber;

    interface ReadOnlyMemoryServer#(XLEN, 32) instructionMemoryServer;
//    interface ReadWriteMemoryServer#(XLEN, XLEN) dataMemoryServer;
endinterface

module mkSimpleIMemorySystem#(Word programMemory[], Word instructionCount)(SimpleMemorySystem);
    RWire#(FallibleMemoryResponse#(32)) memoryResponse <- mkRWire;
    Wire#(Word) cycleNumber <- mkWire;

    interface Put putCycleNumber = toPut(asIfc(cycleNumber));

    interface ReadOnlyMemoryServer instructionMemoryServer;
        interface Put request;
            method Action put(ReadOnlyMemoryRequest#(XLEN, 32) memoryRequest);
                $display("Cycle        : %0d", cycleNumber);
                $display("IMEM received: ", fshow(memoryRequest));

                let wordIndex = memoryRequest.address >> 2;
                if (wordIndex < instructionCount) begin
                    memoryResponse.wset(FallibleMemoryResponse {
                        data: programMemory[wordIndex],
                        denied: False
                    });
                end else begin
                    memoryResponse.wset(FallibleMemoryResponse {
                        data: 'hCCCC_CCCC,
                        denied: True
                    });
                    $fatal();
                end
            endmethod
        endinterface
        interface Get response = toGet(memoryResponse);
    endinterface
endmodule

(* synthesize *)
module mkCPU_tb(Empty);
    // Device under test (DUT)
    CPU dut <- mkCPU(0);

    // Instruction Log
    InstructionLog log <- mkInstructionLog;
    rule logRetiredInstruction;
        let maybeRetiredInstruction <- dut.getRetiredInstruction.get;
        if (maybeRetiredInstruction matches tagged Valid .retiredInstruction) begin
            log.logInstruction(
                retiredInstruction.programCounter,
                retiredInstruction.instruction);
        end
    endrule

    // Cycle counter
    Reg#(Bit#(XLEN)) cycle <- mkReg(0);

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
    //   18:	fe9ff06f          	j	18 <_boot>
    //
    let instructionCount = 12;
    Word32 programMemory[instructionCount] = {
        'h00a00093,
        'h01400113,
        'h01e00493,
        'h002081b3,
        'h00919463,
        'h0000006f,
        'hfe9ff06f,

        'hdeadbeef,
        'hdeadbeef,
        'hdeadbeef,
        'hdeadbeef,
        'hdeadbeef
    };
    
    // PipelineState pipelineStates[3] = {
    //     PipelineState {
    //         pc: 'h0000_0000,
    //         if_id:  defaultValue,
    //         id_ex:  defaultValue,
    //         ex_mem: defaultValue,
    //         mem_wb: defaultValue,
    //         wb_out: defaultValue
    //     },
    //     PipelineState {
    //         pc: 'h0000_0000,
    //         if_id:  defaultValue,
    //         id_ex:  defaultValue,
    //         ex_mem: defaultValue,
    //         mem_wb: defaultValue,
    //         wb_out: defaultValue
    //     },
    //     PipelineState {
    //         pc: 'h0000_0000,
    //         if_id:  IF_ID { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000004 },
    //         id_ex:  ID_EX { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000004, a: 'h00000000, b: 'h00000000, imm: 'h0000000a },
    //         ex_mem: EX_MEM { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h0000000a, b: 'h00000000, cond: False },
    //         mem_wb: MEM_WB { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h0000000a, lmd: 'h00000000 },
    //         wb_out: defaultValue
    //     }
    // };

    //
    // Simulated instruction memory server
    //
    SimpleMemorySystem memorySystem <- mkSimpleIMemorySystem(programMemory, instructionCount);
    mkConnection(dut.instructionMemoryClient, memorySystem.instructionMemoryServer);
    mkConnection(toGet(cycle), toPut(asIfc(memorySystem.putCycleNumber)));

    //
    // Simulated data memory server
    //
    FIFO#(MemoryRequest#(XLEN, XLEN))     dataMemoryRequests <- mkFIFO;
    RWire#(FallibleMemoryResponse#(XLEN)) dataMemoryResponse <- mkRWire;
    Reg#(Bit#(2)) dataMemoryLatencyCounter <- mkReg(~0);
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
                    data: zeroExtend(programMemory[wordIndex]),
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

    rule test(dut.getState == READY);
        $display("-----------------------------");
        $display("Cycle   : %0d", cycle);

        let pipelineState <- dut.getPipelineState.get;

        $display("Testing cycle %0d", cycle);
        $display("Pipeline State: ", fshow(pipelineState));
        // $display("Expected State: ", fshow(pipelineStates[cycle]));
        // dynamicAssert(pipelineState == pipelineStates[cycle], "Pipeline state mismatch");

        // Step the DUT
        dut.step;

        if (cycle > 20) begin
            $display("    PASS");
            $finish();
        end

        cycle <= cycle + 1;
    endrule
endmodule
