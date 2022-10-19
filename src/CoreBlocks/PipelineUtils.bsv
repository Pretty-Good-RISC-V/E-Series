import PGRV::*;
import ISAUtils::*;
import PipelineRegisters::*;

function Tuple2#(Maybe#(Word), Maybe#(Word)) getForwardedOperands(ID_EX id_ex, EX_MEM ex_mem, MEM_WB mem_wb, WB_OUT wb_out);
    // Determine if RS1 or RS2 should be forwarded from later stages (EX_MEM/MEM_WB/WB_OUT) to the execute stage (to replace what's in ID_EX).
    Maybe#(Word) rs1Forward = tagged Invalid;
    Maybe#(Word) rs2Forward = tagged Invalid;

    // Determine if the instructions in EX_MEM, MEM_WB and WB_OUT write to the GPR file.
    let ex_mem_has_rd = instructionHasRD(ex_mem.common.ir);
    let mem_wb_has_rd = instructionHasRD(mem_wb.common.ir);
    let wb_out_has_rd = instructionHasRD(wb_out.common.ir);

    // Determine the destination GPR from the EX_MEM, MEM_WB and WB_OUT.
    let ex_mem_rd = ex_mem.common.ir[11:7];
    let mem_wb_rd = mem_wb.common.ir[11:7];
    let wb_out_rd = wb_out.common.ir[11:7];

    // Determine if the instruction in ID_EX has RS1 and/or RS2 fields
    match { .id_ex_has_rs1, .id_ex_has_rs2 } = instructionHasGPRArguments(id_ex.common.ir);
    let id_ex_rs1 = id_ex.common.ir[19:15];
    let id_ex_rs2 = id_ex.common.ir[24:20];

    // Check each of the later stages for forwarding opportunities.
    //
    // NOTE: Instructions that are *older* (farther along in the pipeline)
    //       are checked first since they may be overwritten by newer 
    //       instructions in the pipeline.

    // Check instructions that have been written back to the register
    // file but weren't picked up during the decode stage.
    if (wb_out_has_rd) begin
        if(id_ex_has_rs1 && wb_out_rd == id_ex_rs1) begin
            rs1Forward = tagged Valid wb_out.gprWritebackValue;
        end

        if (id_ex_has_rs2 && wb_out_rd == id_ex_rs2) begin
            rs2Forward = tagged Valid wb_out.gprWritebackValue;
        end
    end

    // Check instructions in the memory stage that may have come from
    // a load from memory.
    if (mem_wb_has_rd) begin
        if(id_ex_has_rs1 && mem_wb_rd == id_ex_rs1) begin
            rs1Forward = tagged Valid mem_wb.gprWritebackValue;
        end

        if (id_ex_has_rs2 && mem_wb_rd == id_ex_rs2) begin
            rs2Forward = tagged Valid mem_wb.gprWritebackValue;
        end
    end

    // Check instructions that just executed but haven't been written
    // back to the register file.
    if (ex_mem_has_rd) begin
        if (id_ex_has_rs1 && ex_mem_rd == id_ex_rs1) begin
            rs1Forward = tagged Valid ex_mem.aluOutput;
        end

        if (id_ex_has_rs2 && ex_mem_rd == id_ex_rs2) begin
            rs2Forward = tagged Valid ex_mem.aluOutput;
        end
    end

    return tuple2(rs1Forward, rs2Forward);
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
