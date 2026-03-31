`ifndef DESIGN_SV
`define DESIGN_SV

`ifndef LIFT_APB_V
`include "lift_apb.v"
`endif

// Top module: O singura instanta de lift prin lift_apb
// Butoanele directe si APB sunt ambele conectate la acelasi lift
module top(
    input wire [7:0]  buton_scara,
    input wire [7:0]  buton_lift,
    input wire        obstacle_req,
    output wire       obstacle_ack,

    output wire [7:0] various_signals,
    output wire [7:0] floor_management,
    output wire [7:0] led_lift,
    output wire [7:0] led_scara,

    // APB interface
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [7:0]  PADDR,
    input  wire        PSEL,
    input  wire        PWRITE,
    input  wire        PENABLE,
    input  wire [7:0]  PWDATA,
    output wire [7:0]  PRDATA,
    output wire        PREADY,
    output wire        PSLVERR
);

  lift_apb u_lift_apb(
    .buton_scara      (buton_scara),
    .buton_lift       (buton_lift),
    .obstacle_req     (obstacle_req),
    .obstacle_ack     (obstacle_ack),
    .various_signals  (various_signals),
    .floor_management (floor_management),
    .led_lift         (led_lift),
    .led_scara        (led_scara),
    .PCLK             (PCLK),
    .PRESETn          (PRESETn),
    .PADDR            (PADDR),
    .PSEL             (PSEL),
    .PWRITE           (PWRITE),
    .PENABLE          (PENABLE),
    .PWDATA           (PWDATA),
    .PRDATA           (PRDATA),
    .PREADY           (PREADY),
    .PSLVERR          (PSLVERR)
  );

endmodule

`endif // DESIGN_SV
