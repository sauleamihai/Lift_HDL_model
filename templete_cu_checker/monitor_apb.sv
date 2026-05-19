//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_monitor
`define __apb_monitor

class monitor_apb extends uvm_monitor;

  `uvm_component_utils(monitor_apb)

  // coverage_apb este acum o clasa SV simpla (nu uvm_component).
  // Poate fi creata cu new() direct in constructorul monitorului.
  coverage_apb colector_coverage_apb;

  uvm_analysis_port #(tranzactie_apb) port_date_monitor_apb;

  virtual apb_interface_dut interfata_monitor_apb;

  tranzactie_apb starea_preluata_a_apb;
  tranzactie_apb aux_tr_apb;

  function new(string name = "monitor_apb", uvm_component parent = null);
    super.new(name, parent);
    port_date_monitor_apb  = new("port_date_monitor_apb", this);
    colector_coverage_apb  = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    starea_preluata_a_apb = tranzactie_apb::type_id::create("starea_preluata_a_apb");
    aux_tr_apb            = tranzactie_apb::type_id::create("aux_tr_apb");
    if (!uvm_config_db#(virtual apb_interface_dut)::get(
          this, "", "apb_interface_dut", interfata_monitor_apb))
      `uvm_fatal("MONITOR_APB", "Nu s-a putut accesa interfata monitorului APB")
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    #100; // VIVADO ZERO-DELAY LOOP KILLER
    wait(interfata_monitor_apb.rst_n === 1'b1);

    forever begin
      wait(interfata_monitor_apb.psel == 1'b1 && interfata_monitor_apb.penable == 1'b1 && interfata_monitor_apb.rst_n == 1'b1);
      @(negedge interfata_monitor_apb.pclk);
      
      starea_preluata_a_apb.addr = interfata_monitor_apb.paddr;
      starea_preluata_a_apb.rw   = interfata_monitor_apb.pwrite;

      if (interfata_monitor_apb.pwrite)
        starea_preluata_a_apb.data = interfata_monitor_apb.pwdata;
      else
        starea_preluata_a_apb.data = interfata_monitor_apb.prdata;

      aux_tr_apb = starea_preluata_a_apb.copy();
      port_date_monitor_apb.write(aux_tr_apb);

      colector_coverage_apb.update(starea_preluata_a_apb);
      colector_coverage_apb.stari_apb_cg.sample();

      @(negedge interfata_monitor_apb.pclk);
    end
  endtask

endclass : monitor_apb

`endif
