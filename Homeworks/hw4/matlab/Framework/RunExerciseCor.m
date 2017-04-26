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

%myFeedPublisher.StartFeed(FeedSubset(myFeed, 2000));
myFeedPublisher.StartFeed(myFeed);

myTradingRobot.Unwind();
Report(myTradingRobot.ownTrades);

function theFeed = FeedSubset(aFeed, aT)
  theFeed = struct;
  myFieldNames = fieldnames(aFeed);
  for i = 1:length(myFieldNames)
    field = myFieldNames{i};
    theFeed.(field) = aFeed.(field)(1:aT);
  end
end