function ReportFeed(aFeedRobot)
  myIsinLabels = unique(arrayfun(@(aDepth) aDepth.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false));

  myX = 1:size(aFeedRobot.DepthHistory, 2);

  myIsins = arrayfun(@(x) x.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false);
  myIndex = arrayfun(@(x) strcmp(myIsins, x), myIsinLabels, 'UniformOutput', false);

  % In first instance we plot the weighted average of both ask and bid entries.
  myValues = arrayfun(@(aDepth) sum([ aDepth.askLimitPrice .* aDepth.askVolume ; aDepth.bidLimitPrice .* aDepth.bidVolume ]) / (sum(aDepth.askVolume) + sum(aDepth.bidVolume)), aFeedRobot.DepthHistory);

  for i=1:size(myIsinLabels, 2)
    myIndexLogical = cell2mat(myIndex(i));
    plot(myX(myIndexLogical & ~isnan(myValues)), myValues(myIndexLogical & ~isnan(myValues)), '-', 'LineWidth', 3);
    hold on
  end
  
  hold off
  legend(myIsinLabels)

end

