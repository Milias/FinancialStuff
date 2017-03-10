function dur(aS, aMu, aSigma, aE, aT, nt, N, call)
    x = linspace(0, 1, 25);
    NoP = 20;
    
    [X, Ngrid] = ndgrid(x, 1:NoP);
    
    temp = arrayfun(@(x, n) optionPrice(aS, aMu, aSigma, aE, x, nt, N, call), X, Ngrid);
    oP_mean = mean(temp, 2);
    oP_std = std(temp, 0, 2);
    
    if call
        dlmwrite('../data/dur_call_x.txt', x);
        dlmwrite('../data/dur_call_mean.txt', oP_mean);
        dlmwrite('../data/dur_call_std.txt', oP_std);
    else
        dlmwrite('../data/dur_put_x.txt', x);
        dlmwrite('../data/dur_put_mean.txt', oP_mean);
        dlmwrite('../data/dur_put_std.txt', oP_std);
    end
end