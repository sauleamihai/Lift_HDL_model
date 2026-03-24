// Interfata butoane - fara clocking blocks (compatibil Vivado xsim)
interface butoane_interface(input logic clk, reset);

  logic [7:0] butoane_scara;
  logic [7:0] butoane_lift;

endinterface
