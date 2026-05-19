`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_monitor
`define __req_ack_monitor

class monitor_req_ack extends uvm_monitor;

  `uvm_component_utils(monitor_req_ack)

  // coverage_req_ack este o clasa SV simpla — creata cu new() in constructor
  coverage_req_ack                        colector_coverage_req_ack;
  uvm_analysis_port #(tranzactie_req_ack) port_date_monitor_req_ack;
  virtual req_ack_interface_dut           interfata_monitor_req_ack;

  tranzactie_req_ack starea_preluata_req_ack;
  tranzactie_req_ack aux_tr_req_ack;

  function new(string name = "monitor_req_ack", uvm_component parent = null);
    super.new(name, parent);
    port_date_monitor_req_ack  = new("port_date_monitor_req_ack", this);
    colector_coverage_req_ack  = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    starea_preluata_req_ack =
      tranzactie_req_ack::type_id::create("starea_preluata_req_ack");
    aux_tr_req_ack =
      tranzactie_req_ack::type_id::create("aux_tr_req_ack");
    if (!uvm_config_db#(virtual req_ack_interface_dut)::get(
          this, "", "req_ack_interface_dut", interfata_monitor_req_ack))
      `uvm_fatal("MONITOR_REQ_ACK", "Nu s-a putut accesa interfata REQ/ACK a monitorului")
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    #100; // VIVADO ZERO-DELAY LOOP KILLER
    wait(interfata_monitor_req_ack.rst_n === 1'b1);

    forever begin
      @(posedge interfata_monitor_req_ack.obstacle_req);
      
      starea_preluata_req_ack.durata_obstacol         = 0;
      starea_preluata_req_ack.ack_primit              = 0;
      starea_preluata_req_ack.cicli_pana_la_ack       = 0;
      starea_preluata_req_ack.cicli_pana_la_ack_clear = 0;

      begin
        int latenta = 0;
        while (!interfata_monitor_req_ack.obstacle_ack) begin
          @(posedge interfata_monitor_req_ack.clk);
          latenta++;
          if (latenta > 3) break;
        end
        starea_preluata_req_ack.ack_primit        = interfata_monitor_req_ack.obstacle_ack;
        starea_preluata_req_ack.cicli_pana_la_ack = latenta;
      end

      while (interfata_monitor_req_ack.obstacle_req) begin
        @(posedge interfata_monitor_req_ack.clk);
        starea_preluata_req_ack.durata_obstacol++;
      end

      begin
        int latenta_clear = 0;
        while (interfata_monitor_req_ack.obstacle_ack) begin
          @(posedge interfata_monitor_req_ack.clk);
          latenta_clear++;
          if (latenta_clear > 2) break;
        end
        starea_preluata_req_ack.cicli_pana_la_ack_clear = latenta_clear;
      end

      aux_tr_req_ack = starea_preluata_req_ack.copy();
      port_date_monitor_req_ack.write(aux_tr_req_ack);

      colector_coverage_req_ack.update(starea_preluata_req_ack);
      colector_coverage_req_ack.stari_req_ack_cg.sample();
    end
  endtask

endclass : monitor_req_ack

`endif
