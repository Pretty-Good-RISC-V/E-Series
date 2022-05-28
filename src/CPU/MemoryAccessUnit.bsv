//
// MemoryAccessUnit
//
// This module is responsible for handling RISC-V LOAD and STORE instructions.  It 
// accepts a 'ExecutedInstruction' structure and if the values contained therein have
// valid LoadRequest or StoreRequest structures, the requisite load and store operations
// are executed.
//
import PGRV::*;

import BypassUnit::*;
import EncodedInstruction::*;
import Exception::*;
import ExecutedInstruction::*;
import LoadStore::*;
import MemoryIO::*;
import PipelineController::*;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export MemoryAccessUnit(..), mkMemoryAccessUnit;

interface MemoryAccessUnit;
    interface Put#(Word64) putCycleCounter;

    interface Put#(ExecutedInstruction) putExecutedInstruction;
    interface Get#(ExecutedInstruction) getExecutedInstruction;

    interface ReadWriteMemoryClient#(XLEN, XLEN) dataMemoryClient;

    interface Get#(Maybe#(GPRBypassValue)) getGPRBypassValue;

`ifdef ENABLE_ISA_TESTS
    interface Put#(Maybe#(Word)) putToHostAddress;
`endif
endinterface

module mkMemoryAccessUnit#(
    Integer stageNumber,
    PipelineController pipelineController
)(MemoryAccessUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;

`ifdef ENABLE_ISA_TESTS
    Reg#(Maybe#(Word)) toHostAddress <- mkReg(tagged Invalid);
`endif
    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);

    Reg#(ExecutedInstruction) instructionWaitingForMemoryOperation <- mkRegU;
    FIFO#(MemoryRequest#(XLEN, XLEN)) dataMemoryRequests <- mkFIFO;
    FIFO#(FallibleMemoryResponse#(XLEN)) dataMemoryResponses <- mkFIFO;

    RWire#(Maybe#(GPRBypassValue)) gprBypassValue <- mkRWire();

    rule handleMemoryResponse(waitingForMemoryResponse == True);
        Bool verbose <- $test$plusargs ("verbose");
        let memoryResponse <- pop(dataMemoryResponses);
        let executedInstruction = instructionWaitingForMemoryOperation;
        waitingForMemoryResponse <= False;

        if (executedInstruction.storeRequest matches tagged Valid .storeRequest) begin
            let storeAddress = storeRequest.address;
            if (memoryResponse.denied) begin
                if (verbose)
                    $display("[****:****:memory] ERROR - Store returned access denied: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else begin
                if (verbose)
                    $display("[****:****:memory] Store completed");
            end
        end else if (executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
            let loadAddress = loadRequest.memoryRequest.address;
            Word value = ?;
            RVGPRIndex rd = 0; // Any exceptions below that also have writeback data will
                               // write to X0 on completion (instead of any existing RD in the
                               // instruction)

            if (memoryResponse.denied) begin
                if (verbose)
                    $display("[****]:****:memory] ERROR - Load returned access denied: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else begin
                if (verbose)
                    $display("[****:****:memory] Load completed");

                // Save the data that will be written back into the register file on the
                // writeback pipeline stage.
                rd = loadRequest.rd;

                case (loadRequest.memoryRequest.byteen)
                    'b1: begin    // 1 byte
                        if (loadRequest.signExtend)
                            value = signExtend(memoryResponse.data[7:0]);
                        else
                            value = zeroExtend(memoryResponse.data[7:0]);
                    end
                    'b11: begin    // 2 bytes
                        if (loadRequest.signExtend)
                            value = signExtend(memoryResponse.data[15:0]);
                        else
                            value = zeroExtend(memoryResponse.data[15:0]);
                    end
`ifdef RV32
                    'b1111: begin    // 4 bytes
                        value = memoryResponse.data;
                    end
`elsif RV64
                    'b1111: begin    // 4 bytes
                        if (loadRequest.signExtend)
                            value = signExtend(memoryResponse.data[31:0]);
                        else
                            value = zeroExtend(memoryResponse.data[31:0]);
                    end
                    'b1111_1111: begin    // 8 bytes
                        value = memoryResponse.data;
                    end
`endif
                endcase
                executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                    rd: rd,
                    value: value
                };
            end

            // Set the bypass to the value read.  Note: even if an exception 
            // was encountered, this still needs to be done otherwise other
            // stages will stall forever.
            gprBypassValue.wset(tagged Valid GPRBypassValue{
                rd: rd,
                value: tagged Valid value
            });
        end

        outputQueue.enq(executedInstruction);
    endrule

    interface Put putExecutedInstruction;
        method Action put(ExecutedInstruction executedInstruction) if (waitingForMemoryResponse == False);
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = executedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);
            if (!pipelineController.isCurrentEpoch(stageNumber, 1, executedInstruction.pipelineEpoch)) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0d,memory access,stale instruction (%0d != %0d)...propagating bubble", 
                        fetchIndex, 
                        cycleCounter, 
                        executedInstruction.pipelineEpoch, 
                        executedInstruction.programCounter, 
                        stageNumber, 
                        executedInstruction.pipelineEpoch, 
                        stageEpoch);
                outputQueue.enq(executedInstruction);
            end else begin
                if(executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,LOAD", 
                            fetchIndex, 
                            cycleCounter, 
                            stageEpoch, 
                            executedInstruction.programCounter, 
                            stageNumber);

                    // Set the bypass value but mark the value as invalid since
                    // the other side of the bypass has to wait for the load to complete.
                    gprBypassValue.wset(tagged Valid GPRBypassValue{
                        rd: loadRequest.rd,
                        value: tagged Invalid
                    });

                    // NOTE: Alignment checks were already performed during the execution stage.
                    dataMemoryRequests.enq(loadRequest.memoryRequest);

                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,Loading from $%08x with byteen: %d", 
                            fetchIndex, 
                            cycleCounter, 
                            stageEpoch, 
                            executedInstruction.programCounter, 
                            stageNumber, 
                            loadRequest.memoryRequest.address, 
                            loadRequest.memoryRequest.byteen);
                        instructionWaitingForMemoryOperation <= executedInstruction;
                    waitingForMemoryResponse <= True;
                end else if (executedInstruction.storeRequest matches tagged Valid .storeRequest) begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,Storing to $%0x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, storeRequest.address);
`ifdef ENABLE_ISA_TESTS
                    if (toHostAddress matches tagged Valid .tha &&& tha == storeRequest.address) begin
                        let test_num = (storeRequest.data >> 1);
                        if (test_num == 0) $display ("    PASS");
                        else               $display ("    FAIL <test_%0d>", test_num);

                        $finish();
                    end
`endif
                    dataMemoryRequests.enq(storeRequest);
                    instructionWaitingForMemoryOperation <= executedInstruction;
                    waitingForMemoryResponse <= True;
                end else begin
                    // Not a LOAD/STORE
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                    outputQueue.enq(executedInstruction);
                end
            end
        endmethod
    endinterface

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getExecutedInstruction = toGet(outputQueue);
    interface TileLinkLiteWordClient dataMemoryClient = toGPClient(dataMemoryRequests, dataMemoryResponses);
    interface Get getGPRBypassValue = toGet(gprBypassValue);
`ifdef ENABLE_ISA_TESTS
    interface Put putToHostAddress = toPut(asIfc(toHostAddress));
`endif
endmodule
