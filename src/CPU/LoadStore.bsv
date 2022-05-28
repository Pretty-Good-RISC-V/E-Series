import PGRV::*;
import Exception::*;
import MemoryIO::*;

import Memory::*;

//
// LoadRequest
//
// Structure containing information about a request to load data
// from memory.
//
typedef struct {
    MemoryRequest#(XLEN, XLEN) memoryRequest;
    RVGPRIndex rd;
    Bool signExtend;
} LoadRequest deriving(Bits, Eq, FShow);

function Word getWordAddress(Word effectiveAddress);
    Bit#(XLEN) shift = fromInteger(valueOf(TLog#(TDiv#(XLEN,8))));
    Bit#(XLEN) mask = ~((1 << shift) - 1);

    return effectiveAddress & mask;
endfunction

function Result#(LoadRequest, Exception) getLoadRequest(
    RVLoadOperator loadOperator,
    RVGPRIndex rd,
    Word effectiveAddress);

    Result#(LoadRequest, Exception) result = 
        tagged Error createIllegalInstructionException(0);

    let loadRequest = LoadRequest {
        memoryRequest: MemoryRequest {
            write: False,
            byteen: ?,
            address: effectiveAddress,
            data: ?
        },
        rd: rd,
        signExtend: True
    };

    case (loadOperator)
        // Byte
        load_LB: begin
            loadRequest.memoryRequest.byteen = 'b1;
            result = tagged Success loadRequest;
        end

        load_LBU: begin
            loadRequest.memoryRequest.byteen = 'b1;
            loadRequest.signExtend = False;
            result = tagged Success loadRequest;
        end

        // Half-word
        load_LH: begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.memoryRequest.byteen = 'b11;
                result = tagged Success loadRequest;
            end
        end

        load_LHU: begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.memoryRequest.byteen = 'b11;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        // Word
        load_LW: begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.memoryRequest.byteen = 'b1111;
                result = tagged Success loadRequest;
            end
        end

`ifdef RV64
        load_LWU: begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.memoryRequest.byteen = 'b1111;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        load_LD: begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.memoryRequest.byteen = 'b1111_1111;
                result = tagged Success loadRequest;
            end
        end
`endif
    endcase

    return result;
endfunction

//
// StoreRequest
//
// Structure containing information about a request to store data
// to memory.
//
typedef MemoryRequest#(XLEN, XLEN) StoreRequest;

function Result#(StoreRequest, Exception) getStoreRequest(
    RVStoreOperator storeOperator,
    Word effectiveAddress,
    Word value);

    Result#(StoreRequest, Exception) result = 
        tagged Error createIllegalInstructionException(0);

    let storeRequest = StoreRequest {
        write: True,
        byteen: ?,
        address: effectiveAddress,
        data: ?
    };

    case (storeOperator)
        // Byte
        store_SB: begin
            storeRequest.byteen = 'b1;
            storeRequest.data = (value & 'hFF);

            result = tagged Success storeRequest;
        end
        // Half-word
        store_SH: begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error createMisalignedStoreException(effectiveAddress);
            end else begin
                storeRequest.byteen = 'b11;
                storeRequest.data = (value & 'hFFFF);

                result = tagged Success storeRequest;
            end
        end
        // Word
        store_SW: begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error createMisalignedStoreException(effectiveAddress);
            end else begin
                storeRequest.byteen = 'b1111;
                storeRequest.data = (value & 'hFFFF_FFFF);

                result = tagged Success storeRequest;
            end
        end
`ifdef RV64
        // Double-word
        store_SD: begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error createMisalignedStoreException(effectiveAddress);
            end else begin
                storeRequest.byteen = 'b1111_1111;
                storeRequest.data = (value & 'hFFFF_FFFF_FFFF_FFFF);

                result = tagged Success storeRequest;
            end
        end
`endif
    endcase

    return result;
endfunction
