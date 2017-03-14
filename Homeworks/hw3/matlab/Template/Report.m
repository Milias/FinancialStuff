function Report(aTrades)
    % Report the cash and position given the trades
    load('ownTrades.mat');
    aTrades = ownTrades;
    
    myIsinLabels = unique(ownTrades.ISIN);
    
    myData = struct;
    myData.assets = zeros(size(myIsinLabels), 'double');
    myData.cash = zeros(size(myIsinLabels), 'double');
    
    for i = 1:size(myIsinLabels, 1)
        t = strcmp(aTrades.ISIN,myIsinLabels(i));
        myData.assets(i) = sum(aTrades.side(t).*aTrades.volume(t));
        myData.cash(i) = sum(-aTrades.side(t).*aTrades.price(t).*aTrades.volume(t));
    end
    
    fprintf('%s, %s, Total\n', char(myIsinLabels(1)), char(myIsinLabels(2)))
    fprintf('Assets: %d, %d, %d\n', myData.assets, sum(myData.assets))
    fprintf('Cash : %.2f, %.2f, %.2f\n', myData.cash, sum(myData.cash))
end
