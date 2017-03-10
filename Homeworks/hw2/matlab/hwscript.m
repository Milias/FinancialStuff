function hwscript
    % Required variables.
    aS = 14.0;
    aMu = 0.02;
    aSigma = 0.2;
    aT = 0.27652860770583926; % 101 days in years.
    aE = 15.0;
    
    % Extra optional arguments.
    nt = 101; % 1 time step = 1 day
    N = 50000; % Amount of random walks to simulate.
    
    oP = optionPrice(aS, aMu, aSigma, aE, aT, nt, N)
end