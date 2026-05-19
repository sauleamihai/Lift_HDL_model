`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_sequence
`define __req_ack_sequence

class secventa_req_ack extends uvm_sequence #(tranzactie_req_ack);

  `uvm_object_utils(secventa_req_ack)

  rand int numarul_de_tranzactii;

  constraint marimea_sirului_c {
    soft numarul_de_tranzactii inside {[5:15]};
  }

  function new(string name = "secventa_req_ack");
    super.new(name);
  endfunction

  function void post_randomize();
    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("Secventa randomizata: %0d obstacole", numarul_de_tranzactii),
      UVM_LOW)
  endfunction

  // ── Secventa principala: obstacole cu durate random ─────────────────
  virtual task body();
    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("Incepe secventa cu %0d obstacole simulate", numarul_de_tranzactii),
      UVM_LOW)

    for (int i = 0; i < numarul_de_tranzactii; i++) begin
      req = tranzactie_req_ack::type_id::create("req");
      start_item(req);
      assert(req.randomize());
      `uvm_info("SECVENTA_REQ_ACK",
        $sformatf("[%0d/%0d] obstacol durata=%0d cicluri",
                  i+1, numarul_de_tranzactii, req.durata_obstacol),
        UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("Secventa finalizata: %0d obstacole trimise", numarul_de_tranzactii),
      UVM_LOW)
  endtask

  // ── Task helper: obstacol scurt (sub DOOR_OPEN_CYCLES) ──────────────
  // Ușa se va inchide normal dupa disparitia obstacolului
  task obstacol_scurt();
    req = tranzactie_req_ack::type_id::create("req_scurt");
    start_item(req);
    assert(req.randomize() with { durata_obstacol inside {[1:2]}; });
    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("Obstacol SCURT: %0d cicluri", req.durata_obstacol), UVM_LOW)
    finish_item(req);
  endtask

  // ── Task helper: obstacol lung (depaseste DOOR_OPEN_CYCLES) ─────────
  // Verifica ca FSM ramane in STATE_DOOR_OPEN pe toata durata
  task obstacol_lung();
    req = tranzactie_req_ack::type_id::create("req_lung");
    start_item(req);
    assert(req.randomize() with { durata_obstacol inside {[7:15]}; });
    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("Obstacol LUNG: %0d cicluri", req.durata_obstacol), UVM_LOW)
    finish_item(req);
  endtask

  // ── Task helper: obstacol cu durata exacta (directed test) ──────────
  task obstacol_fix(int durata);
    req = tranzactie_req_ack::type_id::create("req_fix");
    start_item(req);
    assert(req.randomize() with { durata_obstacol == durata; });
    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("Obstacol FIX: %0d cicluri", req.durata_obstacol), UVM_LOW)
    finish_item(req);
  endtask

  // ── Task helper: scenariul de stres — multiple obstacole consecutive ─
  task stres_obstacole(int nr_repetitii);
    `uvm_info("SECVENTA_REQ_ACK",
      $sformatf("STRES: %0d obstacole consecutive", nr_repetitii), UVM_LOW)
    repeat(nr_repetitii) obstacol_scurt();
  endtask

endclass

`endif
