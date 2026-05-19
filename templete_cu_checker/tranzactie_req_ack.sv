`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_transaction
`define __req_ack_transaction

// Tranzactia modeleza un eveniment complet de obstacol:
//   REQ: senzorul detecteaza un obstacol (obstacle_req = 1)
//   ACK: DUT confirma ca tine usa deschisa (obstacle_ack = 1)
//   La sfarsit: REQ coboara, ACK trebuie sa coboare in ciclul urmator

class tranzactie_req_ack extends uvm_sequence_item;

  `uvm_object_utils(tranzactie_req_ack)

  // ── REQ: parametrii obstacolului (drivat de sequencer) ─────────────
  rand int durata_obstacol;   // cate cicluri ramane obstacle_req activ

  // ── ACK: raspunsul DUT-ului (capturat de monitor) ──────────────────
  bit ack_primit;             // 1 daca obstacle_ack a urmat REQ in 1 ciclu
  int cicli_pana_la_ack;      // latenta ACK in cicluri de ceas
  int cicli_pana_la_ack_clear; // cicluri pana la dezactivarea ACK dupa REQ

  // ── Constrangeri ───────────────────────────────────────────────────
  // Obstacol scurt: 1-3 cicluri (mai putin decat DOOR_OPEN_CYCLES=3)
  // Obstacol mediu: 4-6 cicluri (cat DOOR_OPEN_CYCLES)
  // Obstacol lung:  7-15 cicluri (mult mai mult decat DOOR_OPEN_CYCLES)
  constraint durata_c {
    soft durata_obstacol inside {[1:15]};
  }

  // Distributie ponderata intre cele 3 categorii de durata
  constraint distributie_c {
    durata_obstacol dist {
      [1:3]  :/ 30,   // scurt
      [4:6]  :/ 40,   // mediu
      [7:15] :/ 30    // lung
    };
  }

  function new(string name = "tranzactie_req_ack");
    super.new(name);
    durata_obstacol      = 1;
    ack_primit           = 0;
    cicli_pana_la_ack    = 0;
    cicli_pana_la_ack_clear = 0;
  endfunction

  function void afiseaza_informatia_tranzactiei();
    $display("[REQ/ACK TRZ] durata_obstacol=%0d cicli | ack_primit=%0b | latenta_ack=%0d cicli | ack_clear=%0d cicli",
             durata_obstacol, ack_primit,
             cicli_pana_la_ack, cicli_pana_la_ack_clear);
  endfunction

  function tranzactie_req_ack copy();
    copy                         = new();
    copy.durata_obstacol         = this.durata_obstacol;
    copy.ack_primit              = this.ack_primit;
    copy.cicli_pana_la_ack       = this.cicli_pana_la_ack;
    copy.cicli_pana_la_ack_clear = this.cicli_pana_la_ack_clear;
    return copy;
  endfunction

endclass
`endif
