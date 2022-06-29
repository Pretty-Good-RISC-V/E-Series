import PGRV::*;
import ISAUtils::*;
import PipelineRegisters::*;

function Tuple2#(Maybe#(Word), Maybe#(Word)) getForwardedOperands(ID_EX id_ex, EX_MEM ex_mem, MEM_WB mem_wb);
    // Determine if RS1 or RS2 should be forwarded from later stages (EX_MEM/MEM_WB) to the decode stage.
    Maybe#(Word) rs1Forward = tagged Invalid;
    Maybe#(Word) rs2Forward = tagged Invalid;

    // Determine if the instructions in EX_MEM and MEM_WB write to the GPR file.
    let ex_mem_has_rd = instructionHasRD(ex_mem.common.ir);
    let mem_wb_has_rd = instructionHasRD(mem_wb.common.ir);

    // Determine the destination GPR from the EX_MEM and MEM_WB.
    let ex_mem_rd = ex_mem.common.ir[11:7];
    let mem_wb_rd = mem_wb.common.ir[11:7];

    // Determine if the instruction in ID_EX has RS1 or RS2 fields
    match { .id_ex_has_rs1, .id_ex_has_rs2 } = instructionHasGPRArguments(id_ex.common.ir);
    let id_ex_rs1 = id_ex.common.ir[19:15];
    let id_ex_rs2 = id_ex.common.ir[24:20];

    // If instruction in EX_MEM has a destination AND it matches the RS1 or RS2 field in IE_EX, forward it.
    if (ex_mem_has_rd) begin
        if (id_ex_has_rs1 && ex_mem_rd == id_ex_rs1) begin
            rs1Forward = tagged Valid ex_mem.aluOutput;
        end

        // if (id_ex_has_rs2 && ex_mem_rd == id_ex_rs2) begin
        //     rs2Forward = tagged Valid ex_mem.aluOutput;
        // end
    end

    // If MEM_WB has a destination AND it matches the RS1 or RS2 field in IE_EX, forward it.
    // NOTE: This check doesn't overrite an existing forward from a more recent instruction.
    // if (mem_wb_has_rd) begin
    //     if(!isValid(rs1Forward) && id_ex_has_rs1 && mem_wb_rd == id_ex_rs1) begin
    //         rs1Forward = tagged Valid mem_wb.aluOutput;
    //     end

    //     if (!isValid(rs2Forward) && id_ex_has_rs2 && mem_wb_rd == id_ex_rs2) begin
    //         rs2Forward = tagged Valid mem_wb.aluOutput;
    //     end
    // end

    return tuple2(rs1Forward, rs2Forward);
endfunction

function ActionValue#(Tuple2#(Maybe#(Word), Maybe#(Word))) getForwardedOperands2(ID_EX id_ex, EX_MEM ex_mem, MEM_WB mem_wb);
    actionvalue
    // Determine if RS1 or RS2 should be forwarded from later stages (EX_MEM/MEM_WB) to the decode stage.
    Maybe#(Word) rs1Forward = tagged Invalid;
    Maybe#(Word) rs2Forward = tagged Invalid;

    // Determine if the instructions in EX_MEM and MEM_WB write to the GPR file.
    let ex_mem_has_rd = instructionHasRD(ex_mem.common.ir);
    let mem_wb_has_rd = instructionHasRD(mem_wb.common.ir);

    // Determine the destination GPR from the EX_MEM and MEM_WB.
    let ex_mem_rd = ex_mem.common.ir[11:7];
    let mem_wb_rd = mem_wb.common.ir[11:7];

    // Determine if the instruction in ID_EX has RS1 or RS2 fields
    match { .id_ex_has_rs1, .id_ex_has_rs2 } = instructionHasGPRArguments(id_ex.common.ir);
    let id_ex_rs1 = id_ex.common.ir[19:15];
    let id_ex_rs2 = id_ex.common.ir[24:20];

    // $display("getFO2 - ex_mem_has_rd: ", fshow(ex_mem_has_rd));
    // $display("getFO2 - id_ex_has_rs1: ", fshow(id_ex_has_rs1));
    // $display("getFO2 - id_ex_has_rs2: ", fshow(id_ex_has_rs2));
    // $display("getFO2 - ex_mem_rd: ", fshow(ex_mem_rd));
    // $display("getFO2 - id_ex_rs1: ", fshow(id_ex_rs1));
    // $display("getFO2 - id_ex_rs2: ", fshow(id_ex_rs2));

    // If instruction in EX_MEM has a destination AND it matches the RS1 or RS2 field in IE_EX, forward it.
    if (ex_mem_has_rd) begin
        if (id_ex_has_rs1 && ex_mem_rd == id_ex_rs1) begin
            rs1Forward = tagged Valid ex_mem.aluOutput;
        end

        // if (id_ex_has_rs2 && ex_mem_rd == id_ex_rs2) begin
        //     rs2Forward = tagged Valid ex_mem.aluOutput;
        // end
    end

    // If MEM_WB has a destination AND it matches the RS1 or RS2 field in IE_EX, forward it.
    // NOTE: This check doesn't overrite an existing forward from a more recent instruction.
    // if (mem_wb_has_rd) begin
    //     if(!isValid(rs1Forward) && id_ex_has_rs1 && mem_wb_rd == id_ex_rs1) begin
    //         rs1Forward = tagged Valid mem_wb.aluOutput;
    //     end

    //     if (!isValid(rs2Forward) && id_ex_has_rs2 && mem_wb_rd == id_ex_rs2) begin
    //         rs2Forward = tagged Valid mem_wb.aluOutput;
    //     end
    // end

    return tuple2(rs1Forward, rs2Forward);
    endactionvalue
endfunction

function Bool detectLoadHazard(IF_ID if_id, ID_EX id_ex);
    Bool loadHazard = False;
    if (id_ex.common.ir == 'b0000011) begin // Load?
        match { .needsRs1, .needsRs2 } = instructionHasGPRArguments(if_id.common.ir);

        if (needsRs1 && id_ex.common.ir[11:7] == if_id.common.ir[19:15]) begin
            loadHazard = True;
        end else if (needsRs1 && id_ex.common.ir[11:7] == if_id.common.ir[24:20]) begin
            loadHazard = True;
        end
    end
    return loadHazard;
endfunction
