//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_coverage_collector
`define __apb_coverage_collector

// Clasa de coverage este o clasa SV simpla (nu uvm_component).
// Coverage nu are nevoie de faze UVM, config_db sau factory — doar sample().
// Monitorul o creeaza cu new() si apeleaza update() + sample() in run_phase.
class coverage_apb;

  // Scalari copiati din tranzactie inainte de sample()
  bit [7:0] cv_addr;
  bit       cv_rw;
  bit [7:0] cv_data;

  covergroup stari_apb_cg;
    option.per_instance = 1;

    // ── 1. Acoperire adrese ──────────────────────────────────────────
    cp_addr: coverpoint cv_addr {
      bins addr_buton_scara = {8'h00};
      bins addr_buton_lift  = {8'h01};
      bins addr_various     = {8'h02};
      bins addr_floor_mgmt  = {8'h03};
      bins addr_led_lift    = {8'h04};
      bins addr_led_scara   = {8'h05};
      bins addr_invalida    = default;
    }

    // ── 2. Acoperire tip operatie ────────────────────────────────────
    cp_rw: coverpoint cv_rw {
      bins citire  = {1'b0};
      bins scriere = {1'b1};
    }

    // ── 3. Acoperire date ────────────────────────────────────────────
    cp_data: coverpoint cv_data {
      bins etaj_0          = {8'h01};
      bins etaj_1          = {8'h02};
      bins etaj_2          = {8'h04};
      bins etaj_3          = {8'h08};
      bins etaj_4          = {8'h10};
      bins etaj_5          = {8'h20};
      bins etaj_6          = {8'h40};
      bins emergency_stop  = {8'h80};
      bins nicio_cerere    = {8'h00};
      bins cereri_multiple = default;
    }

    // ── 4. Cross: adresa x tip operatie ─────────────────────────────
    cx_addr_rw: cross cp_addr, cp_rw {
      illegal_bins scrie_various    = binsof(cp_addr.addr_various)    &&
                                      binsof(cp_rw.scriere);
      illegal_bins scrie_floor_mgmt = binsof(cp_addr.addr_floor_mgmt) &&
                                      binsof(cp_rw.scriere);
      illegal_bins scrie_led_lift   = binsof(cp_addr.addr_led_lift)   &&
                                      binsof(cp_rw.scriere);
      illegal_bins scrie_led_scara  = binsof(cp_addr.addr_led_scara)  &&
                                      binsof(cp_rw.scriere);
    }

    // cx_scriere_etaj (cross 3-way) eliminat — xsim 2024.2 nu suporta
    // cross cu 3 variabile + || in ignore_bins, cauzeaza FATAL la instantiere

  endgroup

  function new();
    stari_apb_cg = new();
  endfunction

  // Apelat de monitor inainte de fiecare sample()
  function void update(tranzactie_apb tr);
    cv_addr = tr.addr;
    cv_rw   = tr.rw;
    cv_data = tr.data;
  endfunction

  function void print_coverage();
    $display("=== RAPORT COVERAGE APB ===");
    $display("  Acoperire totala      : %.2f%%", stari_apb_cg.get_coverage());
    $display("  cp_addr               : %.2f%%", stari_apb_cg.cp_addr.get_coverage());
    $display("  cp_rw                 : %.2f%%", stari_apb_cg.cp_rw.get_coverage());
    $display("  cp_data               : %.2f%%", stari_apb_cg.cp_data.get_coverage());
    $display("  cx_addr_rw            : %.2f%%", stari_apb_cg.cx_addr_rw.get_coverage());
    $display("===========================");
  endfunction

endclass

`endif
