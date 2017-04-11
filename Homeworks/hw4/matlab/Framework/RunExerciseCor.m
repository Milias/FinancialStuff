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

plot(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.l_ask-mean(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.l_ask))
hold on
plot(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.b_ask*100)
plot(myTradingRobot.TriggersData.TrendDetectionTrig.DBK_EUR.b2_ask*5000)
