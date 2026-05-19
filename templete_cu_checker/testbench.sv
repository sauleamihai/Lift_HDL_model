`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "apb_interface_dut.sv"
`include "req_ack_interface_dut.sv"
`include "iesire_interface_dut.sv"
`include "test_exemplu.sv"
`include "test_lift_ocupat.sv"
`include "design.sv"

module top();

  logic clk;
  logic rst_n;

  // ── Generare Ceas FIXA (Fara macrouri, folosind unitati explicite) ──
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    clk = 0;
    forever begin
      #5ns; // Explicit 5 nanoseconds. Previne bucla Time 0!
      clk = ~clk;
    end
  end

  // ── Generare Reset ────────────────────────────────────────────────
  initial begin
    rst_n = 0;
    #100ns;
    rst_n = 1;
    #5000ns;
    $finish;
  end

  // ── Interfete ──────────────────────────────────────────────────────
  apb_interface_dut     intf_apb();
  req_ack_interface_dut intf_req_ack();
  iesire_interface_dut  intf_iesire();

  // ── Conexiuni ──────────────────────────────────────────────────────
  assign intf_apb.pclk      = clk;
  assign intf_req_ack.clk   = clk;
  assign intf_iesire.clk    = clk;
  
  assign intf_apb.rst_n     = rst_n;
  assign intf_req_ack.rst_n = rst_n;
  assign intf_iesire.rst_n  = rst_n;


  // ── Config DB & Start Test ─────────────────────────────────────────
  initial begin
    uvm_config_db#(virtual apb_interface_dut)::set(null, "*", "apb_interface_dut", intf_apb);
    uvm_config_db#(virtual req_ack_interface_dut)::set(null, "*", "req_ack_interface_dut", intf_req_ack);
    uvm_config_db#(virtual iesire_interface_dut)::set(null, "*", "iesire_interface_dut", intf_iesire);

    run_test("test_lift_ocupat");
  end

             


  // ── Instantiere DUT ────────────────────────────────────────────────

   my_dut DUT (
    .pclk_i              (clk),
    .rst_n_i             (rst_n),
    .paddr_i             (intf_apb.paddr),
    .psel_i              (intf_apb.psel),
    .pwrite_i            (intf_apb.pwrite),
    .penable_i           (intf_apb.penable),
    .pwdata_i            (intf_apb.pwdata),
    .prdata_o            (intf_apb.prdata),
    .pready_o            (intf_apb.pready),
    .pslverr_o           (intf_apb.pslverr),
    .led_lift_o          (intf_iesire.led_lift),
    .led_scara_o         (intf_iesire.led_scara),
    .various_signals_o   (intf_iesire.various_signals),
    .floor_management_o  (intf_iesire.floor_management),
    .obstacle_req_i      (intf_req_ack.obstacle_req),
    .obstacle_ack_o      (intf_req_ack.obstacle_ack)
  );

endmodule