function ReportFeed(aFeedRobot)
  myIsinLabels = unique(arrayfun(@(aDepth) aDepth.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false));

  myX = 1:size(aFeedRobot.DepthHistory, 2);

  myIsins = arrayfun(@(x) x.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false);
  myIndex = arrayfun(@(x) strcmp(myIsins, x), myIsinLabels, 'UniformOutput', false);

  % In first instance we plot the weighted average of both ask and bid entries.
  myValues = arrayfun(@(aDepth) sum([ aDepth.askLimitPrice .* aDepth.askVolume ; aDepth.bidLimitPrice .* aDepth.bidVolume ]) / (sum(aDepth.askVolume) + sum(aDepth.bidVolume)), aFeedRobot.DepthHistory);

  % Remove NaN (no entries in the book)
  myNotNaN = ~isnan(myValues);
  myX = myX(myNotNaN);
  myValues = myValues(myNotNaN);
  for i=1:size(myIsinLabels, 2)
    localIndex = cell2mat(myIndex(i));
    localIndex = localIndex(myNotNaN);
    myIndex(i) = {localIndex};
  end

  for i=1:size(myIsinLabels, 2)
    myIndexLogical = cell2mat(myIndex(i));
    localX = myX(myIndexLogical);
    localY1 = myValues(myIndexLogical);

    % Compute the moving average.
    localY1mv = movmean(localY1, [10, 0]);

    % Compute movmean(S) - S
    localY = localY1mv - mean(localY1mv);

    % Compute the sorta derivative of the price. ~dS/S
    % NOTE: too erratic, maybe moving average?
    %localY = zeros(size(localY1));
    %localY(1) = (localY1(2)-localY1(2))/localY1(1);
    %localY(2:end) = (localY1(2:end) - localY1(1:end-1)) ./ localY1(2:end);

    % localY = localY - mean(localY);
    plot(localX, localY, '-', 'LineWidth', 3);
    hold on
  end
  
  hold off
  legend(myIsinLabels)

end

