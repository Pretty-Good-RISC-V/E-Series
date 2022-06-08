import PGRV::*;
import ALU::*;
import PipelineRegisters::*;

interface ExecuteStage;
    method ActionValue#(EX_MEM) execute(ID_EX id_ex);
endinterface

module mkExecuteStage(ExecuteStage);
    ALU alu <- mkALU;

    method ActionValue#(EX_MEM) execute(ID_EX id_ex);
        let func7  = id_ex.common.instruction[31:25];
//        let rs2    = id_ex.common.instruction[24:20];
//        let rs1    = id_ex.common.instruction[19:15];
        let func3  = id_ex.common.instruction[14:12];
//        let rd     = id_ex.common.instruction[11:7];
        let opcode = id_ex.common.instruction[6:0];

        // ALU
        let isALU          = (opcode matches 'b0?10011 ? True : False);
        let isALUImmediate = opcode[5];
        let aluOperation   = {1'b0, func7, func3};
        let aluResult      = alu.execute(aluOperation, id_ex.a, (unpack(isALUImmediate) ? id_ex.immediate : id_ex.b));

        // Branching
        let isBranch      = (opcode == 'b1100011);
        return defaultValue;
    endmethod
endmodule
