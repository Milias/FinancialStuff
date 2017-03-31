clear myExchange;
clear myFeedPublisher;
clear myTradingRobot;

load('CBKDBK1.mat');

myExchange = CreateExchangeCor();

myFeedPublisher = FeedPublisher();
myExchange.RegisterAutoTrader(myFeedPublisher);
myFeedPublisher.StartAutoTrader(myExchange);

myTradingRobot = TradingRobot();
myExchange.RegisterAutoTrader(myTradingRobot);
myTradingRobot.StartAutoTrader(myExchange);

myFeedPublisher.StartShortFeed(myFeed);

myTradingRobot.Unwind();
%ReportFeed(myTradingRobot);
Report(myTradingRobot.ownTrades);
