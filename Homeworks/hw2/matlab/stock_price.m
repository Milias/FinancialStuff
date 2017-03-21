function stock_price(aS, aMu, aSigma, aE, aT, nt, N, call)
    x = linspace(aS - 5, aS + 5, 25);
    NoP = 20;
    
    [X, Ngrid] = ndgrid(x, 1:NoP);
    
    temp = arrayfun(@(x, n) optionPrice(x, aMu, aSigma, aE, aT, nt, N, call), X, Ngrid);
    oP_mean = mean(temp, 2);
    oP_std = std(temp, 0, 2);
    
    if call
        dlmwrite('../data/stock_call_x.txt', x);
        dlmwrite('../data/stock_call_mean.txt', oP_mean);
        dlmwrite('../data/stock_call_std.txt', oP_std);
    else
        dlmwrite('../data/stock_put_x.txt', x);
        dlmwrite('../data/stock_put_mean.txt', oP_mean);
        dlmwrite('../data/stock_put_std.txt', oP_std);
    end
end