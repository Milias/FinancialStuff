function RunExerciseArb(aFeed)
  clear myExchange;
  clear myFeedPublisher;
  clear myTradingRobot;

  load(aFeed);

  myExchange = CreateExchangeArb();

  myFeedPublisher = FeedPublisher();
  myExchange.RegisterAutoTrader(myFeedPublisher);
  myFeedPublisher.StartAutoTrader(myExchange);

  myTradingRobot = TradingRobot();
  myExchange.RegisterAutoTrader(myTradingRobot);
  myTradingRobot.StartAutoTrader(myExchange);

  myFeedPublisher.StartFeed(myFeed);

  Report(myTradingRobot.ownTrades);
end
