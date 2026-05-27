//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __citire_apb_sequence
`define __citire_apb_sequence

// Secventa care testeaza CITIREA tuturor registrelor:
//   1. Scrie valori cunoscute in registrele RW (0x00, 0x01)
//   2. Citeste inapoi cele 2 registre RW si verifica
//   3. Citeste toate registrele RO (0x02..0x05) repetat — valideaza ca
//      PRDATA nu contine X (prin asertiunea p_prdata_known)
//   4. Citeste adrese in afara hartii (0x06..0x10) — trebuie sa returneze 0xFF
class secventa_apb_citire extends uvm_sequence #(tranzactie_apb);

  `uvm_object_utils(secventa_apb_citire)

  function new(string name = "secventa_apb_citire");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SECV_CITIRE", "Faza 1: scriu valori cunoscute in 0x00 si 0x01", UVM_LOW)

    // ── Faza 1: scriere RW ───────────────────────────────────────────
    scrie(8'h00, 8'h05);   // buton_scara = floor 0 + floor 2
    scrie(8'h01, 8'h0A);   // buton_lift  = floor 1 + floor 3

    `uvm_info("SECV_CITIRE", "Faza 2: citesc inapoi 0x00 si 0x01", UVM_LOW)

    // ── Faza 2: citire si verificare RW ─────────────────────────────
    citeste(8'h00);
    citeste(8'h01);

    `uvm_info("SECV_CITIRE", "Faza 3: citesc TOATE registrele RO (cate de 3 ori)", UVM_LOW)

    // ── Faza 3: citire RO repetata ──────────────────────────────────
    repeat (3) begin
      citeste(8'h02);  // various_signals
      citeste(8'h03);  // floor_management
      citeste(8'h04);  // led_lift
      citeste(8'h05);  // led_scara
    end

    `uvm_info("SECV_CITIRE", "Faza 4: citesc adrese invalide (0x06..0x0F)", UVM_LOW)

    // ── Faza 4: citire adrese din afara hartii ──────────────────────
    for (int a = 8'h06; a <= 8'h0F; a++) begin
      citeste(a[7:0]);
    end

    `uvm_info("SECV_CITIRE", "Secventa de citire finalizata", UVM_LOW)
  endtask

  // ── Task helper: scriere ─────────────────────────────────────────────
  task scrie(input bit [7:0] adresa, input bit [7:0] valoare);
    req = tranzactie_apb::type_id::create("req_w");
    start_item(req);
    assert(req.randomize() with {
      addr == adresa;
      rw   == 1'b1;
      data == valoare;
    });
    `uvm_info("SECV_CITIRE", $sformatf("SCRIERE addr=0x%02h data=0x%02h", adresa, valoare), UVM_HIGH)
    finish_item(req);
  endtask

  // ── Task helper: citire ──────────────────────────────────────────────
  task citeste(input bit [7:0] adresa);
    req = tranzactie_apb::type_id::create("req_r");
    start_item(req);
    assert(req.randomize() with {
      addr == adresa;
      rw   == 1'b0;
    });
    finish_item(req);
    `uvm_info("SECV_CITIRE",
      $sformatf("CITIRE addr=0x%02h => data=0x%02h", adresa, req.data), UVM_HIGH)
  endtask

endclass

`endif
