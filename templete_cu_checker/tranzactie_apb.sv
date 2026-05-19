//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_transaction
`define __apb_transaction

class tranzactie_apb extends uvm_sequence_item;

  `uvm_object_utils(tranzactie_apb)

  rand bit [7:0] addr;   // adresa registrului (0x00-0x05 pentru lift)
  rand bit [7:0] data;   // date de scris / date citite dupa tranzactie
  rand bit       rw;     // 1 = scriere (WRITE), 0 = citire (READ)

  function new(string name = "tranzactie_apb");
    super.new(name);
    addr = 0;
    data = 0;
    rw   = 0;
  endfunction

  function void afiseaza_informatia_tranzactiei();
    $display("[APB TRZ] %s | ADDR=0x%02h | DATA=0x%02h",
             rw ? "WRITE" : "READ", addr, data);
  endfunction

  function tranzactie_apb copy();
    copy      = new();
    copy.addr = this.addr;
    copy.data = this.data;
    copy.rw   = this.rw;
    return copy;
  endfunction

endclass
`endif