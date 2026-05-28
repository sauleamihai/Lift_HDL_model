`ifndef LIFT_APB_V
`define LIFT_APB_V

`ifndef LIFT_V
`include "lift.v"
`endif

// ═══════════════════════════════════════════════════════════════════════════
//  MODUL: lift_apb
//  ROL  : Wrapper APB peste modulul `lift`. Expune controlul liftului prin
//         interfata APB-Lite (8 biti adresa + 8 biti date).
//
//  HARTA REGISTRELOR APB:
//   ┌──────┬───────┬──────────────────────────────────────────────────────┐
//   │ Addr │ Acces │ Nume si semnificatie                                 │
//   ├──────┼───────┼──────────────────────────────────────────────────────┤
//   │ 0x00 │ R/W   │ apb_buton_scara_reg — cereri de la palier (1 bit/etaj)│
//   │ 0x01 │ R/W   │ apb_buton_lift_reg  — cereri din cabina + bit 7 urgenta│
//   │ 0x02 │ RO    │ various_signals: [0]door [1]emg [7:2]pending          │
//   │ 0x03 │ RO    │ floor_management: [7:5]etaj [4:2]ultim [1]err [0]door │
//   │ 0x04 │ RO    │ led_lift  — LED ACK cabina (un bit per etaj 0-6)     │
//   │ 0x05 │ RO    │ led_scara — LED ACK palier (un bit per etaj 0-6)     │
//   │ 0x06+│ RO    │ default — returneaza 0xFF                            │
//   └──────┴───────┴──────────────────────────────────────────────────────┘
//
//  PROTOCOL APB-LITE (3 faze):
//    IDLE   : PSEL=0
//    SETUP  : PSEL=1, PENABLE=0   (DUT pune PREADY=1 pentru ciclul urmator)
//    ACCESS : PSEL=1, PENABLE=1   (transfer efectiv; PREADY=1 in acest ciclu)
//
//  TIMING:
//    PREADY este REGISTRAT — fires un ciclu dupa SETUP (asadar disponibil
//    exact in ACCESS, asa cum cere protocolul APB).
//    PRDATA este COMBINATORIAL — disponibil instant in ACCESS, fara latenta.
//    Aceasta separare evita bug-ul de "1 ciclu intarziere" pe citiri.
//
//  CONEXIUNI:
//    apb_buton_scara_reg ─┐
//                         ├─> driver pentru buton_scara/lift in `lift`
//    apb_buton_lift_reg  ─┘
//    (singura cale de control — interfata directa cu butoane a fost eliminata)
// ═══════════════════════════════════════════════════════════════════════════
module lift_apb (
    // ── Senzor obstacol (de la req_ack_interface) ──────────────────
    input  wire        obstacle_req,    // REQ: senzorul a detectat obstacol
    output wire        obstacle_ack,    // ACK: DUT confirma (puls 1 ciclu)

    // ── Iesiri DIRECTE (de la lift.v, expuse pentru monitor pasiv) ─
    output wire [7:0]  various_signals,  // status: door/emergency/pending
    output wire [7:0]  floor_management, // info etaje + door
    output wire [7:0]  led_lift,         // LED-uri ACK pentru cabina
    output wire [7:0]  led_scara,        // LED-uri ACK pentru palier

    // ── Interfata APB-Lite ──────────────────────────────────────────
    input  wire        PCLK,             // ceas APB
    input  wire        PRESETn,          // reset activ-low
    input  wire [7:0]  PADDR,            // adresa registru (8 biti)
    input  wire        PSEL,             // selectie slave
    input  wire        PWRITE,           // 1=scriere, 0=citire
    input  wire        PENABLE,          // faza ACCESS activa
    input  wire [7:0]  PWDATA,           // date scrise de master
    output reg  [7:0]  PRDATA,           // date citite (combinatorial)
    output reg         PREADY,           // confirmare transfer (registrat)
    output wire        PSLVERR           // eroare slave (mereu 0 in DUT-ul nostru)
);

  // ── Registrele APB pentru butoane ──────────────────────────────────
  // Acestea sunt singura cale prin care testbench-ul controleaza liftul.
  // O scriere APB la 0x00 actualizeaza apb_buton_scara_reg, care apoi
  // este conectat ca intrare `buton_scara` in `lift`. Logica de edge-detection
  // din `lift.v` se ocupa de a evita re-asertia continua a cererilor.
  reg [7:0] apb_buton_scara_reg;
  reg [7:0] apb_buton_lift_reg;

  // ── Instantiere modul lift (core) ──────────────────────────────────
  // Singura sursa de "butoane" este registrul APB — interfata directa
  // pentru butoane (cum era in versiunea anterioara) a fost eliminata.
  lift u_lift (
      .clk             (PCLK),
      .rst_n           (PRESETn),
      .buton_scara     (apb_buton_scara_reg),
      .buton_lift      (apb_buton_lift_reg),
      .obstacle_req    (obstacle_req),
      .various_signals (various_signals),
      .floor_management(floor_management),
      .led_lift        (led_lift),
      .led_scara       (led_scara),
      .obstacle_ack    (obstacle_ack)
  );

  // ── PSLVERR: DUT-ul nostru nu genereaza erori APB ──────────────────
  // Toate adresele sunt valide (citirea returneaza 0xFF la adrese invalide).
  // Asertiunea `a_no_slverr` din apb_interface_dut.sv valideaza acest fapt.
  assign PSLVERR = 1'b0;

  // ═══════════════════════════════════════════════════════════════════
  //  PREADY (registrat) — fires in ciclul urmator dupa SETUP
  // ═══════════════════════════════════════════════════════════════════
  // Logica: cand SETUP este activ (PSEL=1, PENABLE=0), scheduluim
  // PREADY <= 1, care va fi vizibil exact in ciclul ACCESS urmator.
  // In faza ACCESS, conditia (PSEL && !PENABLE) este falsa, deci PREADY
  // revine la 0 — fereastra de PREADY este exact 1 ciclu.
  //
  // Timing exemplu:
  //   Cycle N (SETUP):   PSEL=1, PENABLE=0 -> sched PREADY <= 1
  //   Cycle N+1 (ACCESS):PSEL=1, PENABLE=1, PREADY=1 (driver poate sampla)
  //   Cycle N+2 (IDLE):  PSEL=0,            PREADY=0
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
      PREADY <= 1'b0;
    else
      PREADY <= (PSEL && !PENABLE);
  end

  // ═══════════════════════════════════════════════════════════════════
  //  SCRIERI APB (sequential) — actualizeaza registrele in ACCESS
  // ═══════════════════════════════════════════════════════════════════
  // Doar 0x00 si 0x01 sunt R/W. Scrierile la alte adrese sunt ignorate.
  // Conditia (PSEL && PENABLE && PWRITE) asigura ca scriem doar in ACCESS.
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      apb_buton_scara_reg <= 8'd0;
      apb_buton_lift_reg  <= 8'd0;
    end else if (PSEL && PENABLE && PWRITE) begin
      case (PADDR)
        8'h00: apb_buton_scara_reg <= PWDATA;    // cereri palier
        8'h01: apb_buton_lift_reg  <= PWDATA;    // cereri cabina (bit 7 = urgenta)
        default: ;                               // scrieri la RO sunt ignorate
      endcase
    end
  end

  // ═══════════════════════════════════════════════════════════════════
  //  CITIRI APB (combinatorial) — PRDATA valid instant in ACCESS
  // ═══════════════════════════════════════════════════════════════════
  // De ce combinatorial?
  // Daca PRDATA ar fi registrat (cu NBA in always @(posedge PCLK)),
  // ar fi actualizat la ciclul urmator dupa ACCESS. Dar driverul citeste
  // PRDATA in ACCESS (cand PREADY=1), deci ar primi valoarea VECHE.
  // Asta cauza bug-ul "1 ciclu intarziere" — citiri returnau date din
  // tranzactia anterioara.
  //
  // Solutia: PRDATA = combinatorial. In afara ACCESS, PRDATA = 0x00.
  // Adresele invalide (0x06+) returneaza 0xFF (sentinela default).
  always @(*) begin
    if (PSEL && PENABLE && !PWRITE) begin
      case (PADDR)
        8'h00:   PRDATA = apb_buton_scara_reg;   // R/W mirror
        8'h01:   PRDATA = apb_buton_lift_reg;    // R/W mirror
        8'h02:   PRDATA = various_signals;       // RO: status
        8'h03:   PRDATA = floor_management;      // RO: etaj/eroare
        8'h04:   PRDATA = led_lift;              // RO: LED-uri cabina
        8'h05:   PRDATA = led_scara;             // RO: LED-uri palier
        default: PRDATA = 8'hFF;                 // RO: adresa invalida
      endcase
    end else begin
      PRDATA = 8'h00;                            // in afara ACCESS: idle
    end
  end
endmodule

`endif // LIFT_APB_V
