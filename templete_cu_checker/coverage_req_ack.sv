`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_coverage
`define __req_ack_coverage

// Clasa de coverage este o clasa SV simpla (nu uvm_component).
class coverage_req_ack;

  int cv_durata_obstacol;
  int cv_cicli_pana_la_ack;
  int cv_cicli_pana_la_ack_clear;
  bit cv_ack_primit;

  covergroup stari_req_ack_cg;
    option.per_instance = 1;

    cp_durata: coverpoint cv_durata_obstacol {
      bins scurt  = {[1:3]};
      bins mediu  = {[4:6]};
      bins lung   = {[7:15]};
    }

    cp_latenta_ack: coverpoint cv_cicli_pana_la_ack {
      bins imediat   = {0};
      bins un_ciclu  = {1};
      bins doi_cicli = {2};
      bins intarziat = {[3:$]};
    }

    cp_latenta_ack_clear: coverpoint cv_cicli_pana_la_ack_clear {
      bins un_ciclu  = {1};
      bins doi_cicli = {2};
      bins intarziat = {[3:$]};
    }

    cp_ack_primit: coverpoint cv_ack_primit {
      bins ack_ok    = {1'b1};
      bins ack_lipsa = {1'b0};
    }

    cx_durata_latenta: cross cp_durata, cp_latenta_ack {
      ignore_bins ack_intarziat_scurt = binsof(cp_durata.scurt) &&
                                        binsof(cp_latenta_ack.intarziat);
      ignore_bins ack_intarziat_mediu = binsof(cp_durata.mediu) &&
                                        binsof(cp_latenta_ack.intarziat);
      ignore_bins ack_intarziat_lung  = binsof(cp_durata.lung)  &&
                                        binsof(cp_latenta_ack.intarziat);
    }

  endgroup

  function new();
    stari_req_ack_cg = new();
  endfunction

  function void update(tranzactie_req_ack tr);
    cv_durata_obstacol         = tr.durata_obstacol;
    cv_cicli_pana_la_ack       = tr.cicli_pana_la_ack;
    cv_cicli_pana_la_ack_clear = tr.cicli_pana_la_ack_clear;
    cv_ack_primit              = tr.ack_primit;
  endfunction

  function void print_coverage();
    $display("=== RAPORT COVERAGE REQ/ACK OBSTACOL ===");
    $display("  Acoperire totala     : %.2f%%", stari_req_ack_cg.get_coverage());
    $display("  cp_durata            : %.2f%%", stari_req_ack_cg.cp_durata.get_coverage());
    $display("  cp_latenta_ack       : %.2f%%", stari_req_ack_cg.cp_latenta_ack.get_coverage());
    $display("  cp_latenta_ack_clear : %.2f%%", stari_req_ack_cg.cp_latenta_ack_clear.get_coverage());
    $display("  cp_ack_primit        : %.2f%%", stari_req_ack_cg.cp_ack_primit.get_coverage());
    $display("  cx_durata_latenta    : %.2f%%", stari_req_ack_cg.cx_durata_latenta.get_coverage());
    $display("=========================================");
  endfunction

endclass

`endif
