clear myExchange;
clear myFeedPublisher;
clear myTradingRobot;

load('AKZA1.mat');

myExchange = CreateExchangeArb();

myFeedPublisher = FeedPublisher();
myExchange.RegisterAutoTrader(myFeedPublisher);
myFeedPublisher.StartAutoTrader(myExchange);

myTradingRobot = PlotFeedRobot();
myExchange.RegisterAutoTrader(myTradingRobot);
myTradingRobot.StartAutoTrader(myExchange);

myFeedPublisher.StartVeryShortFeed(myFeed);

Report(myTradingRobot.ownTrades);
%ReportFeed(myTradingRobot)
