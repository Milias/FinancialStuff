classdef TradingRobot < AutoTrader
  properties
    EURDepth
    CHIDepth

    myAssets
    
  end

  methods
    function aBot = TradingRobot
      aBot.myAssets = struct('EUR', struct('price', [], 'volume', []), 'CHI', struct('price', [], 'volume', []));
    end

    function HandleDepthUpdate(aBot, ~, aDepth)
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

    function theVolume = GetCurrentVolume(aBot, aISIN, aP)
    switch aISIN
      case 'EUR_AKZA'
        myIndex = find(aBot.myAssets.EUR.price == aP);
        if myIndex
          theVolume = aBot.myAssets.EUR.volume(myIndex);
        else
          theVolume = 0;
        end
      case 'CHI_AKZA'
        myIndex = find(aBot.myAssets.CHI.price == aP);
        if myIndex
          theVolume = aBot.myAssets.CHI.volume(myIndex);
        else
          theVolume = 0;
        end
    end
    end

    function UpdateAssets(aBot, aISIN, aP, aV)
      disp(aISIN)
      switch aISIN
        case 'EUR_AKZA'
          myIndex = find(aBot.myAssets.EUR.price == aP);
          if myIndex
            aBot.myAssets.EUR.volume(myIndex) = aBot.myAssets.EUR.volume(myIndex) + aV;
          else
            aBot.myAssets.EUR.price = [ aBot.myAssets.EUR.price aP ];
            aBot.myAssets.EUR.volume = [ aBot.myAssets.EUR.volume aV ];
          end

          disp(aBot.myAssets.EUR)
        case 'CHI_AKZA'
          myIndex = find(aBot.myAssets.CHI.price == aP);
          if myIndex
            aBot.myAssets.CHI.volume(myIndex) = aBot.myAssets.CHI.volume(myIndex) + aV;
          else
            aBot.myAssets.CHI.price = [ aBot.myAssets.CHI.price aP ];
            aBot.myAssets.CHI.volume = [ aBot.myAssets.CHI.volume aV ];
          end

          disp(aBot.myAssets.CHI)
        end
    end

    function Buy(aBot, aISIN, aP, aV)
      myCurrentTrades = size(aBot.ownTrades.price, 1);
      aBot.SendNewOrder(aP, aV, 1, {aISIN}, {'IMMEDIATE'}, 0);
      if size(aBot.ownTrades.price, 1) > myCurrentTrades
        aBot.UpdateAssets(aISIN, int32(aP * 100), int32(aV))
      end
    end

    function Sell(aBot, aISIN, aP, aV)
      myCurrentTrades = size(aBot.ownTrades.price, 1);
      aBot.SendNewOrder(aP, aV, -1, {aISIN}, {'IMMEDIATE'}, 0);
      if size(aBot.ownTrades.price, 1) > myCurrentTrades
        aBot.UpdateAssets(aISIN, int32(aP * 100), -int32(aV))
      end
    end

    function CHIArbitrage(aBot)
      for i = 1:size(aBot.CHIDepth.bidLimitPrice, 1)
        aBot.Sell('CHI_AKZA', aBot.CHIDepth.bidLimitPrice(i), aBot.CHIDepth.bidVolume(i));
      end
    end

    function EURArbitrage(aBot)
      for i = 1:size(aBot.EURDepth.askLimitPrice, 1)
        aBot.Buy('EUR_AKZA', aBot.EURDepth.askLimitPrice(i), aBot.EURDepth.askVolume(i));
      end
    end
  end
end
