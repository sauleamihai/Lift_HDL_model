class button_generator;

  rand button_transaction trans;
  rand button_transaction tr;

  int repeat_count;
  bit random_generation = 0;

  mailbox gen2driv;

  // eveniment public - environment.sv il va accesa direct
  event ended;

  function new(mailbox gen2driv);
    this.gen2driv = gen2driv;
    trans = new();
  endfunction

  task main();
    if (random_generation == 1) begin
      repeat(repeat_count) begin
        if (!trans.randomize())
          $fatal(1, "Gen:: trans randomization failed");
        tr = trans.do_copy();
        gen2driv.put(tr);
      end
    end
    -> ended;
  endtask

  task write_buttons(input int floor_idx, input bit is_lift_btn, input int tick_delay);
    bit [7:0] scara_vec;
    bit [7:0] lift_vec;
    int       loc_delay;
    scara_vec = 8'b0;
    lift_vec  = 8'b0;
    loc_delay = tick_delay;
    if (is_lift_btn)
      lift_vec[floor_idx]  = 1'b1;
    else
      scara_vec[floor_idx] = 1'b1;
    if (!trans.randomize() with {
          buton_scara == scara_vec;
          buton_lift  == lift_vec;
          delay       == loc_delay;
        })
      $fatal(1, "Gen:: write_buttons randomization failed");
    tr = trans.do_copy();
    gen2driv.put(tr);
  endtask

  task write_buttons_with_delay(bit [7:0] butoane_scara_val, bit [7:0] butoane_lift_val, int delay_val);
    if (!trans.randomize() with {
        buton_scara == butoane_scara_val;
        buton_lift  == butoane_lift_val;
        delay       == delay_val;
    })
      $fatal(1, "Gen:: write_buttons_with_delay randomization failed");
    tr = trans.do_copy();
    gen2driv.put(tr);
  endtask

endclass
