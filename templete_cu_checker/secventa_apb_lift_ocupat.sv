//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __ocupat_apb_sequence
`define __ocupat_apb_sequence

class secventa_apb_lift_ocupat extends uvm_sequence #(tranzactie_apb);

  `uvm_object_utils(secventa_apb_lift_ocupat)

  // ── Parametri secventa ──────────────────────────────────────────────
  rand int numarul_de_tranzactii;

  constraint marimea_sirului_c {
    soft numarul_de_tranzactii inside {[5:15]};
  }

  function new(string name = "secventa_apb_lift_ocupat");
    super.new(name);
  endfunction

  function void post_randomize();
    `uvm_info("secventa_apb_lift_ocupat",
      $sformatf("Secventa randomizata: %0d tranzactii", numarul_de_tranzactii),
      UVM_LOW)
  endfunction

  // ── Secventa principala: tranzactii random cu constrangeri lift ─────
  virtual task body();
    `uvm_info("secventa_apb_lift_ocupat",
      $sformatf("Incepe secventa APB cu %0d tranzactii", numarul_de_tranzactii),
      UVM_LOW)

    for (int i = 0; i < 7; i++) begin
      req = tranzactie_apb::type_id::create("req");
      start_item(req);

      // Constrangeri specifice liftului:
      // - addr: doar adrese valide (0x00-0x05)
      // - registrele RO (0x02-0x05) sunt INTOTDEAUNA citite
      // - registrele RW (0x00-0x01) pot fi citite sau scrise
      // - data: valori one-hot (un etaj) sau cazuri speciale
      assert(req.randomize() with {
        addr ==8'h00;

       rw == 1'b1;

          data == (1<<i);
      });

      `uvm_info("secventa_apb_lift_ocupat",
        $sformatf("[%0d/%0d] Tranzactie generata", i+1, numarul_de_tranzactii),
        UVM_HIGH)
      req.afiseaza_informatia_tranzactiei();

      finish_item(req);
    end

    `uvm_info("secventa_apb_lift_ocupat",
      $sformatf("Secventa finalizata: %0d tranzactii trimise", numarul_de_tranzactii),
      UVM_LOW)
  endtask

  // ── Task helper: scrie o cerere de etaj pe buton_scara (0x00) ───────
  task scrie_buton_scara(int etaj);
    req = tranzactie_apb::type_id::create("req_scara");
    start_item(req);
    assert(req.randomize() with {
      addr == 8'h00;
      rw   == 1'b1;
      data == (8'h01 << etaj);
    });
    `uvm_info("secventa_apb_lift_ocupat",
      $sformatf("SCARA: cerere etaj %0d (data=0x%02h)", etaj, req.data), UVM_LOW)
    finish_item(req);
  endtask

  // ── Task helper: scrie o cerere de etaj pe buton_lift (0x01) ────────
  task scrie_buton_lift(int etaj);
    req = tranzactie_apb::type_id::create("req_lift");
    start_item(req);
    assert(req.randomize() with {
      addr == 8'h01;
      rw   == 1'b1;
      data == (8'h01 << etaj);
    });
    `uvm_info("secventa_apb_lift_ocupat",
      $sformatf("LIFT:  cerere etaj %0d (data=0x%02h)", etaj, req.data), UVM_LOW)
    finish_item(req);
  endtask

  // ── Task helper: declanseaza urgenta prin APB ────────────────────────
  task scrie_urgenta();
    req = tranzactie_apb::type_id::create("req_urgenta");
    start_item(req);
    assert(req.randomize() with {
      addr == 8'h01;
      rw   == 1'b1;
      data == 8'h80;        // bit 7 = emergency_stop
    });
    `uvm_info("secventa_apb_lift_ocupat", "URGENTA: emergency_stop activat prin APB", UVM_LOW)
    finish_item(req);
  endtask

  // ── Task helper: citeste un registru si returneaza valoarea ─────────
  task citeste_registru(input bit [7:0] adresa, output bit [7:0] valoare_citita);
    req = tranzactie_apb::type_id::create("req_citire");
    start_item(req);
    assert(req.randomize() with {
      addr == adresa;
      rw   == 1'b0;
    });
    finish_item(req);
    valoare_citita = req.data;  // populat de driver dupa captura PRDATA
    `uvm_info("secventa_apb_lift_ocupat",
      $sformatf("CITIRE: ADDR=0x%02h => DATA=0x%02h", adresa, valoare_citita),
      UVM_LOW)
  endtask

endclass

`endif