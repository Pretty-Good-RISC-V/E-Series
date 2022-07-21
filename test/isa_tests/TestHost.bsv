import PGRV::*;
import CPU::*;
import InstructionLogger::*;
import MemoryIO::*;
import ProgramMemory::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;

(* synthesize *)
module mkTestHost(Empty);
    Reg#(Bool) writeHostInterceptionEnabled <- mkReg(False);

    //
    // CPU
    //
    CPU cpu <- mkCPU('h8000_0000);

    // 
    // Program memory
    //
    ProgramMemory#(XLEN, XLEN) programMemory <- mkProgramMemory;

    // 
    // CPU/Memory connections
    //
    mkConnection(programMemory.instructionMemoryServer, cpu.instructionMemoryClient);
    mkConnection(programMemory.dataMemoryServer, cpu.dataMemoryClient);

    //
    // Instruction logging
    //
    InstructionLog instructionLog <- mkInstructionLog;
    rule instructionLogger;
        let retiredInstructionMaybe <- cpu.getRetiredInstruction.get;
        if (retiredInstructionMaybe matches tagged Valid .retiredInstruction) begin
            instructionLog.logInstruction(
                retiredInstruction.programCounter,
                retiredInstruction.instruction
            );
        end
    endrule

    // Cycle counter
    Reg#(Bit#(XLEN)) cycle <- mkReg(0);    
    rule test(cpu.getState == READY);
        $display("> -----------------------------");
        $display("> Cycle   : %0d", cycle);

        // Step the CPU
        cpu.step;

        cycle <= cycle + 1;
    endrule
endmodule
