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

myFeedPublisher.StartFeed(myFeed);

myTradingRobot.Unwind();
%ReportFeedHist(myTradingRobot);
Report(myTradingRobot.ownTrades);
