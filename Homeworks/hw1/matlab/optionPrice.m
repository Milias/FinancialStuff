function thePrice = optionPrice(aS, aMu, aSigma, aE, aT, nt, N, P)
    % Return:
    %  thePrice(1) : double - the price of an option with given parameters.
    %  thePrice(3) : double - average profit assuming aS(end) > aE.
    %  thePrice(3) : double - probability of value higher than aE.
    % Parameters:
    %  aS     : double - start value
    %  aMu    : double - drift per year
    %  aSigma : double - volatility per year
    %  aE     : double - the exercise price
    %  aT     : double - time until expiry in years
    %  nt     : int    - time steps (optional)
    %  N      : int    - number of random walks to be simulated (optional)
    %  P      : double - risk taken with profits (optional)
    
    if nargin == 5
        nt = aT*365.2425; % 1 timestep per day
        N = 10000;
    elseif nargin == 6
        N = 10000;
    end
    
    % fValues contains the profit of buying the share using the option.
    
    fValues = arrayfun(@(x) randomWalk(aS, aMu, aSigma, aT, nt, true), zeros([1, N])) - aE;
    
    % fValues is normally distributed, so we compute the mean and std.
    
    fVmu = mean(fValues);
    fVsigma = std(fValues);
    
    % Now we only take positive values.
    
    fValues = max(fValues, 0);
    
    % thePrice is then the average profit.
    
    thePrice = mean(fValues);
    
    %thePrice = [mean(fValues), sum(fValues(fValues>0))/sum(fValues>0), sum(fValues>0)/N];
    
    if nargin == 8
        thePrice = norminv(normcdf(thePrice, fVmu, fVsigma) * (1.0 - P) + P, fVmu, fVsigma);
    end
end
