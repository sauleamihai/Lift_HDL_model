`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __iesire_coverage
`define __iesire_coverage

// Clasa de coverage este o clasa SV simpla (nu uvm_component).
class coverage_iesire;

  bit [2:0] cv_etaj_curent;
  bit       cv_door_open;
  bit       cv_emergency_stop;
  bit [5:0] cv_pending_count;
  bit [7:0] cv_led_lift;
  bit [7:0] cv_led_scara;

  covergroup stari_iesire_cg;
    option.per_instance = 1;

    cp_etaj_curent: coverpoint cv_etaj_curent {
      bins etaj_0 = {3'd0};
      bins etaj_1 = {3'd1};
      bins etaj_2 = {3'd2};
      bins etaj_3 = {3'd3};
      bins etaj_4 = {3'd4};
      bins etaj_5 = {3'd5};
      bins etaj_6 = {3'd6};
      bins etaj_7 = {3'd7};
    }

    cp_door_open: coverpoint cv_door_open {
      bins inchisa  = {1'b0};
      bins deschisa = {1'b1};
    }

    cp_emergency: coverpoint cv_emergency_stop {
      bins normal  = {1'b0};
      bins urgenta = {1'b1};
    }

    cp_pending: coverpoint cv_pending_count {
      bins nicio     = {6'd0};
      bins una       = {6'd1};
      bins doua_trei = {[6'd2 : 6'd3]};
      bins multe     = {[6'd4 : 6'd8]};
    }

    cp_led_lift: coverpoint cv_led_lift {
      wildcard bins led_etaj_0 = {8'b????_???1};
      wildcard bins led_etaj_1 = {8'b????_??1?};
      wildcard bins led_etaj_2 = {8'b????_?1??};
      wildcard bins led_etaj_3 = {8'b????_1???};
      wildcard bins led_etaj_4 = {8'b???1_????};
      wildcard bins led_etaj_5 = {8'b??1?_????};
      wildcard bins led_etaj_6 = {8'b?1??_????};
      bins toate_stinse = {8'h00};
    }

    cp_led_scara: coverpoint cv_led_scara {
      wildcard bins led_etaj_0 = {8'b????_???1};
      wildcard bins led_etaj_1 = {8'b????_??1?};
      wildcard bins led_etaj_2 = {8'b????_?1??};
      wildcard bins led_etaj_3 = {8'b????_1???};
      wildcard bins led_etaj_4 = {8'b???1_????};
      wildcard bins led_etaj_5 = {8'b??1?_????};
      wildcard bins led_etaj_6 = {8'b?1??_????};
      bins toate_stinse = {8'h00};
    }

    cx_etaj_door: cross cp_etaj_curent, cp_door_open {
      ignore_bins etaj_fara_usa = binsof(cp_door_open.inchisa);
    }

    cx_etaj_pending: cross cp_etaj_curent, cp_pending {
      ignore_bins nicio_cerere = binsof(cp_pending.nicio);
    }

  endgroup

  function new();
    stari_iesire_cg = new();
  endfunction

  function void update(tranzactie_iesire tr);
    cv_etaj_curent    = tr.etaj_curent;
    cv_door_open      = tr.door_open;
    cv_emergency_stop = tr.emergency_stop;
    cv_pending_count  = tr.pending_count;
    cv_led_lift       = tr.led_lift;
    cv_led_scara      = tr.led_scara;
  endfunction

  function void print_coverage();
    $display("=== RAPORT COVERAGE IESIRI DUT ===");
    $display("  Acoperire totala   : %.2f%%", stari_iesire_cg.get_coverage());
    $display("  cp_etaj_curent     : %.2f%%", stari_iesire_cg.cp_etaj_curent.get_coverage());
    $display("  cp_door_open       : %.2f%%", stari_iesire_cg.cp_door_open.get_coverage());
    $display("  cp_emergency       : %.2f%%", stari_iesire_cg.cp_emergency.get_coverage());
    $display("  cp_pending         : %.2f%%", stari_iesire_cg.cp_pending.get_coverage());
    $display("  cp_led_lift        : %.2f%%", stari_iesire_cg.cp_led_lift.get_coverage());
    $display("  cp_led_scara       : %.2f%%", stari_iesire_cg.cp_led_scara.get_coverage());
    $display("  cx_etaj_door       : %.2f%%", stari_iesire_cg.cx_etaj_door.get_coverage());
    $display("  cx_etaj_pending    : %.2f%%", stari_iesire_cg.cx_etaj_pending.get_coverage());
    $display("==================================");
  endfunction

endclass

`endif
