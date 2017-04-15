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

level = cellfun(@(wa) wa(1, 1), myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.wa);
trend = cellfun(@(wa) wa(1, 2), myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.wa);
dtrend = cellfun(@(wa) wa(1, 3), myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.wa);
ask = cellfun(@(wa) wa(5, 1), myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.wa);

firstIdx = find(level>0, 1);
level = level(firstIdx:end);
trend = trend(firstIdx:end);
dtrend = dtrend(firstIdx:end);
ask = ask(firstIdx:end);

mtrend = max(trend);
mdtrend = max(dtrend);

plot(trend/mtrend, 'LineWidth', 2, 'Color', 'green')
hold on
plot(dtrend/mdtrend, 'LineWidth', 2, 'Color', 'blue')
plot(level-mean(level), 'LineWidth', 3, 'Color', 'red')
plot(ask-mean(ask), '-', 'LineWidth', 1, 'Color', 'black')
hold off