classdef TradingRobot < AutoTrader
  properties
    AssetMgr
    AlgoParams
    Triggers
    TriggersData
    PerfMeasure
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager;
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});

      % This struct contains basic parameters of the algorithm.
      % max_trading_volume :    maximum amount of shares to hold at any given tick.
      % lookback :              number of past ticks to consider for computations.
      % trigger_params :        several parameters used mainly for triggers.1
      %   dtsmax :              number of ticks we wait before selling stock.
      %   dtbmax :              number of ticks we wait before buying stock.
      %   dthmax :              maximum ticks we hold to the stock.
      %   dssmax :              maximum change of the stock's price before selling.
      %   dsbmax :              change in price before buying.
      self.AlgoParams = struct('max_trading_volume', 100, 'lookback', 10, 'trigger_params', struct('dtsmax', 0, 'dtbmax', 2, 'dthmax', 10, 'dssmax', 0.0, 'dsbmax', 0.0));

      % Here triggers are stored as functions that only take "self" as an argument.
      % TriggersData contains information specific to each function, for bookkeeping.
      self.Triggers = cell(0);
      self.TriggersData = cell(0);

      % Placeholder struct to store performance-related stuff.
      self.PerfMeasure = struct;

      % Initialize triggers.
      self.InitTriggers();
    end
    
    function delete(self)
      % Destructor.
      clear self.AssetMgr;
      clear self.AlgoParams;
      clear self.Triggers;
      clear self.TriggersData;
      clear self.PerfMeasure;
    end

    function InitTriggers(self)
      % BasicBuyTrig : buy stock when movmean(S, [lookback 0]) > S for dtmax ticks. 
      % TODO: how much stock? For now just the first entry.
      self.Triggers{1} = @BasicBuyTrig;
      self.TriggersData{1} = struct('tick_count', 0);

      % BasicSellTrig
      self.Triggers{2} = @BasicSellTrig;
      self.TriggersData{2} = struct;
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);

      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for i = 1:size(self.Triggers, 2)
        self.Triggers{i}(self);
      end
    end

    % Buy when movmean(S_ask, [lookback 0]) < S_bid for dtbmax ticks.
    function BasicBuyTrig(self)
      for i = 1:size(self.AssetMgr.ISINs, 2)
        myISIN = self.AssetMgr.ISINs{i};

        % Get data from the last `lookback` depths.
        myData = self.AssetMgr.GetDataFromHistory(myISIN, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, self.AlgoParams.lookback);

        % Compute the mean weighted with volumes of the ask prices.
        myAskMean = sum(cellfun(@(p, v) sum(p .* v), myData.askLimitPrice, myData.askVolume)) / sum(cell2mat(myData.askVolume'));

        if size(myData.askLimitPrice{end}, 1) && size(myData.bidLimitPrice{end}, 1)
          fprintf('a: %2.2f, b: %2.2f\n', myAskMean, myData.bidLimitPrice{end}(1));
          if myAskMean < myData.bidLimitPrice{end}(1)
            self.TriggersData{1}.tick_count = self.TriggersData{1}.tick_count + 1;
          end

          if self.TriggersData{1}.tick_count == self.AlgoParams.trigger_params.dtbmax
            self.TriggersData{1}.tick_count = 0;
            myVol = self.AlgoParams.max_trading_volume - self.AssetMgr.GetISINVolume(myISIN, 1)
            if myVol > 0
              fprintf('BasicBuyTrig - \n');
              self.Trade(myISIN, myData.askLimitPrice{end}(1), myData.askVolume{end}(1));
            end
          end
        end
      end
    end

    % Basic selling trigger: sell after dthmax ticks or if the price decreases
    % for more than dtsmax ticks.
    function BasicSellTrig(self)
      for myISIN = self.AssetMgr.ISINs
        myISIN = myISIN{1};
        for myTrade = self.AssetMgr.Assets.(myISIN)
          myTrade = myTrade{1};
          if myTrade.volume < 0
            continue
          end
          if self.AssetMgr.CurrentIndex.total - myTrade.index > self.AlgoParams.trigger_params.dthmax
            fprintf('BasicSellTrig - \n');
            self.TradeFullStock(myISIN, -myTrade.volume);
          end
        end
      end
    end 

    function thePrice = ComputeTradingPrice(self, aP, aV)
      aVcs = cumsum(aV);
      myIndex = aVcs < self.AlgoParams.max_trading_volume;
      myNextIndex = find(~myIndex, 1);
      thePrice = (sum(aP(myIndex) .* aV(myIndex)) + aP(myNextIndex)*(aVcs(myNextIndex) - aV)) / (sum(aV(myIndex)) + aVcs(myNextIndex) - aV);
    end

    function [theConfirmation] = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = size(self.ownTrades.price, 1);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      myTradeCount = size(self.ownTrades.price, 1) - myCurrentTrades;
      theConfirmation = myTradeCount > 0;
 
      if theConfirmation
        % Here we iterate over all the trades done (in case aV > first entry's volume),
        % updating our assets and book.
        for i = 1:myTradeCount
          fprintf('Trade: %7s, %3.2f, %3.0f\n', aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));

          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        end
      end
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV < 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end

      myData = self.AssetMgr.GetDataFromHistory(aISIN, myLabels, 0);
      size(myData.(myLabels{1}))
      if size(myData.(myLabels{1}), 2) > 0 && size(myData.(myLabels{2}), 2) > 0
        disp(myData.(myLabels{1}){end})
        disp(myData.(myLabels{2}){end})
        myVol = abs(aV) - [ 0 ; cumsum(myData.(myLabels{2}){1}) ]
        myIndex = myVol > 0
        arrayfun(@(p, v) self.Trade(aISIN, p, sign(aV)*v), myData.(myLabels{1}){1}(myIndex(1:end-1)), sign(aV) * myVol(myIndex(1:end-1)));
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for myISIN = self.AssetMgr.ISINs
        myISIN = myISIN{1};
        for myTrade = self.AssetMgr.Assets.(myISIN)
          myTrade = myTrade{1};
          % self.Trade(myISIN, myTrade.price, -myTrade.volume);
        end
      end

      self.AssetMgr.delete();
    end
  end
end
