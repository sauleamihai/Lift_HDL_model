// File: lift.v
`ifndef LIFT_V
`define LIFT_V

module lift(
    input clk,
    input rst_n,
    input [7:0] buton_scara,
    input [7:0] buton_lift,
    input        obstacle_req,   // senzor obstacol: 1 = obstacol detectat in usa

    output reg [7:0] various_signals,
    output reg [7:0] floor_management,
    output reg [7:0] led_lift,
    output reg [7:0] led_scara,
    output reg       obstacle_ack  // DUT confirma: usa este tinuta deschisa
);

  localparam NUM_FLOORS = 8;

  // FSM states
  localparam STATE_IDLE      = 2'b00;
  localparam STATE_MOVE      = 2'b01;
  localparam STATE_DOOR_OPEN = 2'b10;
  localparam STATE_STOP      = 2'b11;

  // Timing parameters
  parameter MOVE_DELAY_CYCLES = 2;
  parameter DOOR_OPEN_CYCLES  = 3;
  parameter STOP_DELAY_CYCLES = 15;

  // Internal signals
  reg [1:0] state;
  reg [NUM_FLOORS-1:0] request_reg;
  reg [2:0] current_floor_reg;
  reg [2:0] last_request_floor_reg;
  reg error_reg;
  wire door_open = (state == STATE_DOOR_OPEN);

  reg [31:0] move_counter;
  reg [31:0] door_counter;
  reg [31:0] stop_counter;
  reg emergency_stop;
  reg direction;  // 1 = UP (etaj mai mare), 0 = DOWN (etaj mai mic)
  reg [2:0] destination;
  reg [2:0] temp_next_floor;

  // Numarare cereri in asteptare
  integer i;
  reg [3:0] pending_count;
  always @(*) begin
    pending_count = 0;
    for (i = 0; i < NUM_FLOORS; i = i + 1)
      pending_count = pending_count + request_reg[i];
  end

  // Gaseste urmatoarea cerere deasupra etajului curent
  function [2:0] find_next_up;
    input [2:0] curr;
    input [7:0] req;
    integer k;
    begin
      find_next_up = curr;
      for (k = curr + 1; k < NUM_FLOORS; k = k + 1) begin
        if (req[k]) begin
          find_next_up = k;
          k = NUM_FLOORS;
        end
      end
    end
  endfunction

  // Gaseste urmatoarea cerere sub etajul curent
  function [2:0] find_next_down;
    input [2:0] curr;
    input [7:0] req;
    integer k;
    begin
      find_next_down = curr;
      for (k = curr - 1; k >= 0; k = k - 1) begin
        if (req[k]) begin
          find_next_down = k;
          k = -1;
        end
      end
    end
  endfunction

  // Verifica daca exista cereri sub etajul curent
  function has_down_request;
    input [2:0] curr;
    input [7:0] req;
    integer k;
    begin
      has_down_request = 1'b0;
      for (k = 0; k < curr; k = k + 1)
        if (req[k]) has_down_request = 1'b1;
    end
  endfunction

  // various_signals: bit0=door_open, bit1=emergency_stop, bits7:2=pending_count
  always @(*) begin
    various_signals[0]   = door_open;
    various_signals[1]   = emergency_stop;
    various_signals[7:2] = {2'b0, pending_count};
  end

  // floor_management: bits7:5=current, 4:2=last_request, bit1=error, bit0=door_open
  always @(*) begin
    floor_management[7:5] = current_floor_reg;
    floor_management[4:2] = last_request_floor_reg;
    floor_management[1]   = error_reg;
    floor_management[0]   = door_open;
  end

  // FSM principal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                  <= STATE_IDLE;
      request_reg            <= 8'b0;
      current_floor_reg      <= 3'd0;
      last_request_floor_reg <= 3'd0;
      move_counter           <= 0;
      door_counter           <= 0;
      stop_counter           <= 0;
      emergency_stop         <= 0;
      direction              <= 1'b1;
      destination            <= 3'd0;
      error_reg              <= 1'b0;
      led_lift               <= 8'b0;
      led_scara              <= 8'b0;
      obstacle_ack           <= 1'b0;
    end else begin
      // Inregistreaza cereri noi
      request_reg <= request_reg | buton_scara | buton_lift;

      // LED REQ/ACK:
      // A) Aprinde imediat la apasare buton
      led_lift  <= led_lift  | buton_lift;
      led_scara <= led_scara | buton_scara;
      // B) Stinge cand usa se deschide la etajul curent (ultima asignare castiga)
      if (state == STATE_DOOR_OPEN) begin
        led_lift[current_floor_reg]  <= 1'b0;
        led_scara[current_floor_reg] <= 1'b0;
      end

      // Emergency stop
      if (emergency_stop) begin
        state <= STATE_STOP;
      end else begin
        case (state)
          STATE_IDLE: begin
            move_counter <= 0;
            door_counter <= 0;
            stop_counter <= 0;
            if (request_reg[current_floor_reg]) begin
              state                  <= STATE_DOOR_OPEN;
              last_request_floor_reg <= current_floor_reg;
              request_reg[current_floor_reg] <= 1'b0;
            end else if (pending_count > 0) begin
              if (| (request_reg >> (current_floor_reg + 1))) begin
                direction   <= 1'b1;  // UP
                destination <= find_next_up(current_floor_reg, request_reg);
              end else if (has_down_request(current_floor_reg, request_reg)) begin
                direction   <= 1'b0;  // DOWN
                destination <= find_next_down(current_floor_reg, request_reg);
              end
              state <= STATE_MOVE;
            end
          end

          STATE_MOVE: begin
            if (request_reg[current_floor_reg]) begin
              state                  <= STATE_DOOR_OPEN;
              last_request_floor_reg <= current_floor_reg;
              request_reg[current_floor_reg] <= 1'b0;
              move_counter <= 0;
            end else if (move_counter < MOVE_DELAY_CYCLES) begin
              move_counter <= move_counter + 1;
            end else begin
              move_counter <= 0;
              if (current_floor_reg < destination)
                temp_next_floor = current_floor_reg + 1;
              else if (current_floor_reg > destination)
                temp_next_floor = current_floor_reg - 1;
              else
                temp_next_floor = current_floor_reg;

              current_floor_reg <= temp_next_floor;

              if (temp_next_floor == destination) begin
                state                  <= STATE_DOOR_OPEN;
                last_request_floor_reg <= temp_next_floor;
                request_reg[temp_next_floor] <= 1'b0;
              end
            end
          end

          STATE_DOOR_OPEN: begin
            if (obstacle_req) begin
              // Obstacol detectat: reseteaza timerul si confirma prin ACK
              door_counter <= 0;
              obstacle_ack <= 1'b1;
            end else begin
              obstacle_ack <= 1'b0;
              if (door_counter < DOOR_OPEN_CYCLES)
                door_counter <= door_counter + 1;
              else begin
                door_counter <= 0;
                state        <= STATE_IDLE;
              end
            end
          end

          STATE_STOP: begin
            if (current_floor_reg > 0) begin
              if (move_counter < MOVE_DELAY_CYCLES)
                move_counter <= move_counter + 1;
              else begin
                move_counter      <= 0;
                current_floor_reg <= current_floor_reg - 1;
              end
            end else if (stop_counter < STOP_DELAY_CYCLES) begin
              stop_counter <= stop_counter + 1;
            end else begin
              stop_counter   <= 0;
              emergency_stop <= 0;
              state          <= STATE_DOOR_OPEN;
              request_reg    <= 8'b0;
            end
          end
        endcase
      end
    end
  end
endmodule

`endif // LIFT_V
