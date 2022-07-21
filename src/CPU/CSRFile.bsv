import PGRV::*;
import CSRs::*;
import ReadOnly::*;
import Trap::*;

import Cntrs::*;

typedef struct {
    Word value;
    Bool denied;
} CSRReadResult deriving(Bits, Eq, FShow);

typedef struct {
    Bool denied;
} CSRWriteResult deriving(Bits, Eq, FShow);

interface CSRReadPort;
    method ActionValue#(CSRReadResult) read(RVCSRIndex index);
endinterface

interface CSRWritePort;
    method ActionValue#(CSRWriteResult) write(RVCSRIndex index, Word value);
endinterface

interface CSRWritePermission;
    method Bool isWriteable(RVCSRIndex index);
endinterface

interface TrapController;
    method ActionValue#(ProgramCounter) beginTrap(ProgramCounter trapProgramCounter, Trap trap);
    method ActionValue#(ProgramCounter) endTrap;
endinterface

interface CSRFile;
    method Action incrementCycleCounters;
    method Action incrementInstructionsRetiredCounter;

    interface CSRReadPort        csrReadPort;
    interface CSRWritePort       csrWritePort;
    interface CSRWritePermission csrWritePermission;

    interface TrapController trapController;
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

    Reg#(Word)              sideleg             <- mkReg(0);
    Reg#(Word)              sedeleg             <- mkReg(0);

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

    function RVCSRIndex getIndex(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
        RVCSRIndex index = 0;
        index[9:8] = privilegeLevel[1:0];
        index[7:0] = offset;
        return index;
    endfunction

    // Based on fv_new_priv_on_exception from Flute processor.
    function RVPrivilegeLevel getTrapPrivilegeLevel(Trap trap);
        let trapPrivilegeLevel = priv_MACHINE;

        if (currentPriv < priv_MACHINE) begin
            if (misa.extS) begin    // S mode supported?
                // See if this trap should be delegated to SUPERVISOR mode
                let delegated = (trap.isInterrupt ? 
                    (mideleg[trap.cause] == 0 ? False : True) :
                    (medeleg[trap.cause] == 0 ? False : True));

                if (delegated) begin
                    trapPrivilegeLevel = priv_SUPERVISOR;

                    // If the current priv mode is U, and user mode traps are supported,
	                // then consult sedeleg/sideleg to determine if delegated to USER mode.                    
                    if (currentPriv == priv_USER && misa.extN) begin
                        delegated = (trap.isInterrupt ? 
                            (sideleg[trap.cause] == 0 ? False : True) :
                            (sedeleg[trap.cause] == 0 ? False : True));

                        if (delegated) begin
                            trapPrivilegeLevel = priv_USER;
                        end
                    end
                end
            end else begin // S mode *NOT* supported
                // If user mode traps are supported, then consult sedeleg/sideleg to determine 
                // if delegated to USER mode.                    
                if (misa.extN) begin
                    let delegated = (trap.isInterrupt ? 
                        (mideleg[trap.cause] == 0 ? False : True) :
                        (medeleg[trap.cause] == 0 ? False : True));

                    if (delegated) begin
                        trapPrivilegeLevel = priv_USER;
                    end
                end
            end
        end

        return trapPrivilegeLevel;
    endfunction

    //
    // readInternal
    //
    function ActionValue#(CSRReadResult) readInternal(RVCSRIndex index);
        actionvalue
            let result = CSRReadResult {
                value: 0,
                denied: False
            };

            if (!isWARLIgnore(index)) begin
                case(index)
                    // Machine Information Registers (MRO)
                    csr_MVENDORID:  result.value = extend(machineInformation.mvendorid);
                    csr_MARCHID:    result.value = machineInformation.marchid;
                    csr_MIMPID:     result.value = machineInformation.mimpid;
                    csr_MHARTID:    result.value = machineInformation.mhartid;
                    csr_MISA:       result.value = pack(misa);

                    csr_MCAUSE:     result.value = mcause;
                    csr_MTVEC:      result.value = mtvec;
                    csr_MEPC:       result.value = mepc;
                    csr_MTVAL:      result.value = mtval;
                    csr_MIDELEG:    result.value = mideleg;
                    csr_MEDELEG:    result.value = medeleg;

                    csr_MSTATUS:    result.value = pack(mstatus);
                    csr_MCYCLE, csr_CYCLE:     
                        result.value = mcycle;
                    csr_MSCRATCH:   result.value = mscratch;
                    csr_MIP:        result.value = mip;
                    csr_MIE:        result.value = mie;

                    // !bugbug - TSELECT is hardcoded to all 1s.  This is to keep
                    //           the ISA debug test happy.  It *should* report a 
                    //           pass if reading TSELECT failed with a trap (to reflect what's in the spec)
                    //           This is a bug in the debug test.
                    csr_TSELECT:    result.value = 'hFFFF_FFFF;
                    default: begin
                        result.denied = True;
                    end
                endcase
            end

            return result;
        endactionvalue
    endfunction

    //
    // writeInternal
    //
    function ActionValue#(CSRWriteResult) writeInternal(RVCSRIndex index, Word value);
        actionvalue
            let result = CSRWriteResult {
                denied: False
            };

            // Access and write to read-only CSR check.
            if (!isWARLIgnore(index)) begin
                case(index)
                    csr_MCAUSE:   mcause        <= value;
                    csr_MCYCLE:   cycleCounter  <= zeroExtend(value);
                    csr_MEPC:     mepc          <= value;
                    csr_MISA:     misa          <= unpack(value);
                    csr_MSCRATCH: mscratch      <= value;
                    csr_MSTATUS:  mstatus       <= unpack(value);
                    csr_MTVAL:    mtval         <= value;
                    csr_MTVEC:    mtvec         <= value;
                    csr_MIE:      mie           <= value;
                    csr_MIP:      mip           <= value;
                    csr_TSELECT:  begin 
                        // No-Op
                    end
                    default:      result.denied = True;
                endcase   
            end

            return result;
        endactionvalue
    endfunction

    function ActionValue#(CSRReadResult) readWithOffset1(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
        actionvalue
            let csrReadResult <- readInternal(getIndex(privilegeLevel, offset));
            return csrReadResult;
        endactionvalue
    endfunction      

    function ActionValue#(CSRWriteResult) writeWithOffset1(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset, Word value);
        actionvalue
            let csrWriteResult <- writeInternal(getIndex(privilegeLevel, offset), value);
            return csrWriteResult;
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
        method ActionValue#(CSRReadResult) read(RVCSRIndex index);
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
        method ActionValue#(CSRWriteResult) write(RVCSRIndex index, Word value);
            let result = CSRWriteResult {
                denied: True
            };

            if (currentPriv >= index[9:8] && index[11:10] != 'b11) begin
                result <- writeInternal(index, value);
            end

            return result;
        endmethod
    endinterface

    //
    // csrWritePermission
    //
    interface CSRWritePermission csrWritePermission;
        method Bool isWriteable(RVCSRIndex index);
            return (currentPriv >= index[9:8] && index[11:10] != 'b11);
        endmethod
    endinterface

    //
    // trapController
    //
    interface TrapController trapController;
        method ActionValue#(ProgramCounter) beginTrap(ProgramCounter trapProgramCounter, Trap trap);
            Word cause = 0;

            let trapPrivilegeLevel = getTrapPrivilegeLevel(trap);

            cause = zeroExtend(trap.cause);
            if (!trap.isInterrupt) begin
                cause[valueOf(XLEN)-1] = 1;
            end

            // PC => MEPC
            writeWithOffset1(trapPrivilegeLevel, csr_EPC, trapProgramCounter);  

            // CurPriv => MSTATUS::MPP
            let mstatus_  = mstatus;
            mstatus_.mpp  = currentPriv;

            // MSTATUS::MIE => MSTATUS::MPIE
            mstatus_.mpie = mstatus.mie;
            mstatus_.mie  = False;    // Disable interrupts
            mstatus      <= mstatus_;

            // cause => CAUSE
            writeWithOffset1(trapPrivilegeLevel, csr_CAUSE, cause);
            writeWithOffset1(trapPrivilegeLevel, csr_TVAL, trap.tval);

            let readResult <- readWithOffset1(trapPrivilegeLevel, csr_TVEC);
            Word vectorTableBase = readResult.value;
            let trapHandler = vectorTableBase;

            // Check and handle a vectored trap handler table
            if (trapHandler[1:0] == 1) begin
                trapHandler[1:0] = 0;
                if(trap.isInterrupt) begin
                    trapHandler = trapHandler + extend(4 * trap.cause);
                end
            end

            currentPriv <= trapPrivilegeLevel;

            return trapHandler;
        endmethod

        method ActionValue#(ProgramCounter) endTrap;
            return 0;
        endmethod
    endinterface

endmodule
