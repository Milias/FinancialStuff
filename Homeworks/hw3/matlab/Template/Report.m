function Report(aTrades)
    % Report the cash and position given the trades
    myIsinLabels = unique(aTrades.ISIN);

    myTimePerf = struct('assets', [], 'cash', []);
    myTimePerf.assets = cumsum(aTrades.side .* aTrades.volume);
    myTimePerf.cash = cumsum(- aTrades.side .* aTrades.price .* aTrades.volume);

    x = 1:size(myTimePerf.assets, 1);
    plot(x, myTimePerf.assets, 'r-', x, myTimePerf.cash, 'b-', 'LineWidth', 2)

    myData = struct('assets', [ 0 0 ], 'cash', [ 0 0 ]);

    for i = 1:size(myIsinLabels, 1)
        t = strcmp(aTrades.ISIN,myIsinLabels(i));
        myData.assets(i) = sum(aTrades.side(t).*aTrades.volume(t));
        myData.cash(i) = sum(-aTrades.side(t).*aTrades.price(t).*aTrades.volume(t));
    end

    for i=1:size(myIsinLabels,1)
        fprintf('%9s, ', char(myIsinLabels(i)))
    end
    fprintf('%9s\n%9d, %9d, %9d\n', 'Totals', myData.assets, sum(myData.assets))
    fprintf('%9.2f, %9.2f, %9.2f\n', myData.cash, sum(myData.cash))
end
