function hwscript
    % Initial variables.
    aS = 14.0;
    aMu = 0.02;
    aSigma = 0.2;
    aT = 0.27652860770583926; % 101 days in years.
    aE = 15.0;
    
    % Extra optional arguments.
    nt = 101; % 1 time step = 1 day
    N = 2000; % Amount of random walks to simulate.
    
    % Changing stock price.
    
    disp('Stock price call.')
    stock_price(aS, aMu, aSigma, aE, aT, nt, N, true)
    disp('Stock price put.')
    stock_price(aS, aMu, aSigma, aE, aT, nt, N, false)
    
    % Changing volatility.
    
    disp('Volatility call.')
    vol(aS, aMu, aSigma, aE, aT, nt, N, true)
    disp('Volatility put.')
    vol(aS, aMu, aSigma, aE, aT, nt, N, false)
    
    % Changing duration.
    
    disp('Duration call.')
    dur(aS, aMu, aSigma, aE, aT, nt, N, true)
    disp('Duration put.')
    dur(aS, aMu, aSigma, aE, aT, nt, N, false)
    
    % Changing drift.
    
    disp('Drift call.')
    option_drift(aS, aMu, aSigma, aE, aT, nt, N, true)
    disp('Drift put.')
    option_drift(aS, aMu, aSigma, aE, aT, nt, N, false)
end