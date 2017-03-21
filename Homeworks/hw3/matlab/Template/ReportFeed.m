function ReportFeed(aFeedRobot)
  myIsinLabels = {'EUR_AKZA', 'CHI_AKZA'};

  myX = 1:size(aFeedRobot.DepthHistory, 2);

  myIsins = arrayfun(@(x) x.ISIN, aFeedRobot.DepthHistory, 'UniformOutput', false);
  myIndex = [ strcmp(myIsins, myIsinLabels(1)) ; strcmp(myIsins, myIsinLabels(2)) ];

  myAskEUR = arrayfun(@(aDepth) sum(aDepth.askLimitPrice .* aDepth.askVolume) / sum(aDepth.askVolume) / (strcmp(aDepth.ISIN,myIsinLabels(1))), aFeedRobot.DepthHistory);

  myAskCHI = arrayfun(@(aDepth) sum(aDepth.askLimitPrice .* aDepth.askVolume) / sum(aDepth.askVolume) / (strcmp(aDepth.ISIN,myIsinLabels(2))), aFeedRobot.DepthHistory);

  myBidEUR = arrayfun(@(aDepth) sum(aDepth.bidLimitPrice .* aDepth.bidVolume) / sum(aDepth.bidVolume) / (strcmp(aDepth.ISIN,myIsinLabels(1))), aFeedRobot.DepthHistory);

  myBidCHI = arrayfun(@(aDepth) sum(aDepth.bidLimitPrice .* aDepth.bidVolume) / sum(aDepth.bidVolume) / (strcmp(aDepth.ISIN,myIsinLabels(2))), aFeedRobot.DepthHistory);

  plot(myX, myAskEUR, 'r-', myX, myBidEUR, 'b-', myX, myAskCHI, 'k-', myX, myBidCHI, 'g-', 'LineWidth', 2)
  legend('ask\_EUR', 'bid\_EUR', 'ask\_CHI', 'bid\_CHI');
end
