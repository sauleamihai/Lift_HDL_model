// Interfata output - fara clocking blocks (compatibil Vivado xsim)
interface output_interface(input logic clk, input logic reset);

  logic [7:0] various_signals;
  logic [7:0] floor_management;

endinterface
