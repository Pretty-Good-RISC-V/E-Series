import PGRV::*;

import MemoryIO::*;
import PipelineRegisters::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

typedef enum {
    WAITING_FOR_FETCH_REQUEST,
    WAITING_FOR_FETCH_RESPONSE
} FetchState deriving(Bits, Eq, FShow);

interface FetchStage;
    method ActionValue#(IF_ID) fetch(ProgramCounter programCounter, EX_MEM ex_mem, Put#(ProgramCounter) putProgramCounter);
    interface ReadOnlyMemoryClient#(XLEN, 32) instructionMemoryClient;
endinterface

module mkFetchStage(FetchStage);
    RWire#(ReadOnlyMemoryRequest#(XLEN, 32)) instructionMemoryRequest  <- mkRWire;
    RWire#(FallibleMemoryResponse#(32))      instructionMemoryResponse <- mkRWire;

    Reg#(FetchState) state <- mkReg(WAITING_FOR_FETCH_REQUEST);

    method ActionValue#(IF_ID) fetch(ProgramCounter programCounter, EX_MEM ex_mem, Put#(ProgramCounter) putNextProgramCounter);
        IF_ID if_id = defaultValue;

        let npc = programCounter;
        let nextState = state;

        case(state)
            WAITING_FOR_FETCH_REQUEST: begin
                $display("FetchStage - Fetching instruction at $%0h", programCounter);
                instructionMemoryRequest.wset(ReadOnlyMemoryRequest {
                    byteen: 'b1111,
                    address: programCounter
                });
                $display("FetchStage - Inserting pipeline bubble");
                nextState = WAITING_FOR_FETCH_RESPONSE;
            end

            WAITING_FOR_FETCH_RESPONSE: begin
                if (instructionMemoryResponse.wget matches tagged Valid .response) begin
                    npc = (ex_mem.branchTaken ? ex_mem.aluOutput : programCounter + 4);

                    if_id.common.instruction = response.data;
                    if_id.common.programCounter = programCounter;
                    if_id.common.isBubble = False;
                    if_id.nextProgramCounter = npc;

                    if (response.denied) begin
                        if_id.common.exceptionCause = tagged Valid exception_INSTRUCTION_ACCESS_FAULT;
                    end

                    nextState = WAITING_FOR_FETCH_REQUEST;
                    $display("FetchStage - Memory response found: ", fshow(response));
                end else begin
                    $display("FetchStage - Waiting for instruction memory response");
                    $display("FetchStage - Inserting pipeline bubble");
                end
            end
        endcase

        state <= nextState;

        putNextProgramCounter.put(npc);
        return if_id;
    endmethod

    interface ReadOnlyMemoryClient instructionMemoryClient = toGPClient(instructionMemoryRequest, instructionMemoryResponse);
endmodule
