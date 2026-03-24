// aici se declara tipul de data folosit pentru a stoca datele vehiculate intre
// generator si driver; monitorul, de asemenea, preia datele de pe interfata,
// le recompune folosind un obiect al acestui tip de data, si numai apoi le proceseaza
class transaction_out;
  // se declara atributele clasei
  bit [7:0] various_signals;
  bit [7:0] floor_management;

	int delay;

  // Constructor pentru initializare
  function new();

  endfunction

  // aceasta functie este apelata dupa aplicarea functiei randomize() asupra obiectelor apartinand acestei clase
  function void post_randomize();
    $display("--------- [Trans] post_randomize ------");
    $display("\t various_signals  = %0h\t floor_management = %0h\t delay = %0d",
             various_signals, floor_management, delay);
    $display("-----------------------------------------");
  endfunction

  // operator de copiere a unui obiect intr-un alt obiect (deep copy)
  function transaction_out do_copy();
    transaction_out trans;
    trans = new();
    trans.various_signals  = this.various_signals;
    trans.floor_management = this.floor_management;
    trans.delay = this.delay;
    return trans;
  endfunction


  // Afisare a tranzactiei
  function void print();
    $display("Transaction: various_signals=%0h, floor_management=%0b, delay=%0h", various_signals, floor_management, delay);
  endfunction

endclass
