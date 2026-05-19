//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __input_apb_sequence
`define __input_apb_sequence

class secventa_apb extends uvm_sequence #(tranzactie_apb);

  `uvm_object_utils(secventa_apb)

  // ── Parametri secventa ──────────────────────────────────────────────
  rand int numarul_de_tranzactii;

  constraint marimea_sirului_c {
    soft numarul_de_tranzactii inside {[5:15]};
  }

  function new(string name = "secventa_apb");
    super.new(name);
  endfunction

  function void post_randomize();
    `uvm_info("SECVENTA_APB",
      $sformatf("Secventa randomizata: %0d tranzactii", numarul_de_tranzactii),
      UVM_LOW)
  endfunction

  // ── Secventa principala: tranzactii random cu constrangeri lift ─────
  virtual task body();
    `uvm_info("SECVENTA_APB",
      $sformatf("Incepe secventa APB cu %0d tranzactii", numarul_de_tranzactii),
      UVM_LOW)

    for (int i = 0; i < numarul_de_tranzactii; i++) begin
      req = tranzactie_apb::type_id::create("req");
      start_item(req);

      // Constrangeri specifice liftului:
      // - addr: doar adrese valide (0x00-0x05)
      // - registrele RO (0x02-0x05) sunt INTOTDEAUNA citite
      // - registrele RW (0x00-0x01) pot fi citite sau scrise
      // - data: valori one-hot (un etaj) sau cazuri speciale
      assert(req.randomize() with {
        addr inside {8'h00, 8'h01, 8'h02, 8'h03, 8'h04, 8'h05};

        // Registre read-only — doar citire
        if (addr inside {8'h02, 8'h03, 8'h04, 8'h05})
          rw == 1'b0;

        // Date valide pentru scrieri: one-hot etaje sau zero
        if (rw == 1'b1)
          data inside {
            8'h00,                          // nicio cerere
            8'h01, 8'h02, 8'h04, 8'h08,    // etajele 0-3
            8'h10, 8'h20, 8'h40,            // etajele 4-6
            8'h80                           // urgenta / etaj 7
          };
      });

      `uvm_info("SECVENTA_APB",
        $sformatf("[%0d/%0d] Tranzactie generata", i+1, numarul_de_tranzactii),
        UVM_HIGH)
      req.afiseaza_informatia_tranzactiei();

      finish_item(req);
    end

    `uvm_info("SECVENTA_APB",
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
    `uvm_info("SECVENTA_APB",
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
    `uvm_info("SECVENTA_APB",
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
    `uvm_info("SECVENTA_APB", "URGENTA: emergency_stop activat prin APB", UVM_LOW)
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
    `uvm_info("SECVENTA_APB",
      $sformatf("CITIRE: ADDR=0x%02h => DATA=0x%02h", adresa, valoare_citita),
      UVM_LOW)
  endtask

endclass

`endif