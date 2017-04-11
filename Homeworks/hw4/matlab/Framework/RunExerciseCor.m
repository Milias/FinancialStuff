clear myExchange;
clear myFeedPublisher;
clear myTradingRobot;

load('CBKDBK1.mat');

myExchange = CreateExchangeCor();

myFeedPublisher = FeedPublisher();
myExchange.RegisterAutoTrader(myFeedPublisher);
myFeedPublisher.StartAutoTrader(myExchange);

%myTradingRobot = PlotFeedRobot(); 
myTradingRobot = TradingRobot();
myExchange.RegisterAutoTrader(myTradingRobot);
myTradingRobot.StartAutoTrader(myExchange);

myFeedPublisher.StartShortFeed(myFeed);

myTradingRobot.Unwind();
%ReportFeedHist(myTradingRobot);
Report(myTradingRobot.ownTrades);

plot(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.l_ask-mean(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.l_ask), 'LineWidth', 3, 'Color', 'red')
hold on
plot(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.b_ask*100, 'LineWidth', 3, 'Color', 'blue')
plot(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.b2_ask*5000, 'LineWidth', 3, 'Color', 'green')
%plot(cellfun(@GetFirst, myTradingRobot.AssetMgr.DepthHistory.DBK_EUR) - mean(cellfun(@GetFirst, myTradingRobot.AssetMgr.DepthHistory.DBK_EUR)), 'LineWidth', 3, 'Color', 'yellow')

function v = GetFirst(depth)
  if ~isempty(depth.askLimitPrice)
    v = depth.askLimitPrice(1);
  else
    v = 0.0;
  end
end