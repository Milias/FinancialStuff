classdef TradingRobot < AutoTrader
  properties
    EURDepth
    CHIDepth

    Assets
    Prices
  end

  methods
    function aBot = TradingRobot
      aBot.Assets = struct('price', [], 'volume', [], 'total_volume', 0);
      aBot.Prices = struct('EUR', struct('bid', [], 'ask', []), 'CHI', struct('bid', [], 'ask', []));
    end

    function HandleDepthUpdate(aBot, ~, aDepth)
      % Saves mean price
      aBot.UpdatePrices(aDepth)

      % Saves last depth
      switch aDepth.ISIN
      case 'EUR_AKZA'
        aBot.EURDepth = aDepth;
        aBot.EURArbitrage();
      case 'CHI_AKZA'
        aBot.CHIDepth = aDepth;
        aBot.CHIArbitrage();
      end
    end

    function theVolume = GetCurrentVolume(aBot, aP)
      myIndex = find(aBot.Assets.price == aP);
      if myIndex
        theVolume = aBot.Assets.volume(myIndex);
      else
        theVolume = 0;
      end
    end

    function theIndices = GetIndicesLowerThan(aBot, aP)
      theIndices = aBot.Assets.price < int32(100*aP);
    end

    function theMeanPrice = GetMeanPrice(aBot, prices, volume)
      theMeanPrice = sum(prices.*volume)/sum(volume);
    end

    function UpdatePrices(aBot, aDepth)
      myBidMean = aBot.GetMeanPrice(aDepth.bidLimitPrice, aDepth.bidVolume);
      myAskMean = aBot.GetMeanPrice(aDepth.askLimitPrice, aDepth.askVolume);

      switch aDepth.ISIN
      case 'CHI_AKZA'
        if size(aDepth.bidVolume, 1)
          aBot.Prices.CHI.bid = [ aBot.Prices.CHI.bid myBidMean ];
        else
          aBot.Prices.CHI.bid = [ aBot.Prices.CHI.bid aBot.Prices.CHI.bid(end) ];
        end

        if size(aDepth.askVolume, 1)
          aBot.Prices.CHI.ask = [ aBot.Prices.CHI.ask myAskMean ];
        else
          aBot.Prices.CHI.ask = [ aBot.Prices.CHI.ask aBot.Prices.CHI.ask(end) ];
        end

        aBot.Prices.EUR.bid = [ aBot.Prices.EUR.bid aBot.Prices.EUR.bid(end) ];
        aBot.Prices.EUR.ask = [ aBot.Prices.EUR.ask aBot.Prices.EUR.ask(end) ];

      case 'EUR_AKZA'
        if size(aDepth.bidVolume, 1)
          aBot.Prices.EUR.bid = [ aBot.Prices.EUR.bid myBidMean ];
        else
          aBot.Prices.EUR.bid = [ aBot.Prices.EUR.bid aBot.Prices.EUR.bid(end) ];
        end

        if size(aDepth.askVolume, 1)
          aBot.Prices.EUR.ask = [ aBot.Prices.EUR.ask myAskMean ];
        else
          aBot.Prices.EUR.ask = [ aBot.Prices.EUR.ask aBot.Prices.EUR.ask(end) ];
        end

        aBot.Prices.CHI.bid = [ aBot.Prices.CHI.bid aBot.Prices.CHI.bid(end) ];
        aBot.Prices.CHI.ask = [ aBot.Prices.CHI.ask aBot.Prices.CHI.ask(end) ];
      end
    end

    function UpdateAssets(aBot, aP, aV)
      myIndex = find(aBot.Assets.price == aP);
      if myIndex
        aBot.Assets.volume(myIndex) = aBot.Assets.volume(myIndex) + aV;
      else
        aBot.Assets.price = [ aBot.Assets.price aP ];
        aBot.Assets.volume = [ aBot.Assets.volume aV ];
      end

      aBot.Assets.total_volume = aBot.Assets.total_volume + aV;
    end

    function Buy(aBot, aISIN, aP, aV)
      myCurrentTrades = size(aBot.ownTrades.price, 1);

      aBot.SendNewOrder(aP, aV, 1, {aISIN}, {'IMMEDIATE'}, 0);

      if size(aBot.ownTrades.price, 1) > myCurrentTrades
        aBot.UpdateAssets(int32(aP * 100), int32(aV))
      end
    end

    function Sell(aBot, aISIN, aP, aV)
      % Making sure we don't sell more than what we have
      aV = min(max(aBot.Assets.total_volume, 0), aV);

      myCurrentTrades = size(aBot.ownTrades.price, 1);

      aBot.SendNewOrder(aP, aV, -1, {aISIN}, {'IMMEDIATE'}, 0);

      if size(aBot.ownTrades.price, 1) > myCurrentTrades
        aBot.UpdateAssets(int32(aP * 100), -int32(aV))
      end
    end

    function CHIArbitrage(aBot)
      myTrades = aBot.EURDepth.bidLimitPrice > aBot.CHIDepth.askLimitPrice(1);
      myVolume = min(aBot.CHIDepth.askVolume(1), sum(aBot.EURDepth.bidVolume(myTrades)));
      aBot.Buy('CHI_AKZA', aBot.CHIDepth.askLimitPrice(1), myVolume);
      aBot.Sell('EUR_AKZA', aBot.CHIDepth.askLimitPrice(1), myVolume);

      for i = 1:size(aBot.CHIDepth.askLimitPrice, 1)
      end
    end

    function EURArbitrage(aBot)
      for i = 1:size(aBot.EURDepth.bidLimitPrice, 1)
        myIndex = aBot.GetIndicesLowerThan(aBot.EURDepth.bidLimitPrice(i));
        aBot.Sell('EUR_AKZA', aBot.EURDepth.bidLimitPrice(i), min(aBot.EURDepth.bidVolume(i), sum(aBot.Assets.volume(myIndex))));
      end
    end
  end
end
