# ═══════════════════════════════════════════════════════════════════
#  Script TCL pentru Vivado xsim 2024.2 — waveform complet pentru lift
#  Rulare in consola TCL a xsim:
#    > source C:/Users/saule/Desktop/.../wave_setup.tcl
#    > run all
# ═══════════════════════════════════════════════════════════════════

# Stergere semnale existente (daca exista)
catch {close_wave_config}

# Creeaza un nou waveform config
create_wave_config "lift_waveform"

# ── Grup 1: CLOCK & RESET ──────────────────────────────────────────
add_wave_divider "═══ 1. CLOCK & RESET ═══"
add_wave /top/clk
add_wave /top/rst_n

# ── Grup 2: APB PROTOCOL ───────────────────────────────────────────
add_wave_divider "═══ 2. APB PROTOCOL ═══"
add_wave /top/intf_apb/psel
add_wave /top/intf_apb/penable
add_wave /top/intf_apb/pwrite
add_wave /top/intf_apb/pready
add_wave /top/intf_apb/pslverr
add_wave -radix hex /top/intf_apb/paddr
add_wave -radix hex /top/intf_apb/pwdata
add_wave -radix hex /top/intf_apb/prdata

# ── Grup 3: REQ/ACK OBSTACOL ───────────────────────────────────────
add_wave_divider "═══ 3. OBSTACLE REQ/ACK ═══"
add_wave /top/intf_req_ack/obstacle_req
add_wave /top/intf_req_ack/obstacle_ack

# ── Grup 4: REGISTRE APB INTERNE ───────────────────────────────────
add_wave_divider "═══ 4. APB INTERNAL REGISTERS ═══"
add_wave -radix hex /top/DUT/u_lift_apb/apb_buton_scara_reg
add_wave -radix hex /top/DUT/u_lift_apb/apb_buton_lift_reg

# ── Grup 5: FSM LIFT (cel mai important) ───────────────────────────
add_wave_divider "═══ 5. LIFT FSM (CORE) ═══"
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/state
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/current_floor_reg
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/destination
add_wave /top/DUT/u_lift_apb/u_lift/direction
add_wave /top/DUT/u_lift_apb/u_lift/emergency_stop
add_wave /top/DUT/u_lift_apb/u_lift/door_open
add_wave -radix hex /top/DUT/u_lift_apb/u_lift/request_reg
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/pending_count
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/move_counter
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/door_counter
add_wave -radix unsigned /top/DUT/u_lift_apb/u_lift/stop_counter

# ── Grup 6: IESIRI VIZIBILE ────────────────────────────────────────
add_wave_divider "═══ 6. OUTPUTS (LED + STATUS) ═══"
add_wave -radix hex /top/intf_iesire/led_lift
add_wave -radix hex /top/intf_iesire/led_scara
add_wave -radix hex /top/intf_iesire/various_signals
add_wave -radix hex /top/intf_iesire/floor_management

puts "═══════════════════════════════════════════════════"
puts "  Waveform configurat cu succes!"
puts "  Acum executa:   run all"
puts "═══════════════════════════════════════════════════"
