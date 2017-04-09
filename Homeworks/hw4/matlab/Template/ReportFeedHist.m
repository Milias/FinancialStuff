function ReportFeed(aFeedRobot)
  myIsinLabels = unique(cellfun(@(aDepth) aDepth.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false));

  myX = 1:length(aFeedRobot.DepthHistory);

  myIsins = cellfun(@(x) x.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false);
  myIndex = cellfun(@(x) strcmp(myIsins, x), myIsinLabels, 'UniformOutput', false);

  myNotEmptyAsk = logical(cellfun(@(depth) length(depth.askVolume), aFeedRobot.DepthHistory));
  myNotEmptyBid = logical(cellfun(@(depth) length(depth.bidVolume), aFeedRobot.DepthHistory));

  myNEIdx = find(myNotEmptyAsk | myNotEmptyBid);

  for ni = 1:nnz(myNotEmptyAsk | myNotEmptyBid)
    i = myNEIdx(ni);
    figure('Visible','off')
    bar([ aFeedRobot.DepthHistory{i}.askLimitPrice ; aFeedRobot.DepthHistory{i}.bidLimitPrice ], [ aFeedRobot.DepthHistory{i}.askVolume ; aFeedRobot.DepthHistory{i}.bidVolume ]);
    saveas(gcf, strcat('tex/graphs/CBKDBK1_hist/',int2str(ni)), 'png')
  end
end

