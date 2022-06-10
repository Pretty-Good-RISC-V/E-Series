import PGRV::*;
import CPU::*;
import MemoryIO::*;
import ProgramMemory::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;

(* synthesize *)
module mkTestHost(Empty);
    // CPU
    CPU cpu <- mkCPU;

    // Program memory
    ProgramMemory#(XLEN, XLEN) programMemory <- mkProgramMemory;

    // Connect program memory to CPU
    mkConnection(programMemory.instructionMemoryServer, cpu.instructionMemoryClient);
    mkConnection(programMemory.dataMemoryServer, cpu.dataMemoryClient);

    // Cycle counter
    Reg#(Bit#(XLEN)) cycle <- mkReg(0);    
    rule cycleCounter;
        cycle <= cycle + 1;
    endrule

    rule test;
        if (cycle > 20) begin
            $display("    PASS");
            $finish();
        end
    endrule
endmodule
