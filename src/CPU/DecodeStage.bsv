import PGRV::*;
import CSRFile::*;
import PipelineRegisters::*;
import GPRFile::*;

interface DecodeStage;
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2, CSRReadPort csrReadPort);
endinterface

module mkDecodeStage(DecodeStage);
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2, CSRReadPort csrReadPort);
        // Instruction field extraction
        let csr    = if_id.common.ir[31:20];
        let rs2    = if_id.common.ir[24:20];
        let rs1    = if_id.common.ir[19:15];
        let rd     = if_id.common.ir[11:7];
        let opcode = if_id.common.ir[6:0];

        // Determine immediate value stored in the instruction
        Word imm = case(opcode) matches
            // SYSTEM
            // NOTE: SYSTEM - CSR (unsigned) immediates are stored in the RS1 bits.
            'b1110011: return zeroExtend(rs1);

            // S-Type
            'b0100011: begin
                return signExtend({
                    if_id.common.ir[31:25],
                    if_id.common.ir[11:7]
                });
            end

            // B-Type
            'b1100011: begin
                return signExtend({
                    if_id.common.ir[31],
                    if_id.common.ir[7],
                    if_id.common.ir[30:25],
                    if_id.common.ir[11:8],
                    1'b0
                });
            end

            // U-Type
            'b0?10111: begin
                return signExtend({
                    if_id.common.ir[31:12], 
                    12'b0
                });
            end

            // J-Type
            'b1101111: begin
                return signExtend({
                    if_id.common.ir[31],
                    if_id.common.ir[19:12],
                    if_id.common.ir[20],
                    if_id.common.ir[30:21],
                    1'b0
                });
            end

            // (default) assume I-Type (won't be used otherwise)
            default: begin
                return signExtend(if_id.common.ir[31:20]);
            end
        endcase;

        // Read GPR/CSR registers
        let a = gprReadPort1.read(rs1);
        let b = ?;
        let isBValid = True;
        if (opcode == 'b1110011) begin
            if (rd != 0) begin
                let csrReadResult <- csrReadPort.read(csr);
                b = csrReadResult.value;
                isBValid = csrReadResult.denied;
            end else begin
                b = 0;
                isBValid = True;
            end
        end else begin
            $display("Decode: RS2 = %0d", rs2);
            b = gprReadPort2.read(rs2);
            isBValid = True;
        end

        return ID_EX {
            common:   if_id.common,
            epoch:    if_id.epoch,
            npc:      if_id.npc,
            a:        a,
            b:        b,
            isBValid: isBValid,
            imm:      imm
        };
    endmethod
endmodule
