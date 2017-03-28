function Report(aTrades)
    % Report the cash and position given the trades
    myIsinLabels = unique(aTrades.ISIN);

    myTimePerf = struct('assets', [], 'cash', []);
    myTimePerf.assets = cumsum(aTrades.side .* aTrades.volume);
    myTimePerf.cash = cumsum(- aTrades.side .* aTrades.price .* aTrades.volume);

    x = 1:size(myTimePerf.assets, 1);
    %plot(x, myTimePerf.assets, 'r-', x, myTimePerf.cash, 'b-', 'LineWidth', 2)

    myData = struct('assets', [ 0 0 ; 0 0 ], 'cash', [ 0 0 ; 0 0 ]);

    for i = 1:size(myIsinLabels, 1)
        t = strcmp(aTrades.ISIN, myIsinLabels(i));
        myData.assets(1, i) = sum(aTrades.volume(logical(t .* (aTrades.side > 0))));
        myData.assets(2, i) = sum(- aTrades.volume(logical(t .* (aTrades.side < 0))));
        myData.cash(1, i) = sum(- aTrades.price(logical(t .* (aTrades.side > 0))) .* aTrades.volume(logical(t .* (aTrades.side > 0))));
        myData.cash(2, i) = sum( aTrades.price(logical(t .* (aTrades.side < 0))) .* aTrades.volume(logical(t .* (aTrades.side < 0))));
    end

    for i=1:size(myIsinLabels,1)
        fprintf('%18s, ', char(myIsinLabels(i)))
    end
    %fprintf('%9s\n%9d/%8d, %9d/%8d, %9d\n', 'Totals', myData.assets, sum(sum(myData.assets)))
    %fprintf('%9.2f/%8.2f, %9.2f/%8.2f, %9.2f\n', myData.cash, sum(sum(myData.cash)))

    fprintf('%9s\n & %9d & %8d & %9d & %8d & %9d \\\\ \\hline\n', 'Totals', myData.assets, sum(sum(myData.assets)))
    fprintf(' & %9.2f & %8.2f & %9.2f & %8.2f & %9.2f \\\\ \\hline\n', myData.cash, sum(sum(myData.cash)))
end
