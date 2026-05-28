`ifndef LIFT_V
`define LIFT_V

// ═══════════════════════════════════════════════════════════════════════════
//  MODUL: lift
//  ROL  : Controller-ul principal al liftului — FSM cu 4 stari + logica
//         pentru gestionarea cererilor de la butoane si a obstacolelor
//
//  ARHITECTURA:
//    - 8 etaje (NUM_FLOORS=8), indexate 0..7
//    - 2 surse de cereri: buton_scara (apel din palier) si buton_lift (cabina)
//    - Senzor obstacol care tine usa deschisa (REQ/ACK protocol)
//    - LED-uri ACK care arata cererile pendinte (etajele 0-6, bit 7 = rezervat)
//
//  STATE MACHINE:
//    IDLE      -> asteapta cereri; daca apare cerere la etajul curent,
//                 deschide usa; altfel decide directie si trece in MOVE
//    MOVE      -> deplasare pas cu pas (1 etaj la fiecare MOVE_DELAY_CYCLES+1)
//    DOOR_OPEN -> usa deschisa DOOR_OPEN_CYCLES; obstacle_req reseteaza timer
//    STOP      -> stare de URGENTA: coboara la etaj 0 si asteapta evacuare
//
//  SEMANTICA BITULUI 7:
//    - In buton_lift[7]: FRONT ASCENDENT declanseaza emergency_stop
//    - In buton_scara[7]: cerere normala pentru etajul 7
//    - In led_lift[7]/led_scara[7]: REZERVAT — mereu 0
//    - In request_reg[7]: cerere normala pentru etajul 7
// ═══════════════════════════════════════════════════════════════════════════
module lift(
    input clk,                          // ceas sistem
    input rst_n,                        // reset activ pe nivel jos (asincron)
    input [7:0] buton_scara,            // cereri de la palier (din apb_buton_scara_reg)
    input [7:0] buton_lift,             // cereri din cabina (din apb_buton_lift_reg)
    input        obstacle_req,          // senzor obstacol: 1 = usa blocata

    output reg [7:0] various_signals,   // [0]=door_open [1]=emergency [7:2]=pending
    output reg [7:0] floor_management,  // [7:5]=etaj_curent [4:2]=ultim_etaj [1]=err [0]=door
    output reg [7:0] led_lift,          // LED ACK cabina (un bit per etaj 0-6)
    output reg [7:0] led_scara,         // LED ACK palier (un bit per etaj 0-6)
    output reg       obstacle_ack       // ACK obstacle (puls de 1 ciclu la frontul REQ)
);

  // ── Parametri si constante ─────────────────────────────────────────
  localparam NUM_FLOORS      = 8;        // numar total etaje
  localparam STATE_IDLE      = 2'b00;    // stare: stationar, asteapta cereri
  localparam STATE_MOVE      = 2'b01;    // stare: deplasare spre destinatie
  localparam STATE_DOOR_OPEN = 2'b10;    // stare: usa deschisa la un etaj
  localparam STATE_STOP      = 2'b11;    // stare: URGENTA, coboara la 0

  // Parametri de timing — configurabili la instantiere
  parameter MOVE_DELAY_CYCLES = 2;       // cicluri intre 2 etaje consecutive
  parameter DOOR_OPEN_CYCLES  = 3;       // durata standard de usa deschisa
  parameter STOP_DELAY_CYCLES = 15;      // asteptare evacuare la etaj 0 in urgenta

  // ── Registre de stare ──────────────────────────────────────────────
  reg [1:0] state;                      // starea curenta a FSM-ului
  reg [NUM_FLOORS-1:0] request_reg;     // 1 bit per etaj: cerere pendinta
  reg [2:0] current_floor_reg;          // etajul fizic curent al liftului
  reg [2:0] last_request_floor_reg;     // ultim etaj servit (info pentru floor_management)
  reg error_reg;                        // flag de eroare (momentan nefolosit)
  reg prev_obstacle_req;                // valoarea precedenta — pentru detectie front

  // ── Edge detection pe butoane ──────────────────────────────────────
  // Capturam DOAR tranzitiile 0->1 ale butoanelor pentru a evita livelock:
  // registrele APB (apb_buton_*_reg) pastreaza valoarea ultimei scrieri
  // pe timp nedefinit. Daca am OR-ui nivelul direct in request_reg, dupa
  // ce FSM-ul curata bitul, ar fi re-asertat in urmatorul ciclu, blocand
  // liftul intr-o cerere care se re-genereaza la infinit.
  reg [7:0] prev_buton_scara;
  reg [7:0] prev_buton_lift;
  wire [7:0] new_scara_req = buton_scara & ~prev_buton_scara;  // doar tranzitii 0->1
  wire [7:0] new_lift_req  = buton_lift  & ~prev_buton_lift;
  wire door_open = (state == STATE_DOOR_OPEN);                 // alias util

  // ── Contoare interne pentru tranzitii intre stari ──────────────────
  reg [31:0] move_counter;              // contor pentru MOVE_DELAY_CYCLES
  reg [31:0] door_counter;              // contor pentru DOOR_OPEN_CYCLES
  reg [31:0] stop_counter;              // contor pentru STOP_DELAY_CYCLES
  reg emergency_stop;                   // flag URGENTA (1 = STATE_STOP forced)
  reg direction;                        // 1 = sus, 0 = jos (folosit in MOVE)
  reg [2:0] destination;                // etajul tinta in STATE_MOVE
  reg [2:0] temp_next_floor;            // pas intermediar (variabila auxiliara)

  // ── Calculul pending_count (numar de cereri active) ────────────────
  // ATENTIE: folosim sensitivitate explicita pe request_reg pentru a evita
  // bucla infinita Time-0 din Vivado xsim (always @(*) cu integer `i` ar
  // re-evalua continuu in regiunea iterativa la timpul 0).
  integer i;
  reg [3:0] pending_count;              // poate atinge maxim 8 (4 biti = 0..15)
  always @(request_reg) begin
    pending_count = 0;
    for (i = 0; i < NUM_FLOORS; i = i + 1)
      pending_count = pending_count + request_reg[i];
  end

  // ── Functie: gaseste urmatorul etaj cu cerere SUS de la pozitia curr ──
  // Folosita pentru a determina destinatia in directia "sus".
  // Returneaza `curr` daca nu exista cerere mai sus (fallback).
  function [2:0] find_next_up;
    input [2:0] curr;
    input [7:0] req;
    integer k;
    begin
      find_next_up = curr;
      for (k = curr + 1; k < NUM_FLOORS; k = k + 1) begin
        if (req[k]) begin
          find_next_up = k;
          k = NUM_FLOORS;   // break din loop (Verilog nu are break nativ)
        end
      end
    end
  endfunction

  // ── Functie: gaseste urmatorul etaj cu cerere JOS de la pozitia current ──
  // Iteram descrescator pentru a gasi cel mai apropiat etaj cu cerere.
  function [2:0] find_next_down;
    input [2:0] curr;
    input [7:0] req;
    integer k;
    begin
      find_next_down = curr;
      for (k = curr - 1; k >= 0; k = k - 1) begin
        if (req[k]) begin
          find_next_down = k;
          k = -1;           // break din loop
        end
      end
    end
  endfunction

  // ── Functie: daca exista o cerere JOS de la pozitia current ───────────────
  // Helper pentru decizia de directie in STATE_IDLE.
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

  // ── Multiplexarea iesirilor various_signals ────────────────────────
  // Format: [7:2]=pending_count [1]=emergency [0]=door_open
  // Cele 6 biti superiori sunt pending_count extins cu 2 biti de zero
  always @(*) begin
    various_signals[0]   = door_open;
    various_signals[1]   = emergency_stop;
    various_signals[7:2] = {2'b0, pending_count};
  end

  // ── Multiplexarea iesirilor floor_management ───────────────────────
  // Format: [7:5]=etaj_curent [4:2]=ultim_etaj_servit [1]=eroare [0]=door
  always @(*) begin
    floor_management[7:5] = current_floor_reg;
    floor_management[4:2] = last_request_floor_reg;
    floor_management[1]   = error_reg;
    floor_management[0]   = door_open;
  end

  // ── Generare obstacle_ack (combinatorial, puls de 1 ciclu) ─────────
  // ACK-ul este activ DOAR in ciclul in care obstacle_req tocmai a urcat.
  // Astfel: latenta ACK = 1 ciclu, durata ACK = 1 ciclu (asertie prin SVA).
  always @(*) begin
    obstacle_ack = obstacle_req & ~prev_obstacle_req;
  end

  // ═══════════════════════════════════════════════════════════════════
  //  BLOCUL SEQUENTIAL PRINCIPAL — FSM + actualizari de stare
  // ═══════════════════════════════════════════════════════════════════
  always @(posedge clk or negedge rst_n) begin
    // ── Reset asincron: stare initiala ─────────────────────────────
    if (!rst_n) begin
      state                  <= STATE_IDLE;
      request_reg            <= 8'b0;
      current_floor_reg      <= 3'd0;       // liftul porneste la etaj 0
      last_request_floor_reg <= 3'd0;
      move_counter           <= 0;
      door_counter           <= 0;
      stop_counter           <= 0;
      emergency_stop         <= 0;
      direction              <= 1'b1;       // initial: sus
      destination            <= 3'd0;
      error_reg              <= 1'b0;
      led_lift               <= 8'b0;
      led_scara              <= 8'b0;
      prev_obstacle_req      <= 1'b0;
      prev_buton_scara       <= 8'b0;
      prev_buton_lift        <= 8'b0;
    end else begin
      // ── Actualizari (in fiecare ciclu, indiferent de stare) ──
      // Salvam valorile curente pentru detectia de front in ciclul urmator
      prev_obstacle_req <= obstacle_req;
      prev_buton_scara  <= buton_scara;
      prev_buton_lift   <= buton_lift;

      // Inregistreaza cererile NOI (doar fronturi 0->1).
      // Bitii ramanan setati in request_reg pana cand FSM-ul ii sterge
      // dupa servirea etajului respectiv (in STATE_DOOR_OPEN / STATE_STOP).
      request_reg <= request_reg | new_scara_req | new_lift_req;

      // Aprinde LED-urile pe biti 0-6 (bit 7 = rezervat pentru urgenta).
      // Masca 8'h7F = 8'b01111111 forteaza bit 7 sa fie 0.
      led_lift  <= led_lift  | (new_lift_req  & 8'h7F);
      led_scara <= led_scara | (new_scara_req & 8'h7F);

      // URGENTA: front ascendent pe buton_lift[7] declanseaza emergency_stop.
      // Folosim front (nu nivel) pentru a evita re-declansare permanenta
      // cat timp apb_buton_lift_reg ramane la 0x80.
      if (new_lift_req[7]) emergency_stop <= 1'b1;

      // Stinge LED-ul corespunzator etajului curent cand usa este deschisa
      // (liftul a "servit" cererea — vizual: pasagerul a intrat/iesit).
      if (state == STATE_DOOR_OPEN) begin
        led_lift[current_floor_reg]  <= 1'b0;
        led_scara[current_floor_reg] <= 1'b0;
      end

      // ── DECIZIA PRINCIPALA: STATE_STOP overrides totul ─────────────
      // Cand emergency_stop=1, fortam tranzitia in STATE_STOP (din ORICE stare).
      // Conditia `state != STATE_STOP` previne re-intrarea repetata
      // (altfel am reseta contoarele in fiecare ciclu cat timp emergency=1).
      if (emergency_stop && state != STATE_STOP) begin
        state <= STATE_STOP;
        move_counter <= 0;
        stop_counter <= 0;
      end else begin

        // ── FSM Principal ────────────────────────────────────────────
        case (state)
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          //  STATE_IDLE: liftul sta, decide ce sa faca in functie de cereri
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          STATE_IDLE: begin
            move_counter <= 0;
            door_counter <= 0;
            stop_counter <= 0;

            if (request_reg[current_floor_reg]) begin
              // Cerere chiar la etajul curent — deschidem usa imediat
              state                  <= STATE_DOOR_OPEN;
              last_request_floor_reg <= current_floor_reg;
              request_reg[current_floor_reg] <= 1'b0;
            end else if (pending_count > 0) begin
              // Avem cereri in alte parti — alegem directia (SCAN algorithm)
              if (| (request_reg >> (current_floor_reg + 1))) begin
                // Exista cereri mai sus de etajul curent — mergem SUS
                direction   <= 1'b1;
                destination <= find_next_up(current_floor_reg, request_reg);
              end else if (has_down_request(current_floor_reg, request_reg)) begin
                // Exista cereri sub etajul curent — mergem JOS
                direction   <= 1'b0;
                destination <= find_next_down(current_floor_reg, request_reg);
              end
              state <= STATE_MOVE;
            end
            // (else: pending_count=0 -> ramanem in IDLE)
          end

          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          //  STATE_MOVE: deplasare pas cu pas spre destinatie
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          STATE_MOVE: begin
            if (request_reg[current_floor_reg]) begin
              // S-a aparut o cerere chiar la etajul curent (pickup pe drum)
              // Oprim si deschidem usa.
              state                  <= STATE_DOOR_OPEN;
              last_request_floor_reg <= current_floor_reg;
              request_reg[current_floor_reg] <= 1'b0;
              move_counter <= 0;
            end else if (move_counter < MOVE_DELAY_CYCLES) begin
              // Asteptam intre etaje pentru efectul de "durata deplasare"
              move_counter <= move_counter + 1;
            end else begin
              // Timer expirat — facem un pas (sus sau jos)
              move_counter <= 0;
              if (current_floor_reg < destination)
                temp_next_floor = current_floor_reg + 1;
              else if (current_floor_reg > destination)
                temp_next_floor = current_floor_reg - 1;
              else
                temp_next_floor = current_floor_reg;  // deja la destinatie

              current_floor_reg <= temp_next_floor;

              // Daca am ajuns la destinatie — deschidem usa
              if (temp_next_floor == destination) begin
                state                  <= STATE_DOOR_OPEN;
                last_request_floor_reg <= temp_next_floor;
                request_reg[temp_next_floor] <= 1'b0;
              end
            end
          end

          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          //  STATE_DOOR_OPEN: usa deschisa, gestionam si obstacle_req
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          STATE_DOOR_OPEN: begin
            if (obstacle_req) begin
              // Obstacol detectat — RESETAM timer-ul, tinem usa deschisa
              // (mecanism de siguranta pentru pasageri)
              door_counter <= 0;
            end else begin
              // Fara obstacol — numaram cicluri pana cand inchidem usa
              if (door_counter < DOOR_OPEN_CYCLES)
                door_counter <= door_counter + 1;
              else begin
                // Timer expirat — inchidem usa, revenim in IDLE
                door_counter <= 0;
                state        <= STATE_IDLE;
              end
            end
          end

          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          //  STATE_STOP (URGENTA): coboara la etaj 0, deschide usa, reset
          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          STATE_STOP: begin
            if (current_floor_reg > 0) begin
              // Coboram pas cu pas spre etaj 0
              if (move_counter < MOVE_DELAY_CYCLES)
                move_counter <= move_counter + 1;
              else begin
                move_counter      <= 0;
                current_floor_reg <= current_floor_reg - 1;
              end
            end else if (stop_counter < STOP_DELAY_CYCLES) begin
              // La etaj 0 — asteptam evacuarea pasagerilor
              stop_counter <= stop_counter + 1;
            end else begin
              // Evacuare completa — eliberam urgenta si curatam toate cererile
              stop_counter   <= 0;
              emergency_stop <= 0;
              state          <= STATE_DOOR_OPEN;
              request_reg    <= 8'b0;  // RESET TOTAL — eliberam toate cererile
            end
          end
        endcase
      end
    end
  end
endmodule
`endif
