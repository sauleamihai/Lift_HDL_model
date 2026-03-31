`ifndef LIFT_APB_V
`define LIFT_APB_V

`ifndef LIFT_V
`include "lift.v"
`endif

// Modul APB care inconjoara lift.v
// Accepta butoane atat prin interfata directa cat si prin scriere APB (OR intre ele)
// Expune toate iesirile lift.v la nivelul modulului
module lift_apb (
    // Butoane directe (de la req_ack_interface)
    input  wire [7:0]  buton_scara,
    input  wire [7:0]  buton_lift,

    // Senzor obstacol (de la obstacle_interface)
    input  wire        obstacle_req,
    output wire        obstacle_ack,

    // Iesiri directe ale liftului
    output wire [7:0]  various_signals,
    output wire [7:0]  floor_management,
    output wire [7:0]  led_lift,
    output wire [7:0]  led_scara,

    // Interfata APB
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [7:0]  PADDR,
    input  wire        PSEL,
    input  wire        PWRITE,
    input  wire        PENABLE,
    input  wire [7:0]  PWDATA,
    output reg  [7:0]  PRDATA,
    output reg         PREADY,
    output wire        PSLVERR
);

  // Registre APB pentru butoane (scriere prin APB)
  reg [7:0] apb_buton_scara_reg;
  reg [7:0] apb_buton_lift_reg;

  // O singura instanta de lift
  // Butoanele = OR intre interfata directa si registrele APB
  lift u_lift (
      .clk             (PCLK),
      .rst_n           (PRESETn),
      .buton_scara     (buton_scara | apb_buton_scara_reg),
      .buton_lift      (buton_lift  | apb_buton_lift_reg),
      .obstacle_req    (obstacle_req),
      .various_signals (various_signals),
      .floor_management(floor_management),
      .led_lift        (led_lift),
      .led_scara       (led_scara),
      .obstacle_ack    (obstacle_ack)
  );

  assign PSLVERR = 1'b0;

  // PREADY: activ in faza enable
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
      PREADY <= 1'b0;
    else
      PREADY <= (PSEL && !PENABLE);
  end

  // Logica de citire/scriere APB
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      apb_buton_scara_reg <= 8'd0;
      apb_buton_lift_reg  <= 8'd0;
      PRDATA              <= 8'd0;
    end else if (PSEL && PENABLE) begin
      if (PWRITE) begin
        case (PADDR)
          8'h00: apb_buton_scara_reg <= PWDATA;
          8'h01: apb_buton_lift_reg  <= PWDATA;
          default: ;
        endcase
      end else begin
        case (PADDR)
          8'h00: PRDATA <= apb_buton_scara_reg;
          8'h01: PRDATA <= apb_buton_lift_reg;
          8'h02: PRDATA <= various_signals;
          8'h03: PRDATA <= floor_management;
          8'h04: PRDATA <= led_lift;
          8'h05: PRDATA <= led_scara;
          default: PRDATA <= 8'hFF;
        endcase
      end
    end
  end
endmodule

`endif // LIFT_APB_V
