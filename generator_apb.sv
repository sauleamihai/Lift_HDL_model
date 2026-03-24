class generator_apb;

  bit random_transaction;

  rand apb_transaction trans;
  rand apb_transaction tr;

  int repeat_count;

  mailbox apb_gen2driv;

  // eveniment public - environment.sv il va accesa direct
  event ended;

  function new(mailbox apb_gen2driv);
    this.apb_gen2driv = apb_gen2driv;
    trans = new();
  endfunction

  task main();
    if (random_transaction == 1) begin
      repeat(repeat_count) begin
        if (!trans.randomize())
          $fatal(1, "Gen:: trans randomization failed");
        tr = trans.do_copy();
        apb_gen2driv.put(tr);
      end
    end
    -> ended;
  endtask

  task write_reg(bit [2:0] addr1, bit [7:0] data1);
    if (!trans.randomize() with {paddr == addr1; pwdata == data1; pwrite == 1;})
      $fatal(1, "Gen:: trans randomization failed");
    tr = trans.do_copy();
    apb_gen2driv.put(tr);
  endtask

  task write_reg_with_delay(bit [2:0] addr1, bit [7:0] data1, int delay1);
    if (!trans.randomize() with {paddr == addr1; pwdata == data1; pwrite == 1; delay == delay1;})
      $fatal(1, "Gen:: trans randomization failed");
    tr = trans.do_copy();
    apb_gen2driv.put(tr);
  endtask

  task read_reg(bit [2:0] addr1);
    if (!trans.randomize() with {paddr == addr1; pwrite == 0;})
      $fatal(1, "Gen:: trans randomization failed");
    tr = trans.do_copy();
    apb_gen2driv.put(tr);
  endtask

  task read_reg_with_delay(bit [2:0] addr, int delay1);
    if (!trans.randomize() with {paddr == addr; pwrite == 0; delay == delay1;})
      $fatal(1, "Gen:: read_reg_with_delay randomization failed");
    tr = trans.do_copy();
    apb_gen2driv.put(tr);
  endtask

  task modify_reg_bits(bit [2:0] addr, bit [7:0] bitmask, bit value);
    bit [7:0] new_val;
    if (!trans.randomize() with {paddr == addr; pwrite == 0; delay == 0;})
      $fatal(1, "Gen:: modify_reg_bits: citirea a esuat");
    tr = trans.do_copy();
    apb_gen2driv.put(tr);
    if (value)
      new_val = tr.prdata | bitmask;
    else
      new_val = tr.prdata & ~bitmask;
    if (!trans.randomize() with {paddr == addr; pwdata == new_val; pwrite == 1; delay == 0;})
      $fatal(1, "Gen:: modify_reg_bits: scrierea a esuat");
    tr = trans.do_copy();
    apb_gen2driv.put(tr);
  endtask

endclass
