clear myExchange;
clear myFeedPublisher;
clear myTradingRobot;

load('AKZA5.mat');

myExchange = CreateExchangeArb();

myFeedPublisher = FeedPublisher();
myExchange.RegisterAutoTrader(myFeedPublisher);
myFeedPublisher.StartAutoTrader(myExchange);

myTradingRobot = TradingRobot();
myExchange.RegisterAutoTrader(myTradingRobot);
myTradingRobot.StartAutoTrader(myExchange);

myFeedPublisher.StartFeed(myFeed);

Report(myTradingRobot.ownTrades);
