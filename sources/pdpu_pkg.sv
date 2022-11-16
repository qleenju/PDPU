package pdpu_pkg;

    // --------------
    // General Helper Function
    // ---------------
    function automatic int maximum(int a, int b);
        return (a > b) ? a : b;
    endfunction

    function automatic integer clog2(input integer n);
        begin
            n = n-1;
            for(clog2=0; n>0; clog2=clog2+1)
                n = n>>1;
        end
    endfunction

endpackage