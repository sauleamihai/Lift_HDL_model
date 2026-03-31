//-------------------------------------------------------------------------
//					testbench.sv
//-------------------------------------------------------------------------
// tbench_top or testbench top, this is the top most file, in which DUT
// (Design Under Test) and Verification environment are connected.
//-------------------------------------------------------------------------

`timescale 1ns/1ps

// including interface and testcase files
`include "output_interface.sv"
`include "apb_interface.sv"
`include "req_ack_interface.sv"
`include "obstacle_interface.sv"
`include "design.sv"

//-------------------------[NOTE]---------------------------------
// Particular testcase can be run by uncommenting, and commenting the rest
//`include "random_test.sv"
//`include "test_apb_rw_buttons.sv"
`include "test_change_direction.sv"
//`include "test_apasare_emergency.sv"
//`include "test_pready_timing.sv"

//----------------------------------------------------------------


module testbench;

  //clock and reset signal declaration
  bit clk;
  bit reset;

  //clock generation
  always #5 clk = ~clk;

  //reset Generation
  initial begin
    reset = 0;
    #30 reset =1;
  end


  //creating instance of interface, inorder to connect DUT and testcase
  // interfata pentru iesire
  output_interface output_intf(clk,reset);
  // interfata REQ/ACK (butoane + LED-uri)
  req_ack_interface req_ack_intf(clk,reset);
  // interfata pentru apb
  apb_interface apb_intf(clk,reset);
  // interfata senzor obstacol
  obstacle_interface obstacle_intf(clk,reset);

  //Testcase instance, interface handle is passed to test as an argument
  test test_7(output_intf, apb_intf, req_ack_intf, obstacle_intf);

  //DUT instance, interface signals are connected to the DUT ports
  top DUT (
    .PCLK(clk),
    .PRESETn(reset),

    .PADDR(apb_intf.PADDR),
    .PSEL(apb_intf.PSEL),
    .PWRITE(apb_intf.PWRITE),
    .PENABLE(apb_intf.PENABLE),
    .PWDATA(apb_intf.PWDATA),
    .PRDATA(apb_intf.PRDATA),
    .PREADY(apb_intf.PREADY),
    .PSLVERR(apb_intf.PSLVERR),

    .buton_scara(req_ack_intf.buton_scara),
    .buton_lift(req_ack_intf.buton_lift),
    .obstacle_req(obstacle_intf.req),
    .obstacle_ack(obstacle_intf.ack),
    .various_signals(output_intf.various_signals),
    .floor_management(output_intf.floor_management),
    .led_lift(req_ack_intf.led_lift),
    .led_scara(req_ack_intf.led_scara)

   );

  //enabling the wave dump
  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
  end
endmodule
