function Report(aTrades)
    % Report the cash and position given the trades
    myIsinLabels = unique(aTrades.ISIN);

    myData = struct;
    myData.assets = zeros(size(myIsinLabels), 'double');
    myData.cash = zeros(size(myIsinLabels), 'double');

    for i = 1:size(myIsinLabels, 1)
        t = strcmp(aTrades.ISIN,myIsinLabels(i));
        myData.assets(i) = sum(aTrades.side(t).*aTrades.volume(t));
        myData.cash(i) = sum(-aTrades.side(t).*aTrades.price(t).*aTrades.volume(t));
    end

    for i=1:size(myIsinLabels,1)
        fprintf('%s, ', char(myIsinLabels(i)))
    end
    fprintf('Totals\nAssets: %d, %d, %d\n', myData.assets, sum(myData.assets))
    fprintf('Cash: %.2f, %.2f, %.2f\n\n', myData.cash, sum(myData.cash))
end
