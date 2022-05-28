//
// FetchUnit
//
// This module is a RISC-V instruction fetch unit.  It is responsible for fetching instructions 
// from memory and creating a EncodedInstruction structure representing them.
//
`include "PGLib.bsh"

import BranchPredictor::*;
import EncodedInstruction::*;
import Exception::*;
import MemoryIO::*;
import PipelineController::*;
import ProgramCounterRedirect::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;
import Memory::*;
import SpecialFIFOs::*;

export mkFetchUnit, FetchUnit(..);

typedef struct {
    PipelineEpoch epoch;
    Word address;
    Word index;     // The fetch index
} FetchInfo deriving(Bits, Eq, FShow);

interface FetchUnit;
    interface Put#(Word64) putCycleCounter;
    interface Get#(EncodedInstruction) getEncodedInstruction;

    interface ReadOnlyMemoryClient#(XLEN, 32) instructionMemoryClient;
    interface Put#(Bool) putFetchEnabled;
endinterface

module mkFetchUnit#(
    Integer stageNumber,
    Reg#(ProgramCounter) programCounter,
    ProgramCounterRedirect programCounterRedirect
)(FetchUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire();

    Reg#(Bool) fetchEnabled <- mkReg(False);
    Reg#(Word) fetchCounter <- mkReg(0);
    Reg#(PipelineEpoch) currentEpoch <- mkReg(0);
    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);

    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO; // holds the fetch info for the current instruction request

    FIFO#(ReadOnlyMemoryRequest#(XLEN, 32)) instructionMemoryRequests <- mkFIFO;
    FIFO#(FallibleMemoryResponse#(32)) instructionMemoryResponses <- mkFIFO;

    FIFO#(EncodedInstruction) outputQueue <- mkPipelineFIFO;

`ifdef DISABLE_BRANCH_PREDICTOR
    BranchPredictor branchPredictor <- mkNullBranchPredictor;
`else
    BranchPredictor branchPredictor <- mkBackwardBranchTakenPredictor;
`endif

    (* fire_when_enabled *)
    rule sendFetchRequest(fetchEnabled == True && !waitingForMemoryResponse);
        Bool verbose <- $test$plusargs ("verbose");

        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // program counter redirect has a value, move that into the program counter and
        // increment the epoch.
        let fetchProgramCounter = programCounter;
        let fetchEpoch = currentEpoch;
        let redirectedProgramCounter <- programCounterRedirect.getRedirectedProgramCounter;

        if (redirectedProgramCounter matches tagged Valid .rpc) begin 
            fetchProgramCounter = rpc;

            fetchEpoch = fetchEpoch + 1;
            currentEpoch <= fetchEpoch;

            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch send,redirected PC: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);
        end

        if (verbose)
            $display("%0d,%0d,%0d,%0x,%0d,fetch send,fetch address: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);

        instructionMemoryRequests.enq(ReadOnlyMemoryRequest {
            byteen: 'b1111,
            address: fetchProgramCounter
        });

        fetchInfoQueue.enq(FetchInfo {
            epoch: fetchEpoch,
            address: fetchProgramCounter,
            index: fetchCounter
        });

        waitingForMemoryResponse <= True;
        fetchCounter <= fetchCounter + 1;
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse(waitingForMemoryResponse);
        Bool verbose <- $test$plusargs ("verbose");
        let fetchResponse <- pop(instructionMemoryResponses);
        let fetchInfo <- pop(fetchInfoQueue);
        Maybe#(Exception) exception = tagged Invalid;

        if (fetchResponse.denied) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received access denied from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber);
`ifdef ENABLE_RISCOF_TESTS
            if (fetchInfo.address == 'hc0dec0de)
                exception = tagged Valid createRISCOFTestHaltException(fetchInfo.address);
            else
`endif
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,encoded instruction=%08h", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, fetchResponse.data);
        end

        // Predict what the next program counter will be
        let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(fetchInfo.address, fetchResponse.data[31:0]);
        if (verbose)
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,predicted next instruction=$%x", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, predictedNextProgramCounter);
        programCounter <= predictedNextProgramCounter;

        // Tell the decode stage what the program counter for the insruction it'll receive.
        outputQueue.enq(EncodedInstruction {
            fetchIndex: fetchInfo.index,
            programCounter: fetchInfo.address,
            predictedNextProgramCounter: predictedNextProgramCounter,
            pipelineEpoch: fetchInfo.epoch,
            rawInstruction: fetchResponse.data[31:0],
            exception: exception
        });

        waitingForMemoryResponse <= False;
    endrule

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getEncodedInstruction = toGet(outputQueue);
    interface ReadOnlyMemoryClient instructionMemoryClient = toGPClient(instructionMemoryRequests, instructionMemoryResponses);
    interface Put putFetchEnabled = toPut(asIfc(fetchEnabled));
endmodule
