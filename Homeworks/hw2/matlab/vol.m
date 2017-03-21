function vol(aS, aMu, aSigma, aE, aT, nt, N, call)
    x = linspace(0, 1, 25);
    NoP = 20;
    
    [X, Ngrid] = ndgrid(x, 1:NoP);
    
    temp = arrayfun(@(x, n) optionPrice(aS, aMu, x, aE, aT, nt, N, call), X, Ngrid);
    oP_mean = mean(temp, 2);
    oP_std = std(temp, 0, 2);
    
    if call
        dlmwrite('../data/vol_call_x.txt', x);
        dlmwrite('../data/vol_call_mean.txt', oP_mean);
        dlmwrite('../data/vol_call_std.txt', oP_std);
    else
        dlmwrite('../data/vol_put_x.txt', x);
        dlmwrite('../data/vol_put_mean.txt', oP_mean);
        dlmwrite('../data/vol_put_std.txt', oP_std);
    end 
end