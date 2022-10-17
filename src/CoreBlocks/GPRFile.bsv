import PGRV::*;

import ClientServer::*;
import GetPut::*;
import RegFile::*;

typedef Bit#(5) GPRIndex;

interface GPRReadPort;
    method Word read(GPRIndex index);
endinterface

interface GPRWritePort;
    method Action write(GPRIndex index, Word value);
endinterface

interface GPRFile;
    interface GPRReadPort gprReadPort1;
    interface GPRReadPort gprReadPort2;

    interface GPRWritePort gprWritePort;
endinterface

(* synthesize *)
module mkGPRFile(GPRFile);
    RegFile#(GPRIndex, Word) regFile <- mkRegFileFull;

    interface GPRReadPort gprReadPort1;
        method Word read(GPRIndex index);
            return (index == 0 ? 0 : regFile.sub(index));
        endmethod
    endinterface

    interface GPRReadPort gprReadPort2;
        method Word read(GPRIndex index);
            return (index == 0 ? 0 : regFile.sub(index));
        endmethod
    endinterface

    interface GPRWritePort gprWritePort;
        method Action write(GPRIndex index, Word value);
            regFile.upd(index, value);
        endmethod
    endinterface
endmodule

(* synthesize *)
module mkGPRFileLoad#(parameter String file)(GPRFile);
    RegFile#(RVGPRIndex, Word) regFile <- mkRegFileFullLoad(file);

    interface GPRReadPort gprReadPort1;
        method Word read(GPRIndex index);
            return (index == 0 ? 0 : regFile.sub(index));
        endmethod
    endinterface

    interface GPRReadPort gprReadPort2;
        method Word read(GPRIndex index);
            return (index == 0 ? 0 : regFile.sub(index));
        endmethod
    endinterface

    interface GPRWritePort gprWritePort;
        method Action write(GPRIndex index, Word value);
            regFile.upd(index, value);
        endmethod
    endinterface
endmodule