function hw1script
    % Required variables.
    aS = 14.0;
    aMu = 0.02;
    aSigma = 0.2;
    aT = 0.27652860770583926; % 101 days in years.
    aE = 15.0;
    
    % Extra optional arguments.
    nt = 101; % 1 time step = 1 day
    N = 100000; % Amount of random walks to simulate.
    P = linspace(0,1,100); %0.25;
    
    % Random walk histogram
    nbins = 20;
    [counts, edges] = histcounts(arrayfun(@(x) randomWalk(aS, aMu, aSigma, aT, nt, true), zeros([1, N])) - aE, nbins);
    
    dlmwrite('../data/rw-hist-N.txt', counts);
    dlmwrite('../data/rw-hist-edges.txt', edges);
    
    oP = arrayfun(@(P) optionPrice(aS, aMu, aSigma, aE, aT, nt, N, P), P);
    profit = 1 + oP/aE;
    
    dlmwrite('../data/P.txt', P);
    dlmwrite('../data/oP.txt', oP);
    dlmwrite('../data/profit.txt', profit);
    
    %plot(P, oP, 'Linewidth', 3)
end