function theRandomWalk = randomWalk(aS, aMu, aSigma, aT, nt, last_only)
    % Return:
    %  theRandomWalk : n x 1 double - one random walk of an asset value
    % Parameters:
    %  aS     : double - start value
    %  aMu    : double - drift per year
    %  aSigma : double - volatility per year
    %  aT     : double - time until expiry in years
    %  nt     : double - time steps (optional)
    %  last_only : bool - return only the last value (optional)
    
    if nargin == 4
        nt = 100;
        last_only = false;
    elseif nargin == 5
        last_only = false;
    end
    
    % Variables definitions.
    dt = aT/nt;
    S = zeros([1, nt]);
    
    % Initial condition.
    S(1) = aS;
    
    % Computing random numbers.
    dX = sqrt(dt) * normrnd(0, 1, [1, nt-1]);
    
    % Precompute part of the equation, since it doesn't depend on s(i).
    f = 1.0 + aSigma * dX + aMu * dt;
    
    % Computing random walk.
    for i = 1:nt-1
        S(i+1) = S(i) * f(i);
    end
    
    if last_only
        theRandomWalk = S(end);
    else
        theRandomWalk = S;
    end
end
