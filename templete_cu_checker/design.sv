import uvm_pkg::*;

`include "uvm_macros.svh"
//modificat
`ifndef MY_DUT_SV
`define MY_DUT_SV

`ifndef LIFT_APB_V
`include "lift_apb.v"
`endif

module my_dut (
    // ── Clock & Reset ──────────────────────────────────────────
    input  wire        pclk_i,
    input  wire        rst_n_i,

    // ── APB Interface ──────────────────────────────────────────
    input  wire [7:0]  paddr_i,
    input  wire        psel_i,
    input  wire        pwrite_i,
    input  wire        penable_i,
    input  wire [7:0]  pwdata_i,
    output wire [7:0]  prdata_o,
    output wire        pready_o,
    output wire        pslverr_o,

    // ── REQ/ACK Butoane ────────────────────────────────────────
    //input  wire [7:0]  buton_lift_i,    // REQ – cereri cabina
    //input  wire [7:0]  buton_scara_i,   // REQ – cereri scara
    output wire [7:0]  led_lift_o,      // ACK – LED cabina
    output wire [7:0]  led_scara_o,     // ACK – LED scara

    // ── Iesiri stare ───────────────────────────────────────────
    output wire [7:0]  various_signals_o,
    output wire [7:0]  floor_management_o,

    // ── REQ/ACK Senzor Obstacol ────────────────────────────────
    input  wire        obstacle_req_i,  // REQ – obstacol detectat
    output wire        obstacle_ack_o   // ACK – usa tinuta deschisa
);

  lift_apb u_lift_apb (
    .PCLK             (pclk_i),
    .PRESETn          (rst_n_i),
    .PADDR            (paddr_i),
    .PSEL             (psel_i),
    .PWRITE           (pwrite_i),
    .PENABLE          (penable_i),
    .PWDATA           (pwdata_i),
    .PRDATA           (prdata_o),
    .PREADY           (pready_o),
    .PSLVERR          (pslverr_o),
  //  .buton_lift       (buton_lift_i),
   // .buton_scara      (buton_scara_i),
    .led_lift         (led_lift_o),
    .led_scara        (led_scara_o),
    .various_signals  (various_signals_o),
    .floor_management (floor_management_o),
    .obstacle_req     (obstacle_req_i),
    .obstacle_ack     (obstacle_ack_o)
  );

endmodule

`endif // MY_DUT_SV