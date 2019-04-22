

module and_2_GT6100 (o1, i1, i2);
output o1;
input  i1, i2;

nand N1(x1, i1, i2),
     N2(o1, x1, x1);

endmodule

//////////////////////////
module xor_2_GT6100 (o1, i1, i2);
output o1;
input  i1, i2;

nand  N1(x1, i1, i1),
      N2(x2, i2, i2),
      N3(x3, i2, x1),
      N4(x4, x2, i1),
      N5(o1, x3, x4);
      

endmodule
    