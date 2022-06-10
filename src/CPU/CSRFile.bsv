import PGRV::*;
import CSRs::*;
import ReadOnly::*;

import Cntrs::*;

typedef struct {
    Word value;
    Bool denied;
} CSRReadResult deriving(Bits, Eq, FShow);

typedef struct {
    Bool denied;
} CSRWriteResult deriving(Bits, Eq, FShow);

interface CSRReadPort;
    method ActionValue#(CSRReadResult) readCSR(RVCSRIndex index);
endinterface

interface CSRWritePort;
    method ActionValue#(CSRWriteResult) writeCSR(RVCSRIndex index, Word value);
endinterface

interface CSRFile;
    method Action incrementCycleCounters;
    method Action incrementInstructionsRetiredCounter;

    interface CSRReadPort  csrReadPort;
    interface CSRWritePort csrWritePort;
endinterface

(* synthesize *)
module mkCSRFile(CSRFile);
    Reg#(RVPrivilegeLevel)  currentPriv         <- mkReg(priv_MACHINE);

    // Counters
    Count#(Word64)          cycleCounter        <- mkCount(0);
    Count#(Word64)          timeCounter         <- mkCount(0);
    Count#(Word64)          retiredCounter      <- mkCount(0);

    // CSRs
    MachineInformation      machineInformation  <- mkMachineInformationRegisters(0, 0, 0, 0, 0);
    Reg#(MachineISA)        misa                <- mkReg(defaultValue);
    Reg#(MachineStatus)     mstatus             <- mkReg(defaultValue);
    ReadOnly#(Word)         mcycle              <- mkReadOnly(truncate(cycleCounter));
    ReadOnly#(Word)         mtimer              <- mkReadOnly(truncate(timeCounter));
    ReadOnly#(Word)         minstret            <- mkReadOnly(truncate(retiredCounter));
`ifdef RV32
    ReadOnly#(Word)         mcycleh             <- mkReadOnly(truncateLSB(cycleCounter));
    ReadOnly#(Word)         mtimeh              <- mkReadOnly(truncateLSB(timeCounter));
    ReadOnly#(Word)         minstreth           <- mkReadOnly(truncateLSB(retiredCounter));
`endif
    Reg#(Word)              mcause              <- mkReg(0);
    Reg#(Word)              mtvec               <- mkReg('hC0DEC0DE);
    Reg#(Word)              mepc                <- mkReg(0);
    Reg#(Word)              mscratch            <- mkReg(0);
    Reg#(Word)              mip                 <- mkReg(0);
    Reg#(Word)              mie                 <- mkReg(0);
    Reg#(Word)              mtval               <- mkReg(0);
    Reg#(Word)              mideleg             <- mkReg(0);
    Reg#(Word)              medeleg             <- mkReg(0);

    function Bool isWARLIgnore(RVCSRIndex index);
        Bool result = False;
        if ((index >= csr_PMPADDR0 && index <= csr_PMPADDR63) ||
            (index >= csr_PMPCFG0  && index <= csr_PMPCFG15) ||
            index == csr_SATP ||
            index == csr_MIDELEG ||
            index == csr_MEDELEG) begin
            result = True;
        end

        return result;
    endfunction

    //
    // readInternal
    //
    function ActionValue#(CSRReadResult) readInternal(RVCSRIndex index);
        actionvalue
            return CSRReadResult {
                value: 0,
                denied: True
            };
        endactionvalue
    endfunction

    //
    // writeInternal
    //
    function ActionValue#(CSRWriteResult) writeInternal(RVCSRIndex index, Word value);
        actionvalue
            return CSRWriteResult {
                denied: True
            };
        endactionvalue
    endfunction

    method Action incrementCycleCounters;
        cycleCounter.incr(1);
        timeCounter.incr(1);
    endmethod

    method Action incrementInstructionsRetiredCounter;
        retiredCounter.incr(1);
    endmethod

    //
    // csrReadPort
    //
    interface CSRReadPort csrReadPort;
        method ActionValue#(CSRReadResult) readCSR(RVCSRIndex index);
            let result = CSRReadResult {
                value: 0,
                denied: True
            };

            if (currentPriv >= index[9:8]) begin
                result <- readInternal(index);
            end

            return result;
        endmethod
    endinterface

    //
    // csrWritePort
    //
    interface CSRWritePort csrWritePort;
        method ActionValue#(CSRWriteResult) writeCSR(RVCSRIndex index, Word value);
            let result = CSRWriteResult {
                denied: True
            };

            if (currentPriv >= index[9:8] && index[11:10] != 'b11) begin
                result <- writeInternal(index, value);
            end

            return result;
        endmethod
    endinterface

endmodule
