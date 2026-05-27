//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __combinat_apb_sequence
`define __combinat_apb_sequence

// Secventa care testeaza cereri MIXTE pe buton_scara si buton_lift:
//   - Alterneaza scriereri intre 0x00 si 0x01
//   - Etajele cerute sunt diferite pe fiecare buton (testeaza logica up/down)
//   - Verifica ca LED-urile (led_lift si led_scara) reflecta corect cererile
//   - Stress test pe FSM: cereri sus si jos amestecate fortand directia
class secventa_apb_combinat extends uvm_sequence #(tranzactie_apb);

  `uvm_object_utils(secventa_apb_combinat)

  function new(string name = "secventa_apb_combinat");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SECV_COMBINAT", "Faza 1: cereri SUS pe ambele butoane (etaje 2, 4, 6)", UVM_LOW)

    // ── Faza 1: cereri "sus" alternate intre cele 2 surse ────────────
    scrie(8'h00, 8'h04);   // buton_scara: etaj 2
    scrie(8'h01, 8'h10);   // buton_lift:  etaj 4
    scrie(8'h00, 8'h40);   // buton_scara: etaj 6

    // Lasa liftul sa proceseze cateva miscari
    repeat (15) citeste(8'h03);  // citire floor_management (dummy traffic)

    `uvm_info("SECV_COMBINAT", "Faza 2: cereri JOS pe ambele butoane (etaje 5, 3, 1)", UVM_LOW)

    // ── Faza 2: cereri "jos" alternate ──────────────────────────────
    scrie(8'h01, 8'h20);   // buton_lift:  etaj 5
    scrie(8'h00, 8'h08);   // buton_scara: etaj 3
    scrie(8'h01, 8'h02);   // buton_lift:  etaj 1

    repeat (15) citeste(8'h03);

    `uvm_info("SECV_COMBINAT", "Faza 3: cereri SIMULTANE pe ambele butoane (acelasi etaj)", UVM_LOW)

    // ── Faza 3: acelasi etaj cerut din ambele surse ─────────────────
    scrie(8'h00, 8'h10);   // buton_scara: etaj 4
    scrie(8'h01, 8'h10);   // buton_lift:  etaj 4 (acelasi etaj)

    repeat (10) citeste(8'h03);

    `uvm_info("SECV_COMBINAT", "Faza 4: verific LED-urile prin citire 0x04 si 0x05", UVM_LOW)

    // ── Faza 4: verificare LED-uri ──────────────────────────────────
    repeat (3) begin
      citeste(8'h04);    // led_lift
      citeste(8'h05);    // led_scara
    end

    `uvm_info("SECV_COMBINAT", "Secventa combinata finalizata", UVM_LOW)
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
    `uvm_info("SECV_COMBINAT",
      $sformatf("%s [0x%02h] <= 0x%02h",
        (adresa == 8'h00) ? "SCARA " : "LIFT  ", adresa, valoare), UVM_LOW)
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
  endtask

endclass

`endif
