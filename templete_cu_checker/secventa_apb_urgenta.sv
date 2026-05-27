//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __urgenta_apb_sequence
`define __urgenta_apb_sequence

// Secventa care testeaza scenariul de urgenta:
//   1. Trimite cateva cereri de etaj pe buton_scara
//   2. Lasa liftul sa inceapa miscarea
//   3. Declanseaza emergency_stop scriind 0x80 la addr=0x01
//   4. Continua sa observe pana cand liftul coboara la etaj 0 si reseteaza cererile
class secventa_apb_urgenta extends uvm_sequence #(tranzactie_apb);

  `uvm_object_utils(secventa_apb_urgenta)

  function new(string name = "secventa_apb_urgenta");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SECV_URGENTA", "Faza 1: trimit 3 cereri de etaj (1, 3, 5)", UVM_LOW)

    // ── Faza 1: cereri normale pe buton_scara ───────────────────────
    scrie_apb(8'h00, 8'h02);  // etaj 1
    scrie_apb(8'h00, 8'h08);  // etaj 3
    scrie_apb(8'h00, 8'h20);  // etaj 5

    `uvm_info("SECV_URGENTA", "Faza 2: astept ca liftul sa inceapa miscarea (10 cicluri)", UVM_LOW)

    // ── Faza 2: ne lasam liftul sa proceseze cereri ─────────────────
    repeat (10) begin
      scrie_apb(8'h02, 8'h00);  // citire dummy (various_signals)
    end

    `uvm_info("SECV_URGENTA", "Faza 3: DECLANSEZ EMERGENCY_STOP (0x80 la 0x01)", UVM_LOW)

    // ── Faza 3: declansare emergency ────────────────────────────────
    scrie_apb(8'h01, 8'h80);   // bit 7 din buton_lift => emergency_stop=1

    `uvm_info("SECV_URGENTA", "Faza 4: monitorizez coborarea liftului (40 cicluri)", UVM_LOW)

    // ── Faza 4: citiri pentru a observa coborarea catre etaj 0 ──────
    repeat (40) begin
      scrie_apb(8'h03, 8'h00);  // citire floor_management
    end

    `uvm_info("SECV_URGENTA", "Secventa urgenta finalizata", UVM_LOW)
  endtask

  // ── Task helper: scriere/citire APB ──────────────────────────────────
  task scrie_apb(input bit [7:0] adresa, input bit [7:0] valoare);
    req = tranzactie_apb::type_id::create("req");
    start_item(req);
    if (adresa == 8'h02 || adresa == 8'h03 || adresa == 8'h04 || adresa == 8'h05) begin
      // adrese RO => citire
      assert(req.randomize() with {
        addr == adresa;
        rw   == 1'b0;
      });
    end else begin
      // adrese RW => scriere
      assert(req.randomize() with {
        addr == adresa;
        rw   == 1'b1;
        data == valoare;
      });
    end
    finish_item(req);
  endtask

endclass

`endif
