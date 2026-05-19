`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __iesire_monitor
`define __iesire_monitor

class monitor_iesire extends uvm_monitor;

  `uvm_component_utils(monitor_iesire)

  // coverage_iesire este o clasa SV simpla — creata cu new() in constructor
  coverage_iesire                        colector_coverage_iesire;
  uvm_analysis_port #(tranzactie_iesire) port_date_monitor_iesire;
  virtual iesire_interface_dut           interfata_monitor_iesire;

  tranzactie_iesire starea_preluata_iesire;
  tranzactie_iesire aux_tr_iesire;

  function new(string name = "monitor_iesire", uvm_component parent = null);
    super.new(name, parent);
    port_date_monitor_iesire  = new("port_date_monitor_iesire", this);
    colector_coverage_iesire  = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    starea_preluata_iesire =
      tranzactie_iesire::type_id::create("starea_preluata_iesire");
    aux_tr_iesire =
      tranzactie_iesire::type_id::create("aux_tr_iesire");
    if (!uvm_config_db#(virtual iesire_interface_dut)::get(
          this, "", "iesire_interface_dut", interfata_monitor_iesire))
      `uvm_fatal("MONITOR_IESIRE", "Nu s-a putut accesa interfata de iesire")
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    #100; // VIVADO ZERO-DELAY LOOP KILLER
    wait(interfata_monitor_iesire.rst_n === 1'b1);

    forever begin
      @(negedge interfata_monitor_iesire.clk);

      starea_preluata_iesire.led_lift         = interfata_monitor_iesire.led_lift;
      starea_preluata_iesire.led_scara        = interfata_monitor_iesire.led_scara;
      starea_preluata_iesire.various_signals  = interfata_monitor_iesire.various_signals;
      starea_preluata_iesire.floor_management = interfata_monitor_iesire.floor_management;

      starea_preluata_iesire.decodeaza();

      if (starea_preluata_iesire.various_signals != 8'h00 || starea_preluata_iesire.led_lift != 8'h00 || starea_preluata_iesire.led_scara != 8'h00) begin
        aux_tr_iesire = starea_preluata_iesire.copy();
        port_date_monitor_iesire.write(aux_tr_iesire);

        colector_coverage_iesire.update(starea_preluata_iesire);
        colector_coverage_iesire.stari_iesire_cg.sample();
      end
    end
  endtask

endclass : monitor_iesire

`endif
